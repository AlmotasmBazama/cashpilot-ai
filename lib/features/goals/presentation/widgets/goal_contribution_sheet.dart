import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../../shared/domain/currency/localized_decimal_parser.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../exchange_rates/application/base_currency_provider.dart';
import '../../application/providers/goals_providers.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_contribution.dart';
import '../../domain/failures/goal_failure_codes.dart';

class GoalContributionSheet extends ConsumerStatefulWidget {
  const GoalContributionSheet({required this.goal, super.key});

  final Goal goal;

  static Future<bool?> show(BuildContext context, {required Goal goal}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => GoalContributionSheet(goal: goal),
    );
  }

  @override
  ConsumerState<GoalContributionSheet> createState() =>
      _GoalContributionSheetState();
}

class _GoalContributionSheetState extends ConsumerState<GoalContributionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late String _currency;
  DateTime _date = DateTime.now().toUtc();
  String? _amountError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currency = widget.goal.currency.isEmpty
        ? ref.read(effectiveBaseCurrencyCodeProvider)
        : widget.goal.currency;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
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
              title: l10n.addContribution,
              subtitle: widget.goal.title,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: CPSpacing.lg),
            CPTextField(
              controller: _amountController,
              labelText: l10n.contribution,
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
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                '${l10n.contributionDate}: '
                '${FinanceFormatters.compactDate(_date, locale)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _noteController,
              labelText: l10n.contributionNote,
              enabled: !_saving,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
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
                    label: l10n.addContribution,
                    icon: Icons.add_rounded,
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

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.toLocal(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (selected != null) {
      setState(() {
        _date = DateTime.utc(selected.year, selected.month, selected.day);
      });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final amount = LocalizedDecimalParser.tryParse(_amountController.text);
    if (amount == null || amount <= Decimal.zero) {
      setState(() => _amountError = l10n.invalidContributionAmount);
      return;
    }
    setState(() => _saving = true);
    final contribution = GoalContribution.create(
      goalId: widget.goal.id,
      amount: amount,
      currency: _currency,
      date: _date,
      note: _noteController.text,
    );
    final result = await ref.read(addGoalContributionUseCaseProvider)(
      contribution,
    );
    if (!mounted) {
      return;
    }
    switch (result) {
      case AppSuccess<GoalContribution>():
        Navigator.of(context).pop(true);
      case AppFailure<GoalContribution>(:final failure):
        setState(() {
          _saving = false;
          _amountError = switch (failure.code) {
            GoalFailureCodes.missingExchangeRate =>
              l10n.goalMissingExchangeRate,
            GoalFailureCodes.overfunding => l10n.goalWouldExceedTarget,
            _ => l10n.contributionSaveError,
          };
        });
    }
  }
}
