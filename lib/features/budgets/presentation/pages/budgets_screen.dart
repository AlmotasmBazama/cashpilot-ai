import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization;
import '../../../categories/domain/entities/category.dart';
import '../../application/providers/budgets_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_progress.dart';
import '../../domain/enums/budget_period_type.dart';
import '../../domain/enums/budget_status.dart';
import '../widgets/budget_form_sheet.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  bool _includeArchived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progressState = ref.watch(allBudgetProgressProvider);
    final categories = _categories(ref.watch(categoriesProvider));

    return Scaffold(
      appBar: CPAppBar(
        title: l10n.budgetsTitle,
        subtitle: l10n.budgetsSubtitle,
        actions: [
          IconButton(
            tooltip: l10n.retry,
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: CPFloatingActionButton(
        variant: CPFloatingActionButtonVariant.extended,
        icon: Icons.add_rounded,
        label: l10n.addBudget,
        tooltip: l10n.addBudget,
        onPressed: () => _openForm(),
      ),
      body: progressState.when(
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
        error: (_, _) => _error(l10n),
        data: (result) => switch (result) {
          AppSuccess<List<BudgetProgress>>(:final data) => _content(
            data,
            categories,
          ),
          AppFailure<List<BudgetProgress>>() => _error(l10n),
        },
      ),
    );
  }

  Widget _content(
    List<BudgetProgress> progress,
    Map<String, Category> categories,
  ) {
    final l10n = AppLocalizations.of(context);
    final visible = progress
        .where((item) => _includeArchived || !item.budget.isArchived)
        .toList(growable: false);
    final active = progress
        .where(
          (item) =>
              !item.budget.isArchived && item.status != BudgetStatus.inactive,
        )
        .toList(growable: false);
    final alerts = active
        .where(
          (item) =>
              item.status == BudgetStatus.warning ||
              item.status == BudgetStatus.exceeded,
        )
        .length;

    return FinanceScreenBody(
      child: ListView(
        padding: const EdgeInsetsDirectional.only(bottom: 96),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 760 ? 3 : 1;
              final cards = [
                FinanceMetricCard(
                  label: l10n.activeBudgets,
                  value: '${active.length}',
                  icon: Icons.pie_chart_outline_rounded,
                  accentColor: context.cpColors.info,
                ),
                FinanceMetricCard(
                  label: l10n.remainingBudget,
                  value: _remainingTotals(active, l10n.zero),
                  icon: Icons.account_balance_wallet_outlined,
                  accentColor: context.cpColors.savings,
                ),
                FinanceMetricCard(
                  label: l10n.budgetAlerts,
                  value: '$alerts',
                  icon: Icons.notifications_none_rounded,
                  accentColor: alerts > 0
                      ? context.cpColors.warning
                      : context.cpColors.success,
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
                  mainAxisExtent: 176,
                ),
                itemBuilder: (context, index) => cards[index],
              );
            },
          ),
          const SizedBox(height: CPSpacing.lg),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _includeArchived,
            onChanged: (value) => setState(() => _includeArchived = value),
            title: Text(l10n.includeArchivedBudgets),
            secondary: const Icon(Icons.inventory_2_outlined),
          ),
          const SizedBox(height: CPSpacing.md),
          if (visible.isEmpty)
            CPEmptyState(
              icon: Icons.savings_outlined,
              title: l10n.emptyBudgetsTitle,
              message: l10n.createYourFirstBudget,
              action: CPButton(
                label: l10n.addBudget,
                icon: Icons.add_rounded,
                onPressed: _openForm,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visible.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: CPSpacing.md,
                    mainAxisSpacing: CPSpacing.md,
                    mainAxisExtent: 380,
                  ),
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return _BudgetProgressCard(
                      progress: item,
                      category: categories[item.budget.categoryId],
                      onOpen: () => _openDetails(item, categories),
                      onEdit: () => _openForm(item.budget),
                      onArchive: () => _archive(item.budget),
                      onRestore: () => _restore(item.budget),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _error(AppLocalizations l10n) {
    return CPErrorView(
      title: l10n.budgetsLoadError,
      message: l10n.budgetsLoadErrorMessage,
      action: CPButton(
        label: l10n.retry,
        icon: Icons.refresh_rounded,
        onPressed: _refresh,
      ),
    );
  }

  Map<String, Category> _categories(
    AsyncValue<AppResult<List<Category>>> value,
  ) {
    return switch (value.value) {
      AppSuccess<List<Category>>(:final data) => {
        for (final category in data) category.id: category,
      },
      _ => const <String, Category>{},
    };
  }

  String _remainingTotals(List<BudgetProgress> progress, String emptyLabel) {
    final totals = <String, Decimal>{};
    for (final item in progress) {
      totals.update(
        item.budget.currency,
        (value) => value + item.remainingAmount,
        ifAbsent: () => item.remainingAmount,
      );
    }
    if (totals.isEmpty) {
      return emptyLabel;
    }
    return totals.entries
        .map(
          (entry) =>
              FinanceFormatters.amountWithCurrency(entry.value, entry.key),
        )
        .join('  ');
  }

  void _refresh() {
    ref
      ..invalidate(allBudgetProgressProvider)
      ..invalidate(budgetProgressProvider)
      ..invalidate(budgetSummaryProvider);
  }

  Future<void> _openForm([Budget? budget]) async {
    final saved = await BudgetFormSheet.show(context, budget: budget);
    if (saved == true && mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).budgetSaved)),
      );
    }
  }

  Future<void> _archive(Budget budget) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.archiveBudget),
        content: Text(l10n.budgetArchiveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.archive),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final result = await ref.read(archiveBudgetUseCaseProvider)(budget.id);
    if (!mounted) {
      return;
    }
    if (result is AppSuccess<Budget>) {
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.budgetArchived)));
    }
  }

  Future<void> _restore(Budget budget) async {
    final result = await ref.read(restoreBudgetUseCaseProvider)(budget.id);
    if (!mounted) {
      return;
    }
    if (result is AppSuccess<Budget>) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).budgetRestored)),
      );
    }
  }

  Future<void> _openDetails(
    BudgetProgress progress,
    Map<String, Category> categories,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _BudgetDetailsSheet(
        progress: progress,
        category: categories[progress.budget.categoryId],
      ),
    );
  }
}

class _BudgetProgressCard extends StatelessWidget {
  const _BudgetProgressCard({
    required this.progress,
    required this.category,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  final BudgetProgress progress;
  final Category? category;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final budget = progress.budget;
    final color = _statusColor(context, progress.status);
    final categoryName = category == null
        ? budget.categoryId
        : CategoryLocalization.name(l10n, category!);
    return CPCard(
      variant: CPCardVariant.interactive,
      accentColor: color,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  budget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              PopupMenuButton<_BudgetAction>(
                tooltip: l10n.editBudget,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) => switch (action) {
                  _BudgetAction.edit => onEdit(),
                  _BudgetAction.archive => onArchive(),
                  _BudgetAction.restore => onRestore(),
                },
                itemBuilder: (context) => budget.isArchived
                    ? [
                        PopupMenuItem(
                          value: _BudgetAction.restore,
                          child: Text(l10n.restoreBudget),
                        ),
                      ]
                    : [
                        PopupMenuItem(
                          value: _BudgetAction.edit,
                          child: Text(l10n.editBudget),
                        ),
                        PopupMenuItem(
                          value: _BudgetAction.archive,
                          child: Text(l10n.archiveBudget),
                        ),
                      ],
              ),
            ],
          ),
          Text(
            '$categoryName  /  ${_periodLabel(l10n, budget.periodType)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: CPSpacing.md),
          Wrap(
            spacing: CPSpacing.sm,
            runSpacing: CPSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FinanceStatusPill(
                label: _statusLabel(l10n, progress.status),
                icon: _statusIcon(progress.status),
                color: color,
              ),
              Text(
                '${progress.progressPercent.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: CPSpacing.md),
          FinanceProgressBar(
            value: (progress.progressPercent / Decimal.fromInt(100)).toDouble(),
            color: color,
          ),
          const SizedBox(height: CPSpacing.sm),
          FinanceDetailRow(
            label: l10n.spent,
            value: FinanceFormatters.amountWithCurrency(
              progress.spentAmount,
              budget.currency,
            ),
          ),
          FinanceDetailRow(
            label: l10n.remaining,
            value: FinanceFormatters.amountWithCurrency(
              progress.remainingAmount,
              budget.currency,
            ),
            valueColor: progress.remainingAmount < Decimal.zero ? color : null,
          ),
          if (progress.isPartial)
            Text(
              l10n.budgetMissingExchangeRate,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.cpColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _BudgetDetailsSheet extends StatelessWidget {
  const _BudgetDetailsSheet({required this.progress, required this.category});

  final BudgetProgress progress;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final budget = progress.budget;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        CPSpacing.lg,
        0,
        CPSpacing.lg,
        CPSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CPSectionTitle(
            title: l10n.budgetDetails,
            subtitle: budget.name,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: CPSpacing.lg),
          FinanceDetailRow(
            label: l10n.category,
            value: category == null
                ? budget.categoryId
                : CategoryLocalization.name(l10n, category!),
            icon: Icons.category_outlined,
          ),
          FinanceDetailRow(
            label: l10n.budgetAmount,
            value: FinanceFormatters.amountWithCurrency(
              budget.amount,
              budget.currency,
            ),
            icon: Icons.account_balance_wallet_outlined,
          ),
          FinanceDetailRow(
            label: l10n.spent,
            value: FinanceFormatters.amountWithCurrency(
              progress.spentAmount,
              budget.currency,
            ),
            icon: Icons.payments_outlined,
          ),
          FinanceDetailRow(
            label: l10n.remaining,
            value: FinanceFormatters.amountWithCurrency(
              progress.remainingAmount,
              budget.currency,
            ),
            icon: Icons.savings_outlined,
          ),
          FinanceDetailRow(
            label: l10n.budgetPeriod,
            value:
                '${FinanceFormatters.compactDate(progress.periodStart, locale)} '
                '- ${FinanceFormatters.compactDate(progress.periodEnd.subtract(const Duration(days: 1)), locale)}',
            icon: Icons.date_range_outlined,
          ),
          FinanceDetailRow(
            label: l10n.alertThreshold,
            value: '${budget.alertThresholdPercent}%',
            icon: Icons.notifications_outlined,
          ),
          if (progress.isPartial) ...[
            const SizedBox(height: CPSpacing.md),
            FinanceInfoCard(
              title: l10n.missingExchangeRateTitle,
              message:
                  '${l10n.budgetMissingExchangeRate} '
                  '${progress.missingRateWarnings.map((item) => '${item.fromCurrencyCode} \u2192 ${item.toCurrencyCode}').join(', ')}',
              icon: Icons.currency_exchange_rounded,
              color: context.cpColors.warning,
            ),
          ],
        ],
      ),
    );
  }
}

enum _BudgetAction { edit, archive, restore }

String _periodLabel(AppLocalizations l10n, BudgetPeriodType type) {
  return switch (type) {
    BudgetPeriodType.weekly => l10n.weekly,
    BudgetPeriodType.monthly => l10n.monthly,
    BudgetPeriodType.yearly => l10n.yearly,
    BudgetPeriodType.custom => l10n.customPeriod,
  };
}

String _statusLabel(AppLocalizations l10n, BudgetStatus status) {
  return switch (status) {
    BudgetStatus.onTrack => l10n.onTrack,
    BudgetStatus.warning => l10n.nearLimit,
    BudgetStatus.exceeded => l10n.exceeded,
    BudgetStatus.inactive => l10n.inactive,
  };
}

IconData _statusIcon(BudgetStatus status) {
  return switch (status) {
    BudgetStatus.onTrack => Icons.check_circle_outline_rounded,
    BudgetStatus.warning => Icons.notifications_active_outlined,
    BudgetStatus.exceeded => Icons.error_outline_rounded,
    BudgetStatus.inactive => Icons.pause_circle_outline_rounded,
  };
}

Color _statusColor(BuildContext context, BudgetStatus status) {
  return switch (status) {
    BudgetStatus.onTrack => context.cpColors.success,
    BudgetStatus.warning => context.cpColors.warning,
    BudgetStatus.exceeded => context.cpColors.expense,
    BudgetStatus.inactive => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}
