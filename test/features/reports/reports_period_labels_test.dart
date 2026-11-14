import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/accounts/application/providers/accounts_providers.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/dashboard/application/dashboard_providers.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/reports/presentation/pages/reports_screen.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final localeCase in <({Locale locale, List<String> labels})>[
    (
      locale: const Locale('en'),
      labels: const <String>[
        'Yearly income',
        'Yearly expense',
        'Yearly savings',
      ],
    ),
    (
      locale: const Locale('ar'),
      labels: const <String>[
        'الدخل السنوي',
        'المصروف السنوي',
        'الادخار السنوي',
      ],
    ),
  ]) {
    testWidgets(
      'yearly report uses yearly metric labels in ${localeCase.locale.languageCode}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardSnapshotProvider.overrideWith(
                (_) async => AppResult<DashboardSnapshot>.success(_snapshot()),
              ),
              financialInsightsProvider.overrideWith(
                (_) async =>
                    AppResult<List<FinancialInsight>>.success(const []),
              ),
            ],
            child: MaterialApp(
              locale: localeCase.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: CPTheme.dark(),
              home: const ReportsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final yearlyTab = localeCase.locale.languageCode == 'ar'
            ? 'سنوية'
            : 'Yearly';
        await tester.tap(find.text(yearlyTab));
        await tester.pumpAndSettle();

        for (final label in localeCase.labels) {
          expect(find.text(label), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reports Retry clears cached snapshot dependencies', (
    tester,
  ) async {
    var accountReads = 0;
    var categoryReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
            return AppResult<DashboardSnapshot>.success(_snapshot());
          }),
          financialInsightsProvider.overrideWith(
            (_) async => AppResult<List<FinancialInsight>>.success(const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: CPTheme.dark(),
          home: const ReportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load reports'), findsOneWidget);

    await tester.tap(find.byTooltip('Retry'));
    await tester.pumpAndSettle();

    expect(accountReads, 2);
    expect(categoryReads, 2);
    expect(find.text('Monthly report'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

DashboardSnapshot _snapshot() {
  CurrencyTotal total(String amount) =>
      CurrencyTotal(currencyCode: 'LYD', amount: Decimal.parse(amount));
  return DashboardSnapshot(
    accounts: const [],
    transactions: const [],
    categories: const [],
    baseCurrencyCode: 'LYD',
    netWorthInBaseCurrency: total('0'),
    unconvertedNetWorthByCurrency: const [],
    netWorthByCurrency: <CurrencyTotal>[total('0')],
    monthlyIncomeByCurrency: <CurrencyTotal>[total('10')],
    monthlyExpenseByCurrency: <CurrencyTotal>[total('4')],
    monthlySavingsByCurrency: <CurrencyTotal>[total('6')],
    yearlyIncomeByCurrency: <CurrencyTotal>[total('120')],
    yearlyExpenseByCurrency: <CurrencyTotal>[total('48')],
    yearlySavingsByCurrency: <CurrencyTotal>[total('72')],
    recentTransactions: const [],
    spendingByCategory: const [],
    monthlyExpenseTrend: List<Decimal>.filled(6, Decimal.zero),
    missingExchangeRatePairs: const [],
    totalTransactionCount: 0,
  );
}
