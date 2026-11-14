import '../../../../core/error/result.dart';
import '../entities/category.dart';
import '../repositories/categories_repository.dart';

class CreateCategory {
  const CreateCategory(this._repository);

  final CategoriesRepository _repository;

  Future<AppResult<Category>> call(Category category) {
    return _repository.createCategory(category);
  }
}
