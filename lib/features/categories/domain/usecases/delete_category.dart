import '../../../../core/error/result.dart';
import '../repositories/categories_repository.dart';

class DeleteCategory {
  const DeleteCategory(this._repository);

  final CategoriesRepository _repository;

  Future<AppResult<void>> call(String id) {
    return _repository.deleteCategory(id);
  }
}
