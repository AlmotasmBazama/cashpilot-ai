import '../../../../core/error/result.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../repositories/exchange_rate_repository.dart';

class ConvertMoney {
  const ConvertMoney(this._repository);
  final ExchangeRateRepository _repository;
  Future<AppResult<Money>> call(Money money, String toCurrencyCode) =>
      _repository.convert(money, toCurrencyCode);
}
