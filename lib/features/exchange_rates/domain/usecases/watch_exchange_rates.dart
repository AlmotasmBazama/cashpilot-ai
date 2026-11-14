import '../../../../core/error/result.dart';
import '../entities/stored_exchange_rate.dart';
import '../repositories/exchange_rate_repository.dart';

class WatchExchangeRates {
  const WatchExchangeRates(this._repository);
  final ExchangeRateRepository _repository;
  Stream<AppResult<List<StoredExchangeRate>>> call({
    bool includeArchived = false,
  }) => _repository.watchRates(includeArchived: includeArchived);
}
