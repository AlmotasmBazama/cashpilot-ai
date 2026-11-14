import 'package:flutter/material.dart';

import '../tokens/cp_spacing.dart';

class CPSectionTitle extends StatelessWidget {
  const CPSectionTitle({
    required this.title,
    this.subtitle,
    this.action,
    this.padding = CPSpacing.section,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: CPSpacing.xxs),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.32,
                  ),
                ),
              ],
            ],
          );

          if (compact && action != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: CPSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: action,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: titleBlock),
              if (action != null) ...[
                const SizedBox(width: CPSpacing.md),
                Flexible(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: action,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
