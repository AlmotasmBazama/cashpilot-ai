import 'package:decimal/decimal.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/sync/application/sync_mutation_queue.dart';
import '../../../../core/sync/domain/sync_types.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart'
    as finance;
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../domain/entities/stored_exchange_rate.dart';
import '../../domain/failures/exchange_rate_failure_codes.dart';
import '../../domain/repositories/exchange_rate_repository.dart';
import '../datasources/local/exchange_rates_local_data_source.dart';
import '../mappers/exchange_rate_mapper.dart';

class ExchangeRateRepositoryImpl implements ExchangeRateRepository {
  const ExchangeRateRepositoryImpl({
    required ExchangeRatesLocalDataSource localDataSource,
    required AppLogger logger,
    SyncMutationQueue? syncQueue,
  }) : _localDataSource = localDataSource,
       _logger = logger,
       _syncQueue = syncQueue;

  final ExchangeRatesLocalDataSource _localDataSource;
  final AppLogger _logger;
  final SyncMutationQueue? _syncQueue;

  @override
  Stream<AppResult<List<StoredExchangeRate>>> watchRates({
    bool includeArchived = false,
  }) async* {
    try {
      await for (final rates in _localDataSource.watchRates(
        includeArchived: includeArchived,
      )) {
        yield AppResult.success(
          rates.map((rate) => rate.toDomain()).toList(growable: false),
        );
      }
    } on Object catch (error, stackTrace) {
      yield _failure('Unable to watch exchange rates.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<StoredExchangeRate?>> getRate(
    String baseCurrency,
    String quoteCurrency,
  ) async {
    try {
      final base = _currency(baseCurrency);
      final quote = _currency(quoteCurrency);
      final rate = await _localDataSource.getActivePair(base, quote);
      return AppResult.success(rate?.toDomain());
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load exchange rate.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<finance.ExchangeRate?>> getLatestRate(
    String fromCurrency,
    String toCurrency,
  ) async {
    try {
      final from = _currency(fromCurrency);
      final to = _currency(toCurrency);
      return AppResult.success(await _resolveRate(from, to));
    } on Object catch (error, stackTrace) {
      return _failure(
        'Unable to load latest exchange rate.',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<AppResult<List<StoredExchangeRate>>> getRatesForBaseCurrency(
    String baseCurrency,
  ) async {
    try {
      final rates = await _localDataSource.getRatesForBaseCurrency(
        _currency(baseCurrency),
      );
      return AppResult.success(
        rates.map((rate) => rate.toDomain()).toList(growable: false),
      );
    } on Object catch (error, stackTrace) {
      return _failure(
        'Unable to load exchange rates for base currency.',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<AppResult<StoredExchangeRate>> upsertRate(
    StoredExchangeRate rate,
  ) async {
    try {
      final normalized = StoredExchangeRate.create(
        id: rate.id,
        baseCurrency: rate.baseCurrency,
        quoteCurrency: rate.quoteCurrency,
        rate: rate.rate,
        source: rate.source,
        fetchedAt: rate.fetchedAt,
        createdAt: rate.createdAt,
        updatedAt: DateTime.now().toUtc(),
        archivedAt: rate.archivedAt,
      );
      final saved = await _localDataSource.runInTransaction(() async {
        final pair = await _localDataSource.getActivePair(
          normalized.baseCurrency,
          normalized.quoteCurrency,
        );
        final byId = await _localDataSource.getRateById(normalized.id);
        final existing = pair ?? byId;
        if (existing == null) {
          return _localDataSource.createRate(normalized.toDto());
        }
        final updated = normalized.copyWith(
          id: existing.id,
          createdAt: existing.createdAt.toUtc(),
          archivedAt: null,
        );
        return _localDataSource.updateRate(updated.toDto());
      });
      final result = saved.toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to save exchange rate.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<StoredExchangeRate>> archiveRate(String id) async {
    try {
      final existing = await _localDataSource.getRateById(id);
      if (existing == null) {
        throw const ExchangeRateValidationException(
          code: ExchangeRateFailureCodes.notFound,
          message: 'Exchange rate not found.',
        );
      }
      final now = DateTime.now().toUtc();
      final archived = existing.copyWith(archivedAt: now, updatedAt: now);
      final result = (await _localDataSource.updateRate(archived)).toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to archive exchange rate.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Money>> convert(Money money, String toCurrencyCode) async {
    try {
      final from = _currency(money.currencyCode);
      final to = _currency(toCurrencyCode);
      if (from == to) {
        return AppResult.success(Money(amount: money.amount, currencyCode: to));
      }

      final direct = await _localDataSource.getActivePair(from, to);
      if (direct != null) {
        return AppResult.success(
          Money(
            amount: money.amount * direct.toDomain().rate,
            currencyCode: to,
          ),
        );
      }

      final reverse = await _localDataSource.getActivePair(to, from);
      if (reverse != null) {
        return AppResult.success(
          Money(
            amount: (money.amount / reverse.toDomain().rate).toDecimal(
              scaleOnInfinitePrecision: 12,
            ),
            currencyCode: to,
          ),
        );
      }

      return AppResult.failure(
        Failure(
          message: 'Missing exchange rate for $from to $to.',
          code: ExchangeRateFailureCodes.missingRate,
        ),
      );
    } on Object catch (error, stackTrace) {
      return _failure('Unable to convert money.', error, stackTrace);
    }
  }

  Future<finance.ExchangeRate?> _resolveRate(String from, String to) async {
    final normalizedFrom = _currency(from);
    final normalizedTo = _currency(to);
    if (normalizedFrom == normalizedTo) {
      return finance.ExchangeRate.identity(currencyCode: normalizedFrom);
    }

    final direct = await _localDataSource.getActivePair(
      normalizedFrom,
      normalizedTo,
    );
    if (direct != null) {
      final stored = direct.toDomain();
      return finance.ExchangeRate(
        fromCurrencyCode: normalizedFrom,
        toCurrencyCode: normalizedTo,
        rate: stored.rate,
        asOf: stored.fetchedAt,
      );
    }

    final reverse = await _localDataSource.getActivePair(
      normalizedTo,
      normalizedFrom,
    );
    if (reverse == null) {
      return null;
    }
    final stored = reverse.toDomain();
    return finance.ExchangeRate(
      fromCurrencyCode: normalizedFrom,
      toCurrencyCode: normalizedTo,
      rate: (Decimal.one / stored.rate).toDecimal(scaleOnInfinitePrecision: 12),
      asOf: stored.fetchedAt,
    );
  }

  String _currency(String value) => value.trim().toUpperCase();

  AppResult<T> _failure<T>(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.error(message, error, stackTrace);
    return switch (error) {
      ExchangeRateValidationException(:final code, :final message) =>
        AppResult.failure(Failure(message: message, code: code)),
      AppException(:final code, :final message) => AppResult.failure(
        Failure(message: message, code: code),
      ),
      _ => AppResult.failure(Failure(message: message)),
    };
  }

  Future<void> _queueUpsert(StoredExchangeRate rate) {
    return enqueueSyncUpsertBestEffort(
      queue: _syncQueue,
      entityType: SyncEntityType.exchangeRate,
      entityId: rate.id,
      payload: rate.toJson(),
      logger: _logger,
    );
  }
}
