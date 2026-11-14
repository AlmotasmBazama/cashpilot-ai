import '../../../../core/error/app_exception.dart';
import '../enums/transaction_status.dart';
import '../failures/transaction_failure_codes.dart';

void validateTransactionStatusTransition(
  TransactionStatus current,
  TransactionStatus target,
) {
  if (current == target) {
    return;
  }

  if (current == TransactionStatus.cancelled ||
      current == TransactionStatus.failed) {
    throw AppException.validation(
      message: 'A ${current.name} transaction cannot change status.',
      code: TransactionFailureCodes.terminalStatus,
    );
  }

  final isAllowed =
      (current == TransactionStatus.pending &&
          (target == TransactionStatus.posted ||
              target == TransactionStatus.cancelled)) ||
      (current == TransactionStatus.posted &&
          (target == TransactionStatus.pending ||
              target == TransactionStatus.cancelled));
  if (!isAllowed) {
    throw AppException.validation(
      message:
          'Transaction status cannot change from ${current.name} to ${target.name}.',
      code: TransactionFailureCodes.invalidStatusTransition,
    );
  }
}
