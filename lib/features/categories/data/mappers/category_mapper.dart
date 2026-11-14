import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums/category_type.dart';
import '../../domain/value_objects/category_color.dart';
import '../../domain/value_objects/category_icon.dart';
import '../dtos/category_dto.dart';

extension CategoryDomainMapper on Category {
  CategoryDto toDto() {
    return CategoryDto(
      id: id,
      name: name,
      type: type.storageValue,
      icon: icon.key,
      color: color.argb,
      parentCategoryId: parentCategoryId,
      isDefault: isDefault,
      isArchived: isArchived,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension CategoryDtoMapper on CategoryDto {
  Category toDomain() {
    return Category(
      id: id,
      name: name,
      type: CategoryTypeMapper.fromStorage(type),
      icon: CategoryIcon(key: icon),
      color: CategoryColor(argb: color),
      parentCategoryId: parentCategoryId,
      isDefault: isDefault,
      isArchived: isArchived,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  CategoriesCompanion toCompanion() {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      icon: Value(icon),
      color: Value(color),
      parentCategoryId: Value(parentCategoryId),
      isDefault: Value(isDefault),
      isArchived: Value(isArchived),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}

extension CategoryRowMapper on CategoryRow {
  CategoryDto toDto() {
    return CategoryDto(
      id: id,
      name: name,
      type: type,
      icon: icon,
      color: color,
      parentCategoryId: parentCategoryId,
      isDefault: isDefault,
      isArchived: isArchived,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
