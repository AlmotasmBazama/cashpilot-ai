import 'package:flutter/material.dart';

import '../tokens/cp_spacing.dart';

class CPAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CPAppBar({
    required this.title,
    this.subtitle,
    this.actions,
    this.onBackPressed,
    this.automaticallyImplyLeading = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 64 : 88);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      toolbarHeight: preferredSize.height,
      flexibleSpace: colorScheme.brightness == Brightness.dark
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surfaceContainerLowest,
                    colorScheme.surfaceContainerLowest.withValues(alpha: 0.82),
                  ],
                ),
              ),
            )
          : null,
      automaticallyImplyLeading:
          onBackPressed == null && automaticallyImplyLeading,
      leading: onBackPressed == null
          ? null
          : IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBackPressed,
              icon: const BackButtonIcon(),
            ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: CPSpacing.xxs),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: actions,
    );
  }
}
