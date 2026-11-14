import 'package:decimal/decimal.dart';

import '../../../budgets/domain/entities/budget_progress.dart';
import '../../../budgets/domain/enums/budget_status.dart';
import '../../../goals/domain/entities/goal_progress.dart';
import '../../../goals/domain/enums/goal_status.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../entities/financial_insight.dart';
import '../entities/insight_analysis_result.dart';
import '../entities/insight_evidence.dart';
import '../enums/insight_severity.dart';
import '../enums/insight_type.dart';
import '../services/insight_conversion_service.dart';
import 'calculate_monthly_comparison.dart';
import 'detect_cash_flow_trend.dart';
import 'detect_missing_exchange_rate_insights.dart';
import 'detect_recurring_transactions.dart';
import 'detect_top_spending_category.dart';

class GenerateFinancialInsightsUseCase {
  const GenerateFinancialInsightsUseCase({
    CalculateMonthlyComparisonUseCase monthlyComparison =
        const CalculateMonthlyComparisonUseCase(),
    DetectTopSpendingCategoryUseCase topCategory =
        const DetectTopSpendingCategoryUseCase(),
    DetectRecurringTransactionsUseCase recurringTransactions =
        const DetectRecurringTransactionsUseCase(),
    DetectCashFlowTrendUseCase cashFlowTrend =
        const DetectCashFlowTrendUseCase(),
    DetectMissingExchangeRateInsightsUseCase missingRates =
        const DetectMissingExchangeRateInsightsUseCase(),
  }) : _monthlyComparison = monthlyComparison,
       _topCategory = topCategory,
       _recurringTransactions = recurringTransactions,
       _cashFlowTrend = cashFlowTrend,
       _missingRates = missingRates;

  final CalculateMonthlyComparisonUseCase _monthlyComparison;
  final DetectTopSpendingCategoryUseCase _topCategory;
  final DetectRecurringTransactionsUseCase _recurringTransactions;
  final DetectCashFlowTrendUseCase _cashFlowTrend;
  final DetectMissingExchangeRateInsightsUseCase _missingRates;

  Future<List<FinancialInsight>> call({
    required List<Transaction> transactions,
    required List<BudgetProgress> budgets,
    required List<GoalProgress> goals,
    required String baseCurrency,
    required DateTime now,
    required InsightMoneyConverter convertMoney,
    List<InsightMissingRatePair> knownMissingRates =
        const <InsightMissingRatePair>[],
  }) async {
    final monthly = await _monthlyComparison(
      transactions: transactions,
      baseCurrency: baseCurrency,
      now: now,
      convertMoney: convertMoney,
    );
    final top = await _topCategory(
      transactions: transactions,
      baseCurrency: baseCurrency,
      now: now,
      convertMoney: convertMoney,
    );
    final recurring = _recurringTransactions(
      transactions: transactions,
      now: now,
    );
    final cashFlow = await _cashFlowTrend(
      transactions: transactions,
      baseCurrency: baseCurrency,
      now: now,
      convertMoney: convertMoney,
    );

    final values = <FinancialInsight>[];
    final change = monthly.changePercent;
    if (change != null && change >= Decimal.fromInt(10)) {
      values.add(
        FinancialInsight.create(
          type: InsightType.spendingIncrease,
          severity: InsightSeverity.warning,
          title: 'Spending increased',
          message:
              'Spending is up ${change.toStringAsFixed(1)}% compared with last month.',
          evidence: InsightEvidence(
            metricName: 'monthly_expense',
            currentValue: monthly.currentAmount,
            previousValue: monthly.previousAmount,
            changePercent: change,
            currency: monthly.currency,
          ),
          actionLabel: 'Review report',
          actionRoute: '/reports',
          periodStart: monthly.currentPeriodStart,
          periodEnd: monthly.currentPeriodEnd,
        ),
      );
    } else if (change != null && change <= Decimal.fromInt(-10)) {
      values.add(
        FinancialInsight.create(
          type: InsightType.positiveTrend,
          severity: InsightSeverity.positive,
          title: 'Spending trend improved',
          message:
              'Spending is down ${change.abs().toStringAsFixed(1)}% compared with last month.',
          evidence: InsightEvidence(
            metricName: 'monthly_expense',
            currentValue: monthly.currentAmount,
            previousValue: monthly.previousAmount,
            changePercent: change,
            currency: monthly.currency,
          ),
          actionRoute: '/reports',
          periodStart: monthly.currentPeriodStart,
          periodEnd: monthly.currentPeriodEnd,
        ),
      );
    }

    if (top != null) {
      values.add(
        FinancialInsight.create(
          type: InsightType.topCategory,
          severity: InsightSeverity.info,
          title: 'Top spending category',
          message: '${top.categoryId} leads spending this month.',
          evidence: InsightEvidence(
            metricName: 'top_category',
            currentValue: top.amount,
            previousValue: Decimal.zero,
            changePercent: Decimal.zero,
            currency: top.currency,
            relatedCategoryId: top.categoryId,
          ),
          actionLabel: 'Review categories',
          actionRoute: '/reports',
          periodStart: top.periodStart,
          periodEnd: top.periodEnd,
        ),
      );
    }

    if (recurring.patternCount > 0) {
      values.add(
        FinancialInsight.create(
          type: InsightType.recurringPaymentDetected,
          severity: InsightSeverity.info,
          title: 'Possible recurring payments',
          message:
              '${recurring.patternCount} possible recurring payment patterns were detected locally.',
          evidence: InsightEvidence(
            metricName: 'recurring_pattern_count',
            currentValue: Decimal.fromInt(recurring.patternCount),
            previousValue: Decimal.zero,
            changePercent: Decimal.zero,
            currency: baseCurrency.toUpperCase(),
          ),
          actionRoute: '/transactions',
          periodStart: recurring.periodStart,
          periodEnd: recurring.periodEnd,
        ),
      );
    }

    if (cashFlow != null && cashFlow.currentNet < Decimal.zero) {
      values.add(
        FinancialInsight.create(
          type: InsightType.cashFlowWarning,
          severity: InsightSeverity.critical,
          title: 'Cash flow needs attention',
          message: 'Posted expenses are above income for the current month.',
          evidence: InsightEvidence(
            metricName: 'monthly_net_cash_flow',
            currentValue: cashFlow.currentNet,
            previousValue: cashFlow.previousNet,
            changePercent: Decimal.zero,
            currency: cashFlow.currency,
          ),
          actionLabel: 'Review cash flow',
          actionRoute: '/reports',
          periodStart: cashFlow.periodStart,
          periodEnd: cashFlow.periodEnd,
        ),
      );
    } else if (cashFlow != null &&
        cashFlow.currentNet > Decimal.zero &&
        cashFlow.currentNet > cashFlow.previousNet) {
      values.add(
        FinancialInsight.create(
          type: InsightType.positiveTrend,
          severity: InsightSeverity.positive,
          title: 'Positive cash-flow trend',
          message: 'Income is ahead of expenses for the current month.',
          evidence: InsightEvidence(
            metricName: 'monthly_net_cash_flow',
            currentValue: cashFlow.currentNet,
            previousValue: cashFlow.previousNet,
            changePercent: Decimal.zero,
            currency: cashFlow.currency,
          ),
          actionRoute: '/reports',
          periodStart: cashFlow.periodStart,
          periodEnd: cashFlow.periodEnd,
        ),
      );
    }

    for (final progress in budgets.where(
      (value) =>
          value.status == BudgetStatus.warning ||
          value.status == BudgetStatus.exceeded,
    )) {
      values.add(
        FinancialInsight.create(
          type: InsightType.budgetWarning,
          severity: progress.status == BudgetStatus.exceeded
              ? InsightSeverity.critical
              : InsightSeverity.warning,
          title: 'Budget alert',
          message:
              '${progress.budget.name} is at ${progress.progressPercent.toStringAsFixed(1)}%.',
          evidence: InsightEvidence(
            metricName: progress.budget.name,
            currentValue: progress.progressPercent,
            previousValue: Decimal.zero,
            changePercent: progress.progressPercent,
            currency: progress.budget.currency,
            relatedCategoryId: progress.budget.categoryId,
          ),
          actionLabel: 'Review budget',
          actionRoute: '/budgets',
          periodStart: progress.periodStart,
          periodEnd: progress.periodEnd,
        ),
      );
    }

    final visibleGoals =
        goals
            .where((value) => value.status != GoalStatus.archived)
            .toList(growable: false)
          ..sort((a, b) => b.progressPercent.compareTo(a.progressPercent));
    if (visibleGoals.firstOrNull case final progress?) {
      values.add(
        FinancialInsight.create(
          type: InsightType.goalProgress,
          severity: progress.status == GoalStatus.completed
              ? InsightSeverity.positive
              : InsightSeverity.info,
          title: 'Goal progress',
          message:
              '${progress.goal.title} is at ${progress.progressPercent.toStringAsFixed(1)}%.',
          evidence: InsightEvidence(
            metricName: progress.goal.title,
            currentValue: progress.currentAmount,
            previousValue: progress.remainingAmount,
            changePercent: progress.progressPercent,
            currency: progress.goal.currency,
          ),
          actionLabel: 'Review goals',
          actionRoute: '/goals',
          periodStart: progress.goal.createdAt,
          periodEnd: progress.goal.targetDate ?? now,
        ),
      );
    }

    final missing = <String, InsightMissingRatePair>{
      for (final pair in knownMissingRates) pair.key: pair,
      for (final pair in monthly.missingRates) pair.key: pair,
      if (top != null)
        for (final pair in top.missingRates) pair.key: pair,
      if (cashFlow != null)
        for (final pair in cashFlow.missingRates) pair.key: pair,
    };
    values.addAll(
      _missingRates(
        pairs: missing.values,
        periodStart: monthly.currentPeriodStart,
        periodEnd: monthly.currentPeriodEnd,
      ),
    );
    values.sort(
      (a, b) => _severityRank(b.severity).compareTo(_severityRank(a.severity)),
    );
    return values.take(10).toList(growable: false);
  }

  int _severityRank(InsightSeverity value) => switch (value) {
    InsightSeverity.critical => 4,
    InsightSeverity.warning => 3,
    InsightSeverity.positive => 2,
    InsightSeverity.info => 1,
  };
}
