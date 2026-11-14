import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';

class AccountsErrorState extends StatelessWidget {
  const AccountsErrorState({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CPErrorView(
      title: l10n.accountsErrorTitle,
      message: l10n.accountsErrorMessage,
      action: CPButton(
        label: l10n.retry,
        variant: CPButtonVariant.outline,
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
    );
  }
}
