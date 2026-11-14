import '../../../../core/owner_scope/domain/owner_scope.dart';

/// Narrow deletion-facing view of the effective-auth completion overlay.
abstract interface class AccountDeletionCompletionOverlay {
  Stream<void> get changes;

  bool hasTrustedCompletion({
    required String operationId,
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
  });

  Future<void> markCompleted({
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
    required String operationId,
  });
}
