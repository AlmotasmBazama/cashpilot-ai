import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/result.dart';
import '../../features/budgets/application/providers/budgets_providers.dart';
import '../../features/budgets/domain/entities/budget_progress.dart';
import '../../features/dashboard/application/dashboard_providers.dart';
import '../../features/exchange_rates/application/providers/exchange_rates_providers.dart';
import '../../features/goals/application/providers/goals_providers.dart';
import '../../features/goals/domain/entities/goal_progress.dart';
import '../../features/insights/application/providers/insight_use_case_providers.dart';
import '../../features/insights/domain/entities/financial_insight.dart';
import '../../features/insights/domain/entities/insight_analysis_result.dart';

/// App-shell composition for the Insights input assembled from feature-owned
/// read models. The provider remains publicly reachable from the Insights
/// compatibility facade, while no feature owns another feature's snapshot.
final financialInsightsProvider =
    FutureProvider<AppResult<List<FinancialInsight>>>((ref) async {
      final snapshotResult = await ref.watch(dashboardSnapshotProvider.future);
      final budgetResult = await ref.watch(budgetProgressProvider.future);
      final goalResult = await ref.watch(allGoalProgressProvider.future);
      return switch (snapshotResult) {
        AppFailure<DashboardSnapshot>(:final failure) => AppResult.failure(
          failure,
        ),
        AppSuccess<DashboardSnapshot>(:final data) => AppResult.success(
          await ref.watch(generateFinancialInsightsUseCaseProvider)(
            transactions: data.transactions,
            budgets: switch (budgetResult) {
              AppSuccess<List<BudgetProgress>>(:final data) => data,
              _ => const <BudgetProgress>[],
            },
            goals: switch (goalResult) {
              AppSuccess<List<GoalProgress>>(:final data) => data,
              _ => const <GoalProgress>[],
            },
            baseCurrency: data.baseCurrencyCode,
            now: DateTime.now().toUtc(),
            convertMoney: ref.watch(convertMoneyUseCaseProvider).call,
            knownMissingRates: data.missingExchangeRatePairs
                .map(
                  (pair) => InsightMissingRatePair(
                    pair.fromCurrencyCode,
                    pair.toCurrencyCode,
                  ),
                )
                .toList(growable: false),
          ),
        ),
      };
    }, name: 'financialInsightsProvider');
