import 'package:flutter/material.dart';

import '../tokens/cp_breakpoints.dart';
import '../tokens/cp_gradients.dart';
import '../tokens/cp_spacing.dart';

class CPAdaptivePage extends StatelessWidget {
  const CPAdaptivePage({
    required this.child,
    this.maxWidth = CPBreakpoints.contentMaxWidth,
    this.padding = CPSpacing.page,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final colorScheme = Theme.of(context).colorScheme;
    final usesDefaultPadding = padding == CPSpacing.page;
    final effectivePadding = usesDefaultPadding
        ? switch (cpWindowSizeClassForWidth(width)) {
            CPWindowSizeClass.compact => CPSpacing.page,
            CPWindowSizeClass.medium => const EdgeInsetsDirectional.all(
              CPSpacing.xl,
            ),
            CPWindowSizeClass.expanded => const EdgeInsetsDirectional.fromSTEB(
              CPSpacing.xxl,
              CPSpacing.xl,
              CPSpacing.xxl,
              CPSpacing.xxl,
            ),
          }
        : padding;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: colorScheme.brightness == Brightness.dark
            ? CPGradients.page(colorScheme)
            : null,
        color: colorScheme.surfaceContainerLowest,
      ),
      child: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(padding: effectivePadding, child: child),
          ),
        ),
      ),
    );
  }
}
