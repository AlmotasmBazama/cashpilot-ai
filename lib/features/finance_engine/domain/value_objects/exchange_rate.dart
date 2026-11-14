import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/serialization/decimal_converter.dart';

part 'exchange_rate.freezed.dart';
part 'exchange_rate.g.dart';

@freezed
abstract class ExchangeRate with _$ExchangeRate {
  const factory ExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    @DecimalConverter() required Decimal rate,
    DateTime? asOf,
  }) = _ExchangeRate;

  factory ExchangeRate.identity({
    required String currencyCode,
    DateTime? asOf,
  }) {
    return ExchangeRate(
      fromCurrencyCode: currencyCode,
      toCurrencyCode: currencyCode,
      rate: Decimal.one,
      asOf: asOf,
    );
  }

  factory ExchangeRate.fromJson(Map<String, dynamic> json) =>
      _$ExchangeRateFromJson(json);
}
