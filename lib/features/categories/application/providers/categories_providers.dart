import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/sync/application/sync_providers.dart';
import '../../data/datasources/local/categories_local_data_source.dart';
import '../../data/repositories/categories_repository_impl.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums/category_type.dart';
import '../../domain/repositories/categories_repository.dart';
import '../../domain/usecases/create_category.dart';
import '../../domain/usecases/delete_category.dart';
import '../../domain/usecases/get_categories.dart';
import '../../domain/usecases/get_category_by_id.dart';
import '../../domain/usecases/get_default_categories.dart';
import '../../domain/usecases/reset_default_categories.dart';
import '../../domain/usecases/update_category.dart';

final categoriesLocalDataSourceProvider = Provider<CategoriesLocalDataSource>(
  (ref) => DriftCategoriesLocalDataSource(
    ref.watch(requiredScopedAppDatabaseSessionProvider),
  ),
  name: 'categoriesLocalDataSourceProvider',
);

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepositoryImpl(
    localDataSource: ref.watch(categoriesLocalDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
    syncQueue: ref.watch(syncMutationQueueProvider),
  );
}, name: 'categoriesRepositoryProvider');

final createCategoryUseCaseProvider = Provider<CreateCategory>(
  (ref) => CreateCategory(ref.watch(categoriesRepositoryProvider)),
  name: 'createCategoryUseCaseProvider',
);

final updateCategoryUseCaseProvider = Provider<UpdateCategory>(
  (ref) => UpdateCategory(ref.watch(categoriesRepositoryProvider)),
  name: 'updateCategoryUseCaseProvider',
);

final deleteCategoryUseCaseProvider = Provider<DeleteCategory>(
  (ref) => DeleteCategory(ref.watch(categoriesRepositoryProvider)),
  name: 'deleteCategoryUseCaseProvider',
);

final getCategoriesUseCaseProvider = Provider<GetCategories>(
  (ref) => GetCategories(ref.watch(categoriesRepositoryProvider)),
  name: 'getCategoriesUseCaseProvider',
);

final getCategoryByIdUseCaseProvider = Provider<GetCategoryById>(
  (ref) => GetCategoryById(ref.watch(categoriesRepositoryProvider)),
  name: 'getCategoryByIdUseCaseProvider',
);

final getDefaultCategoriesUseCaseProvider = Provider<GetDefaultCategories>(
  (ref) => GetDefaultCategories(ref.watch(categoriesRepositoryProvider)),
  name: 'getDefaultCategoriesUseCaseProvider',
);

final resetDefaultCategoriesUseCaseProvider = Provider<ResetDefaultCategories>(
  (ref) => ResetDefaultCategories(ref.watch(categoriesRepositoryProvider)),
  name: 'resetDefaultCategoriesUseCaseProvider',
);

final categoriesProvider = FutureProvider<AppResult<List<Category>>>(
  (ref) => ref.watch(getCategoriesUseCaseProvider)(),
  name: 'categoriesProvider',
);

final categoriesByTypeProvider =
    FutureProvider.family<AppResult<List<Category>>, CategoryType>((ref, type) {
      return ref.watch(getCategoriesUseCaseProvider)(type: type);
    }, name: 'categoriesByTypeProvider');

final categoryByIdProvider =
    FutureProvider.family<AppResult<Category?>, String>(
      (ref, id) => ref.watch(getCategoryByIdUseCaseProvider)(id),
      name: 'categoryByIdProvider',
    );

final defaultCategoriesProvider = FutureProvider<AppResult<List<Category>>>(
  (ref) => ref.watch(getDefaultCategoriesUseCaseProvider)(),
  name: 'defaultCategoriesProvider',
);
