import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/serialization/decimal_converter.dart';
import '../enums/account_type.dart';

part 'account.freezed.dart';
part 'account.g.dart';

@freezed
abstract class Account with _$Account {
  const Account._();

  const factory Account({
    required String id,
    required String name,
    required AccountType type,
    required String currencyCode,
    @DecimalConverter() required Decimal balance,
    required String icon,
    required int color,
    @Default(<String>[]) List<String> paymentMethodIds,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Account;

  factory Account.create({
    required String name,
    required AccountType type,
    required String currencyCode,
    required Decimal balance,
    required String icon,
    required int color,
    List<String> paymentMethodIds = const <String>[],
    String? id,
    bool isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now().toUtc();
    final resolvedCreatedAt = createdAt ?? now;

    return Account(
      id: id ?? const Uuid().v7(),
      name: name,
      type: type,
      currencyCode: currencyCode,
      balance: balance,
      icon: icon,
      color: color,
      paymentMethodIds: paymentMethodIds,
      isArchived: isArchived,
      createdAt: resolvedCreatedAt,
      updatedAt: updatedAt ?? resolvedCreatedAt,
    );
  }

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);
}
