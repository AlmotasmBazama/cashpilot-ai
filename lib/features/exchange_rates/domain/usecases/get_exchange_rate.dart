import '../../../../core/error/result.dart';
import '../entities/stored_exchange_rate.dart';
import '../repositories/exchange_rate_repository.dart';

class GetExchangeRate {
  const GetExchangeRate(this._repository);
  final ExchangeRateRepository _repository;
  Future<AppResult<StoredExchangeRate?>> call(String base, String quote) =>
      _repository.getRate(base, quote);
}
