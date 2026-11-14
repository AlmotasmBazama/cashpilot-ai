import 'package:flutter/material.dart';

abstract final class CPGradients {
  static LinearGradient page(ColorScheme colorScheme) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const <double>[0, 0.42, 1],
      colors: <Color>[
        colorScheme.surfaceContainerLowest,
        Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.025),
          colorScheme.surfaceContainerLow,
        ),
        colorScheme.surfaceContainerLowest,
      ],
    );
  }

  static LinearGradient premiumSurface(
    ColorScheme colorScheme, {
    Color? accent,
  }) {
    final resolvedAccent = accent ?? colorScheme.primary;
    return LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: <Color>[
        Color.alphaBlend(
          resolvedAccent.withValues(alpha: 0.08),
          colorScheme.surfaceContainerHigh,
        ),
        colorScheme.surfaceContainerLow,
      ],
    );
  }

  static LinearGradient accent(Color color) {
    return LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: <Color>[
        color.withValues(alpha: 0.92),
        color.withValues(alpha: 0.68),
      ],
    );
  }
}
