import 'package:flutter/widgets.dart';

enum WindowSizeClass { compact, medium, expanded }

abstract final class AppBreakpoints {
  static const compactMaxWidth = 599.0;
  static const mediumMaxWidth = 839.0;
  static const contentMaxWidth = 1120.0;
}

WindowSizeClass windowSizeClassForWidth(double width) {
  if (width <= AppBreakpoints.compactMaxWidth) {
    return WindowSizeClass.compact;
  }

  if (width <= AppBreakpoints.mediumMaxWidth) {
    return WindowSizeClass.medium;
  }

  return WindowSizeClass.expanded;
}

extension ResponsiveBuildContext on BuildContext {
  WindowSizeClass get windowSizeClass {
    return windowSizeClassForWidth(MediaQuery.sizeOf(this).width);
  }
}
