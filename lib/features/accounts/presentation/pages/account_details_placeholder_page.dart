import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../application/providers/accounts_providers.dart';
import '../../domain/entities/account.dart';

class AccountDetailsPlaceholderPage extends ConsumerWidget {
  const AccountDetailsPlaceholderPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accountState = ref.watch(accountByIdProvider(accountId));

    return Scaffold(
      appBar: CPAppBar(title: l10n.accountDetailsTitle),
      body: accountState.when(
        data: (result) {
          switch (result) {
            case AppSuccess<Account?>(:final data):
              return CPEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: data?.name ?? l10n.accountDetailsTitle,
                message: l10n.accountDetailsPlaceholder,
              );
            case AppFailure<Account?>():
              return CPErrorView(
                title: l10n.accountsErrorTitle,
                message: l10n.accountsErrorMessage,
              );
          }
        },
        error: (_, _) => CPErrorView(
          title: l10n.accountsErrorTitle,
          message: l10n.accountsErrorMessage,
        ),
        loading: () => const CPLoadingIndicator(),
      ),
    );
  }
}
