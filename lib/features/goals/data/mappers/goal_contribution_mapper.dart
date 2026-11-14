import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/goal_contribution.dart';
import '../../domain/failures/goal_failure_codes.dart';
import '../dtos/goal_contribution_dto.dart';

extension GoalContributionDomainMapper on GoalContribution {
  GoalContributionDto toDto() {
    final resolvedCreditedAmount = creditedAmount;
    if (resolvedCreditedAmount == null) {
      throw const GoalValidationException(
        code: GoalFailureCodes.invalidContribution,
        message: 'Contribution must be converted before it is stored.',
      );
    }
    return GoalContributionDto(
      id: id,
      goalId: goalId,
      amount: amount,
      currency: currency,
      creditedAmount: resolvedCreditedAmount,
      date: date,
      note: note,
      linkedTransactionId: linkedTransactionId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      reversedAt: reversedAt,
    );
  }
}

extension GoalContributionDtoMapper on GoalContributionDto {
  GoalContribution toDomain() => GoalContribution.create(
    id: id,
    goalId: goalId,
    amount: amount,
    currency: currency,
    creditedAmount: creditedAmount,
    date: date,
    note: note,
    linkedTransactionId: linkedTransactionId,
    createdAt: createdAt,
    updatedAt: updatedAt,
    reversedAt: reversedAt,
  );

  GoalContributionsCompanion toCompanion() => GoalContributionsCompanion(
    id: Value(id),
    goalId: Value(goalId),
    amount: Value(amount.toString()),
    currency: Value(currency),
    creditedAmount: Value(creditedAmount.toString()),
    date: Value(date),
    note: Value(note),
    linkedTransactionId: Value(linkedTransactionId),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    reversedAt: Value(reversedAt),
  );
}

extension GoalContributionRowMapper on GoalContributionRow {
  GoalContributionDto toDto() => GoalContributionDto(
    id: id,
    goalId: goalId,
    amount: Decimal.parse(amount),
    currency: currency,
    creditedAmount: Decimal.parse(creditedAmount),
    date: date,
    note: note,
    linkedTransactionId: linkedTransactionId,
    createdAt: createdAt,
    updatedAt: updatedAt,
    reversedAt: reversedAt,
  );
}
