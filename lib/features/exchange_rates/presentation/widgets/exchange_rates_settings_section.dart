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
import '../../application/providers/exchange_rates_providers.dart';
import '../../domain/entities/stored_exchange_rate.dart';
import '../../domain/enums/exchange_rate_source.dart';
import '../../domain/failures/exchange_rate_failure_codes.dart';

class ExchangeRatesSettingsSection extends ConsumerStatefulWidget {
  const ExchangeRatesSettingsSection({super.key});

  @override
  ConsumerState<ExchangeRatesSettingsSection> createState() =>
      _ExchangeRatesSettingsSectionState();
}

class _ExchangeRatesSettingsSectionState
    extends ConsumerState<ExchangeRatesSettingsSection> {
  bool _includeArchived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ratesState = ref.watch(allExchangeRatesProvider);

    return FinanceSection(
      title: l10n.exchangeRatesTitle,
      subtitle: l10n.exchangeRatesSubtitle,
      action: IconButton.filledTonal(
        tooltip: l10n.addExchangeRate,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
      ),
      child: Column(
        children: [
          FinanceInfoCard(
            title: l10n.manualRate,
            message: l10n.ratesAreManualNotice,
            icon: Icons.edit_calendar_outlined,
            color: context.cpColors.info,
          ),
          const SizedBox(height: CPSpacing.md),
          CPCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _includeArchived,
                  onChanged: (value) =>
                      setState(() => _includeArchived = value),
                  title: Text(l10n.includeArchivedRates),
                  secondary: const Icon(Icons.inventory_2_outlined),
                ),
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                ratesState.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(CPSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => _RatesError(onRetry: _retry),
                  data: (result) => switch (result) {
                    AppSuccess<List<StoredExchangeRate>>(:final data) =>
                      _RatesList(
                        rates: data
                            .where(
                              (rate) => _includeArchived || !rate.isArchived,
                            )
                            .toList(growable: false),
                        onAdd: _openForm,
                        onEdit: (rate) => _openForm(rate),
                        onArchive: _archive,
                      ),
                    AppFailure<List<StoredExchangeRate>>() => _RatesError(
                      onRetry: _retry,
                    ),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _retry() => ref.invalidate(allExchangeRatesProvider);

  Future<void> _openForm([StoredExchangeRate? rate]) async {
    final saved = await ExchangeRateFormSheet.show(context, rate: rate);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).exchangeRateSaved)),
      );
    }
  }

  Future<void> _archive(StoredExchangeRate rate) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.archiveExchangeRate),
        content: Text(l10n.archiveExchangeRateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.archive),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final result = await ref.read(archiveExchangeRateUseCaseProvider)(rate.id);
    if (!mounted) {
      return;
    }
    final message = switch (result) {
      AppSuccess<StoredExchangeRate>() => l10n.exchangeRateArchived,
      AppFailure<StoredExchangeRate>() => l10n.exchangeRatesErrorTitle,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RatesList extends StatelessWidget {
  const _RatesList({
    required this.rates,
    required this.onAdd,
    required this.onEdit,
    required this.onArchive,
  });

  final List<StoredExchangeRate> rates;
  final VoidCallback onAdd;
  final ValueChanged<StoredExchangeRate> onEdit;
  final ValueChanged<StoredExchangeRate> onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    if (rates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(CPSpacing.lg),
        child: CPEmptyState(
          icon: Icons.currency_exchange_rounded,
          title: l10n.noExchangeRatesTitle,
          message: l10n.noExchangeRatesMessage,
          action: CPButton(
            label: l10n.addExchangeRate,
            icon: Icons.add_rounded,
            onPressed: onAdd,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final rate in rates)
          CPListTile(
            title: '${rate.baseCurrency} \u2192 ${rate.quoteCurrency}',
            subtitle:
                '1 ${rate.baseCurrency} = ${rate.rate} ${rate.quoteCurrency}',
            supportingText:
                '${l10n.manualRate} \u00b7 ${l10n.lastUpdated}: '
                '${FinanceFormatters.fullDate(rate.updatedAt, localeName)}',
            leading: Icon(
              Icons.currency_exchange_rounded,
              color: rate.isArchived
                  ? Theme.of(context).disabledColor
                  : Theme.of(context).colorScheme.primary,
            ),
            trailing: rate.isArchived
                ? FinanceStatusPill(
                    label: l10n.archivedRate,
                    icon: Icons.inventory_2_outlined,
                  )
                : PopupMenuButton<_RateAction>(
                    tooltip: l10n.editExchangeRate,
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (action) => switch (action) {
                      _RateAction.edit => onEdit(rate),
                      _RateAction.archive => onArchive(rate),
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _RateAction.edit,
                        child: ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(l10n.edit),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _RateAction.archive,
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(l10n.archive),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
            onTap: rate.isArchived ? null : () => onEdit(rate),
          ),
      ],
    );
  }
}

class _RatesError extends StatelessWidget {
  const _RatesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(CPSpacing.lg),
      child: CPErrorView(
        title: l10n.exchangeRatesErrorTitle,
        message: l10n.conversionFailed,
        action: CPButton(
          label: l10n.retry,
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ),
    );
  }
}

enum _RateAction { edit, archive }

class ExchangeRateFormSheet extends ConsumerStatefulWidget {
  const ExchangeRateFormSheet({this.rate, super.key});

  final StoredExchangeRate? rate;

  static Future<bool?> show(BuildContext context, {StoredExchangeRate? rate}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ExchangeRateFormSheet(rate: rate),
    );
  }

  @override
  ConsumerState<ExchangeRateFormSheet> createState() =>
      _ExchangeRateFormSheetState();
}

class _ExchangeRateFormSheetState extends ConsumerState<ExchangeRateFormSheet> {
  late final TextEditingController _rateController;
  late String _baseCurrency;
  late String _quoteCurrency;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.rate;
    _baseCurrency =
        existing?.baseCurrency ?? CurrencyCatalog.defaultCurrencyCode;
    _quoteCurrency = existing?.quoteCurrency ?? 'USD';
    _rateController = TextEditingController(text: existing?.rate.toString());
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.rate != null;
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
              title: editing ? l10n.editExchangeRate : l10n.addExchangeRate,
              subtitle: l10n.ratesAreManualNotice,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: CPSpacing.lg),
            DropdownButtonFormField<String>(
              key: ValueKey('exchange-rate-base-$_baseCurrency'),
              isExpanded: true,
              initialValue: _baseCurrency,
              decoration: InputDecoration(labelText: l10n.fromCurrency),
              items: _currencyItems(),
              onChanged: editing || _saving
                  ? null
                  : (value) => setState(() => _baseCurrency = value!),
            ),
            const SizedBox(height: CPSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey('exchange-rate-quote-$_quoteCurrency'),
              isExpanded: true,
              initialValue: _quoteCurrency,
              decoration: InputDecoration(labelText: l10n.toCurrency),
              items: _currencyItems(),
              onChanged: editing || _saving
                  ? null
                  : (value) => setState(() => _quoteCurrency = value!),
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _rateController,
              labelText: l10n.exchangeRate,
              hintText: l10n.enterExchangeRate,
              helperText: '1 $_baseCurrency = ? $_quoteCurrency',
              errorText: _errorText,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
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

  List<DropdownMenuItem<String>> _currencyItems() => [
    for (final currency in CurrencyCatalog.supported)
      DropdownMenuItem(value: currency.code, child: Text(currency.code)),
  ];

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final rate = LocalizedDecimalParser.tryParse(_rateController.text);
    if (_baseCurrency == _quoteCurrency) {
      setState(() => _errorText = l10n.sameCurrencyNotAllowed);
      return;
    }
    if (rate == null || rate <= Decimal.zero) {
      setState(() => _errorText = l10n.invalidExchangeRate);
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });
    final existing = widget.rate;
    try {
      final entity = StoredExchangeRate.create(
        id: existing?.id,
        baseCurrency: _baseCurrency,
        quoteCurrency: _quoteCurrency,
        rate: rate,
        source: ExchangeRateSource.manual,
        fetchedAt: DateTime.now().toUtc(),
        createdAt: existing?.createdAt,
      );
      final result = await ref.read(upsertExchangeRateUseCaseProvider)(entity);
      if (!mounted) {
        return;
      }
      switch (result) {
        case AppSuccess<StoredExchangeRate>():
          Navigator.of(context).pop(true);
        case AppFailure<StoredExchangeRate>(:final failure):
          setState(() {
            _saving = false;
            _errorText = switch (failure.code) {
              ExchangeRateFailureCodes.sameCurrency =>
                l10n.sameCurrencyNotAllowed,
              ExchangeRateFailureCodes.invalidRate => l10n.invalidExchangeRate,
              _ => l10n.exchangeRatesErrorTitle,
            };
          });
      }
    } on ExchangeRateValidationException catch (error) {
      setState(() {
        _saving = false;
        _errorText = error.code == ExchangeRateFailureCodes.sameCurrency
            ? l10n.sameCurrencyNotAllowed
            : l10n.invalidExchangeRate;
      });
    }
  }
}
