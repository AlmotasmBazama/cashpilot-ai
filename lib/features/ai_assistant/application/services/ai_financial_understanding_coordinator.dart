import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../budgets/domain/entities/budget_progress.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../exchange_rates/domain/entities/stored_exchange_rate.dart';
import '../../../goals/domain/entities/goal.dart';
import '../../../goals/domain/entities/goal_progress.dart';
import '../../../payees/domain/entities/payee.dart';
import '../../domain/entities/ai_understanding_result.dart';
import '../../domain/usecases/understand_ai_message.dart';

typedef AiFinancialContextLoader<T> = Future<AppResult<List<T>>> Function();
typedef AiFinancialOperationIsCurrent = bool Function();
typedef AiBaseCurrencyCodeReader = String Function();

final class AiFinancialUnderstandingRequest {
  const AiFinancialUnderstandingRequest({
    required this.input,
    required this.locale,
    required this.accountClarificationMessage,
    required this.expenseAccountClarificationMessage,
    required this.ambiguousPayeeMessage,
    required this.exchangeRateClarificationMessage,
    required this.categoryClarificationMessage,
    required this.goalClarificationMessage,
    required this.unknownIntentClarificationMessage,
    required this.explicitlyConfirmedMutation,
  });

  final String input;
  final String locale;
  final String accountClarificationMessage;
  final String expenseAccountClarificationMessage;
  final String ambiguousPayeeMessage;
  final String exchangeRateClarificationMessage;
  final String categoryClarificationMessage;
  final String goalClarificationMessage;
  final String unknownIntentClarificationMessage;
  final bool explicitlyConfirmedMutation;
}

sealed class AiFinancialUnderstandingOutcome {
  const AiFinancialUnderstandingOutcome();
}

final class AiFinancialUnderstandingCompleted
    extends AiFinancialUnderstandingOutcome {
  const AiFinancialUnderstandingCompleted({
    required this.understanding,
    required this.accounts,
    required this.categories,
  });

  final AiUnderstandingResult understanding;
  final List<Account> accounts;
  final List<Category> categories;
}

final class AiFinancialUnderstandingFailed
    extends AiFinancialUnderstandingOutcome {
  const AiFinancialUnderstandingFailed(this.failure);

  final Failure failure;
}

final class AiFinancialUnderstandingSuperseded
    extends AiFinancialUnderstandingOutcome {
  const AiFinancialUnderstandingSuperseded();
}

final class AiFinancialUnderstandingCoordinator {
  const AiFinancialUnderstandingCoordinator({
    required AiBaseCurrencyCodeReader readBaseCurrencyCode,
    required AiFinancialContextLoader<Account> loadAccounts,
    required AiFinancialContextLoader<Category> loadCategories,
    required AiFinancialContextLoader<Payee> loadPayees,
    required AiFinancialContextLoader<StoredExchangeRate> loadExchangeRates,
    required AiFinancialContextLoader<BudgetProgress> loadBudgetProgress,
    required AiFinancialContextLoader<Goal> loadGoals,
    required AiFinancialContextLoader<GoalProgress> loadGoalProgress,
  }) : _readBaseCurrencyCode = readBaseCurrencyCode,
       _loadAccounts = loadAccounts,
       _loadCategories = loadCategories,
       _loadPayees = loadPayees,
       _loadExchangeRates = loadExchangeRates,
       _loadBudgetProgress = loadBudgetProgress,
       _loadGoals = loadGoals,
       _loadGoalProgress = loadGoalProgress;

  final AiBaseCurrencyCodeReader _readBaseCurrencyCode;
  final AiFinancialContextLoader<Account> _loadAccounts;
  final AiFinancialContextLoader<Category> _loadCategories;
  final AiFinancialContextLoader<Payee> _loadPayees;
  final AiFinancialContextLoader<StoredExchangeRate> _loadExchangeRates;
  final AiFinancialContextLoader<BudgetProgress> _loadBudgetProgress;
  final AiFinancialContextLoader<Goal> _loadGoals;
  final AiFinancialContextLoader<GoalProgress> _loadGoalProgress;

  Future<AiFinancialUnderstandingOutcome> understand({
    required UnderstandAiMessage understandingUseCase,
    required AiFinancialUnderstandingRequest request,
    required AiFinancialOperationIsCurrent isCurrent,
  }) async {
    final accountsResult = await _loadAccounts();
    if (!isCurrent()) return const AiFinancialUnderstandingSuperseded();
    final categoriesResult = await _loadCategories();
    if (!isCurrent()) return const AiFinancialUnderstandingSuperseded();
    final payeesResult = await _loadPayees();
    if (!isCurrent()) return const AiFinancialUnderstandingSuperseded();
    final exchangeRatesResult = await _loadExchangeRates();
    if (!isCurrent()) return const AiFinancialUnderstandingSuperseded();
    final budgetProgressResult = await _loadBudgetProgress();
    if (!isCurrent()) return const AiFinancialUnderstandingSuperseded();
    final budgetProgress = switch (budgetProgressResult) {
      AppSuccess<List<BudgetProgress>>(:final data) => data,
      _ => const <BudgetProgress>[],
    };
    final goalsResult = await _loadGoals();
    if (!isCurrent()) return const AiFinancialUnderstandingSuperseded();
    final goalProgressResult = await _loadGoalProgress();
    if (!isCurrent()) return const AiFinancialUnderstandingSuperseded();
    final goals = switch (goalsResult) {
      AppSuccess<List<Goal>>(:final data) => data,
      _ => const <Goal>[],
    };
    final goalProgress = switch (goalProgressResult) {
      AppSuccess<List<GoalProgress>>(:final data) => data,
      _ => const <GoalProgress>[],
    };

    if (!isCurrent()) return const AiFinancialUnderstandingSuperseded();

    switch ((
      accountsResult,
      categoriesResult,
      payeesResult,
      exchangeRatesResult,
    )) {
      case (
        AppSuccess<List<Account>>(data: final accounts),
        AppSuccess<List<Category>>(data: final categories),
        AppSuccess<List<Payee>>(data: final payees),
        AppSuccess<List<StoredExchangeRate>>(data: final exchangeRates),
      ):
        final result = await understandingUseCase(
          input: request.input,
          accounts: accounts,
          categories: categories,
          baseCurrencyCode: _readBaseCurrencyCode(),
          locale: request.locale,
          accountClarificationMessage: request.accountClarificationMessage,
          expenseAccountClarificationMessage:
              request.expenseAccountClarificationMessage,
          payees: payees,
          exchangeRates: exchangeRates,
          budgetProgress: budgetProgress,
          goals: goals,
          goalProgress: goalProgress,
          ambiguousPayeeMessage: request.ambiguousPayeeMessage,
          exchangeRateClarificationMessage:
              request.exchangeRateClarificationMessage,
          categoryClarificationMessage: request.categoryClarificationMessage,
          goalClarificationMessage: request.goalClarificationMessage,
          unknownIntentClarificationMessage:
              request.unknownIntentClarificationMessage,
          explicitlyConfirmedMutation: request.explicitlyConfirmedMutation,
        );
        if (!isCurrent()) return const AiFinancialUnderstandingSuperseded();
        return switch (result) {
          AppSuccess<AiUnderstandingResult>(:final data) =>
            AiFinancialUnderstandingCompleted(
              understanding: data,
              accounts: accounts,
              categories: categories,
            ),
          AppFailure<AiUnderstandingResult>(:final failure) =>
            AiFinancialUnderstandingFailed(failure),
        };
      case _:
        final failure = switch (accountsResult) {
          AppFailure<List<Account>>(:final failure) => failure,
          _ => switch (categoriesResult) {
            AppFailure<List<Category>>(:final failure) => failure,
            _ => switch (payeesResult) {
              AppFailure<List<Payee>>(:final failure) => failure,
              _ => switch (exchangeRatesResult) {
                AppFailure<List<StoredExchangeRate>>(:final failure) => failure,
                _ => const Failure(
                  message: 'Required financial context was unavailable.',
                ),
              },
            },
          },
        };
        return AiFinancialUnderstandingFailed(failure);
    }
  }
}
