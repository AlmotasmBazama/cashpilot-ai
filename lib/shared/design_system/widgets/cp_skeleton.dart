import 'package:flutter/material.dart';

import '../tokens/cp_durations.dart';
import '../tokens/cp_radius.dart';
import '../tokens/cp_spacing.dart';

class CPSkeletonCard extends StatefulWidget {
  const CPSkeletonCard({this.height = 180, this.compact = false, super.key});

  final double height;
  final bool compact;

  @override
  State<CPSkeletonCard> createState() => _CPSkeletonCardState();
}

class _CPSkeletonCardState extends State<CPSkeletonCard>
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
        final base = colorScheme.surfaceContainerHigh;
        final highlight = Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.11),
          colorScheme.surfaceContainerHighest,
        );
        final boneColor = Color.lerp(base, highlight, _controller.value)!;
        final isShort = widget.height < 96;
        final isCompact = widget.compact || widget.height < 152;
        final padding = isShort ? CPSpacing.sm : CPSpacing.md;

        return Container(
          height: widget.height,
          padding: EdgeInsetsDirectional.all(
            isCompact ? padding : CPSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(CPRadius.lg),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.58),
            ),
          ),
          child: isShort
              ? _ShortSkeleton(height: widget.height, color: boneColor)
              : isCompact
              ? _CompactSkeleton(color: boneColor)
              : _FullSkeleton(color: boneColor),
        );
      },
    );
  }
}

class _ShortSkeleton extends StatelessWidget {
  const _ShortSkeleton({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final squareSize = (height - (CPSpacing.sm * 2)).clamp(20, 36).toDouble();

    return Row(
      children: [
        _SkeletonBone.square(size: squareSize, color: color),
        const SizedBox(width: CPSpacing.md),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBone(width: double.infinity, height: 7, color: color),
              const SizedBox(height: CPSpacing.xxs),
              FractionallySizedBox(
                widthFactor: 0.64,
                alignment: AlignmentDirectional.centerStart,
                child: _SkeletonBone(
                  width: double.infinity,
                  height: 6,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactSkeleton extends StatelessWidget {
  const _CompactSkeleton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _SkeletonBone.square(size: 36, color: color),
            const Spacer(),
            _SkeletonBone(width: 48, height: 14, color: color),
          ],
        ),
        const Spacer(),
        _SkeletonBone(width: 112, height: 9, color: color),
        const SizedBox(height: CPSpacing.xs),
        _SkeletonBone(width: 176, height: 17, color: color),
      ],
    );
  }
}

class _FullSkeleton extends StatelessWidget {
  const _FullSkeleton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _SkeletonBone.square(size: 46, color: color),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _SkeletonBone(width: 56, height: 18, color: color),
              ),
            ),
          ],
        ),
        const Spacer(),
        _SkeletonBone(width: 126, height: 12, color: color),
        const SizedBox(height: CPSpacing.xs),
        _SkeletonBone(width: 210, height: 24, color: color),
        const SizedBox(height: CPSpacing.xs),
        _SkeletonBone(width: 88, height: 10, color: color),
      ],
    );
  }
}

class _SkeletonBone extends StatelessWidget {
  const _SkeletonBone({
    required this.width,
    required this.height,
    required this.color,
  });

  const _SkeletonBone.square({required double size, required this.color})
    : width = size,
      height = size;

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: CPDurations.normal,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(CPRadius.sm),
      ),
    );
  }
}
