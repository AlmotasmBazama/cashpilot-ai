import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.compact,
    this.medium,
    this.expanded,
    super.key,
  });

  final Widget compact;
  final Widget? medium;
  final Widget? expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return switch (windowSizeClassForWidth(constraints.maxWidth)) {
          WindowSizeClass.compact => compact,
          WindowSizeClass.medium => medium ?? compact,
          WindowSizeClass.expanded => expanded ?? medium ?? compact,
        };
      },
    );
  }
}
