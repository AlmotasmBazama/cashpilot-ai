import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../enums/income_source_type.dart';

abstract final class IncomeReportingPolicy {
  static bool isNormalIncome(Transaction transaction) {
    return _isPostedIncome(transaction) &&
        _bucket(transaction) == IncomeSourceReportingBucket.ordinaryIncome;
  }

  static bool isEarnedIncome(Transaction transaction) {
    return _isPostedIncome(transaction) &&
        (transaction.incomeSourceType?.isEarnedIncome ?? false);
  }

  static bool isRefundOrReimbursement(Transaction transaction) {
    return _isPostedIncome(transaction) &&
        _bucket(transaction) ==
            IncomeSourceReportingBucket.refundOrReimbursement;
  }

  static bool _isPostedIncome(Transaction transaction) =>
      transaction.status == TransactionStatus.posted &&
      transaction.type == TransactionType.income;

  static IncomeSourceReportingBucket _bucket(Transaction transaction) =>
      transaction.incomeSourceType?.reportingBucket ??
      IncomeSourceReportingBucket.unclassified;
}
