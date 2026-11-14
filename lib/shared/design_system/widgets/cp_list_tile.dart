import 'package:flutter/material.dart';

import '../tokens/cp_radius.dart';
import '../tokens/cp_spacing.dart';

class CPListTile extends StatelessWidget {
  const CPListTile({
    required this.title,
    this.subtitle,
    this.supportingText,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.padding,
    this.semanticsIdentifier,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? supportingText;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final EdgeInsetsGeometry? padding;
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    final titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
    );

    final listTile = ListTile(
      minLeadingWidth: 40,
      enabled: enabled,
      selected: selected,
      onTap: enabled ? onTap : null,
      leading: leading,
      trailing: trailing,
      title: titleWidget,
      subtitle: _SubtitleText(
        subtitle: subtitle,
        supportingText: supportingText,
      ),
      contentPadding:
          padding ??
          const EdgeInsetsDirectional.symmetric(
            horizontal: CPSpacing.md,
            vertical: CPSpacing.xxs,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CPRadius.md),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.72)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(CPRadius.md),
        border: selected
            ? Border.all(color: colorScheme.primary.withValues(alpha: 0.28))
            : dark
            ? Border.all(color: Colors.white.withValues(alpha: 0.02))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(CPRadius.md),
        child: semanticsIdentifier == null
            ? listTile
            : Semantics(
                container: true,
                identifier: semanticsIdentifier,
                enabled: enabled,
                button: onTap != null,
                onTap: enabled ? onTap : null,
                child: listTile,
              ),
      ),
    );
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText({required this.subtitle, required this.supportingText});

  final String? subtitle;
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    if (subtitle == null && supportingText == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subtitle != null)
          Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (supportingText != null)
          Text(
            supportingText!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}
