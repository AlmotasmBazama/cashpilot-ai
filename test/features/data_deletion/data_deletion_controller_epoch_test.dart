import 'dart:async';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/database/app_database_provider.dart';
import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_session_guard.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/data_deletion/application/data_deletion_providers.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_request.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/failures/data_deletion_failure_codes.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/repositories/data_deletion_repository.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/usecases/delete_all_user_data.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

const _ownerA = AuthUser(
  uid: 'controller-owner-a',
  emailVerified: true,
  isAnonymous: false,
);
const _ownerB = AuthUser(
  uid: 'controller-owner-b',
  emailVerified: true,
  isAnonymous: false,
);

void main() {
  test(
    'stale deletion success cannot publish or navigate as owner B success',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final auth = StreamController<AuthUser?>.broadcast();
      addTearDown(auth.close);
      final repository = _BlockingDeletionRepository(
        _completedReportFor(_ownerA),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authStateProvider.overrideWith((_) => auth.stream),
          ownerScopeDetachServiceProvider.overrideWithValue(
            const _NoopDetachService(),
          ),
          backupOperationFenceProvider.overrideWithValue(
            BackupOperationFence(),
          ),
          completedAccountDeletionOverlayProvider.overrideWithValue(
            const _TestCompletedDeletionOverlay(),
          ),
          deleteAllUserDataUseCaseProvider.overrideWithValue(
            DeleteAllUserData(repository),
          ),
        ],
      );
      addTearDown(container.dispose);
      final scopeSubscription = container.listen(
        confirmedOwnerScopeSnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(scopeSubscription.close);

      auth.add(_ownerA);
      await _waitForOwner(container, _ownerA.uid);
      await container.read(dataDeletionControllerProvider.future);
      final deletion = container
          .read(dataDeletionControllerProvider.notifier)
          .deleteAll(
            const DataDeletionRequest(
              confirmationAccepted: true,
              confirmationLease: AccountDeletionConfirmationLease(
                opaqueToken: 'controller-confirmation-lease',
                isAnonymous: false,
              ),
            ),
          );
      await repository.started.future;

      auth.add(_ownerB);
      await _waitForOwner(container, _ownerB.uid);
      repository.finish();
      final failure = await deletion;

      expect(failure?.code, DataDeletionFailureCodes.identityChanged);
      final state = container.read(dataDeletionControllerProvider);
      expect(state.value, isNull);
    },
  );

  test('successful Auth deletion logout still returns success to A', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final auth = StreamController<AuthUser?>.broadcast();
    addTearDown(auth.close);
    final repository = _BlockingDeletionRepository(
      _completedReportFor(_ownerA),
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authStateProvider.overrideWith((_) => auth.stream),
        ownerScopeDetachServiceProvider.overrideWithValue(
          const _NoopDetachService(),
        ),
        backupOperationFenceProvider.overrideWithValue(BackupOperationFence()),
        completedAccountDeletionOverlayProvider.overrideWithValue(
          const _TestCompletedDeletionOverlay(),
        ),
        deleteAllUserDataUseCaseProvider.overrideWithValue(
          DeleteAllUserData(repository),
        ),
      ],
    );
    addTearDown(container.dispose);
    final scopeSubscription = container.listen(
      confirmedOwnerScopeSnapshotProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(scopeSubscription.close);

    auth.add(_ownerA);
    await _waitForOwner(container, _ownerA.uid);
    await container.read(dataDeletionControllerProvider.future);
    final deletion = container
        .read(dataDeletionControllerProvider.notifier)
        .deleteAll(
          const DataDeletionRequest(
            confirmationAccepted: true,
            confirmationLease: AccountDeletionConfirmationLease(
              opaqueToken: 'controller-logout-confirmation-lease',
              isAnonymous: false,
            ),
          ),
        );
    await repository.started.future;

    auth.add(null);
    await _waitForUnauthenticated(container);
    repository.finish();

    expect(await deletion, isNull);
    expect(container.read(dataDeletionControllerProvider).value, isNull);
  });

  test('A to B to logout rejects even a valid-looking stale A proof', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final auth = StreamController<AuthUser?>.broadcast();
    addTearDown(auth.close);
    final repository = _BlockingDeletionRepository(
      _completedReportFor(_ownerA),
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authStateProvider.overrideWith((_) => auth.stream),
        ownerScopeDetachServiceProvider.overrideWithValue(
          const _NoopDetachService(),
        ),
        backupOperationFenceProvider.overrideWithValue(BackupOperationFence()),
        completedAccountDeletionOverlayProvider.overrideWithValue(
          const _TestCompletedDeletionOverlay(),
        ),
        deleteAllUserDataUseCaseProvider.overrideWithValue(
          DeleteAllUserData(repository),
        ),
      ],
    );
    addTearDown(container.dispose);
    final scopeSubscription = container.listen(
      confirmedOwnerScopeSnapshotProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(scopeSubscription.close);

    auth.add(_ownerA);
    await _waitForOwner(container, _ownerA.uid);
    await container.read(dataDeletionControllerProvider.future);
    final deletion = container
        .read(dataDeletionControllerProvider.notifier)
        .deleteAll(
          const DataDeletionRequest(
            confirmationAccepted: true,
            confirmationLease: AccountDeletionConfirmationLease(
              opaqueToken: 'controller-stale-unproved-lease',
              isAnonymous: false,
            ),
          ),
        );
    await repository.started.future;

    // B is immediately followed by logout. The owner-scope controller may
    // coalesce transitions and never publish B as a safe scoped session, but
    // the deletion controller must still observe raw Auth exposure.
    auth.add(_ownerB);
    auth.add(null);
    await _waitForUnauthenticated(container);
    repository.finish();

    expect((await deletion)?.code, DataDeletionFailureCodes.identityChanged);
    expect(container.read(dataDeletionControllerProvider).value, isNull);
  });

  test('same-uid token refresh does not invalidate deletion', () async {
    final harness = await _controllerHarness();
    final deletion = harness.start('controller-token-refresh-lease');
    await harness.repository.started.future;

    harness.auth.add(
      const AuthUser(
        uid: 'controller-owner-a',
        email: 'refreshed@example.com',
        emailVerified: true,
        isAnonymous: false,
      ),
    );
    await pumpEventQueue(times: 10);
    harness.repository.finish();

    expect(await deletion, isNull);
    expect(
      harness.container
          .read(dataDeletionControllerProvider)
          .value
          ?.completionProof
          .authDeletionCompleted,
      isTrue,
    );
  });

  test('same-uid replacement generation invalidates stale deletion', () async {
    final harness = await _controllerHarness();
    final deletion = harness.start('controller-same-uid-generation-lease');
    await harness.repository.started.future;

    harness.auth.add(
      const AuthUser(
        uid: 'controller-owner-a',
        emailVerified: true,
        isAnonymous: false,
        authSessionGeneration: 1,
      ),
    );
    await pumpEventQueue(times: 10);
    harness.repository.finish();

    expect((await deletion)?.code, DataDeletionFailureCodes.identityChanged);
    expect(
      harness.container.read(dataDeletionControllerProvider).value,
      isNull,
    );
  });

  test(
    'same-uid replacement then logout cannot validate stale completion proof',
    () async {
      final harness = await _controllerHarness();
      final deletion = harness.start(
        'controller-same-uid-generation-logout-lease',
      );
      await harness.repository.started.future;

      harness.auth.add(
        const AuthUser(
          uid: 'controller-owner-a',
          emailVerified: true,
          isAnonymous: false,
          authSessionGeneration: 1,
        ),
      );
      harness.auth.add(null);
      await _waitForUnauthenticated(harness.container);
      harness.repository.finish();

      expect((await deletion)?.code, DataDeletionFailureCodes.identityChanged);
      expect(
        harness.container.read(dataDeletionControllerProvider).value,
        isNull,
      );
    },
  );

  test('ordinary logout cannot validate a stubbed completion proof', () async {
    final harness = await _controllerHarness(trustedCompletion: false);
    final deletion = harness.start('controller-untrusted-logout-lease');
    await harness.repository.started.future;

    harness.auth.add(null);
    await _waitForUnauthenticated(harness.container);
    harness.repository.finish();

    expect((await deletion)?.code, DataDeletionFailureCodes.identityChanged);
    expect(
      harness.container.read(dataDeletionControllerProvider).value,
      isNull,
    );
  });

  test(
    'logout same-uid relogin logout rejects a valid-looking stale proof',
    () async {
      final harness = await _controllerHarness();
      final deletion = harness.start('controller-same-uid-relogin-lease');
      await harness.repository.started.future;

      harness.auth.add(null);
      harness.auth.add(
        const AuthUser(
          uid: 'controller-owner-a',
          emailVerified: true,
          isAnonymous: false,
        ),
      );
      harness.auth.add(null);
      await _waitForUnauthenticated(harness.container);
      harness.repository.finish();

      expect((await deletion)?.code, DataDeletionFailureCodes.identityChanged);
      expect(
        harness.container.read(dataDeletionControllerProvider).value,
        isNull,
      );
    },
  );

  test('Auth stream error disqualifies special deletion success', () async {
    final harness = await _controllerHarness();
    final deletion = harness.start('controller-auth-error-lease');
    await harness.repository.started.future;

    harness.auth.addError(StateError('simulated Auth stream failure'));
    harness.auth.add(null);
    await _waitForUnauthenticated(harness.container);
    harness.repository.finish();

    expect((await deletion)?.code, DataDeletionFailureCodes.identityChanged);
    expect(
      harness.container.read(dataDeletionControllerProvider).value,
      isNull,
    );
  });
}

Future<_ControllerHarness> _controllerHarness({
  bool trustedCompletion = true,
}) async {
  final database = AppDatabase(executor: NativeDatabase.memory());
  addTearDown(database.close);
  final auth = StreamController<AuthUser?>.broadcast();
  addTearDown(auth.close);
  final repository = _BlockingDeletionRepository(_completedReportFor(_ownerA));
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      authStateProvider.overrideWith((_) => auth.stream),
      ownerScopeDetachServiceProvider.overrideWithValue(
        const _NoopDetachService(),
      ),
      backupOperationFenceProvider.overrideWithValue(BackupOperationFence()),
      completedAccountDeletionOverlayProvider.overrideWithValue(
        _TestCompletedDeletionOverlay(trusted: trustedCompletion),
      ),
      deleteAllUserDataUseCaseProvider.overrideWithValue(
        DeleteAllUserData(repository),
      ),
    ],
  );
  addTearDown(container.dispose);
  final scopeSubscription = container.listen(
    confirmedOwnerScopeSnapshotProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(scopeSubscription.close);
  auth.add(_ownerA);
  await _waitForOwner(container, _ownerA.uid);
  await container.read(dataDeletionControllerProvider.future);
  return _ControllerHarness(
    auth: auth,
    repository: repository,
    container: container,
  );
}

final class _ControllerHarness {
  const _ControllerHarness({
    required this.auth,
    required this.repository,
    required this.container,
  });

  final StreamController<AuthUser?> auth;
  final _BlockingDeletionRepository repository;
  final ProviderContainer container;

  Future<Failure?> start(String leaseToken) => container
      .read(dataDeletionControllerProvider.notifier)
      .deleteAll(
        DataDeletionRequest(
          confirmationAccepted: true,
          confirmationLease: AccountDeletionConfirmationLease(
            opaqueToken: leaseToken,
            isAnonymous: false,
          ),
        ),
      );
}

DataDeletionReport _completedReportFor(
  AuthUser user, {
  bool authDeletionCompleted = true,
}) => DataDeletionReport(
  cloudDocumentsDeleted: 1,
  localRowsDeleted: 1,
  completionProof: DataDeletionCompletionProof(
    operationId: 'controller-operation-proof',
    targetOwnerScopeValue: OwnerScopeDerivation.fromConfirmedFirebaseUid(
      user.uid,
    ).id.value,
    authStateGeneration: 7,
    authDeletionCompleted: authDeletionCompleted,
  ),
);

final class _TestCompletedDeletionOverlay
    implements CompletedAccountDeletionOverlay {
  const _TestCompletedDeletionOverlay({this.trusted = true});

  final bool trusted;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  bool shouldSuppress(firebase_auth.User? user) => false;

  @override
  bool hasTrustedCompletion({
    required String operationId,
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
  }) =>
      trusted &&
      operationId == 'controller-operation-proof' &&
      ownerScope.id.value ==
          OwnerScopeDerivation.fromConfirmedFirebaseUid(_ownerA.uid).id.value &&
      capturedAuthGeneration == 7;

  @override
  Future<void> markCompleted({
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
    required String operationId,
  }) async {}
}

Future<void> _waitForOwner(ProviderContainer container, String uid) async {
  final expected = OwnerScopeDerivation.fromConfirmedFirebaseUid(uid).id.value;
  for (var attempt = 0; attempt < 100; attempt += 1) {
    final snapshot = container.read(confirmedOwnerScopeSnapshotProvider);
    if (snapshot.status == OwnerScopeStatus.safe &&
        snapshot.scope?.id.value == expected) {
      return;
    }
    await pumpEventQueue();
  }
  fail('Owner scope did not settle.');
}

Future<void> _waitForUnauthenticated(ProviderContainer container) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    final snapshot = container.read(confirmedOwnerScopeSnapshotProvider);
    if (snapshot.status == OwnerScopeStatus.unauthenticated) {
      return;
    }
    await pumpEventQueue();
  }
  fail('Owner scope did not become unauthenticated.');
}

final class _BlockingDeletionRepository implements DataDeletionRepository {
  _BlockingDeletionRepository(this.report);

  final DataDeletionReport report;
  final Completer<void> started = Completer<void>();
  final Completer<void> _finished = Completer<void>();

  void finish() => _finished.complete();

  @override
  Future<AppResult<DataDeletionReport>> deleteAllUserData(
    DataDeletionRequest request,
  ) async {
    started.complete();
    await _finished.future;
    return AppResult<DataDeletionReport>.success(report);
  }
}

final class _NoopDetachService implements OwnerScopeDetachService {
  const _NoopDetachService();

  @override
  Future<void> detach(String ownerScopeValue) async {}
}
