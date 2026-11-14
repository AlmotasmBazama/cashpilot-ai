import 'package:decimal/decimal.dart';

import 'budget.dart';
import '../enums/budget_status.dart';

class BudgetMissingRateWarning {
  const BudgetMissingRateWarning({
    required this.fromCurrencyCode,
    required this.toCurrencyCode,
  });

  final String fromCurrencyCode;
  final String toCurrencyCode;

  String get key => '$fromCurrencyCode->$toCurrencyCode';
}

class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.spentAmount,
    required this.remainingAmount,
    required this.progressPercent,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
    required this.missingRateWarnings,
  });

  final Budget budget;
  final Decimal spentAmount;
  final Decimal remainingAmount;
  final Decimal progressPercent;
  final BudgetStatus status;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<BudgetMissingRateWarning> missingRateWarnings;

  bool get isPartial => missingRateWarnings.isNotEmpty;
}
