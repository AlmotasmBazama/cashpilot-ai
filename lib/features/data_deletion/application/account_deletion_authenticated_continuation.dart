import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../data/datasources/account_deletion_auth_data_source.dart';
import '../domain/entities/data_deletion_operation_context.dart';
import '../domain/entities/data_deletion_request.dart';
import '../domain/failures/data_deletion_failure_codes.dart';

typedef AccountDeletionContinuationExecutor =
    Future<AppResult<DataDeletionReport>> Function(DataDeletionRequest request);

/// Authorizes only the cached authenticated session whose opaque owner scope
/// matches one and only one startup-recovery target. No owner database or
/// routed feature provider is touched while a different account is active.
final class AccountDeletionAuthenticatedContinuation {
  const AccountDeletionAuthenticatedContinuation({
    required AccountDeletionAuthDataSource authDataSource,
    required AccountDeletionContinuationExecutor deleteAll,
  }) : _authDataSource = authDataSource,
       _deleteAll = deleteAll;

  final AccountDeletionAuthDataSource _authDataSource;
  final AccountDeletionContinuationExecutor _deleteAll;

  Future<AccountDeletionContinuationAuthorization?> authorize(
    List<AccountDeletionRecoveryTarget> targets,
  ) async {
    final lease = await _authDataSource.issueConfirmationLease();
    final ownerScopeValue = lease.ownerScopeValue;
    final generation = lease.authSessionGeneration;
    final matches = ownerScopeValue == null
        ? const <AccountDeletionRecoveryTarget>[]
        : targets
              .where((target) => target.ownerScopeValue == ownerScopeValue)
              .toList(growable: false);
    if (generation == null || matches.length != 1) {
      _authDataSource.releaseConfirmationLease(lease);
      return null;
    }
    return AccountDeletionContinuationAuthorization._(
      target: matches.single,
      confirmationLease: lease,
    );
  }

  Future<AppResult<DataDeletionReport>> complete(
    AccountDeletionContinuationAuthorization authorization, {
    String? email,
    String? password,
  }) async {
    final lease = authorization.confirmationLease;
    final target = authorization.target;
    if (lease.ownerScopeValue != target.ownerScopeValue ||
        lease.authSessionGeneration == null) {
      _authDataSource.releaseConfirmationLease(lease);
      return _identityFailure();
    }
    late final AppResult<DataDeletionReport> result;
    try {
      result = await _deleteAll(
        DataDeletionRequest(
          confirmationAccepted: true,
          confirmationLease: lease,
          email: email,
          password: password,
          expectedRecoveryTarget: target,
        ),
      );
    } finally {
      // captureSession consumes this token on the normal path. A restricted
      // executor may reject before repository construction, so remove any
      // still-pending capability on every exit as a defense-in-depth cleanup.
      _authDataSource.releaseConfirmationLease(lease);
    }
    if (result case AppSuccess<DataDeletionReport>(data: final report)) {
      final proof = report.completionProof;
      if (!proof.authDeletionCompleted ||
          proof.operationId != target.operationId ||
          proof.targetOwnerScopeValue != target.ownerScopeValue) {
        return _identityFailure();
      }
    }
    return result;
  }

  void release(AccountDeletionContinuationAuthorization authorization) {
    _authDataSource.releaseConfirmationLease(authorization.confirmationLease);
  }

  AppResult<DataDeletionReport> _identityFailure() => const AppResult.failure(
    Failure(
      message: 'The authenticated account does not own this recovery.',
      code: DataDeletionFailureCodes.identityChanged,
    ),
  );
}

final class AccountDeletionContinuationAuthorization {
  const AccountDeletionContinuationAuthorization._({
    required this.target,
    required this.confirmationLease,
  });

  final AccountDeletionRecoveryTarget target;
  final AccountDeletionConfirmationLease confirmationLease;
}
