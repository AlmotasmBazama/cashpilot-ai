import 'package:flutter/material.dart';

import '../tokens/cp_durations.dart';
import '../tokens/cp_radius.dart';

enum CPFloatingActionButtonVariant { primary, small, extended }

class CPFloatingActionButton extends StatelessWidget {
  const CPFloatingActionButton({
    required this.onPressed,
    this.variant = CPFloatingActionButtonVariant.primary,
    this.icon = Icons.add,
    this.label,
    this.tooltip,
    super.key,
  });

  final VoidCallback? onPressed;
  final CPFloatingActionButtonVariant variant;
  final IconData icon;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final button = switch (variant) {
      CPFloatingActionButtonVariant.small => FloatingActionButton.small(
        heroTag: null,
        onPressed: onPressed,
        tooltip: tooltip,
        child: Icon(icon),
      ),
      CPFloatingActionButtonVariant.extended => FloatingActionButton.extended(
        heroTag: null,
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon),
        label: Text(label ?? ''),
      ),
      CPFloatingActionButtonVariant.primary => FloatingActionButton(
        heroTag: null,
        onPressed: onPressed,
        tooltip: tooltip,
        child: Icon(icon),
      ),
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: CPDurations.slow,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.translate(
          offset: Offset(0, (1 - scale) * 18),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CPRadius.full),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.28),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: button,
      ),
    );
  }
}
