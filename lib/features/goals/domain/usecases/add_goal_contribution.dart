import 'package:decimal/decimal.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../entities/goal.dart';
import '../entities/goal_contribution.dart';
import '../failures/goal_failure_codes.dart';
import '../repositories/goal_repository.dart';

typedef GoalContributionMoneyConverter =
    Future<AppResult<Money>> Function(Money money, String toCurrencyCode);

class AddGoalContributionUseCase {
  const AddGoalContributionUseCase({
    required GoalRepository repository,
    required GoalContributionMoneyConverter convertMoney,
  }) : _repository = repository,
       _convertMoney = convertMoney;

  final GoalRepository _repository;
  final GoalContributionMoneyConverter _convertMoney;

  Future<AppResult<GoalContribution>> call(
    GoalContribution contribution,
  ) async {
    final goalResult = await _repository.getGoalById(contribution.goalId);
    final Goal goal;
    switch (goalResult) {
      case AppSuccess<Goal?>(data: final value?):
        goal = value;
      case AppSuccess<Goal?>(data: null):
        return const AppResult.failure(
          Failure(message: 'Goal not found.', code: GoalFailureCodes.notFound),
        );
      case AppFailure<Goal?>(:final failure):
        return AppResult.failure(failure);
    }
    if (goal.isArchived) {
      return const AppResult.failure(
        Failure(
          message: 'Archived goals cannot receive contributions.',
          code: GoalFailureCodes.archived,
        ),
      );
    }

    final Decimal creditedAmount;
    if (contribution.currency == goal.currency) {
      creditedAmount = contribution.amount;
    } else {
      final conversion = await _convertMoney(
        Money(amount: contribution.amount, currencyCode: contribution.currency),
        goal.currency,
      );
      switch (conversion) {
        case AppSuccess<Money>(:final data):
          creditedAmount = data.amount;
        case AppFailure<Money>():
          return const AppResult.failure(
            Failure(
              message: 'An exchange rate is required for this contribution.',
              code: GoalFailureCodes.missingExchangeRate,
            ),
          );
      }
    }

    if (goal.currentAmount + creditedAmount > goal.targetAmount) {
      return const AppResult.failure(
        Failure(
          message: 'This contribution would exceed the goal target.',
          code: GoalFailureCodes.overfunding,
        ),
      );
    }
    return _repository.addContribution(
      contribution.copyWith(creditedAmount: creditedAmount),
    );
  }
}
