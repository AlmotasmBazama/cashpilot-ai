import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/serialization/decimal_converter.dart';
import '../value_objects/money.dart';

part 'account_balance_state.freezed.dart';
part 'account_balance_state.g.dart';

@freezed
abstract class AccountBalanceState with _$AccountBalanceState {
  const AccountBalanceState._();

  const factory AccountBalanceState({
    required String accountId,
    required String currencyCode,
    @DecimalConverter() required Decimal balance,
    @Default(false) bool allowsNegativeBalance,
    @DecimalConverter() Decimal? creditLimit,
    DateTime? updatedAt,
  }) = _AccountBalanceState;

  factory AccountBalanceState.fromJson(Map<String, dynamic> json) =>
      _$AccountBalanceStateFromJson(json);

  Money get money => Money(amount: balance, currencyCode: currencyCode);

  Decimal? get minimumAllowedBalance {
    final limit = creditLimit;
    if (limit != null) {
      return -limit;
    }

    if (allowsNegativeBalance) {
      return null;
    }

    return Decimal.zero;
  }

  bool canDebit(Decimal amount) {
    final minimum = minimumAllowedBalance;
    if (minimum == null) {
      return true;
    }

    return balance - amount >= minimum;
  }
}
