import 'package:decimal/decimal.dart';

import '../entities/financial_insight.dart';
import '../entities/insight_analysis_result.dart';
import '../entities/insight_evidence.dart';
import '../enums/insight_severity.dart';
import '../enums/insight_type.dart';

class DetectMissingExchangeRateInsightsUseCase {
  const DetectMissingExchangeRateInsightsUseCase();

  List<FinancialInsight> call({
    required Iterable<InsightMissingRatePair> pairs,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final unique = <String, InsightMissingRatePair>{
      for (final pair in pairs) pair.key: pair,
    };
    return unique.values
        .map(
          (pair) => FinancialInsight.create(
            type: InsightType.missingExchangeRate,
            severity: InsightSeverity.warning,
            title: 'Missing exchange rate',
            message:
                '${pair.fromCurrency} to ${pair.toCurrency} is missing, so some totals are partial.',
            evidence: InsightEvidence(
              metricName: pair.key,
              currentValue: Decimal.zero,
              previousValue: Decimal.zero,
              changePercent: Decimal.zero,
              currency: pair.toCurrency,
            ),
            actionLabel: 'Review rates',
            actionRoute: '/settings',
            periodStart: periodStart,
            periodEnd: periodEnd,
          ),
        )
        .toList(growable: false);
  }
}
