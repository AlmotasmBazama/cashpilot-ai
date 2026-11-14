import 'package:flutter/material.dart';

import '../tokens/cp_radius.dart';
import '../tokens/cp_spacing.dart';

class CPEmptyState extends StatelessWidget {
  const CPEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: CPSpacing.xl,
                  vertical: CPSpacing.xxl,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow.withValues(
                      alpha: colorScheme.brightness == Brightness.dark
                          ? 0.56
                          : 0,
                    ),
                    borderRadius: BorderRadius.circular(CPRadius.sm),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(
                        alpha: colorScheme.brightness == Brightness.dark
                            ? 0.32
                            : 0,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(CPSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _EmptyIllustration(
                          icon: icon,
                          color: iconColor ?? colorScheme.primary,
                        ),
                        const SizedBox(height: CPSpacing.lg),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: CPSpacing.sm),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.38,
                              ),
                        ),
                        if (action != null) ...[
                          const SizedBox(height: CPSpacing.xl),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: action!,
                          ),
                        ],
                      ],
                    ),
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

class _EmptyIllustration extends StatelessWidget {
  const _EmptyIllustration({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 164,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            bottom: 10,
            child: Container(
              width: 136,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(CPRadius.sm),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
            ),
          ),
          PositionedDirectional(
            top: 8,
            end: 12,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(CPRadius.sm),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: color.withValues(alpha: 0.88),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 24,
            start: 8,
            child: Container(
              width: 34,
              height: 12,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(CPRadius.full),
              ),
            ),
          ),
          PositionedDirectional(
            top: 32,
            start: 22,
            child: Container(
              width: 58,
              height: 12,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(CPRadius.full),
              ),
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(CPRadius.sm),
              border: Border.all(color: color.withValues(alpha: 0.24)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(icon, size: 36, color: color),
          ),
        ],
      ),
    );
  }
}
