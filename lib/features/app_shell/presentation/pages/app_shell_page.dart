import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/accessibility/acceptance_semantics.dart';
import '../../../../shared/design_system/design_system.dart';

class AppShellPage extends StatelessWidget {
  const AppShellPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = _destinations(l10n);
    final selectedIndex = _selectedIndexFor(
      GoRouterState.of(context).uri.path,
      destinations,
    );
    final width = MediaQuery.sizeOf(context).width;

    final Widget shell;
    if (width >= CPBreakpoints.contentMaxWidth) {
      shell = Scaffold(
        body: Row(
          children: [
            _DesktopSidebar(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: (index) => _go(context, destinations[index].path),
            ),
            Expanded(child: child),
          ],
        ),
      );
    } else if (width > CPBreakpoints.compactMaxWidth) {
      shell = Scaffold(
        body: Row(
          children: [
            _TabletNavigationRail(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: (index) => _go(context, destinations[index].path),
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.66),
            ),
            Expanded(child: child),
          ],
        ),
      );
    } else {
      final bottomDestinations = destinations;
      final bottomIndex = bottomDestinations.indexWhere(
        (destination) =>
            _matchesPath(GoRouterState.of(context).uri.path, destination.path),
      );

      shell = Scaffold(
        body: child,
        bottomNavigationBar: CPBottomNavigation(
          items: [
            for (final destination in bottomDestinations)
              CPNavigationItem(
                label: destination.label,
                icon: destination.icon,
                selectedIcon: destination.selectedIcon,
                semanticsIdentifier: destination.semanticsIdentifier,
              ),
          ],
          selectedIndex: bottomIndex < 0 ? 0 : bottomIndex,
          onDestinationSelected: (index) =>
              _go(context, bottomDestinations[index].path),
        ),
      );
    }

    return cashPilotForceStopAcceptanceSemantics(
      identifier: 'cashpilot_acceptance_authenticated_shell',
      child: shell,
    );
  }

  List<_ShellDestination> _destinations(AppLocalizations l10n) {
    return [
      _ShellDestination(
        label: l10n.navDashboard,
        path: AppRoutePaths.dashboard,
        icon: Icons.space_dashboard_outlined,
        selectedIcon: Icons.space_dashboard_rounded,
        semanticsIdentifier: cashPilotForceStopAcceptanceIdentifier(
          'cashpilot_acceptance_nav_dashboard',
        ),
      ),
      _ShellDestination(
        label: l10n.transactionsTitle,
        path: AppRoutePaths.transactions,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
      ),
      _ShellDestination(
        label: l10n.aiAssistantTitle,
        path: AppRoutePaths.aiAssistant,
        icon: Icons.auto_awesome_outlined,
        selectedIcon: Icons.auto_awesome_rounded,
      ),
      _ShellDestination(
        label: l10n.settingsTitle,
        path: AppRoutePaths.settings,
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune_rounded,
        semanticsIdentifier: cashPilotForceStopAcceptanceIdentifier(
          'cashpilot_acceptance_nav_settings',
        ),
      ),
    ];
  }

  int _selectedIndexFor(String path, List<_ShellDestination> destinations) {
    final index = destinations.indexWhere(
      (destination) => _matchesPath(path, destination.path),
    );
    return index < 0 ? 0 : index;
  }

  bool _matchesPath(String currentPath, String destinationPath) {
    return currentPath == destinationPath ||
        currentPath.startsWith('$destinationPath/');
  }

  void _go(BuildContext context, String path) {
    if (GoRouterState.of(context).uri.path != path) {
      context.go(path);
    }
  }
}

class _TabletNavigationRail extends StatelessWidget {
  const _TabletNavigationRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 112,
      decoration: BoxDecoration(
        gradient: colorScheme.brightness == Brightness.dark
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surfaceContainerLow,
                  colorScheme.surfaceContainerLowest,
                ],
              )
            : null,
        color: colorScheme.surfaceContainerLow,
      ),
      child: SafeArea(
        child: NavigationRail(
          minWidth: 112,
          backgroundColor: Colors.transparent,
          selectedIndex: selectedIndex,
          scrollable: true,
          groupAlignment: -0.82,
          onDestinationSelected: onSelected,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(bottom: CPSpacing.lg),
            child: CPBrandMark(size: 44),
          ),
          destinations: [
            for (final destination in destinations)
              NavigationRailDestination(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: CPSpacing.xxs,
                ),
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        gradient: colorScheme.brightness == Brightness.dark
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surfaceContainerLow,
                  colorScheme.surfaceContainerLowest,
                ],
              )
            : null,
        border: BorderDirectional(
          end: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(CPSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CPBrandMark(size: 48),
                  const SizedBox(width: CPSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CPSpacing.xl),
              Expanded(
                child: ListView.separated(
                  itemCount: destinations.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: CPSpacing.xs),
                  itemBuilder: (context, index) {
                    final destination = destinations[index];
                    final selected = index == selectedIndex;

                    return CPListTile(
                      title: destination.label,
                      selected: selected,
                      leading: Icon(
                        selected ? destination.selectedIcon : destination.icon,
                      ),
                      onTap: () => onSelected(index),
                    );
                  },
                ),
              ),
              CPCard(
                variant: CPCardVariant.elevated,
                accentColor: colorScheme.primary,
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: CPSpacing.md),
                    Expanded(
                      child: Text(
                        l10n.secureLocalFirst,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
    this.semanticsIdentifier,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String? semanticsIdentifier;
}
