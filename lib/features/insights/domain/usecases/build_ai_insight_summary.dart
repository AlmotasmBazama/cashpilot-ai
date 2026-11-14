import '../entities/financial_insight.dart';
import '../enums/insight_type.dart';

class BuildAiInsightSummaryUseCase {
  const BuildAiInsightSummaryUseCase();

  Map<String, Object?> call(List<FinancialInsight> insights) {
    return <String, Object?>{
      'insights': [
        for (final insight in insights)
          <String, Object?>{
            'type': insight.type.storageValue,
            'severity': insight.severity.name,
            'currentValue': insight.evidence.currentValue.toString(),
            'previousValue': insight.evidence.previousValue.toString(),
            'changePercent': insight.evidence.changePercent.toString(),
            'currency': insight.evidence.currency,
            'periodStart': insight.periodStart.toIso8601String(),
            'periodEnd': insight.periodEnd.toIso8601String(),
          },
      ],
    };
  }
}
