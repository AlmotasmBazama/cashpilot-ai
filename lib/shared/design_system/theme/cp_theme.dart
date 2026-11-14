import 'package:flutter/material.dart';

import '../tokens/cp_colors.dart';
import '../tokens/cp_elevation.dart';
import '../tokens/cp_radius.dart';
import '../tokens/cp_spacing.dart';
import '../tokens/cp_typography.dart';
import 'cp_semantic_colors.dart';

abstract final class CPTheme {
  static ThemeData light() {
    return _buildTheme(
      colorScheme: _lightScheme,
      semanticColors: CPSemanticColors.light(),
    );
  }

  static ThemeData dark() {
    return _buildTheme(
      colorScheme: _darkScheme,
      semanticColors: CPSemanticColors.dark(),
    );
  }

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: CPColors.brandSeed,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE8E5FF),
    onPrimaryContainer: Color(0xFF2E256F),
    secondary: CPColors.ai,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFEDE9FE),
    onSecondaryContainer: Color(0xFF4C1D95),
    tertiary: CPColors.success,
    onTertiary: Color(0xFF052E16),
    tertiaryContainer: Color(0xFFDCFCE7),
    onTertiaryContainer: Color(0xFF14532D),
    error: CPColors.expense,
    onError: Colors.white,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: CPColors.lightSurface,
    onSurface: CPColors.lightText,
    surfaceDim: CPColors.lightSecondaryBackground,
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: CPColors.lightBackground,
    surfaceContainerLow: CPColors.lightSurface,
    surfaceContainer: CPColors.lightSecondaryBackground,
    surfaceContainerHigh: CPColors.lightSurface,
    surfaceContainerHighest: Color(0xFFECEEF5),
    onSurfaceVariant: CPColors.lightSecondaryText,
    outline: CPColors.lightMutedText,
    outlineVariant: CPColors.lightBorder,
    shadow: Color(0xFF0F172A),
    scrim: Colors.black,
    inverseSurface: CPColors.background,
    onInverseSurface: CPColors.darkText,
    inversePrimary: Color(0xFFC7D2FE),
    surfaceTint: CPColors.brandSeed,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: CPColors.brandAccent,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF312E81),
    onPrimaryContainer: Color(0xFFE0E7FF),
    secondary: CPColors.ai,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF2A1B4A),
    onSecondaryContainer: Color(0xFFDDD6FE),
    tertiary: CPColors.success,
    onTertiary: Color(0xFF052E16),
    tertiaryContainer: Color(0xFF123C24),
    onTertiaryContainer: Color(0xFFBBF7D0),
    error: CPColors.expense,
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF4B1D25),
    onErrorContainer: Color(0xFFFECACA),
    surface: CPColors.surface,
    onSurface: CPColors.darkText,
    surfaceDim: CPColors.background,
    surfaceBright: CPColors.elevatedCard,
    surfaceContainerLowest: CPColors.background,
    surfaceContainerLow: CPColors.secondaryBackground,
    surfaceContainer: CPColors.surface,
    surfaceContainerHigh: CPColors.surface,
    surfaceContainerHighest: CPColors.elevatedCard,
    onSurfaceVariant: CPColors.darkSecondaryText,
    outline: CPColors.darkMutedText,
    outlineVariant: CPColors.softBorder,
    shadow: Color(0xFF000000),
    scrim: Colors.black,
    inverseSurface: CPColors.darkText,
    onInverseSurface: CPColors.background,
    inversePrimary: CPColors.brandSeed,
    surfaceTint: CPColors.brandAccent,
  );

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required CPSemanticColors semanticColors,
  }) {
    final textTheme = CPTypography.textTheme(colorScheme);
    final controlRadius = BorderRadius.circular(CPRadius.md);
    final cardRadius = BorderRadius.circular(CPRadius.lg);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      visualDensity: VisualDensity.standard,
      extensions: [semanticColors],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surfaceContainerLowest.withValues(
          alpha: colorScheme.brightness == Brightness.dark ? 0.92 : 1,
        ),
        foregroundColor: colorScheme.onSurface,
        elevation: CPElevation.level0,
        scrolledUnderElevation: CPElevation.level1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.76),
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: CPElevation.level0,
        color: colorScheme.surfaceContainerHigh,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh.withValues(
          alpha: colorScheme.brightness == Brightness.dark ? 0.68 : 1,
        ),
        contentPadding: CPSpacing.field,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        border: OutlineInputBorder(borderRadius: controlRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.82),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          elevation: CPElevation.level0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: CPElevation.level1,
          backgroundColor: colorScheme.surfaceContainerHigh,
          foregroundColor: colorScheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: CPElevation.level3,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primaryContainer.withValues(alpha: 0.78);
            }
            return colorScheme.surfaceContainerHigh.withValues(alpha: 0.70);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimaryContainer;
            }
            return colorScheme.onSurfaceVariant;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: controlRadius),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CPRadius.full),
        ),
        selectedColor: colorScheme.primaryContainer.withValues(alpha: 0.72),
        backgroundColor: colorScheme.surfaceContainerHigh.withValues(
          alpha: colorScheme.brightness == Brightness.dark ? 0.76 : 1,
        ),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CPRadius.xxl),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(CPRadius.xxl),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(CPRadius.full),
        ),
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: textTheme.labelMedium,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        selectedColor: colorScheme.primary,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: CPSpacing.md,
          vertical: CPSpacing.xxs,
        ),
      ),
    );
  }
}
