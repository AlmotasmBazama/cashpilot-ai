import '../../../../core/error/result.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../repositories/exchange_rate_repository.dart';

class GetLatestExchangeRate {
  const GetLatestExchangeRate(this._repository);
  final ExchangeRateRepository _repository;
  Future<AppResult<ExchangeRate?>> call(String from, String to) =>
      _repository.getLatestRate(from, to);
}
