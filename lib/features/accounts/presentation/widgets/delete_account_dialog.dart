import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../application/providers/accounts_providers.dart';
import '../../domain/entities/account.dart';

class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({required this.account, super.key});

  final Account account;

  static Future<bool?> show(BuildContext context, Account account) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DeleteAccountDialog(account: account),
    );
  }

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      child: CPCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.deleteAccountTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: CPSpacing.sm),
            Text('${l10n.deleteAccountMessage}\n${widget.account.name}'),
            const SizedBox(height: CPSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CPButton(
                  label: l10n.cancel,
                  variant: CPButtonVariant.ghost,
                  onPressed: _isDeleting
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: CPSpacing.sm),
                CPButton(
                  label: l10n.delete,
                  variant: CPButtonVariant.danger,
                  isLoading: _isDeleting,
                  onPressed: _delete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    setState(() => _isDeleting = true);
    final result = await ref.read(deleteAccountUseCaseProvider)(
      widget.account.id,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isDeleting = false);
    switch (result) {
      case AppSuccess<void>():
        ref.invalidate(accountsProvider);
        Navigator.of(context).pop(true);
      case AppFailure<void>(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}
