import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/stored_exchange_rate.dart';
import '../../domain/enums/exchange_rate_source.dart';
import '../dtos/exchange_rate_dto.dart';

extension StoredExchangeRateMapper on StoredExchangeRate {
  ExchangeRateDto toDto() => ExchangeRateDto(
    id: id,
    baseCurrency: baseCurrency,
    quoteCurrency: quoteCurrency,
    rate: rate.toString(),
    source: source.storageValue,
    fetchedAt: fetchedAt.toUtc(),
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    archivedAt: archivedAt?.toUtc(),
  );
}

extension ExchangeRateDtoMapper on ExchangeRateDto {
  StoredExchangeRate toDomain() => StoredExchangeRate(
    id: id,
    baseCurrency: baseCurrency,
    quoteCurrency: quoteCurrency,
    rate: Decimal.parse(rate),
    source: ExchangeRateSourceMapper.fromStorage(source),
    fetchedAt: fetchedAt.toUtc(),
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    archivedAt: archivedAt?.toUtc(),
  );

  ExchangeRatesCompanion toCompanion() => ExchangeRatesCompanion(
    id: Value(id),
    baseCurrency: Value(baseCurrency),
    quoteCurrency: Value(quoteCurrency),
    rate: Value(rate),
    source: Value(source),
    fetchedAt: Value(fetchedAt),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    archivedAt: Value(archivedAt),
  );
}

extension ExchangeRateRowMapper on ExchangeRateRow {
  ExchangeRateDto toDto() => ExchangeRateDto(
    id: id,
    baseCurrency: baseCurrency,
    quoteCurrency: quoteCurrency,
    rate: rate,
    source: source,
    fetchedAt: fetchedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );
}
