import 'package:freezed_annotation/freezed_annotation.dart';

part 'category_dto.freezed.dart';
part 'category_dto.g.dart';

@freezed
abstract class CategoryDto with _$CategoryDto {
  const factory CategoryDto({
    required String id,
    required String name,
    required String type,
    required String icon,
    required int color,
    String? parentCategoryId,
    required bool isDefault,
    required bool isArchived,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _CategoryDto;

  factory CategoryDto.fromJson(Map<String, dynamic> json) =>
      _$CategoryDtoFromJson(json);
}
