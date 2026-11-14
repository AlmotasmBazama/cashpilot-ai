import 'package:flutter/material.dart';

import '../tokens/cp_durations.dart';
import '../tokens/cp_radius.dart';
import '../tokens/cp_spacing.dart';
import 'cp_brand_mark.dart';

enum CPLoadingIndicatorSize { small, medium, large }

class CPLoadingIndicator extends StatefulWidget {
  const CPLoadingIndicator({
    this.label,
    this.size = CPLoadingIndicatorSize.medium,
    this.centered = true,
    super.key,
  });

  final String? label;
  final CPLoadingIndicatorSize size;
  final bool centered;

  @override
  State<CPLoadingIndicator> createState() => _CPLoadingIndicatorState();
}

class _CPLoadingIndicatorState extends State<CPLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dimension = switch (widget.size) {
      CPLoadingIndicatorSize.small => 20.0,
      CPLoadingIndicatorSize.medium => 28.0,
      CPLoadingIndicatorSize.large => 40.0,
    };
    final colorScheme = Theme.of(context).colorScheme;
    final indicator = AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final scale = 0.92 + (_pulse.value * 0.08);
        final logoSize = dimension * 1.7;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: CPBrandMark(size: logoSize),
            ),
            const SizedBox(height: CPSpacing.lg),
            _SkeletonLines(progress: _pulse.value),
            if (widget.label != null) ...[
              const SizedBox(height: CPSpacing.md),
              Text(
                widget.label!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
      },
    );

    return widget.centered ? Center(child: indicator) : indicator;
  }
}

class _SkeletonLines extends StatelessWidget {
  const _SkeletonLines({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final active = Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: 0.16);

    return Column(
      children: [
        _SkeletonLine(width: 118, color: Color.lerp(color, active, progress)!),
        const SizedBox(height: CPSpacing.xs),
        _SkeletonLine(width: 84, color: Color.lerp(active, color, progress)!),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: CPDurations.normal,
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(CPRadius.full),
      ),
    );
  }
}
