import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/domain/currency/localized_decimal_parser.dart';
import '../../../exchange_rates/application/base_currency_provider.dart';
import '../../application/providers/accounts_providers.dart';
import '../../domain/entities/account.dart';
import '../../domain/enums/account_type.dart';
import '../support/account_visuals.dart';
import 'account_form_fields.dart';

class AddAccountBottomSheet extends ConsumerStatefulWidget {
  const AddAccountBottomSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const AddAccountBottomSheet(),
    );
  }

  @override
  ConsumerState<AddAccountBottomSheet> createState() =>
      _AddAccountBottomSheetState();
}

class _AddAccountBottomSheetState extends ConsumerState<AddAccountBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _currencyController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  AccountType _type = AccountType.cash;
  String _iconKey = AccountVisuals.defaultIconKey(AccountType.cash);
  int _color = AccountVisuals.colors.first;
  List<String> _paymentMethodIds = const <String>[];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currencyController.text = ref.read(effectiveBaseCurrencyCodeProvider);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _balanceController.dispose();
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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CPSectionTitle(title: l10n.addAccount, padding: EdgeInsets.zero),
              const SizedBox(height: CPSpacing.lg),
              CPTextField(
                controller: _nameController,
                labelText: l10n.accountName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: CPSpacing.md),
              AccountTypeField(
                value: _type,
                onChanged: (type) {
                  setState(() {
                    _type = type;
                    _iconKey = AccountVisuals.defaultIconKey(type);
                  });
                },
              ),
              const SizedBox(height: CPSpacing.md),
              CPTextField(
                controller: _currencyController,
                labelText: l10n.currencyCode,
                textInputAction: TextInputAction.next,
                inputFormatters: currencyFormatters,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: CPSpacing.md),
              CPAmountField(
                controller: _balanceController,
                labelText: l10n.openingBalance,
                currencyCode: _currencyController.text,
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
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final currencyCode = _currencyController.text.trim().toUpperCase();
    final balance = LocalizedDecimalParser.tryParse(_balanceController.text);

    if (name.isEmpty) {
      _showMessage(l10n.accountNameRequired);
      return;
    }

    if (currencyCode.length != 3) {
      _showMessage(l10n.invalidCurrencyCode);
      return;
    }

    if (balance == null) {
      _showMessage(l10n.invalidAmount);
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref.read(createAccountUseCaseProvider)(
      Account.create(
        name: name,
        type: _type,
        currencyCode: currencyCode,
        balance: balance,
        icon: _iconKey,
        color: _color,
        paymentMethodIds: _paymentMethodIds,
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
