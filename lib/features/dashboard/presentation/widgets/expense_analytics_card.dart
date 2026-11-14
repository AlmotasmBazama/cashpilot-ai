import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization, CategoryVisuals;
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/transactions_presentation.dart'
    show TransactionFormSheet;
import '../../application/dashboard_providers.dart';
import '../../application/expense_analytics_providers.dart';
import '../../domain/entities/expense_analytics.dart';

class ExpenseAnalyticsCard extends ConsumerStatefulWidget {
  const ExpenseAnalyticsCard({
    this.initialPeriod = ExpenseAnalyticsPeriod.month,
    super.key,
  });

  final ExpenseAnalyticsPeriod initialPeriod;

  @override
  ConsumerState<ExpenseAnalyticsCard> createState() =>
      _ExpenseAnalyticsCardState();
}

class _ExpenseAnalyticsCardState extends ConsumerState<ExpenseAnalyticsCard>
    with WidgetsBindingObserver {
  late ExpenseAnalyticsPeriod _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialPeriod;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(expenseAnalyticsProvider(_selectedPeriod));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final analyticsState = ref.watch(expenseAnalyticsProvider(_selectedPeriod));
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final content = analyticsState.when(
      loading: () => const _AnalyticsSkeleton(
        key: ValueKey<String>('expense-analytics-loading'),
      ),
      error: (_, _) => _AnalyticsError(
        key: const ValueKey<String>('expense-analytics-error'),
        onRetry: _retry,
      ),
      data: (result) => switch (result) {
        AppSuccess<ExpenseAnalyticsSnapshot>(:final data) =>
          _ExpenseAnalyticsContent(
            key: ValueKey<String>(
              'expense-analytics-${data.selectedPeriod.name}',
            ),
            snapshot: data,
            onAddExpense: _addExpense,
          ),
        AppFailure<ExpenseAnalyticsSnapshot>() => _AnalyticsError(
          key: const ValueKey<String>('expense-analytics-error'),
          onRetry: _retry,
        ),
      },
    );

    return CPCard(
      key: const Key('expense_analytics_card'),
      variant: CPCardVariant.elevated,
      accentColor: context.cpColors.expense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AnalyticsHeader(
            title: l10n.expenseAnalyticsTitle,
            actionLabel: l10n.expenseAnalyticsViewDetails,
            onDetails: () => context.go(AppRoutePaths.transactions),
          ),
          const SizedBox(height: CPSpacing.sm),
          _PeriodSelector(
            selectedPeriod: _selectedPeriod,
            onSelected: (period) {
              if (period == _selectedPeriod) {
                return;
              }
              setState(() => _selectedPeriod = period);
            },
          ),
          const SizedBox(height: CPSpacing.md),
          AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : CPDurations.normal,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: content,
          ),
        ],
      ),
    );
  }

  void _retry() {
    ref.invalidate(expenseAnalyticsProvider(_selectedPeriod));
  }

  Future<void> _addExpense() async {
    final created = await TransactionFormSheet.show(
      context,
      TransactionType.expense,
    );
    if (!mounted || created != true) {
      return;
    }
    ref
      ..invalidate(expenseAnalyticsProvider(_selectedPeriod))
      ..invalidate(dashboardTransactionsProvider)
      ..invalidate(dashboardSnapshotProvider);
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({
    required this.title,
    required this.actionLabel,
    required this.onDetails,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
    );
    final action = CPButton(
      label: actionLabel,
      variant: CPButtonVariant.ghost,
      size: CPButtonSize.small,
      onPressed: onDetails,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledText = MediaQuery.textScalerOf(context).scale(16);
        if (constraints.maxWidth < 360 || scaledText > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleWidget,
              Align(alignment: AlignmentDirectional.centerEnd, child: action),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleWidget),
            const SizedBox(width: CPSpacing.xs),
            action,
          ],
        );
      },
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onSelected,
  });

  final ExpenseAnalyticsPeriod selectedPeriod;
  final ValueChanged<ExpenseAnalyticsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(CPRadius.md),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final period in ExpenseAnalyticsPeriod.values)
            Expanded(
              child: _PeriodSegment(
                period: period,
                selected: selectedPeriod == period,
                onTap: () => onSelected(period),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodSegment extends StatelessWidget {
  const _PeriodSegment({
    required this.period,
    required this.selected,
    required this.onTap,
  });

  final ExpenseAnalyticsPeriod period;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final label = switch (period) {
      ExpenseAnalyticsPeriod.week => l10n.expenseAnalyticsThisWeek,
      ExpenseAnalyticsPeriod.month => l10n.expenseAnalyticsThisMonth,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? colorScheme.primaryContainer : Colors.transparent,
        child: InkWell(
          key: Key('expense_analytics_period_${period.name}'),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: CPSpacing.xs,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseAnalyticsContent extends StatelessWidget {
  const _ExpenseAnalyticsContent({
    required this.snapshot,
    required this.onAddExpense,
    super.key,
  });

  final ExpenseAnalyticsSnapshot snapshot;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final rangeText = _formatDateRange(snapshot.currentDateRange, localeName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          rangeText,
          textAlign: TextAlign.start,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (snapshot.isPartial) ...[
          const SizedBox(height: CPSpacing.sm),
          _PartialWarning(snapshot: snapshot),
        ],
        const SizedBox(height: CPSpacing.md),
        if (!snapshot.hasCurrentExpenses)
          _AnalyticsEmpty(onAddExpense: onAddExpense)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 620;
              final chart = _DonutChart(snapshot: snapshot);
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CategoryLegend(snapshot: snapshot),
                  const SizedBox(height: CPSpacing.md),
                  _Comparison(snapshot: snapshot),
                ],
              );
              if (twoColumn) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 232, child: chart),
                    const SizedBox(width: CPSpacing.xl),
                    Expanded(child: details),
                  ],
                );
              }
              return Column(
                children: [
                  chart,
                  const SizedBox(height: CPSpacing.lg),
                  details,
                ],
              );
            },
          ),
        if (!snapshot.hasCurrentExpenses && snapshot.isPartial) ...[
          const SizedBox(height: CPSpacing.sm),
          Text(
            l10n.expenseAnalyticsPartialTotal,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ],
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.snapshot});

  final ExpenseAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final total = FinanceFormatters.amountWithCurrency(
      snapshot.totalExpense,
      snapshot.currencyCode,
    );
    final segments = <_DonutSegment>[
      for (final category in snapshot.topCategories)
        _DonutSegment(
          amount: category.amount,
          color: Color(category.categoryColorArgb),
        ),
      if (snapshot.otherTotal > Decimal.zero)
        _DonutSegment(
          amount: snapshot.otherTotal,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    ];
    final highest = snapshot.topCategories.firstOrNull;
    final highestName = highest == null ? null : _categoryName(l10n, highest);
    final semanticsLabel = highest == null
        ? '${l10n.expenseAnalyticsTotal}: $total'
        : l10n.expenseAnalyticsSemanticsSummary(
            _periodLabel(l10n, snapshot.selectedPeriod),
            total,
            highestName!,
            FinanceFormatters.amountWithCurrency(
              highest.amount,
              snapshot.currencyCode,
            ),
            _formatPercentage(highest.percentage, localeName),
          );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      key: const Key('expense_analytics_chart_semantics'),
      container: true,
      image: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey<ExpenseAnalyticsPeriod>(snapshot.selectedPeriod),
          tween: Tween<double>(begin: 0, end: 1),
          duration: reduceMotion ? Duration.zero : CPDurations.slow,
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) {
            return SizedBox.square(
              dimension: 196,
              child: CustomPaint(
                painter: _DonutPainter(
                  segments: segments,
                  total: snapshot.totalExpense,
                  progress: progress,
                  trackColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: SizedBox(
                    width: 128,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          snapshot.isPartial
                              ? l10n.expenseAnalyticsPartialTotal
                              : l10n.expenseAnalyticsTotal,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: CPSpacing.xxs),
                        FinanceAmountText(
                          value: total,
                          alignment: Alignment.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({required this.snapshot});

  final ExpenseAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final entries = <_LegendEntry>[
      for (final category in snapshot.topCategories)
        _LegendEntry(
          name: _categoryName(AppLocalizations.of(context), category),
          icon: CategoryVisuals.iconForKey(category.categoryIconKey),
          color: Color(category.categoryColorArgb),
          amount: category.amount,
          percentage: category.percentage,
        ),
      if (snapshot.otherTotal > Decimal.zero)
        _LegendEntry(
          name: AppLocalizations.of(context).expenseAnalyticsOther,
          icon: Icons.more_horiz_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          amount: snapshot.otherTotal,
          percentage: snapshot.otherPercentage,
        ),
    ];
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _LegendRow(entry: entries[index], currency: snapshot.currencyCode),
          if (index != entries.length - 1) const SizedBox(height: CPSpacing.xs),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.entry, required this.currency});

  final _LegendEntry entry;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final amount = FinanceFormatters.amountWithCurrency(entry.amount, currency);
    final percentage = _formatPercentage(entry.percentage, localeName);
    return Semantics(
      container: true,
      label: l10n.expenseAnalyticsLegendSemantics(
        entry.name,
        amount,
        percentage,
      ),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(CPRadius.sm),
              border: Border.all(color: entry.color.withValues(alpha: 0.48)),
            ),
            child: Icon(entry.icon, size: 19, color: entry.color),
          ),
          const SizedBox(width: CPSpacing.sm),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: CPSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FinanceAmountText(
                  value: amount,
                  alignment: AlignmentDirectional.centerEnd,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  percentage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _Comparison extends StatelessWidget {
  const _Comparison({required this.snapshot});

  final ExpenseAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final previousPeriod =
        snapshot.selectedPeriod == ExpenseAnalyticsPeriod.week
        ? l10n.expenseAnalyticsLastWeek
        : l10n.expenseAnalyticsLastMonth;
    final change = snapshot.percentageChange;
    final formattedChange = change == null
        ? ''
        : _formatPercentage(
            change < Decimal.zero ? -change : change,
            localeName,
          );
    final (message, icon, color) = switch (snapshot.comparisonDirection) {
      ExpenseComparisonDirection.increased => (
        l10n.expenseAnalyticsIncreasedComparison(
          formattedChange,
          previousPeriod,
        ),
        Icons.trending_up_rounded,
        context.cpColors.expense,
      ),
      ExpenseComparisonDirection.decreased => (
        l10n.expenseAnalyticsDecreasedComparison(
          formattedChange,
          previousPeriod,
        ),
        Icons.trending_down_rounded,
        context.cpColors.success,
      ),
      ExpenseComparisonDirection.unchanged => (
        l10n.expenseAnalyticsUnchangedComparison(previousPeriod),
        Icons.trending_flat_rounded,
        colorScheme.primary,
      ),
      ExpenseComparisonDirection.noPreviousData => (
        l10n.expenseAnalyticsNoPreviousData,
        Icons.history_rounded,
        colorScheme.onSurfaceVariant,
      ),
      ExpenseComparisonDirection.unavailable => (
        l10n.expenseAnalyticsComparisonUnavailable,
        Icons.currency_exchange_rounded,
        context.cpColors.warning,
      ),
    };
    return Container(
      padding: const EdgeInsetsDirectional.all(CPSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(CPRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: CPSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartialWarning extends StatelessWidget {
  const _PartialWarning({required this.snapshot});

  final ExpenseAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pairs = snapshot.warnings
        .map(
          (warning) =>
              '${warning.fromCurrencyCode} → ${warning.toCurrencyCode}',
        )
        .join(', ');
    final color = context.cpColors.warning;
    return Container(
      padding: const EdgeInsetsDirectional.all(CPSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(CPRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 21, color: color),
          const SizedBox(width: CPSpacing.sm),
          Expanded(
            child: Text(
              '${l10n.expenseAnalyticsPartialWarning} $pairs',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsEmpty extends StatelessWidget {
  const _AnalyticsEmpty({required this.onAddExpense});

  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: CPSpacing.md),
      child: Column(
        children: [
          Icon(
            Icons.donut_large_rounded,
            size: 44,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: CPSpacing.sm),
          Text(
            l10n.expenseAnalyticsEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: CPSpacing.md),
          CPButton(
            label: l10n.addExpense,
            icon: Icons.add_rounded,
            size: CPButtonSize.small,
            variant: CPButtonVariant.tonal,
            onPressed: onAddExpense,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsError extends StatelessWidget {
  const _AnalyticsError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: CPSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.query_stats_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: CPSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.expenseAnalyticsErrorTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: CPSpacing.xxs),
                Text(
                  l10n.expenseAnalyticsErrorMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: CPSpacing.sm),
                CPButton(
                  label: l10n.retry,
                  variant: CPButtonVariant.outline,
                  size: CPButtonSize.small,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const CPSkeletonCard(height: 260);
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.segments,
    required this.total,
    required this.progress,
    required this.trackColor,
  });

  final List<_DonutSegment> segments;
  final Decimal total;
  final double progress;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 16;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    if (total <= Decimal.zero || segments.isEmpty || progress <= 0) {
      return;
    }

    var startAngle = -math.pi / 2;
    const gap = 0.025;
    for (final segment in segments) {
      final ratio = (segment.amount / total).toDouble();
      final sweep = math.pi * 2 * ratio * progress;
      final visibleSweep = math.max(0.0, sweep - gap);
      if (visibleSweep > 0) {
        final paint = Paint()
          ..color = segment.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          bounds,
          startAngle + gap / 2,
          visibleSweep,
          false,
          paint,
        );
      }
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.total != total ||
        oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        !listEquals(oldDelegate.segments, segments);
  }
}

class _DonutSegment {
  const _DonutSegment({required this.amount, required this.color});

  final Decimal amount;
  final Color color;

  @override
  bool operator ==(Object other) {
    return other is _DonutSegment &&
        other.amount == amount &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(amount, color);
}

class _LegendEntry {
  const _LegendEntry({
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
  });

  final String name;
  final IconData icon;
  final Color color;
  final Decimal amount;
  final Decimal percentage;
}

String _categoryName(AppLocalizations l10n, ExpenseCategoryAnalytics category) {
  return category.isDefaultCategory
      ? CategoryLocalization.defaultCategoryName(l10n, category.categoryName)
      : category.categoryName;
}

String _periodLabel(AppLocalizations l10n, ExpenseAnalyticsPeriod period) {
  return switch (period) {
    ExpenseAnalyticsPeriod.week => l10n.expenseAnalyticsThisWeek,
    ExpenseAnalyticsPeriod.month => l10n.expenseAnalyticsThisMonth,
  };
}

String _formatPercentage(Decimal percentage, String localeName) {
  return NumberFormat.decimalPercentPattern(
    locale: localeName,
    decimalDigits: 0,
  ).format(percentage.toDouble() / 100);
}

String _formatDateRange(ExpenseAnalyticsDateRange range, String localeName) {
  final start = DateFormat.MMMd(localeName).format(range.start);
  final end = DateFormat.yMMMd(localeName).format(range.end);
  return '$start – $end';
}
