import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../budgets/domain/entities/budget.dart';
import '../../../budgets/domain/entities/budget_progress.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../goals/domain/entities/goal.dart';
import '../../../goals/domain/entities/goal_contribution.dart';
import '../../../goals/domain/entities/goal_progress.dart';
import '../../../payment_methods/payment_methods.dart' show PaymentMethod;
import 'ai_intent.dart';
import 'ai_transaction_draft.dart';
import 'ai_transaction_mutation_command.dart';

sealed class AiAction {
  const AiAction();

  AiIntent get intent;

  bool get requiresConfirmation;

  bool get changesMoney;
}

class CreateExpenseDraft extends AiAction {
  const CreateExpenseDraft(this.transactionDraft);

  final AiTransactionDraft transactionDraft;

  @override
  AiIntent get intent => AiIntent.createExpense;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get changesMoney => true;
}

class CreateIncomeDraft extends AiAction {
  const CreateIncomeDraft(this.transactionDraft);

  final AiTransactionDraft transactionDraft;

  @override
  AiIntent get intent => AiIntent.createIncome;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get changesMoney => true;
}

class CreateTransferDraft extends AiAction {
  const CreateTransferDraft({
    required this.sourceAccount,
    required this.destinationAccount,
    required this.sourceAmount,
    this.destinationAmount,
    this.exchangeRate,
    this.note,
  });

  final Account sourceAccount;
  final Account destinationAccount;
  final Money sourceAmount;
  final Money? destinationAmount;
  final ExchangeRate? exchangeRate;
  final String? note;

  @override
  AiIntent get intent => AiIntent.createTransfer;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get changesMoney => true;
}

class CreateCategoryDraft extends AiAction {
  const CreateCategoryDraft({required this.name});

  final String name;

  @override
  AiIntent get intent => AiIntent.createCategory;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get changesMoney => false;
}

class CreateBudgetDraft extends AiAction {
  const CreateBudgetDraft({required this.budget, required this.category});

  final Budget budget;
  final Category category;

  @override
  AiIntent get intent => AiIntent.createBudget;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get changesMoney => false;
}

class CreateGoalDraft extends AiAction {
  const CreateGoalDraft({required this.goal});

  final Goal goal;

  @override
  AiIntent get intent => AiIntent.createGoal;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get changesMoney => false;
}

class AddGoalContributionDraft extends AiAction {
  const AddGoalContributionDraft({
    required this.goal,
    required this.contribution,
  });

  final Goal goal;
  final GoalContribution contribution;

  @override
  AiIntent get intent => AiIntent.addGoalContribution;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get changesMoney => false;
}

class UpdateTransactionDraft extends AiAction {
  const UpdateTransactionDraft({required this.command});

  final UpdateTransactionCommand command;

  @override
  AiIntent get intent => AiIntent.updateTransaction;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get changesMoney => true;
}

class DeleteTransactionDraft extends AiAction {
  const DeleteTransactionDraft({required this.command});

  final DeleteTransactionCommand command;

  @override
  AiIntent get intent => AiIntent.deleteTransaction;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get changesMoney =>
      command.targets.any((target) => target.transaction.affectsBalance);
}

class UndoAiActionDraft extends AiAction {
  const UndoAiActionDraft({required this.command});

  final UndoAiActionCommand command;

  @override
  AiIntent get intent => AiIntent.undoAction;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get changesMoney => true;
}

class AskQuestionAction extends AiAction {
  const AskQuestionAction({required this.question});

  final String question;

  @override
  AiIntent get intent => AiIntent.askFinancialQuestion;

  @override
  bool get requiresConfirmation => false;

  @override
  bool get changesMoney => false;
}

class CurrencyConversionAnswerAction extends AiAction {
  const CurrencyConversionAnswerAction({
    required this.sourceAmount,
    required this.convertedAmount,
  });

  final Money sourceAmount;
  final Money convertedAmount;

  @override
  AiIntent get intent => AiIntent.askFinancialQuestion;

  @override
  bool get requiresConfirmation => false;

  @override
  bool get changesMoney => false;
}

class BudgetProgressAnswerAction extends AiAction {
  const BudgetProgressAnswerAction({required this.progress});

  final BudgetProgress progress;

  @override
  AiIntent get intent => AiIntent.askFinancialQuestion;

  @override
  bool get requiresConfirmation => false;

  @override
  bool get changesMoney => false;
}

class GoalProgressAnswerAction extends AiAction {
  const GoalProgressAnswerAction({required this.progress});

  final GoalProgress progress;

  @override
  AiIntent get intent => AiIntent.askFinancialQuestion;

  @override
  bool get requiresConfirmation => false;

  @override
  bool get changesMoney => false;
}

class ClarificationRequiredAction extends AiAction {
  const ClarificationRequiredAction({required this.message});

  final String message;

  @override
  AiIntent get intent => AiIntent.unknown;

  @override
  bool get requiresConfirmation => false;

  @override
  bool get changesMoney => false;
}

class BlockedAiAction extends AiAction {
  const BlockedAiAction({required this.blockedIntent});

  final AiIntent blockedIntent;

  @override
  AiIntent get intent => blockedIntent;

  @override
  bool get requiresConfirmation => false;

  @override
  bool get changesMoney => false;
}

extension AiTransactionActionX on AiAction {
  AiTransactionDraft? get transactionDraft {
    return switch (this) {
      CreateExpenseDraft(:final transactionDraft) => transactionDraft,
      CreateIncomeDraft(:final transactionDraft) => transactionDraft,
      _ => null,
    };
  }

  Category? get category => transactionDraft?.category;

  Account? get account => transactionDraft?.account;

  Money? get amount {
    return switch (this) {
      CreateTransferDraft(:final sourceAmount) => sourceAmount,
      CurrencyConversionAnswerAction(:final sourceAmount) => sourceAmount,
      CreateBudgetDraft(:final budget) => Money(
        amount: budget.amount,
        currencyCode: budget.currency,
      ),
      CreateGoalDraft(:final goal) => Money(
        amount: goal.targetAmount,
        currencyCode: goal.currency,
      ),
      AddGoalContributionDraft(:final contribution) => Money(
        amount: contribution.amount,
        currencyCode: contribution.currency,
      ),
      BudgetProgressAnswerAction(:final progress) => Money(
        amount: progress.spentAmount,
        currencyCode: progress.budget.currency,
      ),
      GoalProgressAnswerAction(:final progress) => Money(
        amount: progress.currentAmount,
        currencyCode: progress.goal.currency,
      ),
      UpdateTransactionDraft(:final command) =>
        command.updated.transaction.amount,
      DeleteTransactionDraft(:final command) =>
        command.targets.firstOrNull?.transaction.amount,
      UndoAiActionDraft(:final command) =>
        (command.before.firstOrNull ?? command.after.firstOrNull)
            ?.transaction
            .amount,
      _ => transactionDraft?.amount,
    };
  }

  PaymentMethod? get paymentMethod => transactionDraft?.paymentMethod;
}
