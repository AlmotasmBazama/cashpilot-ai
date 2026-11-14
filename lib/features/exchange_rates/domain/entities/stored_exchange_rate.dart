import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/serialization/decimal_converter.dart';
import '../../../../shared/domain/currency/currency_catalog.dart';
import '../enums/exchange_rate_source.dart';
import '../failures/exchange_rate_failure_codes.dart';

part 'stored_exchange_rate.freezed.dart';
part 'stored_exchange_rate.g.dart';

@freezed
abstract class StoredExchangeRate with _$StoredExchangeRate {
  const StoredExchangeRate._();

  const factory StoredExchangeRate({
    required String id,
    required String baseCurrency,
    required String quoteCurrency,
    @DecimalConverter() required Decimal rate,
    required ExchangeRateSource source,
    required DateTime fetchedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) = _StoredExchangeRate;

  factory StoredExchangeRate.create({
    required String baseCurrency,
    required String quoteCurrency,
    required Decimal rate,
    ExchangeRateSource source = ExchangeRateSource.manual,
    DateTime? fetchedAt,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    final base = _validatedCurrencyCode(baseCurrency);
    final quote = _validatedCurrencyCode(quoteCurrency);
    if (base == quote) {
      throw const ExchangeRateValidationException(
        code: ExchangeRateFailureCodes.sameCurrency,
        message: 'Base and quote currencies must be different.',
      );
    }
    if (rate <= Decimal.zero) {
      throw const ExchangeRateValidationException(
        code: ExchangeRateFailureCodes.invalidRate,
        message: 'Exchange rate must be greater than zero.',
      );
    }

    final now = DateTime.now().toUtc();
    final resolvedCreatedAt = (createdAt ?? now).toUtc();
    return StoredExchangeRate(
      id: id ?? const Uuid().v7(),
      baseCurrency: base,
      quoteCurrency: quote,
      rate: rate,
      source: source,
      fetchedAt: (fetchedAt ?? now).toUtc(),
      createdAt: resolvedCreatedAt,
      updatedAt: (updatedAt ?? resolvedCreatedAt).toUtc(),
      archivedAt: archivedAt?.toUtc(),
    );
  }

  factory StoredExchangeRate.fromJson(Map<String, dynamic> json) =>
      _$StoredExchangeRateFromJson(json);

  bool get isArchived => archivedAt != null;
}

String _validatedCurrencyCode(String value) {
  final normalized = value.trim().toUpperCase();
  if (CurrencyCatalog.findByCode(normalized) == null) {
    throw const ExchangeRateValidationException(
      code: ExchangeRateFailureCodes.invalidCurrency,
      message: 'Currency code is not supported.',
    );
  }
  return normalized;
}
