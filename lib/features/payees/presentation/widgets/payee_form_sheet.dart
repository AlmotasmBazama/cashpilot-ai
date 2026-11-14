import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../application/providers/payees_providers.dart';
import '../../domain/entities/payee.dart';
import '../../domain/enums/payee_type.dart';
import '../../domain/failures/payee_failure_codes.dart';
import '../support/payee_type_labels.dart';

class PayeeFormSheet extends ConsumerStatefulWidget {
  const PayeeFormSheet({this.payee, super.key});

  final Payee? payee;

  static Future<bool?> show(BuildContext context, {Payee? payee}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => PayeeFormSheet(payee: payee),
    );
  }

  @override
  ConsumerState<PayeeFormSheet> createState() => _PayeeFormSheetState();
}

class _PayeeFormSheetState extends ConsumerState<PayeeFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _aliasesController;
  late final TextEditingController _notesController;
  late PayeeType _type;
  String? _defaultCategoryId;
  String? _defaultAccountId;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final payee = widget.payee;
    _nameController = TextEditingController(text: payee?.name);
    _aliasesController = TextEditingController(text: payee?.aliases.join(', '));
    _notesController = TextEditingController(text: payee?.notes);
    _type = payee?.type ?? PayeeType.other;
    _defaultCategoryId = payee?.defaultCategoryId;
    _defaultAccountId = payee?.defaultAccountId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accounts = _accounts(ref.watch(accountsProvider));
    final categories = _categories(ref.watch(categoriesProvider));
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: CPSpacing.lg,
        end: CPSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + CPSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CPSectionTitle(
              title: widget.payee == null ? l10n.addPayee : l10n.editPayee,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: CPSpacing.lg),
            CPTextField(
              controller: _nameController,
              labelText: l10n.payeeName,
              errorText: _errorText,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _aliasesController,
              labelText: l10n.payeeAliases,
              hintText: l10n.payeeAliasesHint,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            DropdownButtonFormField<PayeeType>(
              isExpanded: true,
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.payeeType),
              items: [
                for (final type in PayeeType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(PayeeTypeLabels.label(l10n, type)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: CPSpacing.md),
            _OptionalSelector(
              label: l10n.payeeDefaultCategory,
              value: _defaultCategoryId,
              noneLabel: l10n.noDefaultSelection,
              items: categories
                  .map((item) => (id: item.id, label: item.name))
                  .toList(growable: false),
              onChanged: (value) => setState(() => _defaultCategoryId = value),
            ),
            const SizedBox(height: CPSpacing.md),
            _OptionalSelector(
              label: l10n.payeeDefaultAccount,
              value: _defaultAccountId,
              noneLabel: l10n.noDefaultSelection,
              items: accounts
                  .where((account) => !account.isArchived)
                  .map((item) => (id: item.id, label: item.name))
                  .toList(growable: false),
              onChanged: (value) => setState(() => _defaultAccountId = value),
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _notesController,
              labelText: l10n.payeeNotes,
              maxLines: 3,
            ),
            const SizedBox(height: CPSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: CPButton(
                    label: l10n.cancel,
                    variant: CPButtonVariant.ghost,
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: CPSpacing.sm),
                Expanded(
                  child: CPButton(
                    label: l10n.save,
                    isLoading: _saving,
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
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorText = l10n.payeeNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    final existing = widget.payee;
    final aliases = _aliasesController.text
        .split(RegExp('[,\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final Payee payee;
    try {
      payee = Payee.create(
        id: existing?.id,
        name: _nameController.text,
        type: _type,
        aliases: aliases,
        defaultCategoryId: _defaultCategoryId,
        defaultAccountId: _defaultAccountId,
        notes: _notesController.text,
        lastUsedAt: existing?.lastUsedAt,
        createdAt: existing?.createdAt,
        archivedAt: existing?.archivedAt,
      );
    } on PayeeValidationException {
      setState(() {
        _saving = false;
        _errorText = l10n.aliasAlreadyExists;
      });
      return;
    }
    final result = existing == null
        ? await ref.read(createPayeeUseCaseProvider)(payee)
        : await ref.read(updatePayeeUseCaseProvider)(payee);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    switch (result) {
      case AppSuccess<Payee>():
        Navigator.of(context).pop(true);
      case AppFailure<Payee>(:final failure):
        setState(() {
          _errorText = switch (failure.code) {
            PayeeFailureCodes.duplicateName => l10n.payeeAlreadyExists,
            PayeeFailureCodes.duplicateAlias => l10n.aliasAlreadyExists,
            _ => failure.message,
          };
        });
    }
  }

  List<Account> _accounts(AsyncValue<AppResult<List<Account>>> value) {
    return switch (value.value) {
      AppSuccess<List<Account>>(:final data) => data,
      _ => const <Account>[],
    };
  }

  List<Category> _categories(AsyncValue<AppResult<List<Category>>> value) {
    return switch (value.value) {
      AppSuccess<List<Category>>(:final data) => data,
      _ => const <Category>[],
    };
  }
}

class _OptionalSelector extends StatelessWidget {
  const _OptionalSelector({
    required this.label,
    required this.value,
    required this.noneLabel,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String noneLabel;
  final List<({String id, String label})> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(noneLabel)),
        for (final item in items)
          DropdownMenuItem<String?>(value: item.id, child: Text(item.label)),
      ],
      onChanged: onChanged,
    );
  }
}
