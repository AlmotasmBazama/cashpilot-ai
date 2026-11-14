abstract final class GoalFailureCodes {
  static const invalidTitle = 'goal_invalid_title';
  static const invalidAmount = 'goal_invalid_amount';
  static const invalidCurrency = 'goal_invalid_currency';
  static const invalidContribution = 'goal_invalid_contribution';
  static const overfunding = 'goal_overfunding_not_allowed';
  static const notFound = 'goal_not_found';
  static const contributionNotFound = 'goal_contribution_not_found';
  static const contributionAlreadyReversed =
      'goal_contribution_already_reversed';
  static const archived = 'goal_archived';
  static const missingExchangeRate = 'goal_missing_exchange_rate';
}

class GoalValidationException implements Exception {
  const GoalValidationException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'GoalValidationException: [$code] $message';
}
