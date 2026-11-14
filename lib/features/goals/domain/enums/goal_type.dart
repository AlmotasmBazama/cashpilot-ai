enum GoalType { savings, emergencyFund, debtPayoff, purchase, custom }

extension GoalTypeX on GoalType {
  String get storageValue => switch (this) {
    GoalType.savings => 'savings',
    GoalType.emergencyFund => 'emergency_fund',
    GoalType.debtPayoff => 'debt_payoff',
    GoalType.purchase => 'purchase',
    GoalType.custom => 'custom',
  };
}

abstract final class GoalTypeStorage {
  static GoalType fromStorage(String value) => switch (value) {
    'savings' => GoalType.savings,
    'emergency_fund' => GoalType.emergencyFund,
    'debt_payoff' => GoalType.debtPayoff,
    'purchase' => GoalType.purchase,
    _ => GoalType.custom,
  };
}
