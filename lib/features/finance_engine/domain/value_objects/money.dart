import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/serialization/decimal_converter.dart';
import '../exceptions/finance_exception.dart';

part 'money.freezed.dart';
part 'money.g.dart';

@freezed
abstract class Money with _$Money {
  const Money._();

  const factory Money({
    @DecimalConverter() required Decimal amount,
    required String currencyCode,
  }) = _Money;

  factory Money.zero(String currencyCode) {
    return Money(amount: Decimal.zero, currencyCode: currencyCode);
  }

  factory Money.fromJson(Map<String, dynamic> json) => _$MoneyFromJson(json);

  String get normalizedCurrencyCode => currencyCode.toUpperCase();

  bool get isPositive => amount > Decimal.zero;

  Money operator +(Money other) {
    _ensureSameCurrency(other);
    return copyWith(amount: amount + other.amount);
  }

  Money operator -(Money other) {
    _ensureSameCurrency(other);
    return copyWith(amount: amount - other.amount);
  }

  void _ensureSameCurrency(Money other) {
    if (normalizedCurrencyCode != other.normalizedCurrencyCode) {
      throw FinanceException.currencyMismatch(
        expectedCurrencyCode: currencyCode,
        actualCurrencyCode: other.currencyCode,
      );
    }
  }
}
