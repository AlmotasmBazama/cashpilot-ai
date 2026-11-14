import 'package:decimal/decimal.dart';

import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../entities/insight_analysis_result.dart';
import '../services/insight_conversion_service.dart';

class DetectTopSpendingCategoryUseCase {
  const DetectTopSpendingCategoryUseCase({
    InsightConversionService conversionService =
        const InsightConversionService(),
  }) : _conversionService = conversionService;

  final InsightConversionService _conversionService;

  Future<TopSpendingCategoryResult?> call({
    required List<Transaction> transactions,
    required String baseCurrency,
    required DateTime now,
    required InsightMoneyConverter convertMoney,
  }) async {
    final at = now.toUtc();
    final start = DateTime.utc(at.year, at.month);
    final end = DateTime.utc(at.year, at.month + 1);
    final totals = <String, Decimal>{};
    final missing = <String, InsightMissingRatePair>{};
    for (final transaction in transactions) {
      final date = transaction.transactionDate.toUtc();
      if (transaction.status != TransactionStatus.posted ||
          transaction.type != TransactionType.expense ||
          date.isBefore(start) ||
          !date.isBefore(end)) {
        continue;
      }
      final converted = await _conversionService.convertTransaction(
        transaction: transaction,
        baseCurrency: baseCurrency,
        convertMoney: convertMoney,
      );
      if (converted.missingRate case final pair?) {
        missing[pair.key] = pair;
        continue;
      }
      totals.update(
        transaction.categoryId,
        (value) => value + converted.amount!,
        ifAbsent: () => converted.amount!,
      );
    }
    if (totals.isEmpty) {
      return null;
    }
    final top = totals.entries.reduce(
      (left, right) => left.value >= right.value ? left : right,
    );
    return TopSpendingCategoryResult(
      categoryId: top.key,
      amount: top.value,
      currency: baseCurrency.toUpperCase(),
      periodStart: start,
      periodEnd: end,
      missingRates: missing.values.toList(growable: false),
    );
  }
}
