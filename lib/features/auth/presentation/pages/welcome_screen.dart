import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/accessibility/acceptance_semantics.dart';
import '../../../../shared/design_system/design_system.dart';
import '../widgets/auth_screen_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthScreenScaffold(
      title: l10n.authWelcomeTitle,
      subtitle: l10n.authWelcomeSubtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CPButton(
            label: l10n.login,
            semanticsIdentifier: cashPilotForceStopAcceptanceIdentifier(
              'cashpilot_acceptance_welcome_login',
            ),
            icon: Icons.login_rounded,
            size: CPButtonSize.large,
            fullWidth: true,
            onPressed: () => context.go(AppRoutePaths.login),
          ),
          const SizedBox(height: CPSpacing.md),
          CPButton(
            label: l10n.createAccount,
            icon: Icons.person_add_alt_rounded,
            variant: CPButtonVariant.tonal,
            size: CPButtonSize.large,
            fullWidth: true,
            onPressed: () => context.go(AppRoutePaths.register),
          ),
          const SizedBox(height: CPSpacing.md),
          CPButton(
            label: l10n.continueAsGuest,
            icon: Icons.visibility_outlined,
            variant: CPButtonVariant.outline,
            size: CPButtonSize.large,
            fullWidth: true,
            onPressed: () => context.go(AppRoutePaths.guestInfo),
          ),
          const SizedBox(height: CPSpacing.xl),
          const AuthTermsText(),
        ],
      ),
    );
  }
}
