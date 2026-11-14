import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization;
import '../../../categories/domain/entities/category_suggestion.dart';
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/transactions_presentation.dart'
    show TransactionUiFormatters;
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_action_draft.dart';
import '../../domain/entities/ai_transaction_draft.dart';
import '../support/ai_financial_date_formatter.dart';

/// Final, local pre-save preview for a fully resolved expense or income.
/// It intentionally exposes no edit path and no persistence identifiers.
class AiFinancialStoragePreviewCard extends StatelessWidget {
  const AiFinancialStoragePreviewCard({
    required this.draft,
    required this.onReject,
    required this.onConfirm,
    this.timeZoneName = 'Africa/Tripoli',
    this.clock,
    super.key,
  });

  final AiActionDraft draft;
  final VoidCallback onReject;
  final VoidCallback? onConfirm;
  final String timeZoneName;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final transaction = _transactionDraft;
    final isExecuting = draft.status == AiActionExecutionStatus.executing;
    final canConfirm =
        draft.status == AiActionExecutionStatus.awaitingConfirmation
        ? onConfirm
        : null;
    final amount = FinanceFormatters.money(transaction.amount);
    final description = _description(transaction);
    final category = transaction.category!;
    final date = transaction.transactionDate ?? DateTime.now();
    final dateLabel = AiFinancialDateFormatter.label(
      date: date,
      timeZoneName: timeZoneName,
      localeName: Localizations.localeOf(context).toLanguageTag(),
      todayLabel: l10n.aiFinancialPreviewToday,
      now: clock?.call(),
    );
    final statusLabel = transaction.status == TransactionStatus.posted
        ? l10n.transactionStatusPosted
        : l10n.transactionStatusPending;
    final storageEffect = _storageEffect(l10n, transaction, amount);
    final typeLabel = transaction.type == TransactionType.expense
        ? l10n.expense
        : l10n.income;
    final source = transaction.type == TransactionType.income
        ? transaction.incomeSourceIdentity
        : transaction.payee?.name ?? transaction.payeeHint;
    final suggestion = transaction.categorySuggestion;
    final showCategoryAssumption =
        suggestion != null &&
        suggestion.source != CategorySuggestionSource.explicitUserInput &&
        suggestion.source != CategorySuggestionSource.userRule &&
        suggestion.source != CategorySuggestionSource.payeeDefault;
    final warning = _warning(l10n, transaction);

    return Semantics(
      container: true,
      label:
          '${l10n.aiFinancialPreviewTitle}. $typeLabel. $amount. '
          '$description. $storageEffect',
      child: CPCard(
        variant: CPCardVariant.elevated,
        accentColor: context.cpColors.ai,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.aiFinancialPreviewTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: CPSpacing.xs),
                      Text(
                        l10n.aiFinancialPreviewSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CPSpacing.md),
                Icon(Icons.fact_check_outlined, color: context.cpColors.ai),
              ],
            ),
            const SizedBox(height: CPSpacing.lg),
            _PreviewField(label: l10n.aiFinancialPreviewType, value: typeLabel),
            _PreviewField(label: l10n.amount, value: amount),
            _PreviewField(
              label: l10n.aiFinancialPreviewDescription,
              value: description,
            ),
            _PreviewField(
              label: l10n.aiFinancialPreviewSuggestedCategory,
              value: CategoryLocalization.name(l10n, category),
            ),
            _PreviewField(label: l10n.account, value: transaction.account.name),
            _PreviewField(label: l10n.aiFinancialPreviewDate, value: dateLabel),
            _PreviewField(label: l10n.status, value: statusLabel),
            if (source?.trim().isNotEmpty == true)
              _PreviewField(
                label: transaction.type == TransactionType.income
                    ? l10n.aiIncomeSourceName
                    : l10n.payeeName,
                value: source!.trim(),
              ),
            _PreviewField(
              label: l10n.paymentMethod,
              value: TransactionUiFormatters.paymentMethodLabel(
                transaction.paymentMethod,
                l10n,
              ),
            ),
            if (transaction.note.trim().isNotEmpty)
              _PreviewField(label: l10n.note, value: transaction.note.trim()),
            if (showCategoryAssumption)
              _PreviewNotice(
                icon: Icons.auto_awesome_outlined,
                message: l10n.aiFinancialPreviewCategoryAssumption,
              ),
            if (warning != null)
              _PreviewNotice(
                icon: Icons.warning_amber_rounded,
                message: warning,
                warning: true,
              ),
            const SizedBox(height: CPSpacing.sm),
            Container(
              padding: const EdgeInsetsDirectional.all(CPSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(CPRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.aiFinancialPreviewStorageEffect,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: CPSpacing.xs),
                  Text(storageEffect),
                ],
              ),
            ),
            const SizedBox(height: CPSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: CPButton(
                    key: const Key('ai_financial_preview_cancel'),
                    label: l10n.aiFinancialPreviewReject,
                    variant: CPButtonVariant.outline,
                    fullWidth: true,
                    onPressed: isExecuting ? null : onReject,
                  ),
                ),
                const SizedBox(width: CPSpacing.sm),
                Expanded(
                  child: CPButton(
                    key: const Key('ai_financial_preview_confirm'),
                    label: l10n.aiFinancialPreviewConfirm,
                    icon: Icons.check_rounded,
                    fullWidth: true,
                    isLoading: isExecuting,
                    onPressed: canConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  AiTransactionDraft get _transactionDraft => switch (draft.action) {
    CreateExpenseDraft(:final transactionDraft) ||
    CreateIncomeDraft(:final transactionDraft) => transactionDraft,
    _ => throw StateError(
      'AiFinancialStoragePreviewCard requires an expense or income draft.',
    ),
  };

  String _storageEffect(
    AppLocalizations l10n,
    AiTransactionDraft transaction,
    String amount,
  ) {
    if (transaction.status == TransactionStatus.pending) {
      return l10n.aiFinancialPreviewPendingEffect;
    }
    return transaction.type == TransactionType.expense
        ? l10n.aiFinancialPreviewPostedExpenseEffect(
            amount,
            transaction.account.name,
          )
        : l10n.aiFinancialPreviewPostedIncomeEffect(
            amount,
            transaction.account.name,
          );
  }

  String _description(AiTransactionDraft transaction) {
    final value = transaction.itemDescription?.trim();
    if (value == null || value.isEmpty) {
      return transaction.note.trim();
    }
    if (!RegExp(r'^[a-z]').hasMatch(value)) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String? _warning(AppLocalizations l10n, AiTransactionDraft transaction) {
    final sourceType = transaction.incomeSourceSuggestion?.sourceType;
    if (sourceType == null || !sourceType.needsSpecialReview) return null;
    return switch (sourceType) {
      IncomeSourceType.debtRepayment => l10n.aiIncomeDebtRepaymentWarning,
      IncomeSourceType.loanProceeds => l10n.aiIncomeLoanWarning,
      IncomeSourceType.refund => l10n.aiIncomeRefundWarning,
      IncomeSourceType.reimbursement => l10n.aiIncomeReimbursementWarning,
      IncomeSourceType.externalTransfer => l10n.aiIncomeExternalTransferWarning,
      _ => l10n.aiIncomeOtherWarning,
    };
  }
}

class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: CPSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: CPSpacing.md),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({
    required this.icon,
    required this.message,
    this.warning = false,
  });

  final IconData icon;
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? context.cpColors.warning
        : Theme.of(context).colorScheme.tertiary;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: CPSpacing.sm),
      child: Container(
        padding: const EdgeInsetsDirectional.all(CPSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(CPRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: CPSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
