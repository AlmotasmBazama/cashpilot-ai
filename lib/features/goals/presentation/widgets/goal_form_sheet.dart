import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../../shared/domain/currency/localized_decimal_parser.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../exchange_rates/application/base_currency_provider.dart';
import '../../application/models/goal_linked_account_option.dart';
import '../../application/providers/goal_linked_account_options_provider.dart';
import '../../application/providers/goals_providers.dart';
import '../../domain/entities/goal.dart';
import '../../domain/enums/goal_status.dart';
import '../../domain/enums/goal_type.dart';
import '../../domain/failures/goal_failure_codes.dart';

class GoalFormSheet extends ConsumerStatefulWidget {
  const GoalFormSheet({this.goal, super.key});

  final Goal? goal;

  static Future<bool?> show(BuildContext context, {Goal? goal}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => GoalFormSheet(goal: goal),
    );
  }

  @override
  ConsumerState<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<GoalFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetController;
  late String _currency;
  late GoalType _type;
  late GoalStatus _status;
  String? _linkedAccountId;
  DateTime? _targetDate;
  String? _titleError;
  String? _amountError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.goal;
    _titleController = TextEditingController(text: existing?.title);
    _descriptionController = TextEditingController(text: existing?.description);
    _targetController = TextEditingController(
      text: existing?.targetAmount.toString(),
    );
    _currency =
        existing?.currency ?? ref.read(effectiveBaseCurrencyCodeProvider);
    _type = existing?.type ?? GoalType.savings;
    _status = existing?.status == GoalStatus.paused
        ? GoalStatus.paused
        : GoalStatus.active;
    _linkedAccountId = existing?.linkedAccountId;
    _targetDate = existing?.targetDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accounts = _accounts(ref.watch(goalLinkedAccountOptionsProvider));
    final locale = Localizations.localeOf(context).toLanguageTag();
    final existing = widget.goal;
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
            CPSectionTitle(
              title: existing == null ? l10n.addGoal : l10n.editGoal,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: CPSpacing.lg),
            CPTextField(
              controller: _titleController,
              labelText: l10n.goalTitle,
              errorText: _titleError,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _descriptionController,
              labelText: l10n.goalDescription,
              enabled: !_saving,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: CPSpacing.md),
            DropdownButtonFormField<GoalType>(
              isExpanded: true,
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.goalType),
              items: [
                for (final type in GoalType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(goalTypeLabel(l10n, type)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _targetController,
              labelText: l10n.targetAmount,
              errorText: _amountError,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _currency,
              decoration: InputDecoration(labelText: l10n.currency),
              items: [
                for (final currency in CurrencyCatalog.supported)
                  DropdownMenuItem(
                    value: currency.code,
                    child: Text(currency.code),
                  ),
              ],
              onChanged:
                  _saving ||
                      (existing?.currentAmount ?? Decimal.zero) > Decimal.zero
                  ? null
                  : (value) => setState(() => _currency = value!),
            ),
            if (existing != null) ...[
              const SizedBox(height: CPSpacing.sm),
              FinanceDetailRow(
                label: l10n.currentAmount,
                value: FinanceFormatters.amountWithCurrency(
                  existing.currentAmount,
                  existing.currency,
                ),
                icon: Icons.savings_outlined,
              ),
            ],
            const SizedBox(height: CPSpacing.md),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _linkedAccountId ?? '',
              decoration: InputDecoration(labelText: l10n.linkedAccount),
              items: [
                DropdownMenuItem(value: '', child: Text(l10n.noLinkedAccount)),
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(
                      () => _linkedAccountId = value == null || value.isEmpty
                          ? null
                          : value,
                    ),
            ),
            const SizedBox(height: CPSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickTargetDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _targetDate == null
                          ? l10n.targetDate
                          : FinanceFormatters.compactDate(_targetDate!, locale),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_targetDate != null) ...[
                  const SizedBox(width: CPSpacing.xs),
                  IconButton(
                    tooltip: l10n.clearTargetDate,
                    onPressed: _saving
                        ? null
                        : () => setState(() => _targetDate = null),
                    icon: const Icon(Icons.event_busy_outlined),
                  ),
                ],
              ],
            ),
            const SizedBox(height: CPSpacing.md),
            DropdownButtonFormField<GoalStatus>(
              isExpanded: true,
              initialValue: _status,
              decoration: InputDecoration(labelText: l10n.status),
              items: [
                DropdownMenuItem(
                  value: GoalStatus.active,
                  child: Text(l10n.goalStatusActive),
                ),
                DropdownMenuItem(
                  value: GoalStatus.paused,
                  child: Text(l10n.goalStatusPaused),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: CPSpacing.lg),
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
                    icon: Icons.save_outlined,
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

  List<GoalLinkedAccountOption> _accounts(
    AsyncValue<AppResult<List<GoalLinkedAccountOption>>> value,
  ) => switch (value.value) {
    AppSuccess<List<GoalLinkedAccountOption>>(:final data) =>
      data.where((account) => !account.isArchived).toList(growable: false),
    _ => const <GoalLinkedAccountOption>[],
  };

  Future<void> _pickTargetDate() async {
    final initial = (_targetDate ?? DateTime.now()).toLocal();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (selected != null) {
      setState(() {
        _targetDate = DateTime.utc(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
        );
      });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    final target = LocalizedDecimalParser.tryParse(_targetController.text);
    final existing = widget.goal;
    final targetBelowCurrent =
        target != null && existing != null && target < existing.currentAmount;
    if (title.isEmpty ||
        target == null ||
        target <= Decimal.zero ||
        targetBelowCurrent) {
      setState(() {
        _titleError = title.isEmpty ? l10n.goalTitle : null;
        _amountError = targetBelowCurrent
            ? l10n.goalTargetBelowCurrent
            : target == null || target <= Decimal.zero
            ? l10n.invalidGoalAmount
            : null;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      final value = Goal.create(
        id: existing?.id,
        title: title,
        description: _descriptionController.text,
        type: _type,
        targetAmount: target,
        currentAmount: existing?.currentAmount,
        currency: _currency,
        linkedAccountId: _linkedAccountId,
        targetDate: _targetDate,
        icon: goalTypeIconName(_type),
        color: goalTypeColorValue(_type),
        status: _status,
        createdAt: existing?.createdAt,
        archivedAt: existing?.archivedAt,
        completedAt: existing?.completedAt,
      );
      final result = existing == null
          ? await ref.read(createGoalUseCaseProvider)(value)
          : await ref.read(updateGoalUseCaseProvider)(value);
      if (!mounted) {
        return;
      }
      switch (result) {
        case AppSuccess<Goal>():
          Navigator.of(context).pop(true);
        case AppFailure<Goal>():
          setState(() {
            _saving = false;
            _amountError = l10n.goalSaveError;
          });
      }
    } on GoalValidationException catch (error) {
      setState(() {
        _saving = false;
        _amountError = error.code == GoalFailureCodes.overfunding
            ? l10n.goalTargetBelowCurrent
            : l10n.goalSaveError;
      });
    }
  }
}

String goalTypeLabel(AppLocalizations l10n, GoalType type) => switch (type) {
  GoalType.savings => l10n.savingsGoal,
  GoalType.emergencyFund => l10n.emergencyFund,
  GoalType.debtPayoff => l10n.debtPayoff,
  GoalType.purchase => l10n.purchaseGoal,
  GoalType.custom => l10n.customGoal,
};

String goalTypeIconName(GoalType type) => switch (type) {
  GoalType.savings => 'savings',
  GoalType.emergencyFund => 'shield',
  GoalType.debtPayoff => 'receipt',
  GoalType.purchase => 'shopping_bag',
  GoalType.custom => 'flag',
};

int goalTypeColorValue(GoalType type) => switch (type) {
  GoalType.savings => 0xFF17A673,
  GoalType.emergencyFund => 0xFFE0A21A,
  GoalType.debtPayoff => 0xFFD75455,
  GoalType.purchase => 0xFF197E8C,
  GoalType.custom => 0xFF6D5BD0,
};
