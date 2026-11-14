import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/account.dart';
import '../../domain/enums/account_type.dart';
import '../dtos/account_dto.dart';

extension AccountDomainMapper on Account {
  AccountDto toDto() {
    return AccountDto(
      id: id,
      name: name,
      type: type.storageValue,
      currencyCode: currencyCode,
      balance: balance.toString(),
      icon: icon,
      color: color,
      paymentMethodIds: paymentMethodIds,
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension AccountDtoMapper on AccountDto {
  Account toDomain() {
    return Account(
      id: id,
      name: name,
      type: AccountTypeMapper.fromStorage(type),
      currencyCode: currencyCode,
      balance: Decimal.parse(balance),
      icon: icon,
      color: color,
      paymentMethodIds: paymentMethodIds,
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  AccountsCompanion toCompanion() {
    return AccountsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      currencyCode: Value(currencyCode),
      balance: Value(balance),
      icon: Value(icon),
      color: Value(color),
      paymentMethodIds: Value(jsonEncode(paymentMethodIds)),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}

extension AccountRowMapper on AccountRow {
  AccountDto toDto() {
    return AccountDto(
      id: id,
      name: name,
      type: type,
      currencyCode: currencyCode,
      balance: balance,
      icon: icon,
      color: color,
      paymentMethodIds: _decodePaymentMethodIds(paymentMethodIds),
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

List<String> _decodePaymentMethodIds(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! List) {
    return const <String>[];
  }

  return decoded.whereType<String>().toList(growable: false);
}
