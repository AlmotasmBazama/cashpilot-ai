import 'package:flutter/material.dart';

import '../theme/cp_semantic_colors.dart';
import '../tokens/cp_radius.dart';

class CPBrandMark extends StatelessWidget {
  const CPBrandMark({
    this.size = 56,
    this.ai = false,
    this.semanticLabel,
    super.key,
  });

  final double size;
  final bool ai;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cpColors = context.cpColors;
    final accent = ai ? cpColors.ai : colorScheme.primary;
    final secondary = ai ? colorScheme.primary : cpColors.ai;

    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CPRadius.sm),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent,
            Color.alphaBlend(
              secondary.withValues(alpha: 0.72),
              colorScheme.surfaceContainerHighest,
            ),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: size * 0.42,
            offset: Offset(0, size * 0.18),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            top: size * 0.14,
            start: size * 0.15,
            child: _SignalLine(width: size * 0.30, color: Colors.white),
          ),
          PositionedDirectional(
            bottom: size * 0.18,
            end: size * 0.14,
            child: _SignalLine(width: size * 0.24, color: Colors.white),
          ),
          Icon(
            ai ? Icons.auto_awesome_rounded : Icons.stacked_line_chart_rounded,
            size: size * 0.46,
            color: Colors.white,
          ),
        ],
      ),
    );

    if (semanticLabel == null) {
      return ExcludeSemantics(child: mark);
    }

    return Semantics(label: semanticLabel, image: true, child: mark);
  }
}

class _SignalLine extends StatelessWidget {
  const _SignalLine({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 3,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(CPRadius.full),
      ),
    );
  }
}
