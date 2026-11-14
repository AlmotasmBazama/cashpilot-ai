import 'package:decimal/decimal.dart';

import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../entities/insight_analysis_result.dart';
import '../services/insight_conversion_service.dart';

class CalculateMonthlyComparisonUseCase {
  const CalculateMonthlyComparisonUseCase({
    InsightConversionService conversionService =
        const InsightConversionService(),
  }) : _conversionService = conversionService;

  final InsightConversionService _conversionService;

  Future<MonthlyComparisonResult> call({
    required List<Transaction> transactions,
    required String baseCurrency,
    required DateTime now,
    required InsightMoneyConverter convertMoney,
  }) async {
    final at = now.toUtc();
    final currentStart = DateTime.utc(at.year, at.month);
    final currentEnd = DateTime.utc(at.year, at.month + 1);
    final previousStart = DateTime.utc(at.year, at.month - 1);
    var current = Decimal.zero;
    var previous = Decimal.zero;
    final missing = <String, InsightMissingRatePair>{};
    for (final transaction in transactions) {
      if (transaction.status != TransactionStatus.posted ||
          transaction.type != TransactionType.expense) {
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
      final converted = await _conversionService.convertTransaction(
        transaction: transaction,
        baseCurrency: baseCurrency,
        convertMoney: convertMoney,
      );
      if (converted.missingRate case final pair?) {
        missing[pair.key] = pair;
        continue;
      }
      if (isCurrent) {
        current += converted.amount!;
      } else {
        previous += converted.amount!;
      }
    }
    final change = previous == Decimal.zero
        ? null
        : ((current - previous) / previous).toDecimal(
                scaleOnInfinitePrecision: 8,
              ) *
              Decimal.fromInt(100);
    return MonthlyComparisonResult(
      currentAmount: current,
      previousAmount: previous,
      changePercent: change,
      currency: baseCurrency.toUpperCase(),
      currentPeriodStart: currentStart,
      currentPeriodEnd: currentEnd,
      missingRates: missing.values.toList(growable: false),
    );
  }
}
