import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../entities/insight_analysis_result.dart';

class DetectRecurringTransactionsUseCase {
  const DetectRecurringTransactionsUseCase();

  RecurringTransactionsResult call({
    required List<Transaction> transactions,
    required DateTime now,
  }) {
    final end = now.toUtc();
    final start = end.subtract(const Duration(days: 180));
    final groups = <String, List<Transaction>>{};
    for (final transaction in transactions) {
      final date = transaction.transactionDate.toUtc();
      if (transaction.status != TransactionStatus.posted ||
          transaction.type != TransactionType.expense ||
          date.isBefore(start) ||
          date.isAfter(end)) {
        continue;
      }
      final key = transaction.payeeId?.trim().isNotEmpty == true
          ? 'payee:${transaction.payeeId}'
          : 'category:${transaction.categoryId}:'
                '${transaction.amount.normalizedCurrencyCode}:'
                '${transaction.amount.amount}';
      groups.putIfAbsent(key, () => <Transaction>[]).add(transaction);
    }
    var patternCount = 0;
    for (final values in groups.values) {
      if (values.length < 3) {
        continue;
      }
      values.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
      final intervals = <int>[];
      for (var index = 1; index < values.length; index++) {
        intervals.add(
          values[index].transactionDate
              .toUtc()
              .difference(values[index - 1].transactionDate.toUtc())
              .inDays,
        );
      }
      if (intervals.every((days) => days >= 20 && days <= 40)) {
        patternCount++;
      }
    }
    return RecurringTransactionsResult(
      patternCount: patternCount,
      periodStart: start,
      periodEnd: end,
    );
  }
}
