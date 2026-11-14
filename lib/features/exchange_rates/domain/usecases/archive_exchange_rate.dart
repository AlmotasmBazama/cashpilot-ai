import '../../../../core/error/result.dart';
import '../entities/stored_exchange_rate.dart';
import '../repositories/exchange_rate_repository.dart';

class ArchiveExchangeRate {
  const ArchiveExchangeRate(this._repository);
  final ExchangeRateRepository _repository;
  Future<AppResult<StoredExchangeRate>> call(String id) =>
      _repository.archiveRate(id);
}
