import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/dashboard/application/dashboard_providers.dart';
import 'package:cashpilot_ai/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/insight_evidence.dart';
import 'package:cashpilot_ai/features/insights/domain/enums/insight_severity.dart';
import 'package:cashpilot_ai/features/insights/domain/enums/insight_type.dart';
import 'package:cashpilot_ai/features/insights/presentation/widgets/financial_insight_card.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('RTL insight card renders at 320px without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        locale: const Locale('ar'),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: FinancialInsightCard(insight: _insight()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ارتفاع في الإنفاق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard keeps planning insights off the daily Home', (
    tester,
  ) async {
    final zero = CurrencyTotal(currencyCode: 'LYD', amount: Decimal.zero);
    final snapshot = DashboardSnapshot(
      accounts: const [],
      transactions: const [],
      categories: const [],
      baseCurrencyCode: 'LYD',
      netWorthInBaseCurrency: zero,
      unconvertedNetWorthByCurrency: const [],
      netWorthByCurrency: [zero],
      monthlyIncomeByCurrency: [zero],
      monthlyExpenseByCurrency: [zero],
      monthlySavingsByCurrency: [zero],
      yearlyIncomeByCurrency: [zero],
      yearlyExpenseByCurrency: [zero],
      yearlySavingsByCurrency: [zero],
      recentTransactions: const [],
      spendingByCategory: const [],
      monthlyExpenseTrend: List.filled(6, Decimal.zero),
      missingExchangeRatePairs: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAuthUserProvider.overrideWithValue(null),
          dashboardSnapshotProvider.overrideWith(
            (_) async => AppResult.success(snapshot),
          ),
          financialInsightsProvider.overrideWith(
            (_) => throw StateError('Home must not load planning insights.'),
          ),
        ],
        child: _app(locale: const Locale('en'), home: const DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Financial insights'), findsNothing);
    expect(find.text('Spending increased'), findsNothing);
  });
}

Widget _app({required Locale locale, required Widget home}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: CPTheme.dark(),
  home: home,
);

FinancialInsight _insight() => FinancialInsight.create(
  type: InsightType.spendingIncrease,
  severity: InsightSeverity.warning,
  title: 'Spending increased',
  message: 'Spending is up 22% compared with last month.',
  evidence: InsightEvidence(
    metricName: 'monthly_expense',
    currentValue: Decimal.fromInt(122),
    previousValue: Decimal.fromInt(100),
    changePercent: Decimal.fromInt(22),
    currency: 'LYD',
  ),
  periodStart: DateTime.utc(2026, 7, 1),
  periodEnd: DateTime.utc(2026, 8, 1),
);
