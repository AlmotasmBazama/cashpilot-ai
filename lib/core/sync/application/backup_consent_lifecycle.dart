import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../data/sync_queue_repository.dart';
import '../domain/sync_queue_item.dart';
import '../domain/sync_types.dart';
import 'backup_operation_fence.dart';

typedef BackupSettingsSnapshotReader =
    Map<String, dynamic> Function(String userId);

/// Applies backup consent transitions at the same owner-scoped boundary used
/// by network writers.
final class BackupConsentLifecycleCoordinator {
  const BackupConsentLifecycleCoordinator({
    required SyncQueueRepository queueRepository,
    required BackupOperationFence operationFence,
    BackupSettingsSnapshotReader? readSettingsSnapshot,
    DateTime Function()? clock,
  }) : _queueRepository = queueRepository,
       _operationFence = operationFence,
       _readSettingsSnapshot = readSettingsSnapshot,
       _clock = clock ?? _utcNow;

  final SyncQueueRepository _queueRepository;
  final BackupOperationFence _operationFence;
  final BackupSettingsSnapshotReader? _readSettingsSnapshot;
  final DateTime Function() _clock;

  Future<BackupConsentLifecycleResult> apply({
    required String userId,
    required bool enabled,
    required int generation,
  }) async {
    if (!_queueRepository.isActiveForConfirmedRemoteOwner(userId)) {
      return const BackupConsentLifecycleResult.scopeMismatch();
    }
    if (enabled) {
      final writer = _operationFence.tryAcquireWriter(
        _queueRepository.ownerScopeValue,
      );
      if (writer == null) {
        return const BackupConsentLifecycleResult.blocked();
      }
      try {
        writer.assertActive();
        final preparedAt = _clock().toUtc();
        await _queueRepository.reconcileDirtyState(
          forceFull: true,
          reconciledAt: preparedAt,
        );
        if (!_queueRepository.isActiveForConfirmedRemoteOwner(userId)) {
          return const BackupConsentLifecycleResult.scopeMismatch();
        }
        writer.assertActive();
        final settingsSnapshot =
            _readSettingsSnapshot?.call(userId) ?? const <String, dynamic>{};
        await _queueRepository.enqueue(
          SyncQueueItem(
            id: const Uuid().v7(),
            ownerScopeId: _queueRepository.ownerScopeValue,
            entityType: SyncEntityType.settings,
            entityId: 'main',
            operation: SyncOperationType.upsert,
            payloadJson: jsonEncode(<String, dynamic>{
              ...settingsSnapshot,
              'backupEnabled': true,
              'backupMode': 'backupOnly',
              'restoreSupported': false,
              'snapshotVersion': 1,
              'updatedAt': preparedAt.toIso8601String(),
            }),
            status: SyncStatus.pending,
            attemptCount: 0,
            createdAt: preparedAt,
            updatedAt: preparedAt,
          ),
        );
        writer.assertActive();
        if (!_queueRepository.isActiveForConfirmedRemoteOwner(userId)) {
          return const BackupConsentLifecycleResult.scopeMismatch();
        }
        return const BackupConsentLifecycleResult.snapshotPrepared();
      } on BackupWriterCancelledException {
        return const BackupConsentLifecycleResult.blocked();
      } finally {
        writer.release();
      }
    }

    BackupDeletionLease? lease;
    final operationId = 'backup-consent-revoked-$generation';
    try {
      lease = await _operationFence.fenceAndDrain(
        ownerScopeValue: _queueRepository.ownerScopeValue,
        operationId: operationId,
      );
      if (!_queueRepository.isActiveForConfirmedRemoteOwner(userId)) {
        return const BackupConsentLifecycleResult.scopeMismatch();
      }
      await _queueRepository.purgeAll(fencedOperationId: operationId);
      return const BackupConsentLifecycleResult.purged();
    } on StateError {
      // A different destructive operation owns the fence. Backup remains
      // disabled and the startup repair will retry its scoped purge later.
      return const BackupConsentLifecycleResult.blocked();
    } finally {
      lease?.release();
    }
  }
}

class BackupConsentLifecycleResult {
  const BackupConsentLifecycleResult._({
    required this.snapshotPrepared,
    required this.queuePurged,
    required this.blocked,
    required this.scopeMismatch,
  });

  const BackupConsentLifecycleResult.snapshotPrepared()
    : this._(
        snapshotPrepared: true,
        queuePurged: false,
        blocked: false,
        scopeMismatch: false,
      );

  const BackupConsentLifecycleResult.purged()
    : this._(
        snapshotPrepared: false,
        queuePurged: true,
        blocked: false,
        scopeMismatch: false,
      );

  const BackupConsentLifecycleResult.blocked()
    : this._(
        snapshotPrepared: false,
        queuePurged: false,
        blocked: true,
        scopeMismatch: false,
      );

  const BackupConsentLifecycleResult.scopeMismatch()
    : this._(
        snapshotPrepared: false,
        queuePurged: false,
        blocked: true,
        scopeMismatch: true,
      );

  final bool snapshotPrepared;
  final bool queuePurged;
  final bool blocked;
  final bool scopeMismatch;
}

DateTime _utcNow() => DateTime.now().toUtc();
