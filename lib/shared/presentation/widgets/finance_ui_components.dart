import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

class FinanceScreenBody extends StatelessWidget {
  const FinanceScreenBody({
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(CPSpacing.lg),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CPAdaptivePage(
      padding: padding,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        child: AnimatedSwitcher(
          duration: CPDurations.slow,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.015),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: child,
        ),
      ),
    );
  }
}

class FinanceSection extends StatelessWidget {
  const FinanceSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CPSectionTitle(
          title: title,
          subtitle: subtitle,
          action: action,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: CPSpacing.md),
        child,
      ],
    );
  }
}

class FinanceMetricCard extends StatelessWidget {
  const FinanceMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.subtitle,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Theme.of(context).colorScheme.primary;
    final colorScheme = Theme.of(context).colorScheme;

    return CPCard(
      variant: onTap == null
          ? CPCardVariant.elevated
          : CPCardVariant.interactive,
      onTap: onTap,
      accentColor: color,
      padding: const EdgeInsetsDirectional.all(CPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SoftIcon(icon: icon, color: color),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: color.withValues(alpha: 0.78),
                ),
            ],
          ),
          const SizedBox(height: CPSpacing.sm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: CPSpacing.xs),
          Flexible(
            child: AnimatedSwitcher(
              duration: CPDurations.normal,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.10),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              child: Align(
                key: ValueKey(value),
                alignment: AlignmentDirectional.centerStart,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: CPSpacing.xs),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class FinanceInfoCard extends StatelessWidget {
  const FinanceInfoCard({
    required this.title,
    required this.message,
    required this.icon,
    this.action,
    this.color,
    this.leading,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  final Color? color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    final colorScheme = Theme.of(context).colorScheme;

    return CPCard(
      accentColor: resolvedColor,
      variant: CPCardVariant.elevated,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: CPSpacing.xs),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: CPSpacing.md),
                action!,
              ],
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading ?? _SoftIcon(icon: icon, color: resolvedColor),
                const SizedBox(height: CPSpacing.md),
                text,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading ?? _SoftIcon(icon: icon, color: resolvedColor),
              const SizedBox(width: CPSpacing.md),
              Expanded(child: text),
            ],
          );
        },
      ),
    );
  }
}

class FinanceStatusPill extends StatelessWidget {
  const FinanceStatusPill({
    required this.label,
    this.icon,
    this.color,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: CPSpacing.md,
        vertical: CPSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(CPRadius.full),
        border: Border.all(color: resolvedColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: resolvedColor),
            const SizedBox(width: CPSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: resolvedColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceAmountText extends StatelessWidget {
  const FinanceAmountText({
    required this.value,
    this.color,
    this.style,
    this.alignment = AlignmentDirectional.centerStart,
    this.semanticLabel,
    super.key,
  });

  final String value;
  final Color? color;
  final TextStyle? style;
  final AlignmentGeometry alignment;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle =
        style ??
        Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: color ?? Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w900,
        );

    return Semantics(
      label: semanticLabel,
      child: Align(
        alignment: alignment,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: resolvedStyle),
          ),
        ),
      ),
    );
  }
}

enum MoneyTrendTone { positive, negative, neutral }

class MoneyTrendBadge extends StatelessWidget {
  const MoneyTrendBadge({
    required this.label,
    this.tone = MoneyTrendTone.neutral,
    super.key,
  });

  final String label;
  final MoneyTrendTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      MoneyTrendTone.positive => context.cpColors.success,
      MoneyTrendTone.negative => context.cpColors.expense,
      MoneyTrendTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    final icon = switch (tone) {
      MoneyTrendTone.positive => Icons.trending_up_rounded,
      MoneyTrendTone.negative => Icons.trending_down_rounded,
      MoneyTrendTone.neutral => Icons.horizontal_rule_rounded,
    };

    return FinanceStatusPill(label: label, icon: icon, color: color);
  }
}

class AIAccentBadge extends StatelessWidget {
  const AIAccentBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return FinanceStatusPill(
      label: label,
      icon: Icons.auto_awesome_rounded,
      color: context.cpColors.ai,
    );
  }
}

class SmartSuggestionChip extends StatelessWidget {
  const SmartSuggestionChip({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        Icons.auto_awesome_rounded,
        size: 17,
        color: context.cpColors.ai,
      ),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      backgroundColor: context.cpColors.aiContainer.withValues(alpha: 0.64),
      side: BorderSide(color: context.cpColors.ai.withValues(alpha: 0.24)),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: context.cpColors.onAiContainer,
        fontWeight: FontWeight.w800,
      ),
      onPressed: onPressed,
    );
  }
}

class FinanceDetailRow extends StatelessWidget {
  const FinanceDetailRow({
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: CPSpacing.sm),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: CPSpacing.sm),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: CPSpacing.md),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: valueColor ?? colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceSafetyNotice extends StatelessWidget {
  const FinanceSafetyNotice({
    required this.title,
    required this.message,
    this.icon = Icons.verified_user_outlined,
    this.color,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? context.cpColors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(CPSpacing.md),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CPRadius.sm),
        border: Border.all(color: resolvedColor.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: resolvedColor),
          const SizedBox(width: CPSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: resolvedColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: CPSpacing.xxs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.36,
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

class FinanceProgressBar extends StatelessWidget {
  const FinanceProgressBar({required this.value, this.color, super.key});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    final backgroundColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.58);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: CPDurations.slow,
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return Container(
          height: 10,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(CPRadius.full),
          ),
          clipBehavior: Clip.antiAlias,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      resolvedColor.withValues(alpha: 0.72),
                      resolvedColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(CPRadius.full),
                  boxShadow: [
                    BoxShadow(
                      color: resolvedColor.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FinanceMiniBars extends StatelessWidget {
  const FinanceMiniBars({
    required this.values,
    this.color,
    this.height = 120,
    super.key,
  });

  final List<Decimal> values;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    final nonZeroValues = values
        .where((value) => value > Decimal.zero)
        .toList();
    final maxValue = nonZeroValues.isEmpty
        ? Decimal.one
        : nonZeroValues.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final value in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: CPSpacing.xs,
                ),
                child: FractionallySizedBox(
                  heightFactor: _heightFactor(value, maxValue),
                  alignment: AlignmentDirectional.bottomCenter,
                  child: AnimatedContainer(
                    duration: CPDurations.slow,
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          resolvedColor.withValues(alpha: 0.52),
                          resolvedColor.withValues(
                            alpha: value <= Decimal.zero ? 0.20 : 0.92,
                          ),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(CPRadius.full),
                        bottom: Radius.circular(CPRadius.xs),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: resolvedColor.withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _heightFactor(Decimal value, Decimal maxValue) {
    if (value <= Decimal.zero) {
      return 0.08;
    }

    final scaled = (value / maxValue).toDouble();
    return scaled.clamp(0.08, 1);
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(CPRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: color),
    );
  }
}
