import '../../../../core/error/result.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart'
    as finance;
import '../../../finance_engine/domain/value_objects/money.dart';
import '../entities/stored_exchange_rate.dart';

abstract interface class ExchangeRateRepository {
  Stream<AppResult<List<StoredExchangeRate>>> watchRates({
    bool includeArchived = false,
  });

  Future<AppResult<StoredExchangeRate?>> getRate(
    String baseCurrency,
    String quoteCurrency,
  );

  Future<AppResult<finance.ExchangeRate?>> getLatestRate(
    String fromCurrency,
    String toCurrency,
  );

  Future<AppResult<List<StoredExchangeRate>>> getRatesForBaseCurrency(
    String baseCurrency,
  );

  Future<AppResult<StoredExchangeRate>> upsertRate(StoredExchangeRate rate);

  Future<AppResult<StoredExchangeRate>> archiveRate(String id);

  Future<AppResult<Money>> convert(Money money, String toCurrencyCode);
}
