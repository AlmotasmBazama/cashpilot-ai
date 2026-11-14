import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization;
import '../../../dashboard/application/dashboard_providers.dart';
import '../../../insights/application/providers/insights_providers.dart';
import '../../../insights/domain/entities/financial_insight.dart';
import '../../../insights/insights.dart' show FinancialInsightCard;

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapshotState = ref.watch(dashboardSnapshotProvider);
    final insightState = ref.watch(financialInsightsProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: CPAppBar(
          title: l10n.reportsTitle,
          subtitle: l10n.reportsSubtitle,
          actions: [
            IconButton(
              tooltip: l10n.retry,
              onPressed: () {
                ref
                  ..invalidate(accountsProvider)
                  ..invalidate(categoriesProvider)
                  ..invalidate(dashboardTransactionsProvider)
                  ..invalidate(dashboardSnapshotProvider)
                  ..invalidate(financialInsightsProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    CPSpacing.md,
                    CPSpacing.xs,
                    CPSpacing.md,
                    0,
                  ),
                  child: TabBar(
                    isScrollable: false,
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: l10n.monthly),
                      Tab(text: l10n.yearly),
                      Tab(text: l10n.category),
                      Tab(text: l10n.cashFlow),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: snapshotState.when(
                data: (result) {
                  switch (result) {
                    case AppSuccess<DashboardSnapshot>(:final data):
                      return _ReportsTabs(
                        snapshot: data,
                        insightState: insightState,
                      );
                    case AppFailure<DashboardSnapshot>():
                      return CPErrorView(
                        title: l10n.reportsErrorTitle,
                        message: l10n.dashboardErrorMessage,
                      );
                  }
                },
                error: (_, _) => CPErrorView(
                  title: l10n.reportsErrorTitle,
                  message: l10n.dashboardErrorMessage,
                ),
                loading: () => FinanceScreenBody(
                  child: ListView(
                    children: const [
                      CPSkeletonCard(height: 176),
                      SizedBox(height: CPSpacing.md),
                      CPSkeletonCard(height: 176),
                      SizedBox(height: CPSpacing.xl),
                      CPSkeletonCard(height: 220),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsTabs extends StatelessWidget {
  const _ReportsTabs({required this.snapshot, required this.insightState});

  final DashboardSnapshot snapshot;
  final AsyncValue<AppResult<List<FinancialInsight>>> insightState;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        _ReportPanel(snapshot: snapshot, insightState: insightState),
        _YearlyReport(snapshot: snapshot),
        _CategoryReport(snapshot: snapshot),
        _CashFlowReport(snapshot: snapshot),
      ],
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({required this.snapshot, required this.insightState});

  final DashboardSnapshot snapshot;
  final AsyncValue<AppResult<List<FinancialInsight>>> insightState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FinanceScreenBody(
      child: ListView(
        children: [
          if (snapshot.isPartial) ...[
            _MissingRateWarning(snapshot: snapshot),
            const SizedBox(height: CPSpacing.lg),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 700 ? 3 : 1;
              final cards = [
                FinanceMetricCard(
                  label: l10n.monthlyIncome,
                  value: _totals(snapshot.monthlyIncomeByCurrency, l10n.zero),
                  icon: Icons.arrow_downward_rounded,
                  accentColor: context.cpColors.income,
                ),
                FinanceMetricCard(
                  label: l10n.monthlyExpense,
                  value: _totals(snapshot.monthlyExpenseByCurrency, l10n.zero),
                  icon: Icons.arrow_upward_rounded,
                  accentColor: context.cpColors.expense,
                ),
                FinanceMetricCard(
                  label: l10n.monthlySavings,
                  value: _totals(snapshot.monthlySavingsByCurrency, l10n.zero),
                  icon: Icons.savings_rounded,
                  accentColor: context.cpColors.success,
                ),
              ];

              return GridView.builder(
                itemCount: cards.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: CPSpacing.md,
                  mainAxisSpacing: CPSpacing.md,
                  mainAxisExtent: 140,
                ),
                itemBuilder: (context, index) => cards[index],
              );
            },
          ),
          const SizedBox(height: CPSpacing.xl),
          FinanceSection(
            title: l10n.monthlyReport,
            subtitle: l10n.reportActualDataSubtitle,
            child: CPCard(
              child: FinanceMiniBars(values: snapshot.monthlyExpenseTrend),
            ),
          ),
          const SizedBox(height: CPSpacing.xl),
          FinanceSection(
            title: l10n.financialInsights,
            subtitle: l10n.financialInsightsSubtitle,
            child: insightState.when(
              loading: () => const CPSkeletonCard(height: 180),
              error: (_, _) => FinanceInfoCard(
                title: l10n.noInsightsTitle,
                message: l10n.noInsightsMessage,
                icon: Icons.auto_graph_rounded,
              ),
              data: (result) => switch (result) {
                AppSuccess<List<FinancialInsight>>(data: final values)
                    when values.isNotEmpty =>
                  Column(
                    children: [
                      for (final insight in values.take(3)) ...[
                        FinancialInsightCard(
                          insight: insight,
                          categories: {
                            for (final category in snapshot.categories)
                              category.id: category,
                          },
                          compact: true,
                        ),
                        if (insight != values.take(3).last)
                          const SizedBox(height: CPSpacing.md),
                      ],
                    ],
                  ),
                AppSuccess<List<FinancialInsight>>() => FinanceInfoCard(
                  title: l10n.noInsightsTitle,
                  message: l10n.noInsightsMessage,
                  icon: Icons.auto_graph_rounded,
                ),
                AppFailure<List<FinancialInsight>>() => FinanceInfoCard(
                  title: l10n.noInsightsTitle,
                  message: l10n.noInsightsMessage,
                  icon: Icons.auto_graph_rounded,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  String _totals(List<CurrencyTotal> totals, String emptyLabel) {
    if (totals.isEmpty) {
      return emptyLabel;
    }
    return totals
        .map(
          (total) => FinanceFormatters.amountWithCurrency(
            total.amount,
            total.currencyCode,
          ),
        )
        .join('  ');
  }
}

class _YearlyReport extends StatelessWidget {
  const _YearlyReport({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FinanceScreenBody(
      child: ListView(
        children: [
          if (snapshot.isPartial) ...[
            _MissingRateWarning(snapshot: snapshot),
            const SizedBox(height: CPSpacing.lg),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 700 ? 3 : 1;
              final cards = [
                FinanceMetricCard(
                  label: l10n.yearlyIncome,
                  value: _totals(snapshot.yearlyIncomeByCurrency, l10n.zero),
                  icon: Icons.arrow_downward_rounded,
                  accentColor: context.cpColors.income,
                ),
                FinanceMetricCard(
                  label: l10n.yearlyExpense,
                  value: _totals(snapshot.yearlyExpenseByCurrency, l10n.zero),
                  icon: Icons.arrow_upward_rounded,
                  accentColor: context.cpColors.expense,
                ),
                FinanceMetricCard(
                  label: l10n.yearlySavings,
                  value: _totals(snapshot.yearlySavingsByCurrency, l10n.zero),
                  icon: Icons.savings_rounded,
                  accentColor: context.cpColors.success,
                ),
              ];
              return GridView.builder(
                itemCount: cards.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: CPSpacing.md,
                  mainAxisSpacing: CPSpacing.md,
                  mainAxisExtent: 140,
                ),
                itemBuilder: (context, index) => cards[index],
              );
            },
          ),
        ],
      ),
    );
  }

  String _totals(List<CurrencyTotal> totals, String emptyLabel) {
    if (totals.isEmpty) {
      return emptyLabel;
    }
    return totals
        .map(
          (total) => FinanceFormatters.amountWithCurrency(
            total.amount,
            total.currencyCode,
          ),
        )
        .join('  ');
  }
}

class _CategoryReport extends StatelessWidget {
  const _CategoryReport({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FinanceScreenBody(
      child: ListView(
        children: [
          if (snapshot.isPartial) ...[
            _MissingRateWarning(snapshot: snapshot),
            const SizedBox(height: CPSpacing.lg),
          ],
          if (snapshot.spendingByCategory.isEmpty)
            CPEmptyState(
              icon: Icons.category_outlined,
              title: l10n.noSpendingYet,
              message: l10n.noSpendingYetMessage,
            )
          else
            CPCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final item in snapshot.spendingByCategory)
                    CPListTile(
                      title: CategoryLocalization.defaultCategoryName(
                        l10n,
                        item.categoryName,
                      ),
                      subtitle: item.currencyCode,
                      trailing: SizedBox(
                        width: 124,
                        child: FinanceAmountText(
                          value: FinanceFormatters.amountWithCurrency(
                            item.amount,
                            item.currencyCode,
                          ),
                          alignment: AlignmentDirectional.centerEnd,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CashFlowReport extends StatelessWidget {
  const _CashFlowReport({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FinanceScreenBody(
      child: ListView(
        children: [
          if (snapshot.isPartial) ...[
            _MissingRateWarning(snapshot: snapshot),
            const SizedBox(height: CPSpacing.lg),
          ],
          FinanceInfoCard(
            title: l10n.cashFlow,
            message: snapshot.hasTransactions
                ? l10n.cashFlowActiveMessage
                : l10n.cashFlowEmptyMessage,
            icon: Icons.waterfall_chart_rounded,
          ),
          const SizedBox(height: CPSpacing.lg),
          if (snapshot.hasTransactions)
            CPCard(child: FinanceMiniBars(values: snapshot.monthlyExpenseTrend))
          else
            CPEmptyState(
              icon: Icons.waterfall_chart_outlined,
              title: l10n.noSpendingYet,
              message: l10n.cashFlowEmptyMessage,
            ),
        ],
      ),
    );
  }
}

class _MissingRateWarning extends StatelessWidget {
  const _MissingRateWarning({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pairs = snapshot.missingExchangeRatePairs
        .map((pair) => '${pair.fromCurrencyCode} → ${pair.toCurrencyCode}')
        .join(', ');
    return FinanceInfoCard(
      title: l10n.missingExchangeRateTitle,
      message: '${l10n.missingExchangeRateDescription} $pairs',
      icon: Icons.currency_exchange_rounded,
      color: context.cpColors.warning,
    );
  }
}
