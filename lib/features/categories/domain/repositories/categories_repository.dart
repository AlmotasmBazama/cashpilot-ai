import '../../../../core/error/result.dart';
import '../entities/category.dart';
import '../enums/category_type.dart';

abstract interface class CategoriesRepository {
  Future<AppResult<Category>> createCategory(Category category);

  Future<AppResult<Category>> updateCategory(Category category);

  Future<AppResult<void>> deleteCategory(String id);

  Future<AppResult<List<Category>>> getCategories({
    CategoryType? type,
    bool includeArchived = false,
  });

  Future<AppResult<Category?>> getCategoryById(String id);

  Future<AppResult<List<Category>>> getDefaultCategories({CategoryType? type});

  Future<AppResult<List<Category>>> resetDefaultCategories();
}
