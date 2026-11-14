import '../../../../core/error/result.dart';
import '../entities/category.dart';
import '../repositories/categories_repository.dart';

class ResetDefaultCategories {
  const ResetDefaultCategories(this._repository);

  final CategoriesRepository _repository;

  Future<AppResult<List<Category>>> call() {
    return _repository.resetDefaultCategories();
  }
}
