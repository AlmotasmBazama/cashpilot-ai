import 'package:flutter/material.dart';

import '../../../core/responsive/app_breakpoints.dart';
import '../../design_system/design_system.dart';

class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    required this.child,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return CPAdaptivePage(maxWidth: maxWidth, child: child);
  }
}
