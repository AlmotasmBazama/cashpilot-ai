import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../budgets/domain/enums/budget_period_type.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/entities/category_suggestion.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization;
import '../../../goals/domain/enums/goal_type.dart';
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/transactions_presentation.dart'
    show TransactionUiFormatters;
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_action_draft.dart';
import '../../domain/entities/ai_action_validation_result.dart';
import '../../domain/entities/ai_transaction_draft.dart';
import '../../domain/entities/ai_transaction_mutation_command.dart';
import 'ai_financial_storage_preview_card.dart';

class AiActionConfirmationCard extends StatelessWidget {
  const AiActionConfirmationCard({
    required this.draft,
    required this.validation,
    required this.onConfirm,
    required this.onEdit,
    required this.onCancel,
    this.categories = const <Category>[],
    this.accounts = const <Account>[],
    this.onCategoryChanged,
    this.onAccountChanged,
    this.onIncomeSourceTypeChanged,
    this.onIncomeSourceNameChanged,
    this.onTransactionDateChanged,
    this.onTransactionStatusChanged,
    this.timeZoneName = 'Africa/Tripoli',
    super.key,
  });

  final AiActionDraft draft;
  final AiActionValidationResult validation;
  final VoidCallback? onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final List<Category> categories;
  final List<Account> accounts;
  final ValueChanged<Category>? onCategoryChanged;
  final ValueChanged<Account>? onAccountChanged;
  final ValueChanged<IncomeSourceType>? onIncomeSourceTypeChanged;
  final ValueChanged<String>? onIncomeSourceNameChanged;
  final ValueChanged<DateTime>? onTransactionDateChanged;
  final ValueChanged<TransactionStatus>? onTransactionStatusChanged;
  final String timeZoneName;

  AiAction get action => draft.action;

  @override
  Widget build(BuildContext context) {
    if (validation.isValid &&
        (action is CreateExpenseDraft || action is CreateIncomeDraft)) {
      return AiFinancialStoragePreviewCard(
        draft: draft,
        onReject: onCancel,
        onConfirm: onConfirm,
        timeZoneName: timeZoneName,
      );
    }
    final l10n = AppLocalizations.of(context);
    final isExecuting = draft.status == AiActionExecutionStatus.executing;
    final canConfirm =
        validation.isValid &&
        action.requiresConfirmation &&
        draft.status == AiActionExecutionStatus.awaitingConfirmation;
    final canEditOrCancel =
        draft.status != AiActionExecutionStatus.executing &&
        draft.status != AiActionExecutionStatus.executed &&
        draft.status != AiActionExecutionStatus.cancelled;
    final statusColor = _statusColor(context);

    return CPCard(
      variant: CPCardVariant.elevated,
      accentColor: context.cpColors.ai,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  validation.isValid
                      ? l10n.aiActionConfirmationTitle
                      : l10n.aiClarificationTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: CPSpacing.md),
              Icon(Icons.verified_user_rounded, color: context.cpColors.ai),
            ],
          ),
          const SizedBox(height: CPSpacing.md),
          Wrap(
            spacing: CPSpacing.sm,
            runSpacing: CPSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AIAccentBadge(label: _title(context, l10n)),
              FinanceStatusPill(
                label: _statusLabel(l10n),
                icon: _statusIcon(),
                color: statusColor,
              ),
            ],
          ),
          if (action.amount case final amount?) ...[
            const SizedBox(height: CPSpacing.lg),
            FinanceAmountText(
              value: FinanceFormatters.money(amount),
              color: _amountColor(context),
            ),
          ],
          const SizedBox(height: CPSpacing.md),
          Text(
            validation.isValid
                ? l10n.aiActionConfirmationMessage
                : validation.message ?? l10n.aiActionInvalidMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: CPSpacing.sm),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ..._rows(context),
          if (!validation.isValid) ...[
            const SizedBox(height: CPSpacing.sm),
            Text(
              validation.message ?? l10n.aiActionInvalidMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.cpColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (action.requiresConfirmation && validation.isValid) ...[
            const SizedBox(height: CPSpacing.md),
            FinanceSafetyNotice(
              title: l10n.aiConfirmationSafetyTitle,
              message: l10n.aiConfirmationSafetyMessage,
              color: context.cpColors.ai,
            ),
          ],
          const SizedBox(height: CPSpacing.lg),
          Wrap(
            spacing: CPSpacing.sm,
            runSpacing: CPSpacing.sm,
            children: [
              if (action.requiresConfirmation)
                CPButton(
                  label: l10n.confirm,
                  icon: Icons.check_rounded,
                  isLoading: isExecuting,
                  onPressed: canConfirm ? onConfirm : null,
                ),
              CPButton(
                label: l10n.edit,
                icon: Icons.edit_outlined,
                variant: CPButtonVariant.tonal,
                onPressed: canEditOrCancel ? onEdit : null,
              ),
              CPButton(
                label: l10n.cancel,
                icon: Icons.close_rounded,
                variant: CPButtonVariant.ghost,
                onPressed: canEditOrCancel ? onCancel : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n) {
    return switch (draft.status) {
      AiActionExecutionStatus.draft => l10n.aiTransactionDraftTitle,
      AiActionExecutionStatus.awaitingConfirmation =>
        l10n.aiAwaitingConfirmationStatus,
      AiActionExecutionStatus.executing => l10n.aiExecutingStatus,
      AiActionExecutionStatus.executed => l10n.aiExecutedStatus,
      AiActionExecutionStatus.cancelled => l10n.transactionStatusCancelled,
      AiActionExecutionStatus.failed => l10n.transactionStatusFailed,
    };
  }

  IconData _statusIcon() {
    return switch (draft.status) {
      AiActionExecutionStatus.draft => Icons.edit_note_rounded,
      AiActionExecutionStatus.awaitingConfirmation => Icons.fact_check_outlined,
      AiActionExecutionStatus.executing => Icons.sync_rounded,
      AiActionExecutionStatus.executed => Icons.check_circle_rounded,
      AiActionExecutionStatus.cancelled => Icons.cancel_outlined,
      AiActionExecutionStatus.failed => Icons.error_outline_rounded,
    };
  }

  Color _statusColor(BuildContext context) {
    return switch (draft.status) {
      AiActionExecutionStatus.draft => context.cpColors.info,
      AiActionExecutionStatus.awaitingConfirmation => context.cpColors.warning,
      AiActionExecutionStatus.executing => context.cpColors.ai,
      AiActionExecutionStatus.executed => context.cpColors.success,
      AiActionExecutionStatus.cancelled => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
      AiActionExecutionStatus.failed => context.cpColors.expense,
    };
  }

  Color _amountColor(BuildContext context) {
    return switch (action) {
      CreateIncomeDraft() => context.cpColors.income,
      CreateExpenseDraft() => context.cpColors.expense,
      CreateTransferDraft() => context.cpColors.transfer,
      UpdateTransactionDraft(:final command) =>
        command.updated.transaction.type == TransactionType.income
            ? context.cpColors.income
            : context.cpColors.expense,
      DeleteTransactionDraft() => context.cpColors.expense,
      UndoAiActionDraft() => context.cpColors.ai,
      _ => Theme.of(context).colorScheme.onSurface,
    };
  }

  String _title(BuildContext context, AppLocalizations l10n) {
    return switch (action) {
      CreateExpenseDraft() => l10n.aiActionExpenseTitle,
      CreateIncomeDraft() => l10n.aiActionIncomeTitle,
      CreateTransferDraft() => l10n.aiActionTransferTitle,
      AskQuestionAction() => l10n.aiActionQuestionTitle,
      CurrencyConversionAnswerAction() => l10n.aiActionQuestionTitle,
      BudgetProgressAnswerAction() => l10n.budgetProgress,
      GoalProgressAnswerAction() => l10n.goalProgress,
      CreateCategoryDraft() => l10n.createCategory,
      CreateBudgetDraft() => l10n.addBudget,
      CreateGoalDraft() => l10n.addGoal,
      AddGoalContributionDraft() => l10n.addContribution,
      UpdateTransactionDraft() =>
        _isArabic(context) ? 'تعديل عملية' : 'Update transaction',
      DeleteTransactionDraft() =>
        _isArabic(context)
            ? 'حذف أو إلغاء عملية'
            : 'Delete or cancel transaction',
      UndoAiActionDraft() =>
        _isArabic(context) ? 'التراجع عن آخر إجراء' : 'Undo last action',
      ClarificationRequiredAction() => l10n.aiClarificationTitle,
      BlockedAiAction() => l10n.aiActionInvalidMessage,
    };
  }

  List<Widget> _rows(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (action) {
      CreateIncomeDraft(:final transactionDraft) => [
        _IncomeSourceTypeEditor(
          selectedType:
              transactionDraft.incomeSourceSuggestion?.requiresClarification ==
                  true
              ? null
              : transactionDraft.incomeSourceSuggestion?.sourceType,
          onChanged: onIncomeSourceTypeChanged,
        ),
        _IncomeSourceNameEditor(
          initialValue:
              transactionDraft.incomeSourceSuggestion?.sourceNameHint ??
              transactionDraft.payee?.name ??
              transactionDraft.payeeHint ??
              '',
          onSubmitted: onIncomeSourceNameChanged,
        ),
        if (transactionDraft.incomeSourceSuggestion?.sourceType
            case final sourceType? when sourceType.needsSpecialReview)
          FinanceSafetyNotice(
            title: l10n.aiIncomeSpecialReviewTitle,
            message: _incomeWarning(l10n, sourceType),
            color: context.cpColors.warning,
          ),
        if (transactionDraft.itemDescription?.trim().isNotEmpty == true)
          FinanceDetailRow(
            label: l10n.aiDetectedItem,
            value: transactionDraft.itemDescription!,
            icon: Icons.receipt_long_outlined,
          ),
        _CategorySuggestionEditor(
          selectedCategory: transactionDraft.category,
          suggestion: transactionDraft.categorySuggestion,
          categories: categories,
          categoryType: transactionDraft.type == TransactionType.income
              ? CategoryType.income
              : CategoryType.expense,
          onChanged: onCategoryChanged,
        ),
        _AccountEditor(
          selectedAccount: transactionDraft.account,
          accounts: accounts,
          onChanged: onAccountChanged,
        ),
        _TransactionDateEditor(
          selectedDate: transactionDraft.transactionDate,
          onChanged: onTransactionDateChanged,
        ),
        _TransactionStatusEditor(
          selectedStatus: transactionDraft.status,
          onChanged: onTransactionStatusChanged,
        ),
        FinanceDetailRow(
          label: l10n.aiParsedPaymentMethod,
          value: TransactionUiFormatters.paymentMethodLabel(
            transactionDraft.paymentMethod,
            l10n,
          ),
          icon: Icons.payments_outlined,
        ),
        if (transactionDraft.payee case final payee?)
          FinanceDetailRow(
            label: l10n.payeeName,
            value: payee.name,
            icon: Icons.storefront_outlined,
          ),
        if (transactionDraft.note.trim().isNotEmpty)
          FinanceDetailRow(
            label: l10n.note,
            value: transactionDraft.note,
            icon: Icons.notes_rounded,
          ),
      ],
      CreateExpenseDraft(:final transactionDraft) => [
        if (transactionDraft.itemDescription?.trim().isNotEmpty == true)
          FinanceDetailRow(
            label: l10n.aiDetectedItem,
            value: transactionDraft.itemDescription!,
            icon: Icons.receipt_long_outlined,
          ),
        _CategorySuggestionEditor(
          selectedCategory: transactionDraft.category,
          suggestion: transactionDraft.categorySuggestion,
          categories: categories,
          categoryType: CategoryType.expense,
          onChanged: onCategoryChanged,
        ),
        _AccountEditor(
          selectedAccount: transactionDraft.account,
          accounts: accounts,
          onChanged: onAccountChanged,
        ),
        FinanceDetailRow(
          label: l10n.aiParsedPaymentMethod,
          value: TransactionUiFormatters.paymentMethodLabel(
            transactionDraft.paymentMethod,
            l10n,
          ),
          icon: Icons.payments_outlined,
        ),
        if (transactionDraft.payee case final payee?)
          FinanceDetailRow(
            label: l10n.payeeName,
            value: payee.name,
            icon: Icons.storefront_outlined,
          ),
        if (transactionDraft.note.trim().isNotEmpty)
          FinanceDetailRow(
            label: l10n.note,
            value: transactionDraft.note,
            icon: Icons.notes_rounded,
          ),
      ],
      CreateTransferDraft(
        :final sourceAccount,
        :final destinationAccount,
        :final sourceAmount,
        :final destinationAmount,
        :final exchangeRate,
        :final note,
      ) =>
        [
          FinanceDetailRow(
            label: l10n.fromAccount,
            value: sourceAccount.name,
            icon: Icons.arrow_upward_rounded,
          ),
          FinanceDetailRow(
            label: l10n.amount,
            value: FinanceFormatters.money(sourceAmount),
            icon: Icons.payments_outlined,
          ),
          FinanceDetailRow(
            label: l10n.toAccount,
            value: destinationAccount.name,
            icon: Icons.arrow_downward_rounded,
          ),
          if (destinationAmount != null)
            FinanceDetailRow(
              label: l10n.destinationAmount,
              value: FinanceFormatters.money(destinationAmount),
              icon: Icons.currency_exchange_rounded,
            ),
          if (exchangeRate != null)
            FinanceDetailRow(
              label: l10n.manualExchangeRateLabel,
              value:
                  '1 ${exchangeRate.fromCurrencyCode.toUpperCase()} = '
                  '${exchangeRate.rate} ${exchangeRate.toCurrencyCode.toUpperCase()}',
              icon: Icons.currency_exchange_rounded,
            ),
          if (note?.trim().isNotEmpty == true)
            FinanceDetailRow(
              label: l10n.note,
              value: note!,
              icon: Icons.notes_rounded,
            ),
        ],
      CreateCategoryDraft(:final name) => [
        FinanceDetailRow(
          label: l10n.categoryName,
          value: name,
          icon: Icons.category_outlined,
        ),
      ],
      CreateBudgetDraft(:final budget, :final category) => [
        FinanceDetailRow(
          label: l10n.category,
          value: CategoryLocalization.name(l10n, category),
          icon: Icons.category_outlined,
        ),
        FinanceDetailRow(
          label: l10n.budgetAmount,
          value: FinanceFormatters.amountWithCurrency(
            budget.amount,
            budget.currency,
          ),
          icon: Icons.account_balance_wallet_outlined,
        ),
        FinanceDetailRow(
          label: l10n.budgetPeriod,
          value: _budgetPeriodLabel(l10n, budget.periodType),
          icon: Icons.date_range_outlined,
        ),
        FinanceDetailRow(
          label: l10n.alertThreshold,
          value: '${budget.alertThresholdPercent}%',
          icon: Icons.notifications_outlined,
        ),
      ],
      CreateGoalDraft(:final goal) => [
        FinanceDetailRow(
          label: l10n.goalTitle,
          value: goal.title,
          icon: Icons.flag_outlined,
        ),
        FinanceDetailRow(
          label: l10n.goalType,
          value: _goalTypeLabel(l10n, goal.type),
          icon: Icons.category_outlined,
        ),
        FinanceDetailRow(
          label: l10n.targetAmount,
          value: FinanceFormatters.amountWithCurrency(
            goal.targetAmount,
            goal.currency,
          ),
          icon: Icons.savings_outlined,
        ),
        if (goal.targetDate case final date?)
          FinanceDetailRow(
            label: l10n.targetDate,
            value: FinanceFormatters.compactDate(
              date,
              Localizations.localeOf(context).toLanguageTag(),
            ),
            icon: Icons.event_outlined,
          ),
      ],
      AddGoalContributionDraft(:final goal, :final contribution) => [
        FinanceDetailRow(
          label: l10n.goalTitle,
          value: goal.title,
          icon: Icons.flag_outlined,
        ),
        FinanceDetailRow(
          label: l10n.contribution,
          value: FinanceFormatters.amountWithCurrency(
            contribution.amount,
            contribution.currency,
          ),
          icon: Icons.add_circle_outline_rounded,
        ),
        FinanceDetailRow(
          label: l10n.goalTrackingOnly,
          value: l10n.goalTrackingOnly,
          icon: Icons.timeline_outlined,
        ),
      ],
      UpdateTransactionDraft(:final command) => _updateRows(context, command),
      DeleteTransactionDraft(:final command) => _deleteRows(context, command),
      UndoAiActionDraft(:final command) => _undoRows(context, command),
      AskQuestionAction(:final question) => [
        FinanceDetailRow(
          label: l10n.aiActionQuestionTitle,
          value: question,
          icon: Icons.help_outline_rounded,
        ),
      ],
      CurrencyConversionAnswerAction(
        :final sourceAmount,
        :final convertedAmount,
      ) =>
        [
          FinanceDetailRow(
            label: l10n.originalCurrency,
            value: FinanceFormatters.money(sourceAmount),
            icon: Icons.payments_outlined,
          ),
          FinanceDetailRow(
            label: l10n.convertedTotal,
            value: FinanceFormatters.money(convertedAmount),
            icon: Icons.currency_exchange_rounded,
          ),
        ],
      BudgetProgressAnswerAction(:final progress) => [
        FinanceDetailRow(
          label: l10n.budgetName,
          value: progress.budget.name,
          icon: Icons.pie_chart_outline_rounded,
        ),
        FinanceDetailRow(
          label: l10n.spent,
          value: FinanceFormatters.amountWithCurrency(
            progress.spentAmount,
            progress.budget.currency,
          ),
          icon: Icons.payments_outlined,
        ),
        FinanceDetailRow(
          label: l10n.remaining,
          value: FinanceFormatters.amountWithCurrency(
            progress.remainingAmount,
            progress.budget.currency,
          ),
          icon: Icons.savings_outlined,
        ),
      ],
      GoalProgressAnswerAction(:final progress) => [
        FinanceDetailRow(
          label: l10n.goalTitle,
          value: progress.goal.title,
          icon: Icons.flag_outlined,
        ),
        FinanceDetailRow(
          label: l10n.currentAmount,
          value: FinanceFormatters.amountWithCurrency(
            progress.currentAmount,
            progress.goal.currency,
          ),
          icon: Icons.savings_outlined,
        ),
        FinanceDetailRow(
          label: l10n.remainingAmount,
          value: FinanceFormatters.amountWithCurrency(
            progress.remainingAmount,
            progress.goal.currency,
          ),
          icon: Icons.flag_outlined,
        ),
      ],
      ClarificationRequiredAction(:final message) => [
        FinanceDetailRow(
          label: l10n.aiClarificationTitle,
          value: message,
          icon: Icons.question_mark_rounded,
        ),
      ],
      BlockedAiAction() => [
        FinanceDetailRow(
          label: l10n.aiActionInvalidMessage,
          value: l10n.aiActionInvalidMessage,
          icon: Icons.block_rounded,
        ),
      ],
    };
  }

  List<Widget> _updateRows(
    BuildContext context,
    UpdateTransactionCommand command,
  ) {
    final ar = _isArabic(context);
    final before = command.original;
    final after = command.updated;
    final rows = <Widget>[
      FinanceDetailRow(
        label: ar ? 'نوع العملية' : 'Transaction type',
        value: before.transaction.type.name,
        icon: Icons.receipt_long_outlined,
      ),
      FinanceDetailRow(
        label: ar ? 'المبلغ' : 'Amount',
        value: before.transaction.amount == after.transaction.amount
            ? FinanceFormatters.money(before.transaction.amount)
            : '${FinanceFormatters.money(before.transaction.amount)}  →  '
                  '${FinanceFormatters.money(after.transaction.amount)}',
        icon: Icons.payments_outlined,
      ),
      FinanceDetailRow(
        label: ar ? 'الحساب' : 'Account',
        value: before.transaction.accountId == after.transaction.accountId
            ? before.accountName
            : '${before.accountName}  →  ${after.accountName}',
        icon: Icons.account_balance_wallet_outlined,
      ),
      FinanceDetailRow(
        label: ar ? 'الحالة' : 'Status',
        value: before.transaction.status == after.transaction.status
            ? before.transaction.status.name
            : '${before.transaction.status.name}  →  '
                  '${after.transaction.status.name}',
        icon: Icons.sync_alt_rounded,
      ),
    ];
    void changed(
      bool condition,
      String arLabel,
      String enLabel,
      String oldValue,
      String newValue,
      IconData icon,
    ) {
      if (!condition) return;
      rows.add(
        FinanceDetailRow(
          label: ar ? arLabel : enLabel,
          value: '$oldValue  →  $newValue',
          icon: icon,
        ),
      );
    }

    changed(
      before.transaction.categoryId != after.transaction.categoryId,
      'التصنيف',
      'Category',
      before.categoryName,
      after.categoryName,
      Icons.category_outlined,
    );
    changed(
      before.transaction.payeeId != after.transaction.payeeId,
      'المستفيد أو المصدر',
      'Payee or source',
      before.payeeName ?? '—',
      after.payeeName ?? '—',
      Icons.storefront_outlined,
    );
    changed(
      before.transaction.paymentMethod != after.transaction.paymentMethod,
      'طريقة الدفع',
      'Payment method',
      before.transaction.paymentMethod.name,
      after.transaction.paymentMethod.name,
      Icons.credit_card_outlined,
    );
    changed(
      before.transaction.transactionDate != after.transaction.transactionDate,
      'التاريخ',
      'Date',
      FinanceFormatters.compactDate(
        before.transaction.transactionDate,
        Localizations.localeOf(context).toLanguageTag(),
      ),
      FinanceFormatters.compactDate(
        after.transaction.transactionDate,
        Localizations.localeOf(context).toLanguageTag(),
      ),
      Icons.event_outlined,
    );
    changed(
      before.transaction.note != after.transaction.note,
      'الملاحظة',
      'Note',
      before.transaction.note ?? '—',
      after.transaction.note ?? '—',
      Icons.notes_rounded,
    );
    changed(
      before.transaction.location != after.transaction.location,
      'الموقع',
      'Location',
      before.transaction.location ?? '—',
      after.transaction.location ?? '—',
      Icons.location_on_outlined,
    );
    changed(
      before.transaction.incomeSourceType != after.transaction.incomeSourceType,
      'تصنيف مصدر الدخل',
      'Income-source classification',
      before.transaction.incomeSourceType?.storageValue ?? '—',
      after.transaction.incomeSourceType?.storageValue ?? '—',
      Icons.work_outline_rounded,
    );
    rows.add(
      FinanceDetailRow(
        label: ar ? 'الأثر المتوقع على الرصيد' : 'Expected balance effect',
        value: _balanceEffectText(command, ar),
        icon: Icons.account_balance_outlined,
      ),
    );
    if (before.transaction.affectsBalance || after.transaction.affectsBalance) {
      rows.add(
        FinanceSafetyNotice(
          title: ar ? 'تنبيه مالي' : 'Financial warning',
          message: _financialWarningText(command, ar),
          color: context.cpColors.warning,
        ),
      );
    }
    return rows;
  }

  List<Widget> _deleteRows(
    BuildContext context,
    DeleteTransactionCommand command,
  ) {
    final ar = _isArabic(context);
    final rows = <Widget>[];
    for (var index = 0; index < command.targets.length; index++) {
      final target = command.targets[index];
      final transaction = target.transaction;
      if (command.targets.length == 2) {
        rows.add(
          FinanceDetailRow(
            label: ar
                ? 'طرف التحويل ${index + 1}'
                : 'Transfer leg ${index + 1}',
            value:
                '${target.accountName} — ${FinanceFormatters.money(transaction.amount)}',
            icon: transaction.type == TransactionType.transferOut
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
          ),
        );
      } else {
        rows.addAll(<Widget>[
          FinanceDetailRow(
            label: ar ? 'العملية' : 'Transaction',
            value: transaction.note ?? target.payeeName ?? target.categoryName,
            icon: Icons.receipt_long_outlined,
          ),
          FinanceDetailRow(
            label: ar ? 'المبلغ' : 'Amount',
            value: FinanceFormatters.money(transaction.amount),
            icon: Icons.payments_outlined,
          ),
          FinanceDetailRow(
            label: ar ? 'الحساب' : 'Account',
            value: target.accountName,
            icon: Icons.account_balance_wallet_outlined,
          ),
          FinanceDetailRow(
            label: ar ? 'التصنيف أو المصدر' : 'Category or source',
            value: target.payeeName ?? target.categoryName,
            icon: Icons.category_outlined,
          ),
          FinanceDetailRow(
            label: ar ? 'التاريخ والحالة' : 'Date and status',
            value:
                '${FinanceFormatters.compactDate(transaction.transactionDate, Localizations.localeOf(context).toLanguageTag())} — ${transaction.status.name}',
            icon: Icons.event_outlined,
          ),
        ]);
      }
    }
    final posted = command.targets.any(
      (target) => target.transaction.affectsBalance,
    );
    rows.addAll(<Widget>[
      FinanceDetailRow(
        label: ar ? 'تغيير الرصيد' : 'Balance change',
        value: posted
            ? _deleteBalanceChangeText(command, ar)
            : (ar ? 'بدون أثر على الرصيد.' : 'No balance effect.'),
        icon: Icons.account_balance_outlined,
      ),
      FinanceDetailRow(
        label: ar ? 'إمكانية التراجع' : 'Undo availability',
        value: command.targets.first.transaction.isTransfer
            ? (ar
                  ? 'غير متاح لاستعادة التحويل إلا إذا ثبتت السلامة.'
                  : 'Transfer restoration is unavailable unless proven safe.')
            : (ar
                  ? 'متاح لمدة 24 ساعة إذا لم تتغير العملية.'
                  : 'Available for 24 hours if the target remains unchanged.'),
        icon: Icons.undo_rounded,
      ),
    ]);
    return rows;
  }

  List<Widget> _undoRows(BuildContext context, UndoAiActionCommand command) {
    final ar = _isArabic(context);
    final target = command.before.firstOrNull ?? command.after.firstOrNull;
    return <Widget>[
      FinanceDetailRow(
        label: ar ? 'الإجراء الأصلي' : 'Original action',
        value: command.sourceToolId,
        icon: Icons.history_rounded,
      ),
      if (target != null)
        FinanceDetailRow(
          label: ar ? 'العملية' : 'Transaction',
          value:
              '${FinanceFormatters.money(target.transaction.amount)} — ${target.accountName}',
          icon: Icons.receipt_long_outlined,
        ),
      FinanceDetailRow(
        label: ar ? 'قاعدة التراجع' : 'Undo rule',
        value: ar
            ? 'تراجع واحد فقط، مرتبط بنفس المالك ونسخة العملية.'
            : 'One-time only, bound to the same owner and operation revision.',
        icon: Icons.verified_user_outlined,
      ),
    ];
  }

  String _balanceEffectText(UpdateTransactionCommand command, bool ar) {
    final before = command.original.transaction;
    final after = command.updated.transaction;
    if (before.accountId == after.accountId &&
        before.amount.normalizedCurrencyCode ==
            after.amount.normalizedCurrencyCode) {
      final delta = _postedEffect(after) - _postedEffect(before);
      final sign = delta > Decimal.zero ? '+' : '';
      return ar
          ? 'صافي الأثر الإضافي: $sign$delta '
                '${after.amount.normalizedCurrencyCode}.'
          : 'Net additional effect: $sign$delta '
                '${after.amount.normalizedCurrencyCode}.';
    }
    if (!before.affectsBalance && !after.affectsBalance) {
      return ar ? 'بدون أثر على الرصيد.' : 'No balance effect.';
    }
    if (before.affectsBalance && !after.affectsBalance) {
      return ar
          ? 'عكس الأثر السابق مرة واحدة.'
          : 'Reverse the previous effect once.';
    }
    if (!before.affectsBalance && after.affectsBalance) {
      return ar
          ? 'تطبيق الأثر الجديد مرة واحدة.'
          : 'Apply the new effect once.';
    }
    return ar
        ? 'عكس الأثر القديم ثم تطبيق الجديد ذريًا.'
        : 'Reverse the old effect, then apply the new effect atomically.';
  }

  String _financialWarningText(UpdateTransactionCommand command, bool ar) {
    final before = command.original.transaction;
    final after = command.updated.transaction;
    if (before.affectsBalance && after.affectsBalance) {
      return ar
          ? 'سيتم عكس أثر العملية المنشورة القديمة ثم تطبيق الأثر الجديد ذريًا.'
          : 'The old posted effect will be reversed before the new effect is applied atomically.';
    }
    if (before.affectsBalance) {
      return ar
          ? 'سيتم عكس الأثر المنشور السابق مرة واحدة.'
          : 'The previous posted effect will be reversed once.';
    }
    return ar
        ? 'سيتم تطبيق الأثر المنشور الجديد مرة واحدة.'
        : 'The new posted effect will be applied once.';
  }

  String _deleteBalanceChangeText(DeleteTransactionCommand command, bool ar) {
    if (command.targets.length != 1) {
      return ar
          ? 'سيتم عكس أثر كل طرف منشور مرة واحدة.'
          : 'Each posted leg will be reversed once.';
    }
    final transaction = command.targets.single.transaction;
    final delta = -_postedEffect(transaction);
    final sign = delta > Decimal.zero ? '+' : '';
    return ar
        ? 'صافي تغيير الرصيد: $sign$delta '
              '${transaction.amount.normalizedCurrencyCode}.'
        : 'Net balance change: $sign$delta '
              '${transaction.amount.normalizedCurrencyCode}.';
  }

  Decimal _postedEffect(Transaction transaction) {
    if (!transaction.affectsBalance) return Decimal.zero;
    return switch (transaction.type) {
      TransactionType.income ||
      TransactionType.transferIn => transaction.amount.amount,
      TransactionType.expense ||
      TransactionType.transferOut => -transaction.amount.amount,
    };
  }

  bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  String _budgetPeriodLabel(
    AppLocalizations l10n,
    BudgetPeriodType periodType,
  ) {
    return switch (periodType) {
      BudgetPeriodType.weekly => l10n.weekly,
      BudgetPeriodType.monthly => l10n.monthly,
      BudgetPeriodType.yearly => l10n.yearly,
      BudgetPeriodType.custom => l10n.customPeriod,
    };
  }

  String _goalTypeLabel(AppLocalizations l10n, GoalType type) {
    return switch (type) {
      GoalType.savings => l10n.savingsGoal,
      GoalType.emergencyFund => l10n.emergencyFund,
      GoalType.debtPayoff => l10n.debtPayoff,
      GoalType.purchase => l10n.purchaseGoal,
      GoalType.custom => l10n.customGoal,
    };
  }

  String _incomeWarning(AppLocalizations l10n, IncomeSourceType sourceType) {
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

class _IncomeSourceTypeEditor extends StatelessWidget {
  const _IncomeSourceTypeEditor({
    required this.selectedType,
    required this.onChanged,
  });

  final IncomeSourceType? selectedType;
  final ValueChanged<IncomeSourceType>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: CPSpacing.sm),
      child: DropdownButtonFormField<IncomeSourceType>(
        key: const Key('ai_income_source_type_selector'),
        initialValue: selectedType,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.aiIncomeSourceType,
          hintText: l10n.aiCategoryConfidenceNeedsChoice,
          prefixIcon: const Icon(Icons.call_received_rounded),
        ),
        items: [
          for (final type in IncomeSourceType.values)
            DropdownMenuItem<IncomeSourceType>(
              value: type,
              child: Text(_incomeSourceTypeLabel(l10n, type)),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (value) {
                if (value != null) {
                  onChanged?.call(value);
                }
              },
      ),
    );
  }
}

class _IncomeSourceNameEditor extends StatefulWidget {
  const _IncomeSourceNameEditor({
    required this.initialValue,
    required this.onSubmitted,
  });

  final String initialValue;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_IncomeSourceNameEditor> createState() =>
      _IncomeSourceNameEditorState();
}

class _IncomeSourceNameEditorState extends State<_IncomeSourceNameEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _IncomeSourceNameEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final normalized = _controller.text.trim();
    if (normalized.isNotEmpty && normalized != widget.initialValue.trim()) {
      widget.onSubmitted?.call(normalized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: CPSpacing.sm),
      child: TextFormField(
        key: const Key('ai_income_source_name'),
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.onSubmitted != null,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: l10n.aiIncomeSourceName,
          hintText: l10n.aiIncomeSourceIdentityHint,
          prefixIcon: const Icon(Icons.person_outline_rounded),
          suffixIcon: IconButton(
            key: const Key('ai_income_source_name_apply'),
            tooltip: l10n.save,
            onPressed: widget.onSubmitted == null ? null : _commit,
            icon: const Icon(Icons.check_rounded),
          ),
        ),
        onFieldSubmitted: (_) => _commit(),
        onTapOutside: (_) {
          _commit();
          _focusNode.unfocus();
        },
      ),
    );
  }
}

class _TransactionDateEditor extends StatelessWidget {
  const _TransactionDateEditor({
    required this.selectedDate,
    required this.onChanged,
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final value = selectedDate == null
        ? l10n.aiCategoryConfidenceNeedsChoice
        : FinanceFormatters.compactDate(selectedDate!, locale);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: CPSpacing.sm),
      child: OutlinedButton.icon(
        key: const Key('ai_transaction_date_selector'),
        onPressed: onChanged == null
            ? null
            : () async {
                final now = DateTime.now();
                final initial = selectedDate?.toLocal() ?? now;
                final selected = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(now.year - 20),
                  lastDate: DateTime(now.year + 1),
                );
                if (selected != null) {
                  onChanged?.call(
                    DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                    ).toUtc(),
                  );
                }
              },
        icon: const Icon(Icons.event_outlined),
        label: Text('${l10n.transactionDate}: $value'),
      ),
    );
  }
}

class _TransactionStatusEditor extends StatelessWidget {
  const _TransactionStatusEditor({
    required this.selectedStatus,
    required this.onChanged,
  });

  final TransactionStatus selectedStatus;
  final ValueChanged<TransactionStatus>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: CPSpacing.sm),
      child: DropdownButtonFormField<TransactionStatus>(
        key: const Key('ai_transaction_status_selector'),
        initialValue: selectedStatus,
        decoration: InputDecoration(
          labelText: l10n.status,
          prefixIcon: const Icon(Icons.pending_actions_outlined),
        ),
        items: <DropdownMenuItem<TransactionStatus>>[
          DropdownMenuItem(
            value: TransactionStatus.posted,
            child: Text(l10n.transactionStatusPosted),
          ),
          DropdownMenuItem(
            value: TransactionStatus.pending,
            child: Text(l10n.transactionStatusPending),
          ),
        ],
        onChanged: onChanged == null
            ? null
            : (value) {
                if (value != null) {
                  onChanged?.call(value);
                }
              },
      ),
    );
  }
}

class _AccountEditor extends StatelessWidget {
  const _AccountEditor({
    required this.selectedAccount,
    required this.accounts,
    required this.onChanged,
  });

  final Account selectedAccount;
  final List<Account> accounts;
  final ValueChanged<Account>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = accounts
        .where((account) => !account.isArchived)
        .toList(growable: false);
    if (onChanged == null || available.isEmpty) {
      return FinanceDetailRow(
        label: l10n.aiParsedAccount,
        value: selectedAccount.id == AiTransactionDraft.unresolvedAccountId
            ? l10n.aiSelectDestinationAccount
            : selectedAccount.name,
        icon: Icons.account_balance_wallet_outlined,
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: CPSpacing.sm),
      child: DropdownButtonFormField<String>(
        key: const Key('ai_destination_account_selector'),
        initialValue:
            available.any((account) => account.id == selectedAccount.id)
            ? selectedAccount.id
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.aiIncomeDestinationAccount,
          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
        ),
        items: [
          for (final account in available)
            DropdownMenuItem<String>(
              value: account.id,
              child: Text('${account.name} · ${account.currencyCode}'),
            ),
        ],
        onChanged: (id) {
          final account = available
              .where((candidate) => candidate.id == id)
              .firstOrNull;
          if (account != null) {
            onChanged?.call(account);
          }
        },
      ),
    );
  }
}

String _incomeSourceTypeLabel(AppLocalizations l10n, IncomeSourceType type) {
  return switch (type) {
    IncomeSourceType.salary => l10n.incomeSourceSalary,
    IncomeSourceType.freelance => l10n.incomeSourceFreelance,
    IncomeSourceType.businessRevenue => l10n.incomeSourceBusinessRevenue,
    IncomeSourceType.gift => l10n.incomeSourceGift,
    IncomeSourceType.debtRepayment => l10n.incomeSourceDebtRepayment,
    IncomeSourceType.allowance => l10n.incomeSourceAllowance,
    IncomeSourceType.refund => l10n.incomeSourceRefund,
    IncomeSourceType.sale => l10n.incomeSourceSale,
    IncomeSourceType.rentalIncome => l10n.incomeSourceRentalIncome,
    IncomeSourceType.governmentSupport => l10n.incomeSourceGovernmentSupport,
    IncomeSourceType.scholarship => l10n.incomeSourceScholarship,
    IncomeSourceType.investmentReturn => l10n.incomeSourceInvestmentReturn,
    IncomeSourceType.reimbursement => l10n.incomeSourceReimbursement,
    IncomeSourceType.prize => l10n.incomeSourcePrize,
    IncomeSourceType.loanProceeds => l10n.incomeSourceLoanProceeds,
    IncomeSourceType.externalTransfer => l10n.incomeSourceExternalTransfer,
    IncomeSourceType.other => l10n.incomeSourceOther,
  };
}

class _CategorySuggestionEditor extends StatelessWidget {
  const _CategorySuggestionEditor({
    required this.selectedCategory,
    required this.suggestion,
    required this.categories,
    required this.categoryType,
    required this.onChanged,
  });

  final Category? selectedCategory;
  final CategorySuggestion? suggestion;
  final List<Category> categories;
  final CategoryType categoryType;
  final ValueChanged<Category>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = categories
        .where(
          (category) => category.type == categoryType && !category.isArchived,
        )
        .toList(growable: false);
    final canEdit = onChanged != null && available.isNotEmpty;
    final suggestionValue = suggestion;
    final confidenceLabel = switch (suggestionValue?.confidenceLevel) {
      CategoryConfidenceLevel.high => l10n.aiCategoryConfidenceHigh,
      CategoryConfidenceLevel.medium => l10n.aiCategoryConfidenceSuggested,
      CategoryConfidenceLevel.low ||
      null => l10n.aiCategoryConfidenceNeedsChoice,
    };
    final sourceLabel = switch (suggestionValue?.source) {
      CategorySuggestionSource.explicitUserInput =>
        l10n.aiCategorySourceExplicit,
      CategorySuggestionSource.userRule => l10n.aiCategorySourceUserRule,
      CategorySuggestionSource.payeeDefault => l10n.aiCategorySourcePayee,
      CategorySuggestionSource.exactAlias => l10n.aiCategorySourceAlias,
      CategorySuggestionSource.aiSemantic => l10n.aiCategorySourceAi,
      CategorySuggestionSource.localKeyword => l10n.aiCategorySourceKeyword,
      CategorySuggestionSource.fallback ||
      null => l10n.aiCategorySourceFallback,
    };

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: CPSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canEdit)
            DropdownButtonFormField<String>(
              key: const Key('ai_category_selector'),
              initialValue:
                  available.any(
                    (category) => category.id == selectedCategory?.id,
                  )
                  ? selectedCategory?.id
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.aiSuggestedCategory,
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              items: [
                for (final category in available)
                  DropdownMenuItem<String>(
                    key: Key('ai_category_option_${category.id}'),
                    value: category.id,
                    child: Text(CategoryLocalization.name(l10n, category)),
                  ),
              ],
              onChanged: (id) {
                if (id == null) {
                  return;
                }
                final category = available
                    .where((candidate) => candidate.id == id)
                    .firstOrNull;
                if (category != null) {
                  onChanged?.call(category);
                }
              },
            )
          else
            FinanceDetailRow(
              label: l10n.aiSuggestedCategory,
              value: selectedCategory == null
                  ? '-'
                  : CategoryLocalization.name(l10n, selectedCategory!),
              icon: Icons.category_outlined,
            ),
          const SizedBox(height: CPSpacing.xs),
          Text(
            '$confidenceLabel · $sourceLabel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color:
                  suggestionValue?.confidenceLevel ==
                      CategoryConfidenceLevel.low
                  ? context.cpColors.warning
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
