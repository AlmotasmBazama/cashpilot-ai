import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../application/providers/auth_providers.dart';
import '../widgets/auth_screen_scaffold.dart';

class EmailVerificationScreen extends ConsumerWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentAuthUserProvider);
    final state = ref.watch(authControllerProvider);
    final isLoading = state.isLoading;

    return AuthScreenScaffold(
      title: l10n.verifyEmailTitle,
      subtitle: l10n.verifyEmailSubtitle,
      child: AuthLoadingOverlay(
        visible: isLoading,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: CPSpacing.lg),
            Text(
              user?.email ?? l10n.email,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: CPSpacing.md),
            Text(
              l10n.verifyEmailMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_errorMessage(state, l10n.dashboardErrorMessage)
                case final message?) ...[
              const SizedBox(height: CPSpacing.lg),
              AuthErrorBanner(message: message),
            ],
            const SizedBox(height: CPSpacing.xl),
            CPButton(
              label: l10n.resendEmail,
              icon: Icons.mail_outline_rounded,
              fullWidth: true,
              isLoading: isLoading,
              onPressed: isLoading
                  ? null
                  : () async {
                      final ok = await ref
                          .read(authControllerProvider.notifier)
                          .sendEmailVerification();
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.verificationEmailSent)),
                        );
                      }
                    },
            ),
            const SizedBox(height: CPSpacing.md),
            CPButton(
              label: l10n.refreshStatus,
              icon: Icons.refresh_rounded,
              variant: CPButtonVariant.tonal,
              fullWidth: true,
              isLoading: isLoading,
              onPressed: isLoading
                  ? null
                  : () async {
                      await ref
                          .read(authControllerProvider.notifier)
                          .refreshUser();
                      if (context.mounted &&
                          ref.read(currentAuthUserProvider)?.emailVerified ==
                              true) {
                        context.go(AppRoutePaths.dashboard);
                      }
                    },
            ),
            const SizedBox(height: CPSpacing.md),
            CPButton(
              label: l10n.logout,
              variant: CPButtonVariant.ghost,
              fullWidth: true,
              onPressed: isLoading
                  ? null
                  : () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                      if (context.mounted) {
                        context.go(AppRoutePaths.login);
                      }
                    },
            ),
          ],
        ),
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
