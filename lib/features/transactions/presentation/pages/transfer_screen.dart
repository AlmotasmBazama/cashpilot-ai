import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/domain/currency/localized_decimal_parser.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../exchange_rates/application/providers/exchange_rates_providers.dart';
import '../../../finance_engine/domain/exceptions/finance_exception.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../application/providers/transactions_providers.dart';
import '../../domain/entities/create_transfer_command.dart';
import '../../domain/enums/transaction_status.dart';
import '../../domain/failures/transaction_failure_codes.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _amountController = TextEditingController();
  final _targetAmountController = TextEditingController();
  Account? _fromAccount;
  Account? _toAccount;
  TransactionStatus _status = TransactionStatus.posted;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accountsState = ref.watch(accountsProvider);

    return Scaffold(
      appBar: CPAppBar(
        title: l10n.transfer,
        subtitle: l10n.transferScreenSubtitle,
      ),
      body: accountsState.when(
        data: (result) {
          switch (result) {
            case AppSuccess<List<Account>>(:final data):
              return _buildContent(context, data);
            case AppFailure<List<Account>>():
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
        loading: () => FinanceScreenBody(
          child: ListView(
            children: const [
              CPSkeletonCard(height: 88),
              SizedBox(height: CPSpacing.lg),
              CPSkeletonCard(height: 360),
              SizedBox(height: CPSpacing.lg),
              CPSkeletonCard(height: 300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Account> accounts) {
    final l10n = AppLocalizations.of(context);
    _fromAccount ??= accounts.isEmpty ? null : accounts.first;
    _toAccount ??= accounts.length < 2 ? null : accounts[1];
    final hasCurrencyMismatch =
        _fromAccount != null &&
        _toAccount != null &&
        _fromAccount!.currencyCode.toUpperCase() !=
            _toAccount!.currencyCode.toUpperCase();
    final sourceAmount = _parseAmount(_amountController.text);
    final enteredTargetAmount = _parseAmount(_targetAmountController.text);
    final suggestedRate = hasCurrencyMismatch
        ? _storedRate(
            ref.watch(
              latestExchangeRateProvider((
                from: _fromAccount!.currencyCode,
                to: _toAccount!.currencyCode,
              )),
            ),
          )
        : null;
    final usesStoredRate =
        hasCurrencyMismatch &&
        enteredTargetAmount == null &&
        suggestedRate != null;
    final targetAmount = hasCurrencyMismatch
        ? enteredTargetAmount ?? _convert(sourceAmount, suggestedRate)
        : sourceAmount;
    final canSubmit = accounts.length >= 2 && !_isSubmitting;

    return FinanceScreenBody(
      child: ListView(
        children: [
          FinanceSafetyNotice(
            title: l10n.transferSafetyTitle,
            message: l10n.transferSafetyMessage,
            color: context.cpColors.transfer,
          ),
          const SizedBox(height: CPSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              final form = _TransferFormCard(
                accounts: accounts,
                fromAccount: _fromAccount,
                toAccount: _toAccount,
                amountController: _amountController,
                targetAmountController: _targetAmountController,
                hasCurrencyMismatch: hasCurrencyMismatch,
                suggestedRate: suggestedRate,
                status: _status,
                isSubmitting: _isSubmitting,
                onAmountChanged: (_) => setState(() {}),
                onFromSelected: (account) => setState(() {
                  _fromAccount = account;
                  _targetAmountController.clear();
                  if (_toAccount?.id == account.id) {
                    _toAccount = accounts
                        .where((item) => item.id != account.id)
                        .firstOrNull;
                  }
                }),
                onToSelected: (account) => setState(() {
                  _toAccount = account;
                  _targetAmountController.clear();
                }),
                onStatusChanged: (status) => setState(() => _status = status),
              );
              final preview = _TransferPreviewCard(
                fromAccount: _fromAccount,
                toAccount: _toAccount,
                sourceAmount: sourceAmount,
                targetAmount: targetAmount,
                hasCurrencyMismatch: hasCurrencyMismatch,
                rateUsed: usesStoredRate ? suggestedRate : null,
                usesStoredRate: usesStoredRate,
                status: _status,
                isSubmitting: _isSubmitting,
                canSubmit: canSubmit,
                onSubmit: _submitTransfer,
              );

              if (!wide) {
                return Column(
                  children: [
                    form,
                    const SizedBox(height: CPSpacing.lg),
                    preview,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: form),
                  const SizedBox(width: CPSpacing.lg),
                  Expanded(flex: 5, child: preview),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Decimal? _parseAmount(String value) {
    return LocalizedDecimalParser.tryParse(value);
  }

  ExchangeRate? _storedRate(AsyncValue<AppResult<ExchangeRate?>> value) {
    return switch (value.value) {
      AppSuccess<ExchangeRate?>(:final data) => data,
      _ => null,
    };
  }

  Decimal? _convert(Decimal? amount, ExchangeRate? rate) {
    if (amount == null || amount <= Decimal.zero || rate == null) {
      return null;
    }
    return amount * rate.rate;
  }

  Future<void> _submitTransfer() async {
    if (_isSubmitting) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final fromAccount = _fromAccount;
    final toAccount = _toAccount;
    final sourceAmount = LocalizedDecimalParser.tryParse(
      _amountController.text,
    );

    if (fromAccount == null || toAccount == null || sourceAmount == null) {
      _showSnack(l10n.invalidAmount);
      return;
    }

    final hasCurrencyMismatch =
        fromAccount.currencyCode.toUpperCase() !=
        toAccount.currencyCode.toUpperCase();
    final enteredTargetAmount = hasCurrencyMismatch
        ? LocalizedDecimalParser.tryParse(_targetAmountController.text)
        : null;

    if (sourceAmount <= Decimal.zero ||
        (enteredTargetAmount != null && enteredTargetAmount <= Decimal.zero)) {
      _showSnack(l10n.invalidAmount);
      return;
    }

    setState(() => _isSubmitting = true);
    final transferGroupId = const Uuid().v7();
    try {
      ExchangeRate? storedRate;
      if (hasCurrencyMismatch && enteredTargetAmount == null) {
        final rateResult = await ref.read(getLatestExchangeRateUseCaseProvider)(
          fromAccount.currencyCode,
          toAccount.currencyCode,
        );
        storedRate = switch (rateResult) {
          AppSuccess<ExchangeRate?>(:final data) => data,
          AppFailure<ExchangeRate?>() => null,
        };
        if (storedRate == null) {
          if (mounted) {
            _showSnack(l10n.exchangeRateRequired);
          }
          return;
        }
      }

      final result = await ref.read(createTransferUseCaseProvider)(
        CreateTransferCommand(
          sourceAccountId: fromAccount.id,
          targetAccountId: toAccount.id,
          sourceAmount: Money(
            amount: sourceAmount,
            currencyCode: fromAccount.currencyCode,
          ),
          targetAmount: enteredTargetAmount == null
              ? null
              : Money(
                  amount: enteredTargetAmount,
                  currencyCode: toAccount.currencyCode,
                ),
          exchangeRate: storedRate,
          status: _status,
          transferGroupId: transferGroupId,
        ),
      );

      if (!mounted) {
        return;
      }

      switch (result) {
        case AppSuccess():
          _amountController.clear();
          _targetAmountController.clear();
          ref
            ..invalidate(accountsProvider)
            ..invalidate(transactionsProvider);
          _showSnack(l10n.transferCreatedMessage);
        case AppFailure(:final failure):
          _showSnack(_localizedFailure(failure, l10n));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _localizedFailure(Failure failure, AppLocalizations l10n) {
    return switch (failure.code) {
      FinanceFailureCodes.exchangeRateUnavailable ||
      FinanceFailureCodes.invalidExchangeRate =>
        l10n.missingExchangeRateMessage,
      TransactionFailureCodes.invalidTransferInitialStatus ||
      TransactionFailureCodes.transferGroupMissing ||
      TransactionFailureCodes.transferGroupMalformed =>
        l10n.invalidTransferStateMessage,
      TransactionFailureCodes.transferScopeIntegrityQuarantined =>
        l10n.transferIntegrityReviewMessage,
      TransactionFailureCodes.transferDirectEditNotAllowed =>
        l10n.transferCannotBeEditedMessage,
      TransactionFailureCodes.transferHardDeleteNotAllowed =>
        l10n.postedTransferCannotBeDeletedMessage,
      _ => l10n.transferFailedMessage,
    };
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TransferFormCard extends StatelessWidget {
  const _TransferFormCard({
    required this.accounts,
    required this.fromAccount,
    required this.toAccount,
    required this.amountController,
    required this.targetAmountController,
    required this.hasCurrencyMismatch,
    required this.suggestedRate,
    required this.status,
    required this.isSubmitting,
    required this.onAmountChanged,
    required this.onFromSelected,
    required this.onToSelected,
    required this.onStatusChanged,
  });

  final List<Account> accounts;
  final Account? fromAccount;
  final Account? toAccount;
  final TextEditingController amountController;
  final TextEditingController targetAmountController;
  final bool hasCurrencyMismatch;
  final ExchangeRate? suggestedRate;
  final TransactionStatus status;
  final bool isSubmitting;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<Account> onFromSelected;
  final ValueChanged<Account> onToSelected;
  final ValueChanged<TransactionStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CPCard(
      accentColor: context.cpColors.transfer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CPSectionTitle(
            title: l10n.transferBackendPendingTitle,
            subtitle: l10n.transferBackendPendingMessage,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: CPSpacing.lg),
          CPAmountField(
            controller: amountController,
            labelText: l10n.amount,
            currencyCode: fromAccount?.currencyCode,
            enabled: accounts.length >= 2 && !isSubmitting,
            onChanged: onAmountChanged,
          ),
          const SizedBox(height: CPSpacing.md),
          _AccountPicker(
            label: l10n.fromAccount,
            account: fromAccount,
            accounts: accounts,
            onSelected: onFromSelected,
          ),
          const SizedBox(height: CPSpacing.sm),
          Center(
            child: Icon(
              Icons.south_rounded,
              size: 22,
              color: context.cpColors.transfer,
            ),
          ),
          const SizedBox(height: CPSpacing.sm),
          _AccountPicker(
            label: l10n.toAccount,
            account: toAccount,
            accounts: accounts
                .where((account) => account.id != fromAccount?.id)
                .toList(growable: false),
            onSelected: onToSelected,
          ),
          AnimatedSize(
            duration: CPDurations.normal,
            curve: Curves.easeOutCubic,
            child: hasCurrencyMismatch
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: CPSpacing.md),
                      FinanceInfoCard(
                        title: suggestedRate == null
                            ? l10n.transferExchangeRequiredTitle
                            : l10n.suggestedStoredRate,
                        message: suggestedRate == null
                            ? l10n.transferExchangeRequiredMessage
                            : _rateLabel(suggestedRate!),
                        icon: Icons.currency_exchange_rounded,
                        color: context.cpColors.info,
                        action: FinanceStatusPill(
                          label: suggestedRate == null
                              ? l10n.manualConversionBadge
                              : l10n.manualRate,
                          icon: suggestedRate == null
                              ? Icons.edit_outlined
                              : Icons.bookmark_outline_rounded,
                          color: context.cpColors.info,
                        ),
                      ),
                      const SizedBox(height: CPSpacing.md),
                      CPAmountField(
                        controller: targetAmountController,
                        labelText: l10n.destinationAmount,
                        currencyCode: toAccount?.currencyCode,
                        enabled: accounts.length >= 2 && !isSubmitting,
                        onChanged: onAmountChanged,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: CPSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TransactionStatus>(
              segments: [
                ButtonSegment<TransactionStatus>(
                  value: TransactionStatus.posted,
                  label: Text(l10n.transactionStatusPosted),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                ),
                ButtonSegment<TransactionStatus>(
                  value: TransactionStatus.pending,
                  label: Text(l10n.transactionStatusPending),
                  icon: const Icon(Icons.schedule_rounded),
                ),
              ],
              selected: {status},
              onSelectionChanged: isSubmitting
                  ? null
                  : (selection) => onStatusChanged(selection.single),
            ),
          ),
        ],
      ),
    );
  }

  String _rateLabel(ExchangeRate rate) {
    return '1 ${rate.fromCurrencyCode.toUpperCase()} = '
        '${rate.rate} ${rate.toCurrencyCode.toUpperCase()}';
  }
}

class _TransferPreviewCard extends StatelessWidget {
  const _TransferPreviewCard({
    required this.fromAccount,
    required this.toAccount,
    required this.sourceAmount,
    required this.targetAmount,
    required this.hasCurrencyMismatch,
    required this.rateUsed,
    required this.usesStoredRate,
    required this.status,
    required this.isSubmitting,
    required this.canSubmit,
    required this.onSubmit,
  });

  final Account? fromAccount;
  final Account? toAccount;
  final Decimal? sourceAmount;
  final Decimal? targetAmount;
  final bool hasCurrencyMismatch;
  final ExchangeRate? rateUsed;
  final bool usesStoredRate;
  final TransactionStatus status;
  final bool isSubmitting;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final transferColor = context.cpColors.transfer;
    final displayedRate = rateUsed == null
        ? _impliedRate()
        : _rateLabel(rateUsed!);

    return CPCard(
      variant: CPCardVariant.elevated,
      accentColor: transferColor,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: transferColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(CPRadius.sm),
                ),
                child: Icon(Icons.swap_horiz_rounded, color: transferColor),
              ),
              const SizedBox(width: CPSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.transferPreviewTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: CPSpacing.xs),
                    Text(
                      l10n.transferPreviewSubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CPSpacing.lg),
          _TransferAccountRoute(fromAccount: fromAccount, toAccount: toAccount),
          const SizedBox(height: CPSpacing.md),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          FinanceDetailRow(
            label: l10n.amount,
            value: _amountLabel(sourceAmount, fromAccount),
            icon: Icons.arrow_upward_rounded,
            valueColor: sourceAmount != null && sourceAmount! > Decimal.zero
                ? transferColor
                : null,
          ),
          if (hasCurrencyMismatch)
            FinanceDetailRow(
              label: l10n.destinationAmount,
              value: _amountLabel(targetAmount, toAccount),
              icon: Icons.arrow_downward_rounded,
              valueColor: targetAmount != null && targetAmount! > Decimal.zero
                  ? transferColor
                  : null,
            ),
          if (hasCurrencyMismatch && displayedRate != null)
            FinanceDetailRow(
              label: l10n.rateUsed,
              value: displayedRate,
              icon: Icons.currency_exchange_rounded,
            ),
          if (hasCurrencyMismatch && displayedRate == null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: CPSpacing.xs,
                bottom: CPSpacing.sm,
              ),
              child: Text(
                l10n.destinationAmountRequired,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.cpColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: CPSpacing.sm),
          Wrap(
            spacing: CPSpacing.sm,
            runSpacing: CPSpacing.sm,
            children: [
              FinanceStatusPill(
                label: _statusLabel(l10n),
                icon: status == TransactionStatus.posted
                    ? Icons.check_circle_outline_rounded
                    : Icons.schedule_rounded,
                color: status == TransactionStatus.posted
                    ? context.cpColors.success
                    : context.cpColors.warning,
              ),
              if (hasCurrencyMismatch)
                FinanceStatusPill(
                  label: usesStoredRate
                      ? l10n.suggestedStoredRate
                      : l10n.manualConversionBadge,
                  icon: usesStoredRate
                      ? Icons.bookmark_outline_rounded
                      : Icons.edit_outlined,
                  color: context.cpColors.info,
                ),
            ],
          ),
          const SizedBox(height: CPSpacing.lg),
          FinanceSafetyNotice(
            title: _statusLabel(l10n),
            message: status == TransactionStatus.posted
                ? l10n.transferPostedEffectMessage
                : l10n.transferPendingEffectMessage,
            icon: status == TransactionStatus.posted
                ? Icons.bolt_rounded
                : Icons.schedule_rounded,
            color: status == TransactionStatus.posted
                ? context.cpColors.success
                : context.cpColors.warning,
          ),
          const SizedBox(height: CPSpacing.lg),
          CPButton(
            label: l10n.createTransfer,
            icon: Icons.swap_horiz_rounded,
            isLoading: isSubmitting,
            onPressed: canSubmit ? onSubmit : null,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  String _amountLabel(Decimal? amount, Account? account) {
    final currencyCode = account?.currencyCode.toUpperCase();
    if (currencyCode == null) {
      return '--';
    }
    if (amount == null || amount <= Decimal.zero) {
      return '-- $currencyCode';
    }
    return FinanceFormatters.amountWithCurrency(amount, currencyCode);
  }

  String? _impliedRate() {
    if (!hasCurrencyMismatch ||
        sourceAmount == null ||
        targetAmount == null ||
        sourceAmount! <= Decimal.zero ||
        targetAmount! <= Decimal.zero ||
        fromAccount == null ||
        toAccount == null) {
      return null;
    }

    final rate = (targetAmount! / sourceAmount!).toDecimal(
      scaleOnInfinitePrecision: 6,
    );
    return '1 ${fromAccount!.currencyCode.toUpperCase()} = '
        '$rate ${toAccount!.currencyCode.toUpperCase()}';
  }

  String _rateLabel(ExchangeRate rate) {
    return '1 ${rate.fromCurrencyCode.toUpperCase()} = '
        '${rate.rate} ${rate.toCurrencyCode.toUpperCase()}';
  }

  String _statusLabel(AppLocalizations l10n) {
    return switch (status) {
      TransactionStatus.posted => l10n.transactionStatusPosted,
      TransactionStatus.pending => l10n.transactionStatusPending,
      TransactionStatus.cancelled => l10n.transactionStatusCancelled,
      TransactionStatus.failed => l10n.transactionStatusFailed,
    };
  }
}

class _TransferAccountRoute extends StatelessWidget {
  const _TransferAccountRoute({
    required this.fromAccount,
    required this.toAccount,
  });

  final Account? fromAccount;
  final Account? toAccount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 360;
        final from = _TransferAccountNode(
          label: AppLocalizations.of(context).fromAccount,
          account: fromAccount,
        );
        final to = _TransferAccountNode(
          label: AppLocalizations.of(context).toAccount,
          account: toAccount,
        );

        if (vertical) {
          return Column(
            children: [
              from,
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: CPSpacing.sm,
                ),
                child: Icon(
                  Icons.south_rounded,
                  color: context.cpColors.transfer,
                ),
              ),
              to,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: from),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: CPSpacing.sm,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: context.cpColors.transfer,
              ),
            ),
            Expanded(child: to),
          ],
        );
      },
    );
  }
}

class _TransferAccountNode extends StatelessWidget {
  const _TransferAccountNode({required this.label, required this.account});

  final String label;
  final Account? account;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(CPSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(CPRadius.sm),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: CPSpacing.xs),
          Text(
            account?.name ?? '--',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: CPSpacing.xxs),
          Text(
            account?.currencyCode.toUpperCase() ?? '--',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.cpColors.transfer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.label,
    required this.account,
    required this.accounts,
    required this.onSelected,
  });

  final String label;
  final Account? account;
  final List<Account> accounts;
  final ValueChanged<Account> onSelected;

  @override
  Widget build(BuildContext context) {
    return CPTextField(
      key: ValueKey('$label-${account?.id}'),
      initialValue: account?.name ?? '',
      labelText: label,
      prefix: const Icon(Icons.account_balance_wallet_outlined),
      suffix: const Icon(Icons.keyboard_arrow_down_rounded),
      readOnly: true,
      onTap: accounts.isEmpty
          ? null
          : () async {
              final selected = await showModalBottomSheet<Account>(
                context: context,
                showDragHandle: true,
                builder: (context) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsetsDirectional.all(CPSpacing.lg),
                    children: [
                      CPSectionTitle(title: label, padding: EdgeInsets.zero),
                      const SizedBox(height: CPSpacing.md),
                      for (final account in accounts)
                        CPListTile(
                          title: account.name,
                          subtitle: account.currencyCode,
                          onTap: () => Navigator.of(context).pop(account),
                        ),
                    ],
                  ),
                ),
              );
              if (selected != null) {
                onSelected(selected);
              }
            },
    );
  }
}

extension on Iterable<Account> {
  Account? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
