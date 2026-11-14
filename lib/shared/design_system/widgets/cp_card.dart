import 'package:flutter/material.dart';

import '../tokens/cp_elevation.dart';
import '../tokens/cp_radius.dart';
import '../tokens/cp_spacing.dart';

enum CPCardVariant { standard, elevated, outlined, interactive }

class CPCard extends StatelessWidget {
  const CPCard({
    required this.child,
    this.variant = CPCardVariant.standard,
    this.onTap,
    this.padding = CPSpacing.card,
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    this.accentColor,
    super.key,
  });

  final Widget child;
  final CPCardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(CPRadius.lg);
    final isInteractive = onTap != null || variant == CPCardVariant.interactive;
    final content = _CardContent(
      accentColor: accentColor,
      padding: padding,
      child: child,
    );
    final sideColor =
        accentColor?.withValues(alpha: dark ? 0.44 : 0.36) ??
        colorScheme.outlineVariant.withValues(alpha: dark ? 0.76 : 0.70);
    final elevation = switch (variant) {
      CPCardVariant.elevated => CPElevation.level3,
      CPCardVariant.interactive => CPElevation.level1,
      _ => CPElevation.level0,
    };
    final fill =
        backgroundColor ??
        switch (variant) {
          CPCardVariant.elevated => colorScheme.surfaceContainerHighest,
          CPCardVariant.outlined => colorScheme.surfaceContainerHigh,
          _ => colorScheme.surfaceContainerHigh,
        };
    final shadows = <BoxShadow>[
      if (variant == CPCardVariant.elevated)
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: dark ? 0.24 : 0.07),
          blurRadius: dark ? 18 : 14,
          offset: const Offset(0, 8),
        ),
      if (variant == CPCardVariant.interactive)
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: dark ? 0.14 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
    ];

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(
          color: variant == CPCardVariant.elevated
              ? colorScheme.outlineVariant.withValues(alpha: dark ? 0.64 : 0.44)
              : sideColor,
        ),
        boxShadow: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        elevation: elevation,
        borderRadius: radius,
        child: isInteractive
            ? InkWell(
                onTap: onTap,
                borderRadius: radius,
                hoverColor: colorScheme.primary.withValues(alpha: 0.05),
                splashColor: colorScheme.primary.withValues(alpha: 0.10),
                child: content,
              )
            : content,
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.child,
    required this.padding,
    required this.accentColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(padding: padding, child: child),
        if (accentColor != null)
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: Container(
              height: 3,
              color: accentColor!.withValues(alpha: 0.72),
            ),
          ),
      ],
    );
  }
}
