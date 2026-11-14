import 'package:decimal/decimal.dart';

class InsightEvidence {
  const InsightEvidence({
    required this.metricName,
    required this.currentValue,
    required this.previousValue,
    required this.changePercent,
    required this.currency,
    this.relatedCategoryId,
    this.relatedPayeeId,
  });

  final String metricName;
  final Decimal currentValue;
  final Decimal previousValue;
  final Decimal changePercent;
  final String currency;
  final String? relatedCategoryId;
  final String? relatedPayeeId;
}
