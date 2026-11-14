import '../../../../core/error/result.dart';
import '../entities/category.dart';
import '../enums/category_type.dart';
import '../repositories/categories_repository.dart';

class GetCategories {
  const GetCategories(this._repository);

  final CategoriesRepository _repository;

  Future<AppResult<List<Category>>> call({
    CategoryType? type,
    bool includeArchived = false,
  }) {
    return _repository.getCategories(
      type: type,
      includeArchived: includeArchived,
    );
  }
}
