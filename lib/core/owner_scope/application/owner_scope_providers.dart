import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/auth/application/providers/auth_providers.dart';
import '../../../features/auth/domain/entities/auth_user.dart';
import '../../database/app_database.dart';
import '../../database/app_database_provider.dart';
import '../../sync/application/backup_operation_fence.dart';
import '../domain/owner_scope.dart';
import 'owner_scope_health_service.dart';
import 'legacy_data_claim_service.dart';
import 'scoped_app_database_session.dart';

abstract interface class OwnerScopeDetachService {
  Future<void> detach(String ownerScopeValue);
}

final ownerScopeDetachServiceProvider = Provider<OwnerScopeDetachService>(
  (ref) => DriftOwnerScopeDetachService(
    ref.watch(appDatabaseProvider),
    ref.watch(backupOperationFenceProvider),
  ),
  name: 'ownerScopeDetachServiceProvider',
);

final class DriftOwnerScopeDetachService implements OwnerScopeDetachService {
  const DriftOwnerScopeDetachService(this._database, this._operationFence);

  final AppDatabase _database;
  final BackupOperationFence _operationFence;

  @override
  Future<void> detach(String ownerScopeValue) async {
    final lease = await _operationFence.fenceAndDrainForOwnerTransition(
      ownerScopeValue: ownerScopeValue,
      operationId: const Uuid().v7(),
    );
    try {
      final now = DateTime.now().toUtc();
      await _database.transaction(() async {
        await _database.customUpdate(
          '''UPDATE ai_agent_commands
           SET status = 'cancelled', updated_at = ?
           WHERE owner_scope_id = ? AND status IN (
             'proposed', 'resolving', 'needsClarification',
             'readyForPreview', 'awaitingConfirmation', 'confirmed'
           )''',
          variables: <Variable<Object>>[
            Variable<DateTime>(now),
            Variable<String>(ownerScopeValue),
          ],
        );
        await _database.customUpdate(
          "UPDATE ai_agent_plans SET status = 'cancelled', updated_at = ? "
          'WHERE owner_scope_id = ? AND status NOT IN '
          "('succeeded', 'partiallySucceeded', 'failed', 'cancelled', 'expired')",
          variables: <Variable<Object>>[
            Variable<DateTime>(now),
            Variable<String>(ownerScopeValue),
          ],
        );
        await _database.customUpdate(
          'DELETE FROM ai_agent_confirmation_proofs WHERE owner_scope_id = ?',
          variables: <Variable<Object>>[Variable<String>(ownerScopeValue)],
        );
      });
    } finally {
      lease.release();
    }
  }
}

final confirmedOwnerScopeSnapshotProvider =
    NotifierProvider<ConfirmedOwnerScopeController, OwnerScopeSnapshot>(
      ConfirmedOwnerScopeController.new,
      name: 'confirmedOwnerScopeSnapshotProvider',
    );

class ConfirmedOwnerScopeController extends Notifier<OwnerScopeSnapshot> {
  String? _activeScopeValue;
  int? _activeAuthSessionGeneration;
  Future<void> _transitionBarrier = Future<void>.value();
  int _requestedTransition = 0;
  bool _transitionBlocked = false;

  @override
  OwnerScopeSnapshot build() {
    final initialAuth = ref.read(authStateProvider);
    final initial = _mapAuth(initialAuth);
    _activeScopeValue = initial.scope?.id.value;
    _activeAuthSessionGeneration = initialAuth.value?.authSessionGeneration;
    _transitionBarrier = Future<void>.value();
    _requestedTransition = 0;
    _transitionBlocked = false;
    ref.listen(authStateProvider, (_, next) {
      if (next.isLoading && state.hasConfirmedScope) {
        // Token refresh/loading does not switch the active identity.
        return;
      }
      final mapped = _mapAuth(next);
      final nextGeneration = next.value?.authSessionGeneration;
      if (mapped.status == OwnerScopeStatus.safe &&
          state.status == OwnerScopeStatus.safe &&
          mapped.scope?.id.value == _activeScopeValue &&
          nextGeneration == _activeAuthSessionGeneration) {
        return;
      }
      final request = ++_requestedTransition;
      // Revoke the old epoch synchronously. No new scoped session is exposed
      // until every detach requested before this auth event has completed.
      state = const OwnerScopeSnapshot.initializing();
      _transitionBarrier = _transitionBarrier.then(
        (_) => _applyTransition(mapped, request, nextGeneration),
      );
    });
    return initial;
  }

  Future<void> _applyTransition(
    OwnerScopeSnapshot mapped,
    int request,
    int? nextAuthSessionGeneration,
  ) async {
    if (_transitionBlocked) {
      if (ref.mounted && request == _requestedTransition) {
        state = const OwnerScopeSnapshot(
          status: OwnerScopeStatus.unavailable,
          failure: OwnerScopeFailure.integrityCheckFailed,
        );
      }
      return;
    }
    final nextScope = mapped.scope?.id.value;
    try {
      final previousScope = _activeScopeValue;
      if (previousScope != null &&
          (previousScope != nextScope ||
              _activeAuthSessionGeneration != nextAuthSessionGeneration)) {
        await ref.read(ownerScopeDetachServiceProvider).detach(previousScope);
        _activeScopeValue = null;
        _activeAuthSessionGeneration = null;
      }
      if (!ref.mounted || request != _requestedTransition) return;
      _activeScopeValue = nextScope;
      _activeAuthSessionGeneration = nextAuthSessionGeneration;
      state = mapped;
    } on Object {
      _activeScopeValue = null;
      _activeAuthSessionGeneration = null;
      _transitionBlocked = true;
      if (ref.mounted) {
        state = const OwnerScopeSnapshot(
          status: OwnerScopeStatus.unavailable,
          failure: OwnerScopeFailure.integrityCheckFailed,
        );
      }
    }
  }

  OwnerScopeSnapshot _mapAuth(AsyncValue<dynamic> auth) {
    if (auth.isLoading) {
      return const OwnerScopeSnapshot.initializing();
    }
    if (auth.hasError) {
      return const OwnerScopeSnapshot(
        status: OwnerScopeStatus.unavailable,
        failure: OwnerScopeFailure.authUnavailable,
      );
    }
    final user = auth.value;
    if (user == null) {
      return const OwnerScopeSnapshot(
        status: OwnerScopeStatus.unauthenticated,
        failure: OwnerScopeFailure.authNotConfirmed,
      );
    }
    final tenantId = user.tenantId;
    if (tenantId != null) {
      return const OwnerScopeSnapshot(
        status: OwnerScopeStatus.corrupted,
        failure: OwnerScopeFailure.integrityCheckFailed,
      );
    }
    try {
      final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(user.uid);
      return OwnerScopeSnapshot(
        status: OwnerScopeStatus.safe,
        scope: scope,
        authSessionGeneration: user.authSessionGeneration,
      );
    } on ArgumentError {
      return const OwnerScopeSnapshot(
        status: OwnerScopeStatus.corrupted,
        failure: OwnerScopeFailure.integrityCheckFailed,
      );
    }
  }
}

final confirmedOwnerScopeProvider = Provider<ConfirmedOwnerScope?>((ref) {
  return ref.watch(
    confirmedOwnerScopeSnapshotProvider.select((state) => state.scope),
  );
}, name: 'confirmedOwnerScopeProvider');

final scopedAppDatabaseSessionProvider = Provider<ScopedAppDatabaseSession?>((
  ref,
) {
  final scope = ref.watch(confirmedOwnerScopeSnapshotProvider).scope;
  if (scope == null) {
    return null;
  }
  final session = ScopedAppDatabaseSession(
    database: ref.watch(appDatabaseProvider),
    scope: scope,
    operationFence: ref.watch(backupOperationFenceProvider),
  );
  ref.onDispose(session.invalidate);
  return session;
}, name: 'scopedAppDatabaseSessionProvider');

final requiredScopedAppDatabaseSessionProvider =
    Provider<ScopedAppDatabaseSession>((ref) {
      final session = ref.watch(scopedAppDatabaseSessionProvider);
      if (session == null) {
        throw const OwnerScopeException(
          OwnerScopeFailure.scopedSessionUnavailable,
        );
      }
      return session;
    }, name: 'requiredScopedAppDatabaseSessionProvider');

final ownerScopeHealthServiceProvider = Provider<OwnerScopeHealthService>(
  (ref) => OwnerScopeHealthService(ref.watch(appDatabaseProvider)),
  name: 'ownerScopeHealthServiceProvider',
);

final ownerScopeHealthProvider = FutureProvider<OwnerScopeHealth>((ref) async {
  final snapshot = ref.watch(confirmedOwnerScopeSnapshotProvider);
  final session = ref.watch(scopedAppDatabaseSessionProvider);
  return ref
      .watch(ownerScopeHealthServiceProvider)
      .evaluate(snapshot: snapshot, session: session);
}, name: 'ownerScopeHealthProvider');

final legacyDataClaimServiceProvider = Provider<LegacyDataClaimService>((ref) {
  return LegacyDataClaimService(
    session: ref.watch(requiredScopedAppDatabaseSessionProvider),
    currentConfirmedScope: () => ref.read(confirmedOwnerScopeProvider),
  );
}, name: 'legacyDataClaimServiceProvider');

final legacyDataInventoryProvider = FutureProvider<LegacyDataInventory>((ref) {
  return ref.watch(legacyDataClaimServiceProvider).inspectBoundedCounts();
}, name: 'legacyDataInventoryProvider');

final legacyDataClaimControllerProvider =
    AsyncNotifierProvider<LegacyDataClaimController, LegacyDataClaimResult?>(
      LegacyDataClaimController.new,
      name: 'legacyDataClaimControllerProvider',
    );

class LegacyDataClaimController extends AsyncNotifier<LegacyDataClaimResult?> {
  var _operationVersion = 0;

  @override
  Future<LegacyDataClaimResult?> build() async {
    // Rebuild to a neutral state for every auth epoch. A same-owner scoped
    // session can be intentionally rotated after a successful claim so every
    // cached owner-scoped repository sees the newly bound rows immediately.
    // In-flight work still captures and validates the exact database session.
    ref.watch(currentAuthUserProvider);
    _operationVersion += 1;
    return null;
  }

  Future<bool> claim({required bool protectedConfirmationAccepted}) async {
    if (!protectedConfirmationAccepted || state.isLoading) return false;
    final binding = _captureBinding();
    if (binding == null) return false;
    final service = ref.read(legacyDataClaimServiceProvider);
    final operationVersion = ++_operationVersion;
    var currentBinding = binding;
    state = const AsyncLoading();
    try {
      final result = await service.claim(protectedConfirmationAccepted: true);
      if (!_isCurrent(currentBinding, operationVersion)) {
        return false;
      }

      ref.invalidate(ownerScopeHealthProvider);
      final health = await ref.read(ownerScopeHealthProvider.future);
      if (!_isCurrent(currentBinding, operationVersion)) {
        return false;
      }
      if (!health.isSafe) {
        throw OwnerScopeException(
          health.failure ?? OwnerScopeFailure.integrityCheckFailed,
        );
      }

      // Rotate only after the guarded transaction has committed and the old
      // session has independently verified the result. This invalidates every
      // repository/provider rooted in requiredScopedAppDatabaseSessionProvider
      // so the assistant immediately sees claimed accounts and categories.
      final expectedAuthSession = currentBinding.authSession;
      final expectedOwnerScopeValue = currentBinding.ownerScopeValue;
      ref.invalidate(scopedAppDatabaseSessionProvider);
      final refreshedBinding = _captureBinding();
      if (refreshedBinding == null ||
          refreshedBinding.authSession != expectedAuthSession ||
          refreshedBinding.ownerScopeValue != expectedOwnerScopeValue) {
        return false;
      }
      currentBinding = refreshedBinding;

      ref.invalidate(legacyDataInventoryProvider);
      final refreshedInventory = await ref.read(
        legacyDataInventoryProvider.future,
      );
      if (!_isCurrent(currentBinding, operationVersion)) {
        return false;
      }
      if (refreshedInventory.hasLegacyData ||
          refreshedInventory.hasUnexpectedSyncQueueRows) {
        throw const OwnerScopeException(OwnerScopeFailure.integrityCheckFailed);
      }

      ref.invalidate(ownerScopeHealthProvider);
      final refreshedHealth = await ref.read(ownerScopeHealthProvider.future);
      if (!_isCurrent(currentBinding, operationVersion)) {
        return false;
      }
      if (!refreshedHealth.isSafe) {
        throw OwnerScopeException(
          refreshedHealth.failure ?? OwnerScopeFailure.integrityCheckFailed,
        );
      }

      state = AsyncData(result);
      return true;
    } on Object catch (error, stackTrace) {
      if (!_isCurrent(currentBinding, operationVersion)) {
        return false;
      }
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  _LegacyClaimBinding? _captureBinding() {
    final authUser = ref.read(currentAuthUserProvider);
    final session = ref.read(scopedAppDatabaseSessionProvider);
    if (authUser == null || session == null || !session.isActive) {
      return null;
    }
    try {
      final expectedScope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
        authUser.uid,
      );
      if (session.ownerScopeValue != expectedScope.id.value) {
        return null;
      }
    } on Object {
      return null;
    }
    return _LegacyClaimBinding(
      authSession: authUser.sessionIdentity,
      databaseSession: session,
      ownerScopeValue: session.ownerScopeValue,
    );
  }

  bool _isCurrent(_LegacyClaimBinding expected, int operationVersion) {
    if (!ref.mounted || operationVersion != _operationVersion) {
      return false;
    }
    final currentAuth = ref.read(currentAuthUserProvider);
    final currentSession = ref.read(scopedAppDatabaseSessionProvider);
    if (!expected.authSession.matches(currentAuth) ||
        !identical(expected.databaseSession, currentSession) ||
        !expected.databaseSession.isActive) {
      return false;
    }
    try {
      return expected.databaseSession.ownerScopeValue ==
          OwnerScopeDerivation.fromConfirmedFirebaseUid(
            expected.authSession.uid,
          ).id.value;
    } on Object {
      return false;
    }
  }
}

final class _LegacyClaimBinding {
  const _LegacyClaimBinding({
    required this.authSession,
    required this.databaseSession,
    required this.ownerScopeValue,
  });

  final AuthSessionIdentity authSession;
  final ScopedAppDatabaseSession databaseSession;
  final String ownerScopeValue;
}
