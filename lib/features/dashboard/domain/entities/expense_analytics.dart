import 'package:decimal/decimal.dart';

enum ExpenseAnalyticsPeriod { week, month }

enum ExpenseComparisonDirection {
  increased,
  decreased,
  unchanged,
  noPreviousData,
  unavailable,
}

class ExpenseAnalyticsDateRange {
  const ExpenseAnalyticsDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class ExpenseAnalyticsRanges {
  const ExpenseAnalyticsRanges({
    required this.period,
    required this.current,
    required this.previous,
    required this.timeZoneName,
  });

  final ExpenseAnalyticsPeriod period;
  final ExpenseAnalyticsDateRange current;
  final ExpenseAnalyticsDateRange previous;
  final String timeZoneName;
}

class ExpenseAnalyticsQuery {
  const ExpenseAnalyticsQuery({
    required this.ranges,
    required this.baseCurrencyCode,
  });

  final ExpenseAnalyticsRanges ranges;
  final String baseCurrencyCode;
}

class ExpenseCategoryAnalytics {
  const ExpenseCategoryAnalytics({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIconKey,
    required this.categoryColorArgb,
    required this.isDefaultCategory,
    required this.amount,
    required this.percentage,
  });

  final String categoryId;
  final String categoryName;
  final String categoryIconKey;
  final int categoryColorArgb;
  final bool isDefaultCategory;
  final Decimal amount;
  final Decimal percentage;
}

class ExpenseAnalyticsWarning {
  const ExpenseAnalyticsWarning({
    required this.fromCurrencyCode,
    required this.toCurrencyCode,
  });

  final String fromCurrencyCode;
  final String toCurrencyCode;

  String get key => '$fromCurrencyCode->$toCurrencyCode';
}

class ExpenseAnalyticsQueryMetrics {
  const ExpenseAnalyticsQueryMetrics({
    required this.sourceRowCount,
    required this.aggregateRowCount,
    required this.processingDuration,
  });

  final int sourceRowCount;
  final int aggregateRowCount;
  final Duration processingDuration;
}

class ExpenseAnalyticsSnapshot {
  const ExpenseAnalyticsSnapshot({
    required this.selectedPeriod,
    required this.currentDateRange,
    required this.previousDateRange,
    required this.totalExpense,
    required this.previousTotalExpense,
    required this.percentageChange,
    required this.comparisonDirection,
    required this.topCategories,
    required this.otherTotal,
    required this.otherPercentage,
    required this.currencyCode,
    required this.isPartial,
    required this.warnings,
    required this.hasCurrentExpenses,
    required this.metrics,
  });

  final ExpenseAnalyticsPeriod selectedPeriod;
  final ExpenseAnalyticsDateRange currentDateRange;
  final ExpenseAnalyticsDateRange previousDateRange;
  final Decimal totalExpense;
  final Decimal previousTotalExpense;
  final Decimal? percentageChange;
  final ExpenseComparisonDirection comparisonDirection;
  final List<ExpenseCategoryAnalytics> topCategories;
  final Decimal otherTotal;
  final Decimal otherPercentage;
  final String currencyCode;
  final bool isPartial;
  final List<ExpenseAnalyticsWarning> warnings;
  final bool hasCurrentExpenses;
  final ExpenseAnalyticsQueryMetrics metrics;
}
