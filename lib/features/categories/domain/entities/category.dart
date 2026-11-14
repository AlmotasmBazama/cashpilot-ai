import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../enums/category_type.dart';
import '../value_objects/category_color.dart';
import '../value_objects/category_icon.dart';

part 'category.freezed.dart';
part 'category.g.dart';

@freezed
abstract class Category with _$Category {
  const Category._();

  const factory Category({
    required String id,
    required String name,
    required CategoryType type,
    required CategoryIcon icon,
    required CategoryColor color,
    String? parentCategoryId,
    required bool isDefault,
    required bool isArchived,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Category;

  factory Category.create({
    required String name,
    required CategoryType type,
    required CategoryIcon icon,
    required CategoryColor color,
    String? id,
    String? parentCategoryId,
    bool isArchived = false,
    int sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now().toUtc();
    final resolvedCreatedAt = createdAt ?? now;

    return Category(
      id: id ?? const Uuid().v7(),
      name: name,
      type: type,
      icon: icon,
      color: color,
      parentCategoryId: parentCategoryId,
      isDefault: false,
      isArchived: isArchived,
      sortOrder: sortOrder,
      createdAt: resolvedCreatedAt,
      updatedAt: updatedAt ?? resolvedCreatedAt,
    );
  }

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
