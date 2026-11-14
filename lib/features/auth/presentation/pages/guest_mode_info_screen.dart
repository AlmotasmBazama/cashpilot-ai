import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../application/providers/auth_providers.dart';
import '../widgets/auth_screen_scaffold.dart';

class GuestModeInfoScreen extends ConsumerWidget {
  const GuestModeInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(authControllerProvider);
    final isLoading = state.isLoading;

    return AuthScreenScaffold(
      title: l10n.guestModeTitle,
      subtitle: l10n.guestModeSubtitle,
      child: AuthLoadingOverlay(
        visible: isLoading,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GuestModeRow(
              icon: Icons.lock_clock_outlined,
              title: l10n.guestModeLocalTitle,
              message: l10n.guestModeLocalMessage,
            ),
            const SizedBox(height: CPSpacing.md),
            _GuestModeRow(
              icon: Icons.cloud_off_outlined,
              title: l10n.guestModeSyncTitle,
              message: l10n.guestModeSyncMessage,
            ),
            const SizedBox(height: CPSpacing.md),
            _GuestModeRow(
              icon: Icons.upgrade_outlined,
              title: l10n.guestModeUpgradeTitle,
              message: l10n.guestModeUpgradeMessage,
            ),
            if (_errorMessage(state, l10n.dashboardErrorMessage)
                case final message?) ...[
              const SizedBox(height: CPSpacing.lg),
              AuthErrorBanner(message: message),
            ],
            const SizedBox(height: CPSpacing.xl),
            CPButton(
              label: l10n.continueAsGuest,
              icon: Icons.visibility_outlined,
              size: CPButtonSize.large,
              fullWidth: true,
              isLoading: isLoading,
              onPressed: isLoading
                  ? null
                  : () async {
                      final ok = await ref
                          .read(authControllerProvider.notifier)
                          .signInAnonymously();
                      if (ok && context.mounted) {
                        context.go(AppRoutePaths.dashboard);
                      }
                    },
            ),
            const SizedBox(height: CPSpacing.md),
            CPButton(
              label: l10n.backToLogin,
              variant: CPButtonVariant.ghost,
              fullWidth: true,
              onPressed: isLoading
                  ? null
                  : () {
                      ref.invalidate(authControllerProvider);
                      context.go(AppRoutePaths.login);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestModeRow extends StatelessWidget {
  const _GuestModeRow({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsetsDirectional.all(CPSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CPRadius.md),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: CPSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: CPSpacing.xs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _errorMessage(AsyncValue<void> state, String fallbackMessage) {
  final error = state.error;
  if (error is Failure) {
    return error.message;
  }

  return error == null ? null : fallbackMessage;
}
