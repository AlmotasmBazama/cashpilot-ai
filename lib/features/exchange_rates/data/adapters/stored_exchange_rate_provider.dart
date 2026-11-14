import '../../../../core/error/result.dart';
import '../../../finance_engine/domain/exceptions/finance_exception.dart';
import '../../../finance_engine/domain/repositories/exchange_rate_provider.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../domain/repositories/exchange_rate_repository.dart';

class StoredExchangeRateProvider implements ExchangeRateProvider {
  const StoredExchangeRateProvider(this._repository);

  final ExchangeRateRepository _repository;

  @override
  Future<ExchangeRate> getExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    DateTime? at,
  }) async {
    final result = await _repository.getLatestRate(
      fromCurrencyCode,
      toCurrencyCode,
    );
    final rate = switch (result) {
      AppSuccess(:final data) => data,
      AppFailure() => null,
    };
    if (rate == null) {
      throw FinanceException.exchangeRateUnavailable(
        fromCurrencyCode: fromCurrencyCode,
        toCurrencyCode: toCurrencyCode,
      );
    }
    return rate.asOf == null ? rate.copyWith(asOf: at) : rate;
  }
}
