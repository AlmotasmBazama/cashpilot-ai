import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../enums/payee_type.dart';
import '../failures/payee_failure_codes.dart';
import '../services/payee_name_normalizer.dart';

part 'payee.freezed.dart';
part 'payee.g.dart';

@freezed
abstract class Payee with _$Payee {
  const Payee._();

  const factory Payee({
    required String id,
    required String name,
    required String normalizedName,
    required PayeeType type,
    @Default(<String>[]) List<String> aliases,
    String? defaultCategoryId,
    String? defaultAccountId,
    String? notes,
    DateTime? lastUsedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) = _Payee;

  factory Payee.create({
    required String name,
    PayeeType type = PayeeType.other,
    List<String> aliases = const <String>[],
    String? defaultCategoryId,
    String? defaultAccountId,
    String? notes,
    DateTime? lastUsedAt,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const PayeeValidationException(
        code: PayeeFailureCodes.emptyName,
        message: 'Payee name is required.',
      );
    }

    final cleanedAliases = <String>[];
    final aliasKeys = <String>{PayeeNameNormalizer.compact(trimmedName)};
    for (final alias in aliases) {
      final trimmedAlias = alias.trim();
      if (trimmedAlias.isEmpty) {
        continue;
      }
      final key = PayeeNameNormalizer.compact(trimmedAlias);
      if (key.isEmpty || !aliasKeys.add(key)) {
        throw const PayeeValidationException(
          code: PayeeFailureCodes.duplicateAlias,
          message: 'Payee aliases must be unique.',
        );
      }
      cleanedAliases.add(trimmedAlias);
    }

    final now = DateTime.now().toUtc();
    final resolvedCreatedAt = (createdAt ?? now).toUtc();
    return Payee(
      id: id ?? const Uuid().v7(),
      name: trimmedName,
      normalizedName: PayeeNameNormalizer.normalize(trimmedName),
      type: type,
      aliases: List.unmodifiable(cleanedAliases),
      defaultCategoryId: _nullableTrim(defaultCategoryId),
      defaultAccountId: _nullableTrim(defaultAccountId),
      notes: _nullableTrim(notes),
      lastUsedAt: lastUsedAt?.toUtc(),
      createdAt: resolvedCreatedAt,
      updatedAt: (updatedAt ?? resolvedCreatedAt).toUtc(),
      archivedAt: archivedAt?.toUtc(),
    );
  }

  factory Payee.fromJson(Map<String, dynamic> json) => _$PayeeFromJson(json);

  bool get isArchived => archivedAt != null;
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
