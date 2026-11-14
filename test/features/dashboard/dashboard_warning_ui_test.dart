import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/features/accounts/application/providers/accounts_providers.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/dashboard/application/dashboard_providers.dart';
import 'package:cashpilot_ai/features/dashboard/application/expense_analytics_providers.dart';
import 'package:cashpilot_ai/features/dashboard/domain/entities/expense_analytics.dart';
import 'package:cashpilot_ai/features/budgets/application/providers/budgets_providers.dart';
import 'package:cashpilot_ai/features/goals/application/providers/goals_providers.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard renders total count and missing-rate pair warning', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final zero = CurrencyTotal(currencyCode: 'LYD', amount: Decimal.zero);
    final snapshot = DashboardSnapshot(
      accounts: const [],
      transactions: const [],
      categories: const [],
      baseCurrencyCode: 'LYD',
      netWorthInBaseCurrency: zero,
      unconvertedNetWorthByCurrency: const [],
      netWorthByCurrency: <CurrencyTotal>[zero],
      monthlyIncomeByCurrency: <CurrencyTotal>[zero],
      monthlyExpenseByCurrency: <CurrencyTotal>[zero],
      monthlySavingsByCurrency: <CurrencyTotal>[zero],
      yearlyIncomeByCurrency: <CurrencyTotal>[zero],
      yearlyExpenseByCurrency: <CurrencyTotal>[zero],
      yearlySavingsByCurrency: <CurrencyTotal>[zero],
      recentTransactions: const [],
      spendingByCategory: const [],
      monthlyExpenseTrend: List<Decimal>.filled(6, Decimal.zero),
      missingExchangeRatePairs: const <MissingExchangeRatePair>[
        MissingExchangeRatePair('USD', 'LYD'),
      ],
      totalTransactionCount: 10020,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAuthUserProvider.overrideWithValue(null),
          dashboardSnapshotProvider.overrideWith(
            (_) async => AppResult<DashboardSnapshot>.success(snapshot),
          ),
          expenseAnalyticsProvider.overrideWith(
            (_, period) => Stream.value(
              AppResult<ExpenseAnalyticsSnapshot>.success(
                _expenseAnalyticsSnapshot(period),
              ),
            ),
          ),
          budgetSummaryProvider.overrideWith(
            (_) async => const AppResult<BudgetSummary>.success(
              BudgetSummary(
                activeCount: 0,
                warningCount: 0,
                exceededCount: 0,
                topWarning: null,
              ),
            ),
          ),
          goalSummaryProvider.overrideWith(
            (_) async => const AppResult<GoalSummary>.success(
              GoalSummary(
                activeCount: 0,
                savedTotals: <GoalCurrencyTotal>[],
                nearestTargetDate: null,
                completedCount: 0,
              ),
            ),
          ),
          financialInsightsProvider.overrideWith(
            (_) async => AppResult<List<FinancialInsight>>.success(const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: CPTheme.dark(),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Net worth is partially calculated.'), findsOneWidget);
    expect(find.textContaining('USD \u2192 LYD'), findsOneWidget);
    expect(find.text('10020'), findsOneWidget);
    final quickActionsTop = tester.getTopLeft(find.text('Quick actions')).dy;
    final analyticsTop = tester
        .getTopLeft(find.byKey(const Key('expense_analytics_card')))
        .dy;
    final recentTop = tester.getTopLeft(find.text('Recent transactions')).dy;
    expect(analyticsTop, greaterThan(quickActionsTop));
    expect(analyticsTop, lessThan(recentTop));
    expect(find.text('Add expense'), findsWidgets);
    expect(
      find.text('No budgets yet'),
      findsNothing,
      reason: 'Planning tools stay out of the action-first Home screen.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard Retry clears cached account and category failures', (
    tester,
  ) async {
    var accountReads = 0;
    var categoryReads = 0;
    final snapshot = _emptySnapshot();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAuthUserProvider.overrideWithValue(null),
          accountsProvider.overrideWith((_) async {
            accountReads += 1;
            return accountReads == 1
                ? const AppResult<List<Account>>.failure(
                    Failure(message: 'transient account failure'),
                  )
                : const AppResult<List<Account>>.success(<Account>[]);
          }),
          categoriesProvider.overrideWith((_) async {
            categoryReads += 1;
            return categoryReads == 1
                ? const AppResult<List<Category>>.failure(
                    Failure(message: 'transient category failure'),
                  )
                : const AppResult<List<Category>>.success(<Category>[]);
          }),
          dashboardSnapshotProvider.overrideWith((ref) async {
            final accounts = await ref.watch(accountsProvider.future);
            final categories = await ref.watch(categoriesProvider.future);
            if (accounts is AppFailure<List<Account>> ||
                categories is AppFailure<List<Category>>) {
              return const AppResult<DashboardSnapshot>.failure(
                Failure(message: 'transient dependency failure'),
              );
            }
            return AppResult<DashboardSnapshot>.success(snapshot);
          }),
          budgetSummaryProvider.overrideWith(
            (_) async => const AppResult<BudgetSummary>.success(
              BudgetSummary(
                activeCount: 0,
                warningCount: 0,
                exceededCount: 0,
                topWarning: null,
              ),
            ),
          ),
          goalSummaryProvider.overrideWith(
            (_) async => const AppResult<GoalSummary>.success(
              GoalSummary(
                activeCount: 0,
                savedTotals: <GoalCurrencyTotal>[],
                nearestTargetDate: null,
                completedCount: 0,
              ),
            ),
          ),
          financialInsightsProvider.overrideWith(
            (_) async => AppResult<List<FinancialInsight>>.success(const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: CPTheme.dark(),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load dashboard'), findsOneWidget);
    expect(accountReads, 1);
    expect(categoryReads, 1);

    await tester.tap(find.widgetWithText(CPButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(accountReads, 2);
    expect(categoryReads, 2);
    expect(find.text('Total net worth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard supports both themes, Arabic RTL, and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cases = <({Locale locale, ThemeData theme})>[
      (locale: const Locale('en'), theme: CPTheme.light()),
      (locale: const Locale('en'), theme: CPTheme.dark()),
      (locale: const Locale('ar'), theme: CPTheme.dark()),
    ];

    for (final testCase in cases) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthUserProvider.overrideWithValue(null),
            dashboardSnapshotProvider.overrideWith(
              (_) async =>
                  AppResult<DashboardSnapshot>.success(_emptySnapshot()),
            ),
            budgetSummaryProvider.overrideWith(
              (_) async => const AppResult<BudgetSummary>.success(
                BudgetSummary(
                  activeCount: 0,
                  warningCount: 0,
                  exceededCount: 0,
                  topWarning: null,
                ),
              ),
            ),
            goalSummaryProvider.overrideWith(
              (_) async => const AppResult<GoalSummary>.success(
                GoalSummary(
                  activeCount: 0,
                  savedTotals: <GoalCurrencyTotal>[],
                  nearestTargetDate: null,
                  completedCount: 0,
                ),
              ),
            ),
            financialInsightsProvider.overrideWith(
              (_) async => AppResult<List<FinancialInsight>>.success(const []),
            ),
          ],
          child: MaterialApp(
            locale: testCase.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: testCase.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

DashboardSnapshot _emptySnapshot() {
  final zero = CurrencyTotal(currencyCode: 'LYD', amount: Decimal.zero);
  return DashboardSnapshot(
    accounts: const [],
    transactions: const [],
    categories: const [],
    baseCurrencyCode: 'LYD',
    netWorthInBaseCurrency: zero,
    unconvertedNetWorthByCurrency: const [],
    netWorthByCurrency: <CurrencyTotal>[zero],
    monthlyIncomeByCurrency: <CurrencyTotal>[zero],
    monthlyExpenseByCurrency: <CurrencyTotal>[zero],
    monthlySavingsByCurrency: <CurrencyTotal>[zero],
    yearlyIncomeByCurrency: <CurrencyTotal>[zero],
    yearlyExpenseByCurrency: <CurrencyTotal>[zero],
    yearlySavingsByCurrency: <CurrencyTotal>[zero],
    recentTransactions: const [],
    spendingByCategory: const [],
    monthlyExpenseTrend: List<Decimal>.filled(6, Decimal.zero),
    missingExchangeRatePairs: const [],
    totalTransactionCount: 0,
  );
}

ExpenseAnalyticsSnapshot _expenseAnalyticsSnapshot(
  ExpenseAnalyticsPeriod period,
) {
  final currentStart = period == ExpenseAnalyticsPeriod.month
      ? DateTime.utc(2026, 8)
      : DateTime.utc(2026, 8, 17);
  return ExpenseAnalyticsSnapshot(
    selectedPeriod: period,
    currentDateRange: ExpenseAnalyticsDateRange(
      start: currentStart,
      end: DateTime.utc(2026, 8, 23),
    ),
    previousDateRange: ExpenseAnalyticsDateRange(
      start: period == ExpenseAnalyticsPeriod.month
          ? DateTime.utc(2026, 7)
          : DateTime.utc(2026, 8, 10),
      end: currentStart,
    ),
    totalExpense: Decimal.parse('50'),
    previousTotalExpense: Decimal.parse('40'),
    percentageChange: Decimal.parse('25'),
    comparisonDirection: ExpenseComparisonDirection.increased,
    topCategories: const [],
    otherTotal: Decimal.zero,
    otherPercentage: Decimal.zero,
    currencyCode: 'LYD',
    isPartial: false,
    warnings: const [],
    hasCurrentExpenses: true,
    metrics: const ExpenseAnalyticsQueryMetrics(
      sourceRowCount: 2,
      aggregateRowCount: 2,
      processingDuration: Duration.zero,
    ),
  );
}
