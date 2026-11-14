class SyncFailure {
  const SyncFailure({
    required this.message,
    required this.code,
    this.queueItemId,
  });

  final String message;
  final String code;
  final String? queueItemId;
}

class SyncResult {
  const SyncResult({
    required this.attemptedCount,
    required this.syncedCount,
    required this.deletedCount,
    required this.failedCount,
    required this.failures,
    required this.completedAt,
    this.blocked = false,
  });

  factory SyncResult.blocked(SyncFailure failure) => SyncResult(
    attemptedCount: 0,
    syncedCount: 0,
    deletedCount: 0,
    failedCount: 1,
    failures: [failure],
    completedAt: null,
    blocked: true,
  );

  final int attemptedCount;
  final int syncedCount;
  final int deletedCount;
  final int failedCount;
  final List<SyncFailure> failures;
  final DateTime? completedAt;
  final bool blocked;

  bool get isSuccess => !blocked && failedCount == 0;
}
