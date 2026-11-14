import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/result.dart';
import '../../../../features/auth/application/providers/auth_providers.dart';
import '../../../../features/auth/domain/entities/auth_user.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/accessibility/acceptance_semantics.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../accounts/accounts_presentation.dart'
    show AccountTypeLabels, AccountVisuals;
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization;
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/transactions_presentation.dart'
    show TransactionFormSheet;
import '../../application/dashboard_providers.dart';
import '../widgets/expense_analytics_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapshotState = ref.watch(dashboardSnapshotProvider);
    final user = ref.watch(currentAuthUserProvider);

    return Scaffold(
      floatingActionButton: _AiFloatingButton(
        label: l10n.aiAssistantShort,
        tooltip: l10n.aiAssistantTitle,
        onPressed: () => context.go(AppRoutePaths.aiAssistant),
      ),
      body: snapshotState.when(
        data: (result) {
          return switch (result) {
            AppSuccess<DashboardSnapshot>(:final data) => _DashboardContent(
              snapshot: data,
              user: user,
              onRefresh: () async {
                ref
                  ..invalidate(accountsProvider)
                  ..invalidate(categoriesProvider)
                  ..invalidate(dashboardTransactionsProvider)
                  ..invalidate(dashboardSnapshotProvider);
                await ref.read(dashboardSnapshotProvider.future);
              },
            ),
            AppFailure<DashboardSnapshot>() => CPErrorView(
              title: l10n.dashboardErrorTitle,
              message: l10n.dashboardErrorMessage,
              action: CPButton(
                label: l10n.retry,
                onPressed: () {
                  ref
                    ..invalidate(accountsProvider)
                    ..invalidate(categoriesProvider)
                    ..invalidate(dashboardTransactionsProvider)
                    ..invalidate(dashboardSnapshotProvider);
                },
              ),
            ),
          };
        },
        error: (_, _) => CPErrorView(
          title: l10n.dashboardErrorTitle,
          message: l10n.dashboardErrorMessage,
          action: CPButton(
            label: l10n.retry,
            onPressed: () {
              ref
                ..invalidate(accountsProvider)
                ..invalidate(categoriesProvider)
                ..invalidate(dashboardTransactionsProvider)
                ..invalidate(dashboardSnapshotProvider);
            },
          ),
        ),
        loading: () => const _DashboardSkeleton(),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.snapshot,
    required this.user,
    required this.onRefresh,
  });

  final DashboardSnapshot snapshot;
  final AuthUser? user;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FinanceScreenBody(
        padding: const EdgeInsetsDirectional.fromSTEB(
          CPSpacing.md,
          CPSpacing.md,
          CPSpacing.md,
          CPSpacing.xxl,
        ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Entrance(child: _DashboardHeader(user: user)),
              const SizedBox(height: CPSpacing.md),
              _Entrance(
                delay: const Duration(milliseconds: 40),
                child: _NetWorthCard(snapshot: snapshot),
              ),
              if (snapshot.isPartial) ...[
                const SizedBox(height: CPSpacing.md),
                _Entrance(
                  delay: const Duration(milliseconds: 60),
                  child: _MissingExchangeRateWarning(snapshot: snapshot),
                ),
              ],
              const SizedBox(height: CPSpacing.md),
              _Entrance(
                delay: const Duration(milliseconds: 80),
                child: _QuickActions(),
              ),
              const SizedBox(height: CPSpacing.lg),
              const _Entrance(
                delay: Duration(milliseconds: 100),
                child: ExpenseAnalyticsCard(),
              ),
              const SizedBox(height: CPSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 920;

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _RecentTransactions(snapshot: snapshot),
                        ),
                        const SizedBox(width: CPSpacing.md),
                        Expanded(
                          flex: 5,
                          child: _AccountsPreview(snapshot: snapshot),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _RecentTransactions(snapshot: snapshot),
                      const SizedBox(height: CPSpacing.lg),
                      _AccountsPreview(snapshot: snapshot),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingExchangeRateWarning extends StatelessWidget {
  const _MissingExchangeRateWarning({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pairs = snapshot.missingExchangeRatePairs
        .map((pair) => '${pair.fromCurrencyCode} → ${pair.toCurrencyCode}')
        .join(', ');
    return FinanceInfoCard(
      title: l10n.netWorthPartiallyCalculated,
      message: '${l10n.missingExchangeRateDescription} $pairs',
      icon: Icons.currency_exchange_rounded,
      color: context.cpColors.warning,
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = user?.displayName?.trim();

    return Row(
      children: [
        Tooltip(
          message: l10n.profileTitle,
          child: InkWell(
            borderRadius: BorderRadius.circular(CPRadius.full),
            onTap: () => context.go(AppRoutePaths.profile),
            child: _ProfileAvatar(user: user),
          ),
        ),
        const SizedBox(width: CPSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greetingFor(context),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: CPSpacing.xxs),
              Text(
                [
                  FinanceFormatters.weekdayDate(
                    DateTime.now(),
                    Localizations.localeOf(context).toString(),
                  ),
                  if (name != null && name.isNotEmpty) name,
                ].join('  /  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: CPSpacing.md),
        IconButton.filledTonal(
          tooltip: l10n.aiAssistantTitle,
          style: IconButton.styleFrom(
            backgroundColor: context.cpColors.aiContainer,
            foregroundColor: context.cpColors.onAiContainer,
            fixedSize: const Size.square(44),
          ),
          onPressed: () => context.go(AppRoutePaths.aiAssistant),
          icon: const Icon(Icons.auto_awesome_rounded),
        ),
      ],
    );
  }

  String _greetingFor(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return l10n.greetingMorning;
    }
    if (hour < 18) {
      return l10n.greetingAfternoon;
    }
    return l10n.greetingEvening;
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = user?.displayName ?? user?.email ?? 'C';
    final initial = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();

    return Hero(
      tag: 'profile-avatar',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.76),
              colorScheme.primaryContainer.withValues(alpha: 0.52),
            ],
          ),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            initial,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _AiMark extends StatelessWidget {
  const _AiMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.cpColors;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: CPDurations.slow,
      curve: Curves.easeOutBack,
      builder: (context, lift, child) {
        return Transform.scale(
          scale: lift,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colors.ai.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(CPRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: colors.ai.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Center(child: CPBrandMark(size: size * 0.72, ai: true)),
          ),
        );
      },
    );
  }
}

class _HeroInsightChip extends StatelessWidget {
  const _HeroInsightChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.maxWidth,
  });

  final String label;
  final String value;
  final IconData icon;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: CPSpacing.sm,
          vertical: CPSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(CPRadius.sm),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.72)),
            const SizedBox(width: CPSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactHeroStat extends StatelessWidget {
  const _CompactHeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.64)),
          const SizedBox(width: CPSpacing.xxs),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.cpColors;
    final monthlySavings = _totals(
      snapshot.monthlySavingsByCurrency,
      l10n.zero,
    );
    final savingsNegative = _hasNegativeTotal(
      snapshot.monthlySavingsByCurrency,
    );
    final changeColor = savingsNegative ? colors.expense : colors.income;

    return CPCard(
      accentColor: colors.savings,
      variant: CPCardVariant.interactive,
      onTap: () => context.go(AppRoutePaths.accounts),
      backgroundColor: CPColors.brandPanel,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _HeroTexturePainter(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              CPSpacing.lg,
              CPSpacing.md,
              CPSpacing.lg,
              CPSpacing.lg,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          color: Colors.white.withValues(alpha: 0.72),
                          size: 20,
                        ),
                        const SizedBox(width: CPSpacing.sm),
                        Expanded(
                          child: Text(
                            l10n.totalNetWorth,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: CPSpacing.sm),
                    AnimatedSwitcher(
                      duration: CPDurations.normal,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.08),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: FittedBox(
                        key: ValueKey(snapshot.netWorthByCurrency),
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          FinanceFormatters.amountWithCurrency(
                            snapshot.netWorthInBaseCurrency.amount,
                            snapshot.netWorthInBaseCurrency.currencyCode,
                          ),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: CPSpacing.sm),
                    Wrap(
                      spacing: CPSpacing.sm,
                      runSpacing: CPSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FinanceStatusPill(
                          label: monthlySavings,
                          icon: savingsNegative
                              ? Icons.trending_down_rounded
                              : Icons.trending_up_rounded,
                          color: changeColor,
                        ),
                        Text(
                          l10n.monthlySavings,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    if (compact) ...[
                      const SizedBox(height: CPSpacing.sm),
                      Wrap(
                        spacing: CPSpacing.md,
                        runSpacing: CPSpacing.xs,
                        children: [
                          _CompactHeroStat(
                            label: l10n.accountsTitle,
                            value: '${snapshot.accounts.length}',
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                          _CompactHeroStat(
                            label: l10n.transactionsTitle,
                            value: '${snapshot.totalTransactionCount}',
                            icon: Icons.receipt_long_outlined,
                          ),
                        ],
                      ),
                    ],
                    if (!compact) ...[
                      const SizedBox(height: CPSpacing.md),
                      Wrap(
                        spacing: CPSpacing.sm,
                        runSpacing: CPSpacing.sm,
                        children: [
                          _HeroInsightChip(
                            label: l10n.accountsTitle,
                            value: '${snapshot.accounts.length}',
                            icon: Icons.account_balance_wallet_outlined,
                            maxWidth: 140,
                          ),
                          _HeroInsightChip(
                            label: l10n.transactionsTitle,
                            value: '${snapshot.totalTransactionCount}',
                            icon: Icons.receipt_long_outlined,
                            maxWidth: 150,
                          ),
                          if (snapshot.unconvertedNetWorthByCurrency.isNotEmpty)
                            _HeroInsightChip(
                              label: snapshot.baseCurrencyCode,
                              value: _totals(
                                snapshot.unconvertedNetWorthByCurrency,
                                l10n.zero,
                              ),
                              icon: Icons.currency_exchange_rounded,
                              maxWidth: 180,
                            ),
                        ],
                      ),
                    ],
                  ],
                );

                if (compact) {
                  return content;
                }

                return Row(
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: CPSpacing.lg),
                    const _AiMark(size: 76),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTexturePainter extends CustomPainter {
  const _HeroTexturePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = color.withValues(alpha: 0.12);
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader =
          RadialGradient(
            colors: [color.withValues(alpha: 0.22), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.92, size.height * 0.20),
              radius: size.shortestSide * 0.92,
            ),
          );

    canvas.drawRect(Offset.zero & size, glowPaint);

    for (var index = 0; index < 8; index++) {
      final y = size.height * (0.18 + index * 0.09);
      final path = Path()
        ..moveTo(size.width * 0.48, y)
        ..quadraticBezierTo(
          size.width * 0.68,
          y + 18,
          size.width * 0.98,
          y - 8,
        );
      canvas.drawPath(path, wavePaint);
    }

    final dotPaint = Paint()..color = color.withValues(alpha: 0.18);
    for (var index = 0; index < 34; index++) {
      final x = size.width * (0.62 + (index % 9) * 0.042);
      final y = size.height * (0.55 + (index ~/ 9) * 0.085);
      canvas.drawCircle(Offset(x, y), 1.15, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroTexturePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            );
            if (action != null && constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: CPSpacing.xs),
                  action!,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: titleBlock),
                if (action != null) ...[
                  const SizedBox(width: CPSpacing.sm),
                  action!,
                ],
              ],
            );
          },
        ),
        const SizedBox(height: CPSpacing.sm),
        child,
      ],
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final actions = [
      _ActionSpec(
        label: l10n.addAccount,
        icon: Icons.account_balance_wallet_outlined,
        color: context.cpColors.savings,
        onTap: () => context.go(AppRoutePaths.accounts),
      ),
      _ActionSpec(
        label: l10n.addExpense,
        icon: Icons.remove_circle_outline_rounded,
        color: context.cpColors.expense,
        onTap: () => _openTransaction(context, ref, TransactionType.expense),
      ),
      _ActionSpec(
        label: l10n.addIncome,
        icon: Icons.add_circle_outline_rounded,
        color: context.cpColors.income,
        onTap: () => _openTransaction(context, ref, TransactionType.income),
      ),
      _ActionSpec(
        label: l10n.transfer,
        icon: Icons.swap_horiz_rounded,
        color: context.cpColors.transfer,
        onTap: () => context.go(AppRoutePaths.transfer),
      ),
      _ActionSpec(
        label: l10n.scanReceipt,
        icon: Icons.document_scanner_outlined,
        color: context.cpColors.warning,
        onTap: () => context.go(AppRoutePaths.receiptCapture),
      ),
      _ActionSpec(
        label: l10n.aiAssistantShort,
        icon: Icons.auto_awesome_rounded,
        color: context.cpColors.ai,
        onTap: () => context.go(AppRoutePaths.aiAssistant),
      ),
    ];

    return _DashboardSection(
      title: l10n.quickActions,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dense = constraints.maxWidth < 620;
          return SizedBox(
            height: dense ? 140 : 72,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: dense ? 3 : 6,
                crossAxisSpacing: CPSpacing.xs,
                mainAxisSpacing: CPSpacing.xs,
                mainAxisExtent: dense ? 66 : 72,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) =>
                  _QuickActionTile(action: actions[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openTransaction(
    BuildContext context,
    WidgetRef ref,
    TransactionType type,
  ) async {
    final created = await TransactionFormSheet.show(context, type);
    if (!context.mounted || created != true) {
      return;
    }
    ref
      ..invalidate(dashboardTransactionsProvider)
      ..invalidate(dashboardSnapshotProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).transactionCreatedMessage),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _ActionSpec action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxWidth < 110;

        return CPCard(
          variant: CPCardVariant.interactive,
          padding: const EdgeInsetsDirectional.all(CPSpacing.xxs),
          onTap: action.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SoftIcon(
                icon: action.icon,
                color: action.color,
                size: dense ? 24 : 30,
              ),
              const SizedBox(height: CPSpacing.xxs),
              SizedBox(
                height: dense ? 14 : 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    action.label,
                    maxLines: 1,
                    style:
                        (dense
                                ? Theme.of(context).textTheme.labelSmall
                                : Theme.of(context).textTheme.labelLarge)
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionSpec {
  const _ActionSpec({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _AccountsPreview extends StatelessWidget {
  const _AccountsPreview({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accounts = snapshot.accounts.take(3).toList(growable: false);

    return _DashboardSection(
      title: l10n.accountsPreview,
      action: CPButton(
        label: l10n.viewAll,
        variant: CPButtonVariant.ghost,
        size: CPButtonSize.small,
        onPressed: () => context.go(AppRoutePaths.accounts),
      ),
      child: CPCard(
        padding: const EdgeInsetsDirectional.all(CPSpacing.sm),
        child: accounts.isEmpty
            ? CPEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: l10n.emptyAccountsTitle,
                message: l10n.emptyAccountsMessage,
                action: CPButton(
                  label: l10n.addAccount,
                  onPressed: () => context.go(AppRoutePaths.accounts),
                ),
              )
            : Column(
                children: [
                  for (var index = 0; index < accounts.length; index++) ...[
                    _CompactAccountTile(account: accounts[index]),
                    if (index != accounts.length - 1)
                      const SizedBox(height: CPSpacing.xs),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CompactAccountTile extends StatelessWidget {
  const _CompactAccountTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final color = Color(account.color);
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(CPRadius.sm),
        onTap: () => context.goNamed(
          AppRouteNames.accountDetails,
          pathParameters: {'accountId': account.id},
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: CPSpacing.sm,
            vertical: CPSpacing.sm,
          ),
          child: Row(
            children: [
              _SoftIcon(
                icon: AccountVisuals.iconForKey(account.icon),
                color: color,
                size: 36,
              ),
              const SizedBox(width: CPSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: CPSpacing.xxs),
                    Text(
                      '${AccountTypeLabels.label(l10n, account.type)} / ${account.currencyCode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CPSpacing.sm),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    FinanceFormatters.amountWithCurrency(
                      account.balance,
                      account.currencyCode,
                    ),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categoryNames = {
      for (final category in snapshot.categories)
        category.id: CategoryLocalization.name(l10n, category),
    };
    final transactions = snapshot.recentTransactions
        .take(4)
        .toList(growable: false);

    return _DashboardSection(
      title: l10n.recentTransactions,
      action: CPButton(
        label: l10n.viewAll,
        variant: CPButtonVariant.ghost,
        size: CPButtonSize.small,
        onPressed: () => context.go(AppRoutePaths.transactions),
      ),
      child: CPCard(
        padding: const EdgeInsetsDirectional.all(CPSpacing.sm),
        child: transactions.isEmpty
            ? CPEmptyState(
                icon: Icons.receipt_long_outlined,
                title: l10n.emptyTransactionsTitle,
                message: l10n.emptyTransactionsMessage,
              )
            : Column(
                children: [
                  for (var index = 0; index < transactions.length; index++) ...[
                    _CompactTransactionTile(
                      transaction: transactions[index],
                      categoryName:
                          categoryNames[transactions[index].categoryId],
                    ),
                    if (index != transactions.length - 1)
                      const SizedBox(height: CPSpacing.xs),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CompactTransactionTile extends StatelessWidget {
  const _CompactTransactionTile({
    required this.transaction,
    required this.categoryName,
  });

  final Transaction transaction;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context, transaction.type);
    final sign = switch (transaction.type) {
      TransactionType.income || TransactionType.transferIn => '+',
      TransactionType.expense || TransactionType.transferOut => '-',
    };
    final localeName = Localizations.localeOf(context).toString();
    final title = transaction.note?.isNotEmpty == true
        ? transaction.note!
        : categoryName ?? transaction.type.name;
    final subtitle = [
      if (categoryName != null && categoryName != title) categoryName!,
      FinanceFormatters.compactDate(transaction.transactionDate, localeName),
    ].join(' / ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(CPRadius.sm),
        onTap: () => context.goNamed(
          AppRouteNames.transactionDetails,
          pathParameters: {'transactionId': transaction.id},
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: CPSpacing.sm,
            vertical: CPSpacing.sm,
          ),
          child: Row(
            children: [
              _SoftIcon(
                icon: _iconFor(transaction.type),
                color: color,
                size: 36,
              ),
              const SizedBox(width: CPSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: CPSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CPSpacing.sm),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    '$sign${FinanceFormatters.money(transaction.amount)}',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorFor(BuildContext context, TransactionType type) {
    final cpColors = context.cpColors;
    return switch (type) {
      TransactionType.income => cpColors.income,
      TransactionType.expense => cpColors.expense,
      TransactionType.transferIn ||
      TransactionType.transferOut => cpColors.transfer,
    };
  }

  IconData _iconFor(TransactionType type) {
    return switch (type) {
      TransactionType.income => Icons.south_west_rounded,
      TransactionType.expense => Icons.north_east_rounded,
      TransactionType.transferIn ||
      TransactionType.transferOut => Icons.swap_horiz_rounded,
    };
  }
}

class _AiFloatingButton extends StatelessWidget {
  const _AiFloatingButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.cpColors;

    return Semantics(
      button: true,
      label: label,
      identifier: cashPilotForceStopAcceptanceIdentifier(
        'cashpilot_acceptance_dashboard_ai',
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.94, end: 1),
        duration: CPDurations.slow,
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.translate(
            offset: Offset(0, (1 - scale) * 12),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Tooltip(
          message: tooltip,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CPRadius.full),
              boxShadow: [
                BoxShadow(
                  color: colors.ai.withValues(alpha: 0.36),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: 'dashboard-ai-fab',
              mini: false,
              backgroundColor: colors.ai,
              foregroundColor: colors.onAi,
              onPressed: onPressed,
              child: const Icon(Icons.auto_awesome_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return FinanceScreenBody(
      child: ListView(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(width: 220, height: 30),
                    SizedBox(height: CPSpacing.sm),
                    _SkeletonBlock(width: 180, height: 14),
                  ],
                ),
              ),
              _SkeletonBlock(width: 48, height: 48),
            ],
          ),
          const SizedBox(height: CPSpacing.xl),
          const _SkeletonCard(height: 190),
          const SizedBox(height: CPSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 840;
              if (!wide) {
                return const Column(
                  children: [
                    _SkeletonCard(height: 190),
                    SizedBox(height: CPSpacing.xl),
                    _SkeletonCard(height: 170),
                  ],
                );
              }

              return const Row(
                children: [
                  Expanded(child: _SkeletonCard(height: 190)),
                  SizedBox(width: CPSpacing.xl),
                  Expanded(child: _SkeletonCard(height: 170)),
                ],
              );
            },
          ),
          const SizedBox(height: CPSpacing.xl),
          const _SkeletonCard(height: 140),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return CPCard(
      child: SizedBox(
        height: height,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBlock(width: 82, height: 34),
            Spacer(),
            _SkeletonBlock(width: 220, height: 28),
            SizedBox(height: CPSpacing.sm),
            _SkeletonBlock(width: 148, height: 14),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatefulWidget {
  const _SkeletonBlock({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<_SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
          colorScheme.primary.withValues(alpha: 0.14),
          _controller.value,
        )!;

        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(CPRadius.sm),
          ),
        );
      },
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CPRadius.md),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: CPDurations.slow + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
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

bool _hasNegativeTotal(List<CurrencyTotal> totals) {
  return totals.any((total) => total.amount < Decimal.zero);
}
