import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/budgets/application/providers/budgets_providers.dart';
import 'package:cashpilot_ai/features/budgets/domain/entities/budget.dart';
import 'package:cashpilot_ai/features/budgets/domain/entities/budget_progress.dart';
import 'package:cashpilot_ai/features/budgets/domain/enums/budget_period_type.dart';
import 'package:cashpilot_ai/features/budgets/domain/enums/budget_status.dart';
import 'package:cashpilot_ai/features/budgets/presentation/pages/budgets_screen.dart';
import 'package:cashpilot_ai/features/budgets/presentation/widgets/budget_form_sheet.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/categories/domain/enums/category_type.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/base_currency_provider.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:cashpilot_ai/shared/presentation/widgets/finance_ui_components.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('budget list renders without overflow at 320px in RTL', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final groceries = _groceries();
    final progress = _progress(groceries);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allBudgetProgressProvider.overrideWith(
            (_) async => AppResult<List<BudgetProgress>>.success(
              <BudgetProgress>[progress],
            ),
          ),
          categoriesProvider.overrideWith(
            (_) async =>
                AppResult<List<Category>>.success(<Category>[groceries]),
          ),
        ],
        child: _app(locale: const Locale('ar'), child: const BudgetsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('ميزانية الطعام'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('ميزانية الطعام'), findsOneWidget);
    expect(find.textContaining('250 LYD'), findsWidgets);
    expect(find.byType(FinanceProgressBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add budget form validates amount and category', (tester) async {
    final groceries = _groceries();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveBaseCurrencyCodeProvider.overrideWithValue('LYD'),
          categoriesByTypeProvider.overrideWith(
            (_, _) async =>
                AppResult<List<Category>>.success(<Category>[groceries]),
          ),
        ],
        child: _app(
          locale: const Locale('en'),
          child: const Scaffold(body: BudgetFormSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CPButton, 'Save'));
    await tester.pump();

    expect(
      find.text('Enter a budget amount greater than zero.'),
      findsOneWidget,
    );
    expect(find.text('Select a category.'), findsOneWidget);
  });
}

Widget _app({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: CPTheme.dark(),
    home: child,
  );
}

Category _groceries() {
  return buildDefaultCategories().firstWhere(
    (category) =>
        category.type == CategoryType.expense && category.name == 'Groceries',
  );
}

BudgetProgress _progress(Category category) {
  final budget = Budget.create(
    name: 'ميزانية الطعام',
    categoryId: category.id,
    amount: Decimal.fromInt(500),
    currency: 'LYD',
    periodType: BudgetPeriodType.monthly,
    startDate: DateTime.utc(2026, 7, 1),
    endDate: DateTime.utc(2026, 8, 1),
  );
  return BudgetProgress(
    budget: budget,
    spentAmount: Decimal.fromInt(250),
    remainingAmount: Decimal.fromInt(250),
    progressPercent: Decimal.fromInt(50),
    status: BudgetStatus.onTrack,
    periodStart: budget.startDate,
    periodEnd: budget.endDate,
    missingRateWarnings: const [],
  );
}
