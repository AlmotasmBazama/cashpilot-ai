import '../data/firestore_sync_data_source.dart';
import '../data/sync_queue_repository.dart';
import '../../owner_scope/domain/owner_scope.dart';
import '../domain/sync_queue_item.dart';
import '../domain/sync_result.dart';
import '../domain/sync_types.dart';
import 'backup_operation_fence.dart';

class SyncManager {
  const SyncManager({
    required SyncQueueRepository queueRepository,
    required FirestoreSyncDataSource remoteDataSource,
    required BackupOperationFence operationFence,
    required bool Function(String userId) isBackupEnabled,
    required int Function(String userId) readConsentGeneration,
    required bool Function(String userId) isInitialSnapshotComplete,
    required Future<void> Function(String userId, bool complete)
    saveInitialSnapshotComplete,
  }) : _queueRepository = queueRepository,
       _remoteDataSource = remoteDataSource,
       _operationFence = operationFence,
       _isBackupEnabled = isBackupEnabled,
       _readConsentGeneration = readConsentGeneration,
       _isInitialSnapshotComplete = isInitialSnapshotComplete,
       _saveInitialSnapshotComplete = saveInitialSnapshotComplete;

  static const snapshotVersion = 1;

  final SyncQueueRepository _queueRepository;
  final FirestoreSyncDataSource _remoteDataSource;
  final BackupOperationFence _operationFence;
  final bool Function(String userId) _isBackupEnabled;
  final int Function(String userId) _readConsentGeneration;
  final bool Function(String userId) _isInitialSnapshotComplete;
  final Future<void> Function(String userId, bool complete)
  _saveInitialSnapshotComplete;

  Future<SyncResult> synchronize({
    required String? userId,
    required String deviceId,
    bool isAnonymous = false,
    bool retryFailed = false,
  }) async {
    final uid = userId;
    if (uid == null || uid.isEmpty || uid != uid.trim() || isAnonymous) {
      return SyncResult.blocked(
        const SyncFailure(
          message: 'A signed-in non-guest account is required for backup.',
          code: 'sync_unauthenticated',
        ),
      );
    }
    if (!_queueRepository.isActiveForConfirmedRemoteOwner(uid)) {
      return _blockedByOwnerChange();
    }
    if (!_isBackupEnabled(uid)) {
      return _blockedByConsent();
    }
    final consentGeneration = _readConsentGeneration(uid);

    final writer = _operationFence.tryAcquireWriter(
      _queueRepository.ownerScopeValue,
    );
    if (writer == null) {
      return _blockedByFence(uid);
    }

    try {
      final startedAt = DateTime.now().toUtc();
      _assertWriteAuthorized(uid, consentGeneration, writer);
      await _queueRepository.reconcileDirtyState(
        forceFull: !_isInitialSnapshotComplete(uid),
        reconciledAt: startedAt,
      );
      _assertWriteAuthorized(uid, consentGeneration, writer);
      if (retryFailed) {
        await _queueRepository.retryFailed(startedAt);
      }
      final items = await _queueRepository.getPending();
      _assertWriteAuthorized(uid, consentGeneration, writer);
      var syncedCount = 0;
      var deletedCount = 0;
      final failures = <SyncFailure>[];

      for (final item in items) {
        _assertWriteAuthorized(uid, consentGeneration, writer);
        final attemptAt = DateTime.now().toUtc();
        SyncUploadAttempt? attempt;
        try {
          attempt = await _queueRepository.markAttempt(item, attemptAt);
          _assertWriteAuthorized(uid, consentGeneration, writer);
          if (attempt == null) continue;
          final uploadItem = attempt.uploadItem;
          await _remoteDataSource.uploadItem(uid, uploadItem);
          _assertWriteAuthorized(uid, consentGeneration, writer);
          final completed = await _queueRepository.markCompleted(attempt);
          if (!completed) {
            failures.add(
              SyncFailure(
                message: 'A newer local change remains queued for backup.',
                code: 'sync_attempt_superseded',
                queueItemId: item.id,
              ),
            );
            continue;
          }
          if (uploadItem.operation == SyncOperationType.delete) {
            deletedCount++;
          } else {
            syncedCount++;
          }
        } on BackupWriterCancelledException {
          rethrow;
        } on _BackupConsentRevokedException {
          rethrow;
        } on Object catch (error) {
          _assertWriteAuthorized(uid, consentGeneration, writer);
          final message = error.toString();
          if (attempt != null) {
            await _queueRepository.markFailed(
              attempt,
              'sync_upload_failed',
              DateTime.now().toUtc(),
            );
          }
          failures.add(
            SyncFailure(
              message: message,
              code: 'sync_upload_failed',
              queueItemId: item.id,
            ),
          );
        }
      }

      _assertWriteAuthorized(uid, consentGeneration, writer);
      final snapshotComplete =
          failures.isEmpty && (await _queueRepository.getPending()).isEmpty;
      _assertWriteAuthorized(uid, consentGeneration, writer);
      final completedAt = DateTime.now().toUtc();
      var metadataSucceeded = false;
      try {
        await _remoteDataSource.updateSyncMetadata(
          userId: uid,
          deviceId: deviceId,
          syncedAt: completedAt,
          uploadedCount: syncedCount + deletedCount,
          failedCount: failures.length,
          snapshotComplete: snapshotComplete,
          snapshotVersion: snapshotVersion,
        );
        _assertWriteAuthorized(uid, consentGeneration, writer);
        metadataSucceeded = true;
      } on BackupWriterCancelledException {
        rethrow;
      } on _BackupConsentRevokedException {
        rethrow;
      } on Object catch (error) {
        _assertWriteAuthorized(uid, consentGeneration, writer);
        failures.add(
          SyncFailure(message: error.toString(), code: 'sync_metadata_failed'),
        );
      }

      if (metadataSucceeded && snapshotComplete) {
        _assertWriteAuthorized(uid, consentGeneration, writer);
        await _saveInitialSnapshotComplete(uid, true);
        _assertWriteAuthorized(uid, consentGeneration, writer);
      }
      return SyncResult(
        attemptedCount: items.length,
        syncedCount: syncedCount,
        deletedCount: deletedCount,
        failedCount: failures.length,
        failures: List.unmodifiable(failures),
        completedAt: completedAt,
      );
    } on _BackupConsentRevokedException {
      return _blockedByConsent();
    } on _SyncOwnerChangedException {
      return _blockedByOwnerChange();
    } on OwnerScopeException catch (error) {
      return error.failure == OwnerScopeFailure.deletionQuarantined
          ? _blockedByFence(uid)
          : _blockedByOwnerChange();
    } on BackupWriterCancelledException {
      return _blockedByFence(uid);
    } finally {
      writer.release();
    }
  }

  void _assertWriteAuthorized(
    String userId,
    int generation,
    BackupWriterLease writer,
  ) {
    writer.assertActive();
    if (!_queueRepository.isActiveForConfirmedRemoteOwner(userId)) {
      throw const _SyncOwnerChangedException();
    }
    if (!_isBackupEnabled(userId) ||
        _readConsentGeneration(userId) != generation) {
      throw const _BackupConsentRevokedException();
    }
  }

  SyncResult _blockedByFence(String userId) {
    return _isBackupEnabled(userId)
        ? SyncResult.blocked(
            const SyncFailure(
              message: 'Backup is paused while account deletion is active.',
              code: 'sync_deletion_in_progress',
            ),
          )
        : _blockedByConsent();
  }

  SyncResult _blockedByConsent() {
    return SyncResult.blocked(
      const SyncFailure(
        message: 'Cloud backup is disabled for this account.',
        code: 'sync_backup_disabled',
      ),
    );
  }

  SyncResult _blockedByOwnerChange() {
    return SyncResult.blocked(
      const SyncFailure(
        message: 'The active backup owner changed.',
        code: 'sync_owner_scope_mismatch',
      ),
    );
  }
}

final class _BackupConsentRevokedException implements Exception {
  const _BackupConsentRevokedException();
}

final class _SyncOwnerChangedException implements Exception {
  const _SyncOwnerChangedException();
}
