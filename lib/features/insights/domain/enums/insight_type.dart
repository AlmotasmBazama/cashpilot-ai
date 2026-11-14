enum InsightType {
  spendingIncrease,
  topCategory,
  cashFlowWarning,
  savingsOpportunity,
  budgetWarning,
  goalProgress,
  recurringPaymentDetected,
  missingExchangeRate,
  unusualTransaction,
  positiveTrend,
}

extension InsightTypeX on InsightType {
  String get storageValue => switch (this) {
    InsightType.spendingIncrease => 'spending_increase',
    InsightType.topCategory => 'top_category',
    InsightType.cashFlowWarning => 'cash_flow_warning',
    InsightType.savingsOpportunity => 'savings_opportunity',
    InsightType.budgetWarning => 'budget_warning',
    InsightType.goalProgress => 'goal_progress',
    InsightType.recurringPaymentDetected => 'recurring_payment_detected',
    InsightType.missingExchangeRate => 'missing_exchange_rate',
    InsightType.unusualTransaction => 'unusual_transaction',
    InsightType.positiveTrend => 'positive_trend',
  };
}
