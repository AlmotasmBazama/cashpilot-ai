import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization;
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../application/services/ai_assistant_conversation_workflow_controller.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_transaction_draft.dart';
import '../../domain/entities/ai_transaction_mutation_command.dart';
import '../support/ai_financial_date_formatter.dart';

class AiVerifiedActionCard extends StatelessWidget {
  const AiVerifiedActionCard({
    required this.verifiedAction,
    required this.onUndo,
    this.timeZoneName = 'Africa/Tripoli',
    this.clock,
    super.key,
  });

  final AiAssistantVerifiedAction verifiedAction;
  final VoidCallback onUndo;
  final String timeZoneName;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context);
    final action = verifiedAction.action;
    return CPCard(
      variant: CPCardVariant.elevated,
      accentColor: context.cpColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: context.cpColors.success),
              const SizedBox(width: CPSpacing.sm),
              Expanded(
                child: Text(
                  _title(action, ar, l10n),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          ..._details(context, action, ar, l10n),
          if (verifiedAction.result.undoAvailable) ...[
            const SizedBox(height: CPSpacing.md),
            CPButton(
              label: ar ? 'تراجع' : 'Undo',
              icon: Icons.undo_rounded,
              variant: CPButtonVariant.tonal,
              onPressed: onUndo,
            ),
          ],
        ],
      ),
    );
  }

  String _title(AiAction action, bool ar, AppLocalizations l10n) {
    return switch (action) {
      UpdateTransactionDraft() =>
        ar ? 'تم تعديل العملية' : 'Transaction updated',
      DeleteTransactionDraft(:final command) =>
        command.targets.any((item) => item.transaction.affectsBalance)
            ? (ar
                  ? 'تم حذف العملية وعكس أثرها المالي'
                  : 'Transaction deleted and financial effect reversed')
            : (ar ? 'تم حذف العملية' : 'Transaction deleted'),
      UndoAiActionDraft() =>
        ar ? 'تم التراجع عن التغيير' : 'The change was undone',
      CreateExpenseDraft() => l10n.aiFinancialExpenseSaved,
      CreateIncomeDraft() => l10n.aiFinancialIncomeSaved,
      CreateTransferDraft() => ar ? 'تم حفظ التحويل' : 'Transfer saved',
      _ => ar ? 'تم تنفيذ الإجراء والتحقق منه' : 'Action verified',
    };
  }

  List<Widget> _details(
    BuildContext context,
    AiAction action,
    bool ar,
    AppLocalizations l10n,
  ) {
    return switch (action) {
      UpdateTransactionDraft(:final command) => <Widget>[
        const SizedBox(height: CPSpacing.md),
        Text(
          ar ? 'قبل' : 'Before',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Text(_summary(command.original)),
        const SizedBox(height: CPSpacing.xs),
        Text(
          ar ? 'بعد' : 'After',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Text(_summary(command.updated)),
      ],
      DeleteTransactionDraft(:final command) => <Widget>[
        const SizedBox(height: CPSpacing.md),
        for (final target in command.targets) Text(_summary(target)),
      ],
      UndoAiActionDraft() => const <Widget>[],
      CreateExpenseDraft(:final transactionDraft) ||
      CreateIncomeDraft(:final transactionDraft) => <Widget>[
        const SizedBox(height: CPSpacing.md),
        Text(
          l10n.aiFinancialSavedSummary(
            FinanceFormatters.money(transactionDraft.amount),
            _description(transactionDraft),
          ),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: CPSpacing.xs),
        Text(
          l10n.aiFinancialSavedCategory(
            CategoryLocalization.name(l10n, transactionDraft.category!),
          ),
        ),
        Text(l10n.aiFinancialSavedAccount(transactionDraft.account.name)),
        Text(
          l10n.aiFinancialSavedDate(
            _dateLabel(context, transactionDraft, l10n),
          ),
        ),
        Text(
          l10n.aiFinancialSavedStatus(
            transactionDraft.status == TransactionStatus.posted
                ? l10n.transactionStatusPosted
                : l10n.transactionStatusPending,
          ),
        ),
      ],
      _ => const <Widget>[],
    };
  }

  String _description(AiTransactionDraft transactionDraft) {
    final item = transactionDraft.itemDescription?.trim();
    final value = item == null || item.isEmpty
        ? transactionDraft.note.trim()
        : item;
    if (!RegExp(r'^[a-z]').hasMatch(value)) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _dateLabel(
    BuildContext context,
    AiTransactionDraft transactionDraft,
    AppLocalizations l10n,
  ) {
    final date = transactionDraft.transactionDate ?? DateTime.now();
    return AiFinancialDateFormatter.label(
      date: date,
      timeZoneName: timeZoneName,
      localeName: Localizations.localeOf(context).toLanguageTag(),
      todayLabel: l10n.aiFinancialPreviewToday,
      now: clock?.call(),
    );
  }

  String _summary(AiTransactionTargetSnapshot snapshot) {
    return '${FinanceFormatters.money(snapshot.transaction.amount)} — '
        '${snapshot.categoryName} — ${snapshot.accountName}';
  }
}
