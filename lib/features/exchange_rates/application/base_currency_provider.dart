import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_local_data_source.dart';
import '../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../core/owner_scope/domain/owner_scope.dart';
import '../../../core/sync/application/backup_operation_fence.dart';
import '../../../core/sync/application/sync_providers.dart';
import '../../../core/sync/application/sync_mutation_queue.dart';
import '../../../core/sync/domain/sync_types.dart';
import '../../../shared/domain/currency/currency_catalog.dart';
import '../../auth/application/providers/auth_providers.dart';
import '../../auth/domain/entities/auth_user.dart';

final baseCurrencyControllerProvider =
    NotifierProvider<BaseCurrencyController, String>(
      BaseCurrencyController.new,
      name: 'baseCurrencyControllerProvider',
    );

final _baseCurrencyRevisionProvider =
    NotifierProvider<_BaseCurrencyRevision, int>(
      _BaseCurrencyRevision.new,
      name: 'baseCurrencyRevisionProvider',
    );

final effectiveBaseCurrencyCodeProvider = Provider<String>((ref) {
  ref.watch(_baseCurrencyRevisionProvider);
  final unauthenticatedDefault = ref.watch(baseCurrencyControllerProvider);
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading || auth.hasError) {
    return CurrencyCatalog.defaultCurrencyCode;
  }
  final user = auth.value;
  if (user == null) {
    return CurrencyCatalog.normalizeCode(unauthenticatedDefault);
  }
  final scope = ref.watch(confirmedOwnerScopeSnapshotProvider);
  if (scope.status != OwnerScopeStatus.safe ||
      scope.scope == null ||
      scope.authSessionGeneration != user.authSessionGeneration) {
    return CurrencyCatalog.defaultCurrencyCode;
  }
  final profileCurrency = user.currency;
  if (profileCurrency != null && profileCurrency.trim().isNotEmpty) {
    return CurrencyCatalog.normalizeCode(profileCurrency);
  }
  final scopedCurrency = ref
      .watch(settingsLocalDataSourceProvider)
      .readOwnerBaseCurrencyCode(scope.scope!);
  return CurrencyCatalog.normalizeCode(
    scopedCurrency ?? CurrencyCatalog.defaultCurrencyCode,
  );
}, name: 'effectiveBaseCurrencyCodeProvider');

class BaseCurrencyController extends Notifier<String> {
  @override
  String build() {
    return CurrencyCatalog.normalizeCode(
      ref.watch(settingsLocalDataSourceProvider).readBaseCurrencyCode(),
    );
  }

  Future<bool> setBaseCurrencyCode(
    String currencyCode, {
    required AuthSessionIdentity? expectedSession,
  }) async {
    final normalized = CurrencyCatalog.normalizeCode(currencyCode);
    final settings = ref.read(settingsLocalDataSourceProvider);
    final capturedOwnerSession = ref.read(scopedAppDatabaseSessionProvider);
    final capturedScope = ref.read(confirmedOwnerScopeSnapshotProvider);
    final targetScope = expectedSession == null ? null : capturedScope.scope;
    final operationFence = ref.read(backupOperationFenceProvider);
    BackupWriterLease? writer;
    SyncMutationQueue? capturedQueue;
    if (!_matchesBoundary(
      expectedSession,
      capturedScope: capturedScope,
      capturedOwnerSession: capturedOwnerSession,
    )) {
      return false;
    }
    if (expectedSession != null) {
      // Resolve the A-bound queue before the first asynchronous gap. Never
      // resolve a scoped provider after persistence may have switched to B.
      capturedQueue = ref.read(syncMutationQueueProvider);
      writer = operationFence.tryAcquireWriter(targetScope!.id.value);
      if (writer == null) {
        return false;
      }
    }
    final payload = <String, dynamic>{
      'baseCurrencyCode': normalized,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      writer?.assertActive();
      if (targetScope == null) {
        await settings.saveBaseCurrencyCode(normalized);
      } else {
        await settings.saveOwnerBaseCurrencyCode(targetScope, normalized);
      }
      writer?.assertActive();
      if (!_matchesBoundary(
        expectedSession,
        capturedScope: capturedScope,
        capturedOwnerSession: capturedOwnerSession,
      )) {
        return false;
      }
      await capturedQueue?.enqueueUpsert(
        SyncEntityType.settings,
        'main',
        payload,
      );
      writer?.assertActive();
      if (!_matchesBoundary(
        expectedSession,
        capturedScope: capturedScope,
        capturedOwnerSession: capturedOwnerSession,
      )) {
        return false;
      }
      if (targetScope == null) {
        state = normalized;
      } else {
        ref.read(_baseCurrencyRevisionProvider.notifier).bump();
      }
      return true;
    } on BackupWriterCancelledException {
      return false;
    } finally {
      writer?.release();
    }
  }

  bool _matchesBoundary(
    AuthSessionIdentity? expectedSession, {
    required OwnerScopeSnapshot capturedScope,
    required Object? capturedOwnerSession,
  }) {
    if (!ref.mounted) {
      return false;
    }
    final currentUser = ref.read(currentAuthUserProvider);
    final currentScope = ref.read(confirmedOwnerScopeSnapshotProvider);
    final currentOwnerSession = ref.read(scopedAppDatabaseSessionProvider);
    if (expectedSession == null) {
      return currentUser == null &&
          capturedScope.scope == null &&
          currentScope.scope == null &&
          capturedOwnerSession == null &&
          currentOwnerSession == null;
    }
    ConfirmedOwnerScope expectedScope;
    try {
      expectedScope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
        expectedSession.uid,
      );
    } on Object {
      return false;
    }
    return expectedSession.matches(currentUser) &&
        capturedScope.status == OwnerScopeStatus.safe &&
        capturedScope.scope?.id.value == expectedScope.id.value &&
        capturedScope.authSessionGeneration ==
            expectedSession.authSessionGeneration &&
        currentScope.status == OwnerScopeStatus.safe &&
        currentScope.scope?.id.value == expectedScope.id.value &&
        currentScope.authSessionGeneration ==
            expectedSession.authSessionGeneration &&
        capturedOwnerSession != null &&
        identical(capturedOwnerSession, currentOwnerSession);
  }
}

class _BaseCurrencyRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state += 1;
}
