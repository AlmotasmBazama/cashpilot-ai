import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../logging/app_logger.dart';
import '../data/sync_queue_repository.dart';
import '../domain/sync_queue_item.dart';
import '../domain/sync_types.dart';
import 'backup_operation_fence.dart';

class SyncOwner {
  const SyncOwner({required this.userId, required this.isAnonymous});

  final String userId;
  final bool isAnonymous;
}

abstract interface class SyncMutationQueue {
  Future<void> enqueueUpsert(
    SyncEntityType entityType,
    String entityId,
    Map<String, dynamic> payload,
  );

  Future<void> enqueueDelete(SyncEntityType entityType, String entityId);
}

Future<void> enqueueSyncUpsertBestEffort({
  required SyncMutationQueue? queue,
  required SyncEntityType entityType,
  required String entityId,
  required Map<String, dynamic> payload,
  required AppLogger logger,
}) async {
  try {
    await queue?.enqueueUpsert(entityType, entityId, payload);
  } on Object catch (error, stackTrace) {
    logger.warning(
      'Local mutation succeeded, but its backup hook failed.',
      error,
      stackTrace,
    );
  }
}

Future<void> enqueueSyncDeleteBestEffort({
  required SyncMutationQueue? queue,
  required SyncEntityType entityType,
  required String entityId,
  required AppLogger logger,
}) async {
  try {
    await queue?.enqueueDelete(entityType, entityId);
  } on Object catch (error, stackTrace) {
    logger.warning(
      'Local deletion succeeded, but its backup hook failed.',
      error,
      stackTrace,
    );
  }
}

class BestEffortSyncMutationQueue implements SyncMutationQueue {
  const BestEffortSyncMutationQueue({
    required SyncQueueRepository repository,
    required SyncOwner? Function() currentOwner,
    required bool Function(String userId) isBackupEnabled,
    required AppLogger logger,
    required BackupOperationFence operationFence,
  }) : _repository = repository,
       _currentOwner = currentOwner,
       _isBackupEnabled = isBackupEnabled,
       _logger = logger,
       _operationFence = operationFence;

  final SyncQueueRepository _repository;
  final SyncOwner? Function() _currentOwner;
  final bool Function(String userId) _isBackupEnabled;
  final AppLogger _logger;
  final BackupOperationFence _operationFence;

  @override
  Future<void> enqueueUpsert(
    SyncEntityType entityType,
    String entityId,
    Map<String, dynamic> payload,
  ) {
    return _enqueue(entityType, entityId, SyncOperationType.upsert, payload);
  }

  @override
  Future<void> enqueueDelete(SyncEntityType entityType, String entityId) {
    return _enqueue(
      entityType,
      entityId,
      SyncOperationType.delete,
      <String, dynamic>{'id': entityId},
    );
  }

  Future<void> _enqueue(
    SyncEntityType entityType,
    String entityId,
    SyncOperationType operation,
    Map<String, dynamic> payload,
  ) async {
    final owner = _currentOwner();
    if (owner == null ||
        owner.isAnonymous ||
        owner.userId.trim().isEmpty ||
        owner.userId != owner.userId.trim() ||
        !_isBackupEnabled(owner.userId) ||
        !_repository.isActiveForConfirmedRemoteOwner(owner.userId)) {
      return;
    }

    final writer = _operationFence.tryAcquireWriter(
      _repository.ownerScopeValue,
    );
    if (writer == null) {
      return;
    }
    final now = DateTime.now().toUtc();
    try {
      writer.assertActive();
      await _repository.enqueue(
        SyncQueueItem(
          id: const Uuid().v7(),
          ownerScopeId: _repository.ownerScopeValue,
          entityType: entityType,
          entityId: entityId,
          operation: operation,
          payloadJson: jsonEncode(payload),
          status: SyncStatus.pending,
          attemptCount: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      writer.assertActive();
      final currentOwner = _currentOwner();
      if (currentOwner == null ||
          currentOwner.isAnonymous ||
          currentOwner.userId != owner.userId ||
          !_repository.isActiveForConfirmedRemoteOwner(owner.userId) ||
          !_isBackupEnabled(owner.userId)) {
        return;
      }
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Local mutation succeeded, but its backup item was not queued.',
        error,
        stackTrace,
      );
    } finally {
      writer.release();
    }
  }
}
