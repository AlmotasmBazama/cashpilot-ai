abstract interface class RestoreService {
  Future<RestorePreview> preview({required String userId});

  Future<RestoreResult> restore({
    required String userId,
    required String confirmationToken,
  });
}

class RestorePreview {
  const RestorePreview({
    required this.entityCounts,
    required this.requiresExplicitConfirmation,
  });

  final Map<String, int> entityCounts;
  final bool requiresExplicitConfirmation;
}

class RestoreResult {
  const RestoreResult({
    required this.restoredCount,
    required this.skippedCount,
  });

  final int restoredCount;
  final int skippedCount;
}

// TODO(sync-restore): Implement only after conflict resolution, ownership,
// schema-version validation, and a non-destructive preview are specified.
