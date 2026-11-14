import 'dart:async';

import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/dashboard/application/expense_analytics_providers.dart';
import 'package:cashpilot_ai/features/dashboard/domain/entities/expense_analytics.dart';
import 'package:cashpilot_ai/features/dashboard/presentation/widgets/expense_analytics_card.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/base_currency_provider.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders weekly/monthly in dark/light and English/Arabic', (
    tester,
  ) async {
    final cases =
        <({Locale locale, ThemeData theme, ExpenseAnalyticsPeriod period})>[
          (
            locale: const Locale('en'),
            theme: CPTheme.light(),
            period: ExpenseAnalyticsPeriod.week,
          ),
          (
            locale: const Locale('en'),
            theme: CPTheme.dark(),
            period: ExpenseAnalyticsPeriod.month,
          ),
          (
            locale: const Locale('ar'),
            theme: CPTheme.light(),
            period: ExpenseAnalyticsPeriod.month,
          ),
          (
            locale: const Locale('ar'),
            theme: CPTheme.dark(),
            period: ExpenseAnalyticsPeriod.week,
          ),
        ];

    for (final testCase in cases) {
      await tester.pumpWidget(
        _app(
          locale: testCase.locale,
          theme: testCase.theme,
          initialPeriod: testCase.period,
          resultFor: (period) => AppResult.success(_snapshot(period: period)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expense_analytics_card')), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(const Key('expense_analytics_card'))),
        ),
        testCase.locale.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('fits 320px, large text, top five plus Other, and semantics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(
        locale: const Locale('ar'),
        theme: CPTheme.dark(),
        textScale: 1.5,
        resultFor: (period) => AppResult.success(
          _snapshot(period: period, categoryCount: 5, other: '12'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('أخرى'), findsOneWidget);
    expect(find.text('بقالة ومواد غذائية'), findsOneWidget);
    expect(find.textContaining('Category'), findsNWidgets(4));
    final chartSemantics = tester.getSemantics(
      find.byKey(const Key('expense_analytics_chart_semantics')),
    );
    expect(chartSemantics.label, contains('إجمالي مصروفات'));
    expect(chartSemantics.label, contains('LYD'));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('tablet switches to a balanced two-column composition', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(resultFor: (period) => AppResult.success(_snapshot(period: period))),
    );
    await tester.pumpAndSettle();

    final chartCenter = tester.getCenter(
      find.byKey(const Key('expense_analytics_chart_semantics')),
    );
    final categoryCenter = tester.getCenter(
      find.text('Groceries & food staples'),
    );
    expect((chartCenter.dy - categoryCenter.dy).abs(), lessThan(130));
    expect(categoryCenter.dx, greaterThan(chartCenter.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('period selector swaps the provider without stale values', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        initialPeriod: ExpenseAnalyticsPeriod.month,
        resultFor: (period) => AppResult.success(
          _snapshot(
            period: period,
            total: period == ExpenseAnalyticsPeriod.month ? '850' : '120',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('850 LYD'), findsOneWidget);

    await tester.tap(find.byKey(const Key('expense_analytics_period_week')));
    await tester.pumpAndSettle();

    expect(find.text('120 LYD'), findsOneWidget);
    expect(find.text('850 LYD'), findsNothing);
  });

  testWidgets('shows a compact loading skeleton', (tester) async {
    final controller = StreamController<AppResult<ExpenseAnalyticsSnapshot>>();
    addTearDown(controller.close);

    await tester.pumpWidget(_appWithBuilder((_, _) => controller.stream));
    await tester.pump();

    expect(find.byType(CPSkeletonCard), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows empty state with an expense action', (tester) async {
    await tester.pumpWidget(
      _app(
        resultFor: (period) => AppResult.success(
          _snapshot(period: period, hasExpenses: false, total: '0'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No expenses were recorded in this period.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(CPButton, 'Add expense'), findsOneWidget);
  });

  testWidgets('shows partial FX warning and suppresses percentage comparison', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        resultFor: (period) =>
            AppResult.success(_snapshot(period: period, partial: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Some expenses are not included'),
      findsOneWidget,
    );
    expect(find.textContaining('USD → LYD'), findsOneWidget);
    expect(find.textContaining('comparison is unavailable'), findsOneWidget);
    expect(find.textContaining('Infinity'), findsNothing);
    expect(find.textContaining('NaN'), findsNothing);
  });

  testWidgets('compact error Retry recovers from one temporary failure', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _appWithBuilder((_, period) {
        attempts += 1;
        return Stream.value(
          attempts == 1
              ? const AppResult<ExpenseAnalyticsSnapshot>.failure(
                  Failure(message: 'temporary'),
                )
              : AppResult.success(_snapshot(period: period)),
        );
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load expense analysis'), findsOneWidget);
    await tester.tap(find.widgetWithText(CPButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Could not load expense analysis'), findsNothing);
    expect(find.text('250 LYD'), findsOneWidget);
  });
}

Widget _app({
  Locale locale = const Locale('en'),
  ThemeData? theme,
  double textScale = 1,
  ExpenseAnalyticsPeriod initialPeriod = ExpenseAnalyticsPeriod.month,
  required AppResult<ExpenseAnalyticsSnapshot> Function(
    ExpenseAnalyticsPeriod period,
  )
  resultFor,
}) {
  return _appWithBuilder(
    (_, period) => Stream.value(resultFor(period)),
    locale: locale,
    theme: theme,
    textScale: textScale,
    initialPeriod: initialPeriod,
  );
}

Widget _appWithBuilder(
  Stream<AppResult<ExpenseAnalyticsSnapshot>> Function(
    Ref ref,
    ExpenseAnalyticsPeriod period,
  )
  builder, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  double textScale = 1,
  ExpenseAnalyticsPeriod initialPeriod = ExpenseAnalyticsPeriod.month,
}) {
  return ProviderScope(
    overrides: [
      currentAuthUserProvider.overrideWithValue(null),
      effectiveBaseCurrencyCodeProvider.overrideWithValue('LYD'),
      expenseAnalyticsProvider.overrideWith(builder),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? CPTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ExpenseAnalyticsCard(initialPeriod: initialPeriod),
        ),
      ),
    ),
  );
}

ExpenseAnalyticsSnapshot _snapshot({
  required ExpenseAnalyticsPeriod period,
  String total = '250',
  bool hasExpenses = true,
  bool partial = false,
  int categoryCount = 1,
  String other = '0',
}) {
  final totalDecimal = Decimal.parse(total);
  final otherDecimal = Decimal.parse(other);
  final categories = <ExpenseCategoryAnalytics>[
    for (var index = 0; index < categoryCount; index++)
      ExpenseCategoryAnalytics(
        categoryId: 'category-$index',
        categoryName: index == 0 ? 'Groceries' : 'Category ${index + 1}',
        categoryIconKey: index.isEven ? 'groceries' : 'transport',
        categoryColorArgb: <int>[
          0xFF5B4CF0,
          0xFF14B8A6,
          0xFFF59E0B,
          0xFFEC4899,
          0xFF3B82F6,
        ][index % 5],
        isDefaultCategory: index == 0,
        amount: Decimal.parse('${50 - (index * 5)}'),
        percentage: Decimal.parse('${35 - (index * 3)}'),
      ),
  ];
  final currentStart = period == ExpenseAnalyticsPeriod.month
      ? DateTime.utc(2026, 8)
      : DateTime.utc(2026, 8, 17);
  final previousStart = period == ExpenseAnalyticsPeriod.month
      ? DateTime.utc(2026, 7)
      : DateTime.utc(2026, 8, 10);
  return ExpenseAnalyticsSnapshot(
    selectedPeriod: period,
    currentDateRange: ExpenseAnalyticsDateRange(
      start: currentStart,
      end: DateTime.utc(2026, 8, 23),
    ),
    previousDateRange: ExpenseAnalyticsDateRange(
      start: previousStart,
      end: currentStart,
    ),
    totalExpense: totalDecimal,
    previousTotalExpense: Decimal.parse('200'),
    percentageChange: partial ? null : Decimal.parse('25'),
    comparisonDirection: partial
        ? ExpenseComparisonDirection.unavailable
        : ExpenseComparisonDirection.increased,
    topCategories: categories,
    otherTotal: otherDecimal,
    otherPercentage: otherDecimal == Decimal.zero
        ? Decimal.zero
        : Decimal.parse('8'),
    currencyCode: 'LYD',
    isPartial: partial,
    warnings: partial
        ? const [
            ExpenseAnalyticsWarning(
              fromCurrencyCode: 'USD',
              toCurrencyCode: 'LYD',
            ),
          ]
        : const [],
    hasCurrentExpenses: hasExpenses,
    metrics: const ExpenseAnalyticsQueryMetrics(
      sourceRowCount: 10,
      aggregateRowCount: 4,
      processingDuration: Duration(milliseconds: 2),
    ),
  );
}
