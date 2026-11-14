import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../../shared/domain/currency/localized_decimal_parser.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization;
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../exchange_rates/application/base_currency_provider.dart';
import '../../application/providers/budgets_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/enums/budget_period_type.dart';
import '../../domain/failures/budget_failure_codes.dart';

class BudgetFormSheet extends ConsumerStatefulWidget {
  const BudgetFormSheet({this.budget, super.key});

  final Budget? budget;

  static Future<bool?> show(BuildContext context, {Budget? budget}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BudgetFormSheet(budget: budget),
    );
  }

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late String _currency;
  late BudgetPeriodType _periodType;
  late DateTime _startDate;
  late DateTime _endDate;
  late int _threshold;
  String? _categoryId;
  String? _nameError;
  String? _amountError;
  String? _categoryError;
  String? _periodError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.budget;
    _nameController = TextEditingController(text: existing?.name);
    _amountController = TextEditingController(
      text: existing?.amount.toString(),
    );
    _currency =
        existing?.currency ?? ref.read(effectiveBaseCurrencyCodeProvider);
    _periodType = existing?.periodType ?? BudgetPeriodType.monthly;
    final period = _periodFor(_periodType, DateTime.now().toUtc());
    _startDate = existing?.startDate ?? period.start;
    _endDate = existing?.endDate ?? period.end;
    _threshold = existing?.alertThresholdPercent ?? 80;
    _categoryId = existing?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = _categories(
      ref.watch(categoriesByTypeProvider(CategoryType.expense)),
    );
    final localeName = Localizations.localeOf(context).toLanguageTag();
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
              title: widget.budget == null ? l10n.addBudget : l10n.editBudget,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: CPSpacing.lg),
            CPTextField(
              controller: _nameController,
              labelText: l10n.budgetName,
              errorText: _nameError,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _amountController,
              labelText: l10n.budgetAmount,
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
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _currency = value!),
            ),
            const SizedBox(height: CPSpacing.md),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _categoryId,
              decoration: InputDecoration(
                labelText: l10n.category,
                errorText: _categoryError,
              ),
              items: [
                for (final category in categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(CategoryLocalization.name(l10n, category)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _categoryId = value;
                      _categoryError = null;
                    }),
            ),
            const SizedBox(height: CPSpacing.md),
            DropdownButtonFormField<BudgetPeriodType>(
              isExpanded: true,
              initialValue: _periodType,
              decoration: InputDecoration(
                labelText: l10n.budgetPeriod,
                errorText: _periodError,
              ),
              items: [
                for (final type in BudgetPeriodType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(_periodLabel(l10n, type)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => _changePeriod(value ?? _periodType),
            ),
            if (_periodType == BudgetPeriodType.custom) ...[
              const SizedBox(height: CPSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => _pickDate(start: true),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        '${l10n.budgetStartDate}: '
                        '${FinanceFormatters.compactDate(_startDate, localeName)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: CPSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => _pickDate(start: false),
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(
                        '${l10n.budgetEndDate}: '
                        '${FinanceFormatters.compactDate(_endDate.subtract(const Duration(days: 1)), localeName)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: CPSpacing.lg),
            Text(
              '${l10n.alertThreshold}: $_threshold%',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Slider(
              value: _threshold.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '$_threshold%',
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _threshold = value.round()),
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

  List<Category> _categories(AsyncValue<AppResult<List<Category>>> value) {
    return switch (value.value) {
      AppSuccess<List<Category>>(:final data) => data,
      _ => const <Category>[],
    };
  }

  void _changePeriod(BudgetPeriodType type) {
    final period = _periodFor(type, DateTime.now().toUtc());
    setState(() {
      _periodType = type;
      _startDate = period.start;
      _endDate = period.end;
      _periodError = null;
    });
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start
        ? _startDate
        : _endDate.subtract(const Duration(days: 1));
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.toLocal(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      if (start) {
        _startDate = DateTime.utc(selected.year, selected.month, selected.day);
      } else {
        _endDate = DateTime.utc(
          selected.year,
          selected.month,
          selected.day + 1,
        );
      }
      _periodError = null;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final amount = LocalizedDecimalParser.tryParse(_amountController.text);
    final name = _nameController.text.trim();
    final valid =
        name.isNotEmpty &&
        amount != null &&
        amount > Decimal.zero &&
        _categoryId != null &&
        _startDate.isBefore(_endDate);
    if (!valid) {
      setState(() {
        _nameError = name.isEmpty ? l10n.budgetName : null;
        _amountError = amount == null || amount <= Decimal.zero
            ? l10n.invalidBudgetAmount
            : null;
        _categoryError = _categoryId == null ? l10n.selectCategory : null;
        _periodError = !_startDate.isBefore(_endDate)
            ? l10n.budgetPeriodInvalid
            : null;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = widget.budget;
      final value = Budget.create(
        id: existing?.id,
        name: name,
        categoryId: _categoryId!,
        amount: amount,
        currency: _currency,
        periodType: _periodType,
        startDate: _startDate,
        endDate: _endDate,
        alertThresholdPercent: _threshold,
        isActive: existing?.isActive ?? true,
        createdAt: existing?.createdAt,
        archivedAt: existing?.archivedAt,
      );
      final result = existing == null
          ? await ref.read(createBudgetUseCaseProvider)(value)
          : await ref.read(updateBudgetUseCaseProvider)(value);
      if (!mounted) {
        return;
      }
      switch (result) {
        case AppSuccess<Budget>():
          Navigator.of(context).pop(true);
        case AppFailure<Budget>(:final failure):
          setState(() {
            _saving = false;
            _amountError = failure.code == BudgetFailureCodes.invalidAmount
                ? l10n.invalidBudgetAmount
                : l10n.budgetSaveError;
          });
      }
    } on BudgetValidationException catch (error) {
      setState(() {
        _saving = false;
        _periodError = error.code == BudgetFailureCodes.invalidPeriod
            ? l10n.budgetPeriodInvalid
            : null;
        _amountError = error.code == BudgetFailureCodes.invalidAmount
            ? l10n.invalidBudgetAmount
            : l10n.budgetSaveError;
      });
    }
  }
}

({DateTime start, DateTime end}) _periodFor(
  BudgetPeriodType type,
  DateTime now,
) {
  final at = now.toUtc();
  return switch (type) {
    BudgetPeriodType.weekly => (
      start: DateTime.utc(
        at.year,
        at.month,
        at.day,
      ).subtract(Duration(days: at.weekday - DateTime.monday)),
      end: DateTime.utc(at.year, at.month, at.day)
          .subtract(Duration(days: at.weekday - DateTime.monday))
          .add(const Duration(days: 7)),
    ),
    BudgetPeriodType.monthly => (
      start: DateTime.utc(at.year, at.month),
      end: DateTime.utc(at.year, at.month + 1),
    ),
    BudgetPeriodType.yearly => (
      start: DateTime.utc(at.year),
      end: DateTime.utc(at.year + 1),
    ),
    BudgetPeriodType.custom => (
      start: DateTime.utc(at.year, at.month, at.day),
      end: DateTime.utc(at.year, at.month, at.day + 1),
    ),
  };
}

String _periodLabel(AppLocalizations l10n, BudgetPeriodType type) {
  return switch (type) {
    BudgetPeriodType.weekly => l10n.weekly,
    BudgetPeriodType.monthly => l10n.monthly,
    BudgetPeriodType.yearly => l10n.yearly,
    BudgetPeriodType.custom => l10n.customPeriod,
  };
}
