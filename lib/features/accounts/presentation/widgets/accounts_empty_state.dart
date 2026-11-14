import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';

class AccountsEmptyState extends StatelessWidget {
  const AccountsEmptyState({required this.onAddPressed, super.key});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CPEmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: l10n.emptyAccountsTitle,
      message: l10n.emptyAccountsMessage,
      action: CPButton(
        label: l10n.addAccount,
        icon: Icons.add_rounded,
        onPressed: onAddPressed,
      ),
    );
  }
}
