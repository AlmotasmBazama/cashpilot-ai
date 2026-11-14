import 'package:decimal/decimal.dart';

import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../entities/insight_analysis_result.dart';
import '../services/insight_conversion_service.dart';

class DetectCashFlowTrendUseCase {
  const DetectCashFlowTrendUseCase({
    InsightConversionService conversionService =
        const InsightConversionService(),
  }) : _conversionService = conversionService;

  final InsightConversionService _conversionService;

  Future<CashFlowTrendResult?> call({
    required List<Transaction> transactions,
    required String baseCurrency,
    required DateTime now,
    required InsightMoneyConverter convertMoney,
  }) async {
    final at = now.toUtc();
    final currentStart = DateTime.utc(at.year, at.month);
    final currentEnd = DateTime.utc(at.year, at.month + 1);
    final previousStart = DateTime.utc(at.year, at.month - 1);
    var currentNet = Decimal.zero;
    var previousNet = Decimal.zero;
    var hasValues = false;
    final missing = <String, InsightMissingRatePair>{};
    for (final transaction in transactions) {
      if (transaction.status != TransactionStatus.posted ||
          (transaction.type != TransactionType.expense &&
              transaction.type != TransactionType.income)) {
        continue;
      }
      final date = transaction.transactionDate.toUtc();
      final isCurrent =
          !date.isBefore(currentStart) && date.isBefore(currentEnd);
      final isPrevious =
          !date.isBefore(previousStart) && date.isBefore(currentStart);
      if (!isCurrent && !isPrevious) {
        continue;
      }
      hasValues = true;
      final converted = await _conversionService.convertTransaction(
        transaction: transaction,
        baseCurrency: baseCurrency,
        convertMoney: convertMoney,
      );
      if (converted.missingRate case final pair?) {
        missing[pair.key] = pair;
        continue;
      }
      final signedAmount = transaction.type == TransactionType.income
          ? converted.amount!
          : -converted.amount!;
      if (isCurrent) {
        currentNet += signedAmount;
      } else {
        previousNet += signedAmount;
      }
    }
    return hasValues
        ? CashFlowTrendResult(
            currentNet: currentNet,
            previousNet: previousNet,
            currency: baseCurrency.toUpperCase(),
            periodStart: currentStart,
            periodEnd: currentEnd,
            missingRates: missing.values.toList(growable: false),
          )
        : null;
  }
}
