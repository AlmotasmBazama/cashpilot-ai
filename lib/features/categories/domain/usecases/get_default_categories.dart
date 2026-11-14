import '../../../../core/error/result.dart';
import '../entities/category.dart';
import '../enums/category_type.dart';
import '../repositories/categories_repository.dart';

class GetDefaultCategories {
  const GetDefaultCategories(this._repository);

  final CategoriesRepository _repository;

  Future<AppResult<List<Category>>> call({CategoryType? type}) {
    return _repository.getDefaultCategories(type: type);
  }
}
