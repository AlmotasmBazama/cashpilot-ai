import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../features/auth/application/providers/auth_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentAuthUserProvider);
    final displayName = user?.displayName ?? l10n.profileGuestName;
    final subtitle = user?.isAnonymous == true
        ? l10n.guestAccount
        : user?.email ?? l10n.profileLocalAccount;

    return Scaffold(
      appBar: CPAppBar(title: l10n.profileTitle),
      body: FinanceScreenBody(
        child: ListView(
          children: [
            CPCard(
              variant: CPCardVariant.elevated,
              backgroundColor: CPColors.brandPanel,
              accentColor: Theme.of(context).colorScheme.primary,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: CPSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: CPSpacing.xs),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CPSpacing.xl),
            if (user?.isAnonymous == true)
              FinanceInfoCard(
                title: l10n.guestModeTitle,
                message: l10n.guestModeSyncMessage,
                icon: Icons.visibility_outlined,
                color: context.cpColors.info,
              )
            else if (user?.emailVerified == false)
              FinanceInfoCard(
                title: l10n.verifyEmailTitle,
                message: l10n.verifyEmailMessage,
                icon: Icons.mark_email_unread_outlined,
                color: context.cpColors.warning,
              )
            else
              FinanceInfoCard(
                title: l10n.verifiedAccount,
                message: l10n.verifiedAccountMessage,
                icon: Icons.verified_user_outlined,
                color: context.cpColors.income,
              ),
            const SizedBox(height: CPSpacing.xl),
            CPCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  CPListTile(
                    title: l10n.profileCompletionTitle,
                    subtitle: l10n.profileCompletionSettingsSubtitle,
                    leading: const Icon(Icons.manage_accounts_outlined),
                    onTap: () => context.go(AppRoutePaths.profileCompletion),
                  ),
                  CPListTile(
                    title: l10n.security,
                    subtitle: user?.emailVerified == true
                        ? l10n.verifiedAccount
                        : l10n.securityPendingMessage,
                    leading: const Icon(Icons.shield_outlined),
                  ),
                  CPListTile(
                    title: l10n.backup,
                    subtitle: user?.isAnonymous == true
                        ? l10n.guestModeSyncMessage
                        : l10n.backupPendingMessage,
                    leading: const Icon(Icons.cloud_upload_outlined),
                  ),
                  CPListTile(
                    title: l10n.about,
                    subtitle: l10n.aboutMessage,
                    leading: const Icon(Icons.info_outline_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
