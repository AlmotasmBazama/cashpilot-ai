import 'package:freezed_annotation/freezed_annotation.dart';

part 'payee_dto.freezed.dart';
part 'payee_dto.g.dart';

@freezed
abstract class PayeeDto with _$PayeeDto {
  const factory PayeeDto({
    required String id,
    required String name,
    required String normalizedName,
    required String type,
    @Default(<String>[]) List<String> aliases,
    String? defaultCategoryId,
    String? defaultAccountId,
    String? notes,
    DateTime? lastUsedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) = _PayeeDto;

  factory PayeeDto.fromJson(Map<String, dynamic> json) =>
      _$PayeeDtoFromJson(json);
}
