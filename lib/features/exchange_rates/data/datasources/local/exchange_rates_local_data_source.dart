import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../dtos/exchange_rate_dto.dart';
import '../../mappers/exchange_rate_mapper.dart';

abstract interface class ExchangeRatesLocalDataSource {
  Future<T> runInTransaction<T>(Future<T> Function() operation);
  Stream<List<ExchangeRateDto>> watchRates({bool includeArchived = false});
  Future<List<ExchangeRateDto>> getRates({bool includeArchived = false});
  Future<List<ExchangeRateDto>> getRatesForBaseCurrency(String baseCurrency);
  Future<ExchangeRateDto?> getRateById(String id);
  Future<ExchangeRateDto?> getActivePair(String base, String quote);
  Future<ExchangeRateDto> createRate(ExchangeRateDto rate);
  Future<ExchangeRateDto> updateRate(ExchangeRateDto rate);
}

class DriftExchangeRatesLocalDataSource
    implements ExchangeRatesLocalDataSource {
  const DriftExchangeRatesLocalDataSource(this._session);

  final ScopedAppDatabaseSession _session;
  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() operation) =>
      _session.runGuardedWrite(() => _database.transaction(operation));

  @override
  Stream<List<ExchangeRateDto>> watchRates({bool includeArchived = false}) {
    final query = _database.select(_database.exchangeRates);
    query.where((row) => row.ownerScopeId.equals(_scope));
    if (!includeArchived) {
      query.where((row) => row.archivedAt.isNull());
    }
    query.orderBy([
      (row) => OrderingTerm(expression: row.fetchedAt, mode: OrderingMode.desc),
    ]);
    return _session
        .guardStream(query.watch())
        .map((rows) => rows.map((row) => row.toDto()).toList(growable: false));
  }

  @override
  Future<List<ExchangeRateDto>> getRates({bool includeArchived = false}) async {
    final query = _database.select(_database.exchangeRates);
    query.where((row) => row.ownerScopeId.equals(_scope));
    if (!includeArchived) {
      query.where((row) => row.archivedAt.isNull());
    }
    query.orderBy([
      (row) => OrderingTerm(expression: row.fetchedAt, mode: OrderingMode.desc),
    ]);
    return (await query.get())
        .map((row) => row.toDto())
        .toList(growable: false);
  }

  @override
  Future<List<ExchangeRateDto>> getRatesForBaseCurrency(
    String baseCurrency,
  ) async {
    final rows =
        await (_database.select(_database.exchangeRates)
              ..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.baseCurrency.equals(baseCurrency) &
                    row.archivedAt.isNull(),
              )
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.fetchedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return rows.map((row) => row.toDto()).toList(growable: false);
  }

  @override
  Future<ExchangeRateDto?> getRateById(String id) async {
    final row =
        await (_database.select(_database.exchangeRates)..where(
              (row) => row.ownerScopeId.equals(_scope) & row.id.equals(id),
            ))
            .getSingleOrNull();
    return row?.toDto();
  }

  @override
  Future<ExchangeRateDto?> getActivePair(String base, String quote) async {
    final row =
        await (_database.select(_database.exchangeRates)
              ..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.baseCurrency.equals(base) &
                    row.quoteCurrency.equals(quote) &
                    row.archivedAt.isNull(),
              )
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.fetchedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.toDto();
  }

  @override
  Future<ExchangeRateDto> createRate(ExchangeRateDto rate) async {
    return _session.runGuardedWrite(() async {
      await _database
          .into(_database.exchangeRates)
          .insert(rate.toCompanion().copyWith(ownerScopeId: Value(_scope)));
      return rate;
    });
  }

  @override
  Future<ExchangeRateDto> updateRate(ExchangeRateDto rate) async {
    return _session.runGuardedWrite(() async {
      final count =
          await (_database.update(_database.exchangeRates)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) & row.id.equals(rate.id),
              ))
              .write(rate.toCompanion().copyWith(ownerScopeId: Value(_scope)));
      if (count == 0) {
        throw const AppException.cache(
          message: 'Exchange rate not found.',
          code: 'exchange_rate_not_found',
        );
      }
      return rate;
    });
  }
}
