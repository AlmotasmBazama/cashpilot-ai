import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../application/providers/accounts_providers.dart';
import '../../domain/entities/account.dart';
import '../support/account_formatters.dart';
import 'account_form_fields.dart';

class EditAccountBottomSheet extends ConsumerStatefulWidget {
  const EditAccountBottomSheet({required this.account, super.key});

  final Account account;

  static Future<bool?> show(BuildContext context, Account account) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => EditAccountBottomSheet(account: account),
    );
  }

  @override
  ConsumerState<EditAccountBottomSheet> createState() =>
      _EditAccountBottomSheetState();
}

class _EditAccountBottomSheetState
    extends ConsumerState<EditAccountBottomSheet> {
  final _nameController = TextEditingController();
  final _currencyController = TextEditingController();
  late String _iconKey;
  late int _color;
  late List<String> _paymentMethodIds;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.account.name;
    _currencyController.text = widget.account.currencyCode;
    _iconKey = widget.account.icon;
    _color = widget.account.color;
    _paymentMethodIds = widget.account.paymentMethodIds;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: CPSpacing.lg,
        end: CPSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + CPSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CPSectionTitle(title: l10n.editAccount, padding: EdgeInsets.zero),
            const SizedBox(height: CPSpacing.lg),
            CPTextField(
              controller: _nameController,
              labelText: l10n.accountName,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            AccountTypeField(value: widget.account.type),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _currencyController,
              labelText: l10n.currencyCode,
              helperText: l10n.accountCurrencyLockedMessage,
              readOnly: true,
            ),
            const SizedBox(height: CPSpacing.md),
            CPAmountField(
              initialValue: AccountFormatters.amount(widget.account.balance),
              labelText: l10n.accountBalance,
              currencyCode: _currencyController.text,
              readOnly: true,
            ),
            const SizedBox(height: CPSpacing.md),
            AccountIconField(
              value: _iconKey,
              onChanged: (value) => setState(() => _iconKey = value),
            ),
            const SizedBox(height: CPSpacing.lg),
            AccountColorField(
              value: _color,
              onChanged: (value) => setState(() => _color = value),
            ),
            const SizedBox(height: CPSpacing.lg),
            AccountPaymentMethodsField(
              value: _paymentMethodIds,
              onChanged: (value) => setState(() => _paymentMethodIds = value),
            ),
            const SizedBox(height: CPSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: CPButton(
                    label: l10n.cancel,
                    variant: CPButtonVariant.ghost,
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: CPSpacing.sm),
                Expanded(
                  child: CPButton(
                    label: l10n.save,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage(l10n.accountNameRequired);
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref.read(updateAccountUseCaseProvider)(
      widget.account.copyWith(
        name: name,
        currencyCode: widget.account.currencyCode,
        icon: _iconKey,
        color: _color,
        paymentMethodIds: _paymentMethodIds,
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);
    switch (result) {
      case AppSuccess<Account>():
        ref.invalidate(accountsProvider);
        Navigator.of(context).pop(true);
      case AppFailure<Account>(:final failure):
        _showMessage(failure.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
