import '../../../../core/error/result.dart';
import '../entities/category.dart';
import '../repositories/categories_repository.dart';

class UpdateCategory {
  const UpdateCategory(this._repository);

  final CategoriesRepository _repository;

  Future<AppResult<Category>> call(Category category) {
    return _repository.updateCategory(category);
  }
}
