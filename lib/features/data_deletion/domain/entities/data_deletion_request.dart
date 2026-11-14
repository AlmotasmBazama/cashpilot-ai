import 'data_deletion_operation_context.dart';

final class AccountDeletionConfirmationLease {
  const AccountDeletionConfirmationLease({
    required this.opaqueToken,
    required this.isAnonymous,
    this.email,
    this.ownerScopeValue,
    this.authSessionGeneration,
  });

  final String opaqueToken;
  final bool isAnonymous;
  final String? email;
  final String? ownerScopeValue;
  final int? authSessionGeneration;
}

class DataDeletionRequest {
  const DataDeletionRequest({
    required this.confirmationAccepted,
    required this.confirmationLease,
    this.email,
    this.password,
    this.expectedRecoveryTarget,
  });

  final bool confirmationAccepted;
  final AccountDeletionConfirmationLease confirmationLease;
  final String? email;
  final String? password;
  final AccountDeletionRecoveryTarget? expectedRecoveryTarget;
}

class DataDeletionReport {
  const DataDeletionReport({
    required this.cloudDocumentsDeleted,
    required this.localRowsDeleted,
    required this.completionProof,
  });

  final int cloudDocumentsDeleted;
  final int localRowsDeleted;
  final DataDeletionCompletionProof completionProof;
}

/// Repository-issued evidence that the authoritative Auth deletion boundary
/// completed for the same opaque owner scope that initiated the operation.
class DataDeletionCompletionProof {
  const DataDeletionCompletionProof({
    required this.operationId,
    required this.targetOwnerScopeValue,
    required this.authStateGeneration,
    required this.authDeletionCompleted,
  });

  final String operationId;
  final String targetOwnerScopeValue;
  final int authStateGeneration;
  final bool authDeletionCompleted;

  bool matchesOwnerScope(String ownerScopeValue) =>
      authDeletionCompleted &&
      operationId.trim().isNotEmpty &&
      targetOwnerScopeValue == ownerScopeValue;
}
