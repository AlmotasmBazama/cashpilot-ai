import '../../../../core/error/result.dart';
import '../entities/stored_exchange_rate.dart';
import '../repositories/exchange_rate_repository.dart';

class UpsertExchangeRate {
  const UpsertExchangeRate(this._repository);
  final ExchangeRateRepository _repository;
  Future<AppResult<StoredExchangeRate>> call(StoredExchangeRate rate) =>
      _repository.upsertRate(rate);
}
