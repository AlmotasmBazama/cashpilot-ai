import 'package:flutter/material.dart';

import '../theme/cp_semantic_colors.dart';
import '../tokens/cp_radius.dart';
import '../tokens/cp_spacing.dart';

enum CPButtonVariant { primary, secondary, tonal, outline, ghost, danger }

enum CPButtonSize { small, medium, large }

class CPButton extends StatelessWidget {
  const CPButton({
    required this.label,
    required this.onPressed,
    this.variant = CPButtonVariant.primary,
    this.size = CPButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.tooltip,
    this.semanticsIdentifier,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final CPButtonVariant variant;
  final CPButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final String? tooltip;
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = _ButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
      variant: variant,
    );
    final style = _styleFor(context);
    final button = switch (variant) {
      CPButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      CPButtonVariant.secondary => ElevatedButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      CPButtonVariant.tonal => FilledButton.tonal(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      CPButtonVariant.outline => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      CPButtonVariant.ghost => TextButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      CPButtonVariant.danger => FilledButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
    };

    final constrained = fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;

    final result = tooltip == null
        ? constrained
        : Tooltip(message: tooltip, child: constrained);
    if (semanticsIdentifier == null) {
      return result;
    }
    return Semantics(
      container: true,
      identifier: semanticsIdentifier,
      child: result,
    );
  }

  ButtonStyle _styleFor(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cpColors = context.cpColors;
    final metrics = _ButtonMetrics.forSize(size);
    final base = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, metrics.height)),
      padding: WidgetStatePropertyAll(metrics.padding),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CPRadius.md),
        ),
      ),
      textStyle: WidgetStatePropertyAll(theme.textTheme.labelLarge),
    );

    return switch (variant) {
      CPButtonVariant.danger => base.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.12);
          }

          return cpColors.expense;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }

          return cpColors.onExpense;
        }),
      ),
      CPButtonVariant.ghost => base.copyWith(
        foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
      ),
      _ => base,
    };
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.variant,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final CPButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final progressColor = _progressColorFor(context);
    final leading = isLoading
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          )
        : icon == null
        ? null
        : Icon(icon, size: 18);
    final labelWidget = Flexible(
      child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
    );

    if (leading == null) {
      return Text(label, overflow: TextOverflow.ellipsis, maxLines: 1);
    }

    final children = direction == TextDirection.rtl
        ? [labelWidget, const SizedBox(width: CPSpacing.sm), leading]
        : [leading, const SizedBox(width: CPSpacing.sm), labelWidget];

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Color _progressColorFor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cpColors = context.cpColors;

    return switch (variant) {
      CPButtonVariant.primary => colorScheme.onPrimary,
      CPButtonVariant.danger => cpColors.onExpense,
      CPButtonVariant.tonal => colorScheme.onSecondaryContainer,
      _ => colorScheme.primary,
    };
  }
}

class _ButtonMetrics {
  const _ButtonMetrics({required this.height, required this.padding});

  final double height;
  final EdgeInsetsGeometry padding;

  static _ButtonMetrics forSize(CPButtonSize size) {
    return switch (size) {
      CPButtonSize.small => const _ButtonMetrics(
        height: 44,
        padding: EdgeInsetsDirectional.symmetric(horizontal: 12),
      ),
      CPButtonSize.medium => const _ButtonMetrics(
        height: 48,
        padding: EdgeInsetsDirectional.symmetric(horizontal: 16),
      ),
      CPButtonSize.large => const _ButtonMetrics(
        height: 52,
        padding: EdgeInsetsDirectional.symmetric(horizontal: 20),
      ),
    };
  }
}
