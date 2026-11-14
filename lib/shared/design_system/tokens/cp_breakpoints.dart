import '../../../core/responsive/app_breakpoints.dart';

enum CPWindowSizeClass { compact, medium, expanded }

abstract final class CPBreakpoints {
  static const compactMaxWidth = AppBreakpoints.compactMaxWidth;
  static const mediumMaxWidth = AppBreakpoints.mediumMaxWidth;
  static const contentMaxWidth = AppBreakpoints.contentMaxWidth;
}

CPWindowSizeClass cpWindowSizeClassForWidth(double width) {
  return switch (windowSizeClassForWidth(width)) {
    WindowSizeClass.compact => CPWindowSizeClass.compact,
    WindowSizeClass.medium => CPWindowSizeClass.medium,
    WindowSizeClass.expanded => CPWindowSizeClass.expanded,
  };
}
