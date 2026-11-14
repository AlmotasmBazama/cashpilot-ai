import 'package:flutter/material.dart';

import '../tokens/cp_durations.dart';
import '../tokens/cp_radius.dart';
import '../tokens/cp_spacing.dart';

class CPNavigationItem {
  const CPNavigationItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.tooltip,
    this.semanticsIdentifier,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String? tooltip;
  final String? semanticsIdentifier;
}

class CPBottomNavigation extends StatelessWidget {
  const CPBottomNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final List<CPNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    final effectiveIndex = selectedIndex.clamp(0, items.length - 1);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        CPSpacing.xs,
        0,
        CPSpacing.xs,
        CPSpacing.xxs,
      ),
      child: Material(
        elevation: 0,
        shadowColor: Colors.transparent,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(CPRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(
              alpha: dark ? 0.88 : 0.96,
            ),
            gradient: dark
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.94,
                      ),
                      colorScheme.surfaceContainerLow.withValues(alpha: 0.96),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(CPRadius.lg),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: dark ? 0.72 : 0.62,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: dark ? 0.30 : 0.10),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Semantics(
            container: true,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: CPSpacing.xxs,
                vertical: CPSpacing.xxs,
              ),
              child: Row(
                children: [
                  for (var index = 0; index < items.length; index++)
                    Expanded(
                      child: _BottomNavigationItem(
                        item: items[index],
                        selected: index == effectiveIndex,
                        onTap: () => onDestinationSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final CPNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: foreground,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
    );

    return Tooltip(
      message: item.tooltip ?? item.label,
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        identifier: item.semanticsIdentifier,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CPRadius.md),
          child: AnimatedContainer(
            duration: CPDurations.normal,
            curve: Curves.easeOutCubic,
            height: 58,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: CPSpacing.xs,
              vertical: CPSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.72)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(CPRadius.md),
              border: selected
                  ? Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.40),
                    )
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedPositionedDirectional(
                  duration: CPDurations.normal,
                  curve: Curves.easeOutCubic,
                  top: selected ? 2 : -8,
                  start: 0,
                  end: 0,
                  child: Center(
                    child: AnimatedContainer(
                      duration: CPDurations.normal,
                      width: selected ? 24 : 8,
                      height: 3,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(CPRadius.full),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      duration: CPDurations.fast,
                      scale: selected ? 1.08 : 1,
                      child: Icon(
                        selected ? item.selectedIcon ?? item.icon : item.icon,
                        size: 21,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: CPSpacing.xxs),
                    SizedBox(
                      height: 14,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(item.label, maxLines: 1, style: labelStyle),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
