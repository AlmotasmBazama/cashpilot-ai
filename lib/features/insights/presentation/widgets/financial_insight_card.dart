import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization;
import '../../../categories/domain/entities/category.dart';
import '../../domain/entities/financial_insight.dart';
import '../../domain/enums/insight_severity.dart';
import '../../domain/enums/insight_type.dart';

class FinancialInsightCard extends StatelessWidget {
  const FinancialInsightCard({
    required this.insight,
    this.categories = const <String, Category>{},
    this.compact = false,
    super.key,
  });

  final FinancialInsight insight;
  final Map<String, Category> categories;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = _severityColor(context, insight.severity);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return CPCard(
      accentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(CPRadius.sm),
                ),
                child: Icon(_typeIcon(insight.type), color: color),
              ),
              const SizedBox(width: CPSpacing.sm),
              Expanded(
                child: Text(
                  InsightPresentationText.title(l10n, insight),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CPSpacing.sm),
          Text(
            InsightPresentationText.message(l10n, insight, categories),
            maxLines: compact ? 2 : 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: CPSpacing.md),
          Wrap(
            spacing: CPSpacing.sm,
            runSpacing: CPSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FinanceStatusPill(
                label: _evidenceLabel(insight),
                icon: Icons.analytics_outlined,
                color: color,
              ),
              Text(
                '${FinanceFormatters.compactDate(insight.periodStart, locale)} '
                '- ${FinanceFormatters.compactDate(insight.periodEnd, locale)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (insight.actionRoute case final route?) ...[
            const SizedBox(height: CPSpacing.md),
            CPButton(
              label: _actionLabel(l10n, route),
              icon: Icons.arrow_forward_rounded,
              variant: CPButtonVariant.ghost,
              size: CPButtonSize.small,
              onPressed: () => context.go(route),
            ),
          ],
        ],
      ),
    );
  }

  String _evidenceLabel(FinancialInsight value) {
    if (value.type == InsightType.recurringPaymentDetected) {
      return value.evidence.currentValue.toString();
    }
    if (value.type == InsightType.spendingIncrease ||
        (value.type == InsightType.positiveTrend &&
            value.evidence.metricName == 'monthly_expense') ||
        value.type == InsightType.budgetWarning ||
        value.type == InsightType.goalProgress) {
      return '${value.evidence.changePercent.abs().toStringAsFixed(1)}%';
    }
    if (value.type == InsightType.missingExchangeRate) {
      return value.evidence.metricName.replaceAll('->', ' → ');
    }
    return FinanceFormatters.amountWithCurrency(
      value.evidence.currentValue,
      value.evidence.currency,
    );
  }

  String _actionLabel(AppLocalizations l10n, String route) => switch (route) {
    '/budgets' => l10n.openBudgets,
    '/goals' => l10n.openGoals,
    '/settings' => l10n.exchangeRatesTitle,
    '/reports' => l10n.reportsTitle,
    _ => l10n.reviewInsight,
  };
}

abstract final class InsightPresentationText {
  static String title(AppLocalizations l10n, FinancialInsight insight) {
    return switch (insight.type) {
      InsightType.spendingIncrease => l10n.insightSpendingIncreaseTitle,
      InsightType.topCategory => l10n.insightTopCategoryTitle,
      InsightType.cashFlowWarning => l10n.insightCashFlowWarningTitle,
      InsightType.savingsOpportunity => l10n.insightSavingsOpportunityTitle,
      InsightType.budgetWarning => l10n.insightBudgetWarningTitle,
      InsightType.goalProgress => l10n.insightGoalProgressTitle,
      InsightType.recurringPaymentDetected => l10n.insightRecurringTitle,
      InsightType.missingExchangeRate => l10n.insightMissingRateTitle,
      InsightType.unusualTransaction => l10n.insightUnusualTransactionTitle,
      InsightType.positiveTrend =>
        insight.evidence.metricName == 'monthly_expense'
            ? l10n.insightPositiveSpendingTitle
            : l10n.insightPositiveCashFlowTitle,
    };
  }

  static String message(
    AppLocalizations l10n,
    FinancialInsight insight,
    Map<String, Category> categories,
  ) {
    final evidence = insight.evidence;
    final percent = evidence.changePercent.abs().toStringAsFixed(1);
    final amount = FinanceFormatters.amountWithCurrency(
      evidence.currentValue,
      evidence.currency,
    );
    return switch (insight.type) {
      InsightType.spendingIncrease => l10n.insightSpendingIncreaseMessage(
        percent,
      ),
      InsightType.topCategory => l10n.insightTopCategoryMessage(
        _categoryName(l10n, evidence.relatedCategoryId, categories),
        amount,
      ),
      InsightType.cashFlowWarning => l10n.insightCashFlowWarningMessage(amount),
      InsightType.savingsOpportunity ||
      InsightType.unusualTransaction => insight.message,
      InsightType.budgetWarning => l10n.insightBudgetWarningMessage(
        evidence.metricName,
        percent,
      ),
      InsightType.goalProgress => l10n.insightGoalProgressMessage(
        evidence.metricName,
        percent,
      ),
      InsightType.recurringPaymentDetected => l10n.insightRecurringMessage(
        evidence.currentValue.toString(),
      ),
      InsightType.missingExchangeRate => l10n.insightMissingRateMessage(
        evidence.metricName.replaceAll('->', ' → '),
      ),
      InsightType.positiveTrend =>
        evidence.metricName == 'monthly_expense'
            ? l10n.insightPositiveSpendingMessage(percent)
            : l10n.insightPositiveCashFlowMessage(amount),
    };
  }

  static String _categoryName(
    AppLocalizations l10n,
    String? id,
    Map<String, Category> categories,
  ) {
    final category = categories[id];
    return category == null
        ? id ?? '-'
        : CategoryLocalization.name(l10n, category);
  }
}

Color _severityColor(BuildContext context, InsightSeverity severity) =>
    switch (severity) {
      InsightSeverity.info => context.cpColors.info,
      InsightSeverity.positive => context.cpColors.success,
      InsightSeverity.warning => context.cpColors.warning,
      InsightSeverity.critical => context.cpColors.expense,
    };

IconData _typeIcon(InsightType type) => switch (type) {
  InsightType.spendingIncrease => Icons.trending_up_rounded,
  InsightType.topCategory => Icons.category_outlined,
  InsightType.cashFlowWarning => Icons.waterfall_chart_outlined,
  InsightType.savingsOpportunity => Icons.savings_outlined,
  InsightType.budgetWarning => Icons.pie_chart_outline_rounded,
  InsightType.goalProgress => Icons.flag_outlined,
  InsightType.recurringPaymentDetected => Icons.repeat_rounded,
  InsightType.missingExchangeRate => Icons.currency_exchange_rounded,
  InsightType.unusualTransaction => Icons.manage_search_rounded,
  InsightType.positiveTrend => Icons.trending_down_rounded,
};
