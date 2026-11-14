abstract final class ExchangeRateFailureCodes {
  static const invalidCurrency = 'exchange_rate_invalid_currency';
  static const sameCurrency = 'exchange_rate_same_currency';
  static const invalidRate = 'exchange_rate_invalid_rate';
  static const missingRate = 'exchange_rate_missing';
  static const notFound = 'exchange_rate_not_found';
}

class ExchangeRateValidationException implements Exception {
  const ExchangeRateValidationException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => 'ExchangeRateValidationException: [$code] $message';
}
