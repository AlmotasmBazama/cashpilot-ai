import '../exceptions/finance_exception.dart';
import '../value_objects/exchange_rate.dart';

abstract interface class ExchangeRateProvider {
  Future<ExchangeRate> getExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    DateTime? at,
  });
}

class SameCurrencyExchangeRateProvider implements ExchangeRateProvider {
  const SameCurrencyExchangeRateProvider();

  @override
  Future<ExchangeRate> getExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    DateTime? at,
  }) async {
    if (fromCurrencyCode.toUpperCase() != toCurrencyCode.toUpperCase()) {
      throw FinanceException.exchangeRateUnavailable(
        fromCurrencyCode: fromCurrencyCode,
        toCurrencyCode: toCurrencyCode,
      );
    }

    return ExchangeRate.identity(currencyCode: fromCurrencyCode, asOf: at);
  }
}
