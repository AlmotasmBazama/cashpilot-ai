import 'package:flutter/material.dart';

abstract final class CPTypography {
  static TextTheme textTheme(ColorScheme colorScheme) {
    final base = Typography.material2021().black;
    final color = colorScheme.onSurface;

    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontSize: 34,
            color: color,
            fontWeight: FontWeight.w800,
            height: 1.08,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontSize: 32,
            color: color,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
          displaySmall: base.displaySmall?.copyWith(
            fontSize: 30,
            color: color,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontSize: 28,
            color: color,
            fontWeight: FontWeight.w800,
            height: 1.14,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 26,
            color: color,
            fontWeight: FontWeight.w800,
            height: 1.16,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontSize: 22,
            color: color,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontSize: 20,
            color: color,
            fontWeight: FontWeight.w800,
            height: 1.22,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontSize: 17,
            color: color,
            fontWeight: FontWeight.w700,
            height: 1.26,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontSize: 15,
            color: color,
            fontWeight: FontWeight.w600,
            height: 1.28,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            fontSize: 16,
            color: color,
            height: 1.45,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontSize: 14,
            color: color,
            height: 1.42,
          ),
          bodySmall: base.bodySmall?.copyWith(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
            height: 1.38,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: base.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: color, displayColor: color);
  }
}
