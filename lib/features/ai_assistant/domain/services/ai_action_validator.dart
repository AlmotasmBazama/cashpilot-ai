import 'package:decimal/decimal.dart';

import '../../../categories/domain/enums/category_type.dart';
import '../../../income_sources/domain/entities/income_source_suggestion.dart';
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../entities/ai_action.dart';
import '../entities/ai_action_validation_result.dart';
import '../entities/ai_transaction_draft.dart';

class AiActionValidator {
  const AiActionValidator();

  AiActionValidationResult validate(AiAction action) {
    return switch (action) {
      CreateExpenseDraft(:final transactionDraft) ||
      CreateIncomeDraft(
        :final transactionDraft,
      ) => _validateTransactionDraft(action, transactionDraft),
      CreateTransferDraft() => _validateTransferDraft(action),
      CreateBudgetDraft(:final budget, :final category) =>
        budget.amount <= Decimal.zero || category.isArchived
            ? const AiActionValidationResult.invalid(
                'Budget amount and category must be active and valid.',
              )
            : AiActionValidationResult.valid(action),
      CreateGoalDraft(:final goal) =>
        goal.targetAmount <= Decimal.zero || goal.isArchived
            ? const AiActionValidationResult.invalid(
                'Goal target must be positive and active.',
              )
            : AiActionValidationResult.valid(action),
      AddGoalContributionDraft(:final goal, :final contribution) =>
        contribution.amount <= Decimal.zero || goal.isArchived
            ? const AiActionValidationResult.invalid(
                'Contribution must be positive and the goal must be active.',
              )
            : AiActionValidationResult.valid(action),
      UpdateTransactionDraft(:final command) =>
        command.original.transaction.id != command.updated.transaction.id ||
                command.original.transaction.type !=
                    command.updated.transaction.type ||
                command.original.transaction.transferGroupId !=
                    command.updated.transaction.transferGroupId ||
                command.original.transaction.isTransfer ||
                command.updated.transaction.amount.amount <= Decimal.zero ||
                command.updated.transaction.status ==
                    TransactionStatus.cancelled ||
                command.updated.transaction.status == TransactionStatus.failed
            ? const AiActionValidationResult.invalid(
                'The transaction update is not safe.',
              )
            : AiActionValidationResult.valid(action),
      DeleteTransactionDraft(:final command) =>
        command.targets.isEmpty || command.targets.length > 2
            ? const AiActionValidationResult.invalid(
                'The transaction delete target is invalid.',
              )
            : AiActionValidationResult.valid(action),
      UndoAiActionDraft(:final command) =>
        command.sourceCommandId.trim().isEmpty ||
                (command.before.isEmpty && command.after.isEmpty)
            ? const AiActionValidationResult.invalid(
                'The action can no longer be undone safely.',
              )
            : AiActionValidationResult.valid(action),
      CreateCategoryDraft(:final name) =>
        name.trim().isEmpty
            ? const AiActionValidationResult.invalid(
                'Category name is required.',
              )
            : AiActionValidationResult.valid(action),
      AskQuestionAction() => AiActionValidationResult.valid(action),
      CurrencyConversionAnswerAction() => AiActionValidationResult.valid(
        action,
      ),
      BudgetProgressAnswerAction() => AiActionValidationResult.valid(action),
      GoalProgressAnswerAction() => AiActionValidationResult.valid(action),
      ClarificationRequiredAction(:final message) =>
        AiActionValidationResult.needsClarification(message),
      BlockedAiAction() => const AiActionValidationResult.invalid(
        'Destructive AI actions are not supported.',
      ),
    };
  }

  AiActionValidationResult _validateTransactionDraft(
    AiAction action,
    AiTransactionDraft draft,
  ) {
    if (draft.amount.amount <= Decimal.zero) {
      return const AiActionValidationResult.invalid(
        'Amount must be greater than zero.',
      );
    }

    if (draft.account.id == AiTransactionDraft.unresolvedAccountId) {
      return AiActionValidationResult.needsClarification(
        action is CreateIncomeDraft
            ? 'Which account received this income?'
            : 'Which account should I use?',
      );
    }

    if (draft.account.isArchived) {
      return const AiActionValidationResult.invalid(
        'The selected account is archived.',
      );
    }

    if (draft.account.currencyCode.toUpperCase() !=
        draft.amount.currencyCode.toUpperCase()) {
      return const AiActionValidationResult.needsClarification(
        'The transaction currency does not match the selected account.',
      );
    }

    final category = draft.category;
    if (category == null) {
      return const AiActionValidationResult.needsClarification(
        'Which category should I use?',
      );
    }

    if (category.isArchived) {
      return const AiActionValidationResult.invalid(
        'The selected category is archived.',
      );
    }

    final expectedCategoryType = draft.type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
    if (category.type != expectedCategoryType) {
      return const AiActionValidationResult.needsClarification(
        'Choose a category that matches the transaction type.',
      );
    }

    if (draft.status != TransactionStatus.pending &&
        draft.status != TransactionStatus.posted) {
      return const AiActionValidationResult.invalid(
        'Only pending or posted transactions can be created.',
      );
    }

    if (action is CreateIncomeDraft) {
      if (draft.type != TransactionType.income) {
        return const AiActionValidationResult.invalid(
          'The income draft has an invalid transaction type.',
        );
      }
      final suggestion = draft.incomeSourceSuggestion;
      final hasExplicitClassification =
          suggestion != null &&
          !suggestion.requiresClarification &&
          !suggestion.isInternalTransfer &&
          (suggestion.source ==
                  IncomeSourceSuggestionSource.explicitUserInput ||
              suggestion.source == IncomeSourceSuggestionSource.exactPhrase);
      if (!hasExplicitClassification) {
        return const AiActionValidationResult.needsClarification(
          'How should I classify this income source?',
        );
      }
      if (draft.transactionDate == null) {
        return const AiActionValidationResult.needsClarification(
          'What date should I use for this income?',
        );
      }
      if (suggestion.sourceType.requiresSourceIdentity &&
          !_hasIncomeSourceIdentity(draft)) {
        return const AiActionValidationResult.needsClarification(
          'Who or what was the source of this income?',
        );
      }
    } else if (draft.type != TransactionType.expense) {
      return const AiActionValidationResult.invalid(
        'The expense draft has an invalid transaction type.',
      );
    }

    return AiActionValidationResult.valid(action);
  }

  bool _hasIncomeSourceIdentity(AiTransactionDraft draft) {
    return draft.payee != null ||
        (draft.payeeHint?.trim().isNotEmpty ?? false) ||
        (draft.incomeSourceSuggestion?.sourceNameHint?.trim().isNotEmpty ??
            false);
  }

  AiActionValidationResult _validateTransferDraft(CreateTransferDraft action) {
    if (action.sourceAccount.id == action.destinationAccount.id) {
      return const AiActionValidationResult.invalid(
        'Source and destination accounts must be different.',
      );
    }

    if (action.sourceAmount.amount <= Decimal.zero) {
      return const AiActionValidationResult.invalid(
        'Amount must be greater than zero.',
      );
    }

    if (action.sourceAccount.currencyCode.toUpperCase() !=
        action.sourceAmount.currencyCode.toUpperCase()) {
      return const AiActionValidationResult.needsClarification(
        'The transfer currency does not match the source account.',
      );
    }

    final crossCurrency =
        action.sourceAccount.currencyCode.toUpperCase() !=
        action.destinationAccount.currencyCode.toUpperCase();
    if (crossCurrency &&
        action.destinationAmount == null &&
        action.exchangeRate == null) {
      return const AiActionValidationResult.needsClarification(
        'Enter a destination amount or exchange rate for this transfer.',
      );
    }

    return AiActionValidationResult.valid(action);
  }
}
