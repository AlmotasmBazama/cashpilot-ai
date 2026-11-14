import '../../../../core/error/result.dart';
import '../entities/stored_exchange_rate.dart';
import '../repositories/exchange_rate_repository.dart';

class GetRatesForBaseCurrency {
  const GetRatesForBaseCurrency(this._repository);
  final ExchangeRateRepository _repository;
  Future<AppResult<List<StoredExchangeRate>>> call(String base) =>
      _repository.getRatesForBaseCurrency(base);
}
