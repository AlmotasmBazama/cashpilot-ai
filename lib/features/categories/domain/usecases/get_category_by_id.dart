import '../../../../core/error/result.dart';
import '../entities/category.dart';
import '../repositories/categories_repository.dart';

class GetCategoryById {
  const GetCategoryById(this._repository);

  final CategoriesRepository _repository;

  Future<AppResult<Category?>> call(String id) {
    return _repository.getCategoryById(id);
  }
}
