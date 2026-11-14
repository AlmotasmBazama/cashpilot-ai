import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../features/auth/application/providers/auth_providers.dart';
import '../../../features/auth/domain/entities/auth_user.dart';
import '../../firebase/firebase_providers.dart';
import '../../logging/app_logger.dart';
import '../../owner_scope/application/owner_scope_providers.dart';
import '../../owner_scope/domain/owner_scope.dart';
import '../data/firestore_sync_data_source.dart';
import '../data/sync_preferences_local_data_source.dart';
import '../data/sync_queue_repository.dart';
import '../domain/sync_queue_item.dart';
import '../domain/sync_result.dart';
import 'backup_operation_fence.dart';
import 'sync_manager.dart';
import 'sync_mutation_queue.dart';

final syncQueueRepositoryProvider = Provider<SyncQueueRepository>(
  (ref) => DriftSyncQueueRepository(
    ref.watch(requiredScopedAppDatabaseSessionProvider),
  ),
  name: 'syncQueueRepositoryProvider',
);

final firestoreSyncDataSourceProvider = Provider<FirestoreSyncDataSource>(
  (ref) => DefaultFirestoreSyncDataSource(ref.watch(firebaseFirestoreProvider)),
  name: 'firestoreSyncDataSourceProvider',
);

final syncMutationQueueProvider = Provider<SyncMutationQueue>(
  (ref) => BestEffortSyncMutationQueue(
    repository: ref.watch(syncQueueRepositoryProvider),
    currentOwner: () {
      final user = ref.read(currentAuthUserProvider);
      return user == null
          ? null
          : SyncOwner(userId: user.uid, isAnonymous: user.isAnonymous);
    },
    isBackupEnabled: ref
        .watch(syncPreferencesLocalDataSourceProvider)
        .readBackupEnabled,
    logger: ref.watch(appLoggerProvider),
    operationFence: ref.watch(backupOperationFenceProvider),
  ),
  name: 'syncMutationQueueProvider',
);

final syncManagerProvider = Provider<SyncManager>((ref) {
  final preferences = ref.watch(syncPreferencesLocalDataSourceProvider);
  return SyncManager(
    queueRepository: ref.watch(syncQueueRepositoryProvider),
    remoteDataSource: ref.watch(firestoreSyncDataSourceProvider),
    operationFence: ref.watch(backupOperationFenceProvider),
    isBackupEnabled: preferences.readBackupEnabled,
    readConsentGeneration: preferences.readConsentGeneration,
    isInitialSnapshotComplete: preferences.readInitialSnapshotComplete,
    saveInitialSnapshotComplete: preferences.saveInitialSnapshotComplete,
  );
}, name: 'syncManagerProvider');

final syncQueueStatsProvider = StreamProvider.family<SyncQueueStats, String>((
  ref,
  userId,
) {
  final repository = ref.watch(syncQueueRepositoryProvider);
  if (!repository.isActiveForConfirmedRemoteOwner(userId)) {
    return Stream<SyncQueueStats>.value(const SyncQueueStats.empty());
  }
  return repository.watchStats();
}, name: 'syncQueueStatsProvider');

final backupEnabledProvider = Provider.family<bool, String>(
  (ref, userId) => ref
      .watch(syncPreferencesLocalDataSourceProvider)
      .readBackupEnabled(userId),
  name: 'backupEnabledProvider',
);

final lastBackupAtProvider = Provider.family<DateTime?, String>(
  (ref, userId) => ref
      .watch(syncPreferencesLocalDataSourceProvider)
      .readLastBackupAt(userId),
  name: 'lastBackupAtProvider',
);

final syncActionControllerProvider =
    AsyncNotifierProvider<SyncActionController, SyncResult?>(
      SyncActionController.new,
      name: 'syncActionControllerProvider',
    );

class SyncActionController extends AsyncNotifier<SyncResult?> {
  var _operationVersion = 0;

  @override
  FutureOr<SyncResult?> build() {
    ref.listen(confirmedOwnerScopeSnapshotProvider, (_, _) {
      _operationVersion++;
      if (ref.mounted) {
        state = const AsyncData(null);
      }
    });
    ref.onDispose(() {
      _operationVersion++;
    });
    return null;
  }

  Future<SyncResult> synchronize(
    AuthUser? user, {
    bool retryFailed = false,
  }) async {
    final keepAlive = ref.keepAlive();
    final operationVersion = ++_operationVersion;
    final ownerSession = ref.read(scopedAppDatabaseSessionProvider);
    final enforceOwnerEpoch = user != null;
    state = const AsyncLoading();
    try {
      final preferences = ref.read(syncPreferencesLocalDataSourceProvider);
      var deviceId = preferences.readSyncDeviceId();
      if (deviceId == null) {
        deviceId = const Uuid().v7();
        await preferences.saveSyncDeviceId(deviceId);
      }
      if (enforceOwnerEpoch &&
          !_isCurrentOwnerOperation(operationVersion, ownerSession)) {
        return _ownerChangedResult();
      }
      final result = await ref
          .read(syncManagerProvider)
          .synchronize(
            userId: user?.uid,
            isAnonymous: user?.isAnonymous ?? false,
            deviceId: deviceId,
            retryFailed: retryFailed,
          );
      if (enforceOwnerEpoch &&
          !_isCurrentOwnerOperation(operationVersion, ownerSession)) {
        return _ownerChangedResult();
      }
      if (result.isSuccess && result.completedAt != null && user != null) {
        try {
          await preferences.saveLastBackupAt(user.uid, result.completedAt!);
        } on BackupWriterCancelledException {
          if (!_isCurrentOwnerOperation(operationVersion, ownerSession)) {
            return _ownerChangedResult();
          }
          final blocked = _deletionInProgressResult();
          state = AsyncData(blocked);
          return blocked;
        } on OwnerScopeException {
          if (!_isCurrentOwnerOperation(operationVersion, ownerSession)) {
            return _ownerChangedResult();
          }
          final blocked = _deletionInProgressResult();
          state = AsyncData(blocked);
          return blocked;
        }
        if (enforceOwnerEpoch &&
            !_isCurrentOwnerOperation(operationVersion, ownerSession)) {
          return _ownerChangedResult();
        }
        ref.invalidate(lastBackupAtProvider(user.uid));
      }
      state = AsyncData(result);
      return result;
    } finally {
      keepAlive.close();
    }
  }

  bool _isCurrentOwnerOperation(int version, Object? ownerSession) {
    return ref.mounted &&
        version == _operationVersion &&
        ownerSession != null &&
        identical(ownerSession, ref.read(scopedAppDatabaseSessionProvider));
  }

  SyncResult _ownerChangedResult() {
    return SyncResult.blocked(
      const SyncFailure(
        message: 'The active backup owner changed.',
        code: 'sync_owner_scope_mismatch',
      ),
    );
  }

  SyncResult _deletionInProgressResult() {
    return SyncResult.blocked(
      const SyncFailure(
        message: 'Backup is paused while account deletion is active.',
        code: 'sync_deletion_in_progress',
      ),
    );
  }
}
