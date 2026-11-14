import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/payee.dart';
import '../../domain/enums/payee_type.dart';
import '../dtos/payee_dto.dart';

extension PayeeDomainMapper on Payee {
  PayeeDto toDto() => PayeeDto(
    id: id,
    name: name,
    normalizedName: normalizedName,
    type: type.storageValue,
    aliases: aliases,
    defaultCategoryId: defaultCategoryId,
    defaultAccountId: defaultAccountId,
    notes: notes,
    lastUsedAt: lastUsedAt?.toUtc(),
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    archivedAt: archivedAt?.toUtc(),
  );
}

extension PayeeDtoMapper on PayeeDto {
  Payee toDomain() => Payee(
    id: id,
    name: name,
    normalizedName: normalizedName,
    type: PayeeTypeMapper.fromStorage(type),
    aliases: aliases,
    defaultCategoryId: defaultCategoryId,
    defaultAccountId: defaultAccountId,
    notes: notes,
    lastUsedAt: lastUsedAt?.toUtc(),
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    archivedAt: archivedAt?.toUtc(),
  );

  PayeesCompanion toCompanion() => PayeesCompanion(
    id: Value(id),
    name: Value(name),
    normalizedName: Value(normalizedName),
    type: Value(type),
    aliases: Value(jsonEncode(aliases)),
    defaultCategoryId: Value(defaultCategoryId),
    defaultAccountId: Value(defaultAccountId),
    notes: Value(notes),
    lastUsedAt: Value(lastUsedAt),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    archivedAt: Value(archivedAt),
  );
}

extension PayeeRowMapper on PayeeRow {
  PayeeDto toDto() => PayeeDto(
    id: id,
    name: name,
    normalizedName: normalizedName,
    type: type,
    aliases: _decodeAliases(aliases),
    defaultCategoryId: defaultCategoryId,
    defaultAccountId: defaultAccountId,
    notes: notes,
    lastUsedAt: lastUsedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );
}

List<String> _decodeAliases(String value) {
  try {
    final decoded = jsonDecode(value);
    return decoded is List
        ? decoded.whereType<String>().toList(growable: false)
        : const <String>[];
  } on FormatException {
    return const <String>[];
  }
}
