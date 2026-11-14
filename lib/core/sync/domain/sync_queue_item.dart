import 'sync_types.dart';

class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    String? ownerScopeId,
    String? ownerUserId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
    this.lastAttemptAt,
  }) : assert(
         ownerScopeId != null || ownerUserId != null,
         'An opaque owner scope is required.',
       ),
       assert(
         ownerScopeId == null ||
             ownerUserId == null ||
             ownerScopeId == ownerUserId,
         'Owner scope aliases must match.',
       ),
       ownerScopeId = ownerScopeId ?? ownerUserId ?? '';

  final String id;

  /// Opaque, locally-derived scope. A Firebase UID must never be persisted in
  /// the local outbox.
  final String ownerScopeId;

  /// Transitional source-compatible alias. New writers pass only an opaque
  /// scope; the value is never a Firebase UID.
  @Deprecated('Use ownerScopeId; this alias does not contain a Firebase UID.')
  String get ownerUserId => ownerScopeId;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperationType operation;
  final String payloadJson;
  final SyncStatus status;
  final int attemptCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAttemptAt;

  SyncQueueItem copyWith({SyncOperationType? operation, String? payloadJson}) {
    return SyncQueueItem(
      id: id,
      ownerScopeId: ownerScopeId,
      entityType: entityType,
      entityId: entityId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status,
      attemptCount: attemptCount,
      lastError: lastError,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastAttemptAt: lastAttemptAt,
    );
  }
}

/// Immutable description of the exact queue revision and projection sent to
/// the remote store. Completion and failure updates compare this token and
/// revision with the durable row, so a later coalesced mutation cannot be
/// acknowledged by an older upload.
final class SyncUploadAttempt {
  const SyncUploadAttempt({
    required this.uploadItem,
    required this.token,
    required this.revision,
    required this.attemptedAt,
    required this.uploadedProjectionFingerprint,
  });

  final SyncQueueItem uploadItem;
  final String token;
  final int revision;
  final DateTime attemptedAt;
  final String? uploadedProjectionFingerprint;
}

class SyncReconciliationResult {
  const SyncReconciliationResult({
    required this.queuedUpserts,
    required this.queuedDeletes,
  });

  const SyncReconciliationResult.empty() : queuedUpserts = 0, queuedDeletes = 0;

  final int queuedUpserts;
  final int queuedDeletes;

  int get queuedTotal => queuedUpserts + queuedDeletes;
}

class SyncQueueStats {
  const SyncQueueStats({required this.pendingCount, required this.failedCount});

  const SyncQueueStats.empty() : pendingCount = 0, failedCount = 0;

  final int pendingCount;
  final int failedCount;
}
