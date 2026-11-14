import 'package:decimal/decimal.dart';

class InsightMissingRatePair {
  const InsightMissingRatePair(this.fromCurrency, this.toCurrency);

  final String fromCurrency;
  final String toCurrency;

  String get key => '$fromCurrency->$toCurrency';
}

class MonthlyComparisonResult {
  const MonthlyComparisonResult({
    required this.currentAmount,
    required this.previousAmount,
    required this.changePercent,
    required this.currency,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.missingRates,
  });

  final Decimal currentAmount;
  final Decimal previousAmount;
  final Decimal? changePercent;
  final String currency;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final List<InsightMissingRatePair> missingRates;
}

class TopSpendingCategoryResult {
  const TopSpendingCategoryResult({
    required this.categoryId,
    required this.amount,
    required this.currency,
    required this.periodStart,
    required this.periodEnd,
    required this.missingRates,
  });

  final String categoryId;
  final Decimal amount;
  final String currency;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<InsightMissingRatePair> missingRates;
}

class RecurringTransactionsResult {
  const RecurringTransactionsResult({
    required this.patternCount,
    required this.periodStart,
    required this.periodEnd,
  });

  final int patternCount;
  final DateTime periodStart;
  final DateTime periodEnd;
}

class CashFlowTrendResult {
  const CashFlowTrendResult({
    required this.currentNet,
    required this.previousNet,
    required this.currency,
    required this.periodStart,
    required this.periodEnd,
    required this.missingRates,
  });

  final Decimal currentNet;
  final Decimal previousNet;
  final String currency;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<InsightMissingRatePair> missingRates;
}
