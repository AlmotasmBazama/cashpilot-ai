import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../application/models/goal_linked_account_option.dart';
import '../../application/providers/goal_linked_account_options_provider.dart';
import '../../application/providers/goals_providers.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_contribution.dart';
import '../../domain/entities/goal_progress.dart';
import '../../domain/enums/goal_status.dart';
import '../../domain/enums/goal_type.dart';
import '../widgets/goal_contribution_sheet.dart';
import '../widgets/goal_form_sheet.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  bool _includeArchived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progressState = ref.watch(allGoalProgressProvider);
    final accounts = _accounts(ref.watch(goalLinkedAccountOptionsProvider));
    return Scaffold(
      appBar: CPAppBar(
        title: l10n.goalsTitle,
        subtitle: l10n.goalsSubtitle,
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
        label: l10n.addGoal,
        tooltip: l10n.addGoal,
        onPressed: _openGoalForm,
      ),
      body: progressState.when(
        loading: () => FinanceScreenBody(
          child: ListView(
            children: const [
              CPSkeletonCard(height: 176),
              SizedBox(height: CPSpacing.md),
              CPSkeletonCard(height: 176),
              SizedBox(height: CPSpacing.xl),
              CPSkeletonCard(height: 320),
            ],
          ),
        ),
        error: (_, _) => _error(l10n),
        data: (result) => switch (result) {
          AppSuccess<List<GoalProgress>>(:final data) => _content(
            data,
            accounts,
          ),
          AppFailure<List<GoalProgress>>() => _error(l10n),
        },
      ),
    );
  }

  Widget _content(
    List<GoalProgress> progress,
    Map<String, GoalLinkedAccountOption> accounts,
  ) {
    final l10n = AppLocalizations.of(context);
    final visible = progress
        .where((item) => _includeArchived || !item.goal.isArchived)
        .toList(growable: false);
    final active = progress
        .where(
          (item) =>
              item.status == GoalStatus.active ||
              item.status == GoalStatus.paused,
        )
        .toList(growable: false);
    final completed = progress
        .where((item) => item.status == GoalStatus.completed)
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
                  label: l10n.activeGoals,
                  value: '${active.length}',
                  icon: Icons.flag_outlined,
                  accentColor: context.cpColors.info,
                ),
                FinanceMetricCard(
                  label: l10n.savedForGoals,
                  value: _savedTotals(active, l10n.zero),
                  icon: Icons.savings_outlined,
                  accentColor: context.cpColors.savings,
                ),
                FinanceMetricCard(
                  label: l10n.completedGoals,
                  value: '$completed',
                  icon: Icons.emoji_events_outlined,
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
            title: Text(l10n.includeArchivedGoals),
            secondary: const Icon(Icons.inventory_2_outlined),
          ),
          const SizedBox(height: CPSpacing.md),
          if (visible.isEmpty)
            CPEmptyState(
              icon: Icons.flag_outlined,
              title: l10n.emptyGoalsTitle,
              message: l10n.createYourFirstGoal,
              action: CPButton(
                label: l10n.addGoal,
                icon: Icons.add_rounded,
                onPressed: _openGoalForm,
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
                    mainAxisExtent: 390,
                  ),
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return _GoalProgressCard(
                      progress: item,
                      account: accounts[item.goal.linkedAccountId],
                      onOpen: () => _openDetails(item, accounts),
                      onEdit: () => _openGoalForm(item.goal),
                      onContribute: () => _openContribution(item.goal),
                      onArchive: () => _archive(item.goal),
                      onRestore: () => _restore(item.goal),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _error(AppLocalizations l10n) => CPErrorView(
    title: l10n.goalsLoadError,
    message: l10n.goalsLoadErrorMessage,
    action: CPButton(
      label: l10n.retry,
      icon: Icons.refresh_rounded,
      onPressed: _refresh,
    ),
  );

  Map<String, GoalLinkedAccountOption> _accounts(
    AsyncValue<AppResult<List<GoalLinkedAccountOption>>> value,
  ) => switch (value.value) {
    AppSuccess<List<GoalLinkedAccountOption>>(:final data) => {
      for (final account in data) account.id: account,
    },
    _ => const <String, GoalLinkedAccountOption>{},
  };

  String _savedTotals(List<GoalProgress> progress, String emptyLabel) {
    final totals = <String, Decimal>{};
    for (final item in progress) {
      totals.update(
        item.goal.currency,
        (value) => value + item.currentAmount,
        ifAbsent: () => item.currentAmount,
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
      ..invalidate(goalsProvider)
      ..invalidate(allGoalsProvider)
      ..invalidate(goalProgressProvider)
      ..invalidate(allGoalProgressProvider)
      ..invalidate(goalSummaryProvider);
  }

  Future<void> _openGoalForm([Goal? goal]) async {
    final saved = await GoalFormSheet.show(context, goal: goal);
    if (saved == true && mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).goalSaved)),
      );
    }
  }

  Future<void> _openContribution(Goal goal) async {
    final saved = await GoalContributionSheet.show(context, goal: goal);
    if (saved == true && mounted) {
      _refresh();
      ref.invalidate(goalContributionsProvider(goal.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).contributionAdded)),
      );
    }
  }

  Future<void> _archive(Goal goal) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.archiveGoal),
        content: Text(l10n.goalArchiveConfirm),
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
    final result = await ref.read(archiveGoalUseCaseProvider)(goal.id);
    if (mounted && result is AppSuccess<Goal>) {
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.goalArchived)));
    }
  }

  Future<void> _restore(Goal goal) async {
    final result = await ref.read(restoreGoalUseCaseProvider)(goal.id);
    if (mounted && result is AppSuccess<Goal>) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).goalRestored)),
      );
    }
  }

  Future<void> _reverseContribution(GoalContribution contribution) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reverseContribution),
        content: Text(l10n.reverseContributionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.reverseContribution),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final result = await ref.read(reverseGoalContributionUseCaseProvider)(
      contribution.id,
    );
    if (mounted && result is AppSuccess<GoalContribution>) {
      _refresh();
      ref.invalidate(goalContributionsProvider(contribution.goalId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.contributionReversed)));
    }
  }

  Future<void> _openDetails(
    GoalProgress progress,
    Map<String, GoalLinkedAccountOption> accounts,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _GoalDetailsSheet(
          progress: progress,
          account: accounts[progress.goal.linkedAccountId],
          onContribute: () => _openContribution(progress.goal),
          onReverse: _reverseContribution,
        ),
      ),
    );
  }
}

class _GoalProgressCard extends StatelessWidget {
  const _GoalProgressCard({
    required this.progress,
    required this.account,
    required this.onOpen,
    required this.onEdit,
    required this.onContribute,
    required this.onArchive,
    required this.onRestore,
  });

  final GoalProgress progress;
  final GoalLinkedAccountOption? account;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onContribute;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final goal = progress.goal;
    final color = goalStatusColor(context, progress.status, Color(goal.color));
    final rawRatio = (progress.progressPercent / Decimal.fromInt(100))
        .toDouble();
    final ratio = rawRatio < 0
        ? 0.0
        : rawRatio > 1
        ? 1.0
        : rawRatio;
    return CPCard(
      variant: CPCardVariant.interactive,
      accentColor: color,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(CPRadius.sm),
                ),
                child: Icon(goalTypeIcon(goal.type), color: color),
              ),
              const SizedBox(width: CPSpacing.sm),
              Expanded(
                child: Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              PopupMenuButton<_GoalAction>(
                tooltip: l10n.editGoal,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) => switch (action) {
                  _GoalAction.edit => onEdit(),
                  _GoalAction.contribute => onContribute(),
                  _GoalAction.archive => onArchive(),
                  _GoalAction.restore => onRestore(),
                },
                itemBuilder: (context) => goal.isArchived
                    ? [
                        PopupMenuItem(
                          value: _GoalAction.restore,
                          child: Text(l10n.restoreGoal),
                        ),
                      ]
                    : [
                        if (progress.status != GoalStatus.completed)
                          PopupMenuItem(
                            value: _GoalAction.contribute,
                            child: Text(l10n.addContribution),
                          ),
                        PopupMenuItem(
                          value: _GoalAction.edit,
                          child: Text(l10n.editGoal),
                        ),
                        PopupMenuItem(
                          value: _GoalAction.archive,
                          child: Text(l10n.archiveGoal),
                        ),
                      ],
              ),
            ],
          ),
          const SizedBox(height: CPSpacing.sm),
          Wrap(
            spacing: CPSpacing.sm,
            runSpacing: CPSpacing.xs,
            children: [
              FinanceStatusPill(
                label: goalStatusLabel(l10n, progress.status),
                icon: goalStatusIcon(progress.status),
                color: color,
              ),
              if (goal.targetDate case final date?)
                FinanceStatusPill(
                  label: FinanceFormatters.compactDate(
                    date,
                    Localizations.localeOf(context).toLanguageTag(),
                  ),
                  icon: Icons.event_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
          const SizedBox(height: CPSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  FinanceFormatters.amountWithCurrency(
                    progress.currentAmount,
                    goal.currency,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
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
          const SizedBox(height: CPSpacing.sm),
          FinanceProgressBar(value: ratio, color: color),
          const SizedBox(height: CPSpacing.sm),
          FinanceDetailRow(
            label: l10n.targetAmount,
            value: FinanceFormatters.amountWithCurrency(
              goal.targetAmount,
              goal.currency,
            ),
          ),
          FinanceDetailRow(
            label: l10n.remainingAmount,
            value: FinanceFormatters.amountWithCurrency(
              progress.remainingAmount,
              goal.currency,
            ),
          ),
          if (account != null)
            FinanceDetailRow(label: l10n.linkedAccount, value: account!.name),
        ],
      ),
    );
  }
}

class _GoalDetailsSheet extends ConsumerWidget {
  const _GoalDetailsSheet({
    required this.progress,
    required this.account,
    required this.onContribute,
    required this.onReverse,
  });

  final GoalProgress progress;
  final GoalLinkedAccountOption? account;
  final Future<void> Function() onContribute;
  final Future<void> Function(GoalContribution contribution) onReverse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final goal = progress.goal;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final contributions = ref.watch(goalContributionsProvider(goal.id));
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        CPSpacing.lg,
        0,
        CPSpacing.lg,
        CPSpacing.xl,
      ),
      children: [
        CPSectionTitle(
          title: l10n.goalDetails,
          subtitle: goal.title,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: CPSpacing.lg),
        FinanceDetailRow(
          label: l10n.goalType,
          value: goalTypeLabel(l10n, goal.type),
          icon: goalTypeIcon(goal.type),
        ),
        FinanceDetailRow(
          label: l10n.currentAmount,
          value: FinanceFormatters.amountWithCurrency(
            progress.currentAmount,
            goal.currency,
          ),
          icon: Icons.savings_outlined,
        ),
        FinanceDetailRow(
          label: l10n.remainingAmount,
          value: FinanceFormatters.amountWithCurrency(
            progress.remainingAmount,
            goal.currency,
          ),
          icon: Icons.flag_outlined,
        ),
        if (progress.daysRemaining case final days?)
          FinanceDetailRow(
            label: l10n.daysRemaining,
            value: '$days',
            icon: Icons.event_outlined,
          ),
        if (progress.monthlyNeeded case final amount?)
          FinanceDetailRow(
            label: l10n.monthlyNeeded,
            value: FinanceFormatters.amountWithCurrency(amount, goal.currency),
            icon: Icons.calendar_view_month_outlined,
          ),
        FinanceDetailRow(
          label: l10n.linkedAccount,
          value: account?.name ?? l10n.noLinkedAccount,
          icon: Icons.account_balance_wallet_outlined,
        ),
        if (goal.description.isNotEmpty) ...[
          const SizedBox(height: CPSpacing.md),
          Text(goal.description),
        ],
        if (!goal.isArchived && progress.status != GoalStatus.completed) ...[
          const SizedBox(height: CPSpacing.lg),
          CPButton(
            label: l10n.addContribution,
            icon: Icons.add_rounded,
            onPressed: onContribute,
          ),
        ],
        const SizedBox(height: CPSpacing.xl),
        CPSectionTitle(
          title: l10n.contributionHistory,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: CPSpacing.md),
        contributions.when(
          loading: () => const CPSkeletonCard(height: 160),
          error: (_, _) => CPErrorView(
            title: l10n.goalsLoadError,
            message: l10n.goalsLoadErrorMessage,
          ),
          data: (result) => switch (result) {
            AppSuccess<List<GoalContribution>>(:final data) when data.isEmpty =>
              CPEmptyState(
                icon: Icons.timeline_outlined,
                title: l10n.noContributionsYet,
                message: l10n.noContributionsMessage,
              ),
            AppSuccess<List<GoalContribution>>(:final data) => Column(
              children: [
                for (final contribution in data)
                  _ContributionTimelineItem(
                    contribution: contribution,
                    locale: locale,
                    onReverse: contribution.isReversed
                        ? null
                        : () => onReverse(contribution),
                  ),
              ],
            ),
            AppFailure<List<GoalContribution>>() => CPErrorView(
              title: l10n.goalsLoadError,
              message: l10n.goalsLoadErrorMessage,
            ),
          },
        ),
      ],
    );
  }
}

class _ContributionTimelineItem extends StatelessWidget {
  const _ContributionTimelineItem({
    required this.contribution,
    required this.locale,
    required this.onReverse,
  });

  final GoalContribution contribution;
  final String locale;
  final VoidCallback? onReverse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = contribution.isReversed
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : context.cpColors.success;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: CPSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsetsDirectional.only(top: CPSpacing.xs),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: CPSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FinanceFormatters.amountWithCurrency(
                    contribution.amount,
                    contribution.currency,
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    decoration: contribution.isReversed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  FinanceFormatters.compactDate(contribution.date, locale),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (contribution.note.isNotEmpty)
                  Text(
                    contribution.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (contribution.isReversed)
                  Text(
                    l10n.reversedContribution,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          if (onReverse != null)
            IconButton(
              tooltip: l10n.reverseContribution,
              onPressed: onReverse,
              icon: const Icon(Icons.undo_rounded),
            ),
        ],
      ),
    );
  }
}

enum _GoalAction { edit, contribute, archive, restore }

String goalStatusLabel(AppLocalizations l10n, GoalStatus status) =>
    switch (status) {
      GoalStatus.active => l10n.goalStatusActive,
      GoalStatus.completed => l10n.goalStatusCompleted,
      GoalStatus.paused => l10n.goalStatusPaused,
      GoalStatus.archived => l10n.goalStatusArchived,
    };

IconData goalStatusIcon(GoalStatus status) => switch (status) {
  GoalStatus.active => Icons.play_circle_outline_rounded,
  GoalStatus.completed => Icons.check_circle_outline_rounded,
  GoalStatus.paused => Icons.pause_circle_outline_rounded,
  GoalStatus.archived => Icons.inventory_2_outlined,
};

Color goalStatusColor(
  BuildContext context,
  GoalStatus status,
  Color goalColor,
) => switch (status) {
  GoalStatus.active => goalColor,
  GoalStatus.completed => context.cpColors.success,
  GoalStatus.paused => context.cpColors.warning,
  GoalStatus.archived => Theme.of(context).colorScheme.onSurfaceVariant,
};

IconData goalTypeIcon(GoalType type) => switch (type) {
  GoalType.savings => Icons.savings_outlined,
  GoalType.emergencyFund => Icons.shield_outlined,
  GoalType.debtPayoff => Icons.receipt_long_outlined,
  GoalType.purchase => Icons.shopping_bag_outlined,
  GoalType.custom => Icons.flag_outlined,
};
