abstract final class BudgetFailureCodes {
  static const invalidName = 'budget_invalid_name';
  static const invalidCategory = 'budget_invalid_category';
  static const invalidAmount = 'budget_invalid_amount';
  static const invalidCurrency = 'budget_invalid_currency';
  static const invalidThreshold = 'budget_invalid_threshold';
  static const invalidPeriod = 'budget_invalid_period';
  static const notFound = 'budget_not_found';
}

class BudgetValidationException implements Exception {
  const BudgetValidationException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'BudgetValidationException: [$code] $message';
}
