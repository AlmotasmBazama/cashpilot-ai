import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/sync/application/sync_mutation_queue.dart';
import '../../../../core/sync/domain/sync_types.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums/category_type.dart';
import '../../domain/repositories/categories_repository.dart';
import '../datasources/local/categories_local_data_source.dart';
import '../mappers/category_mapper.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  const CategoriesRepositoryImpl({
    required CategoriesLocalDataSource localDataSource,
    required AppLogger logger,
    SyncMutationQueue? syncQueue,
  }) : _localDataSource = localDataSource,
       _logger = logger,
       _syncQueue = syncQueue;

  final CategoriesLocalDataSource _localDataSource;
  final AppLogger _logger;
  final SyncMutationQueue? _syncQueue;

  @override
  Future<AppResult<Category>> createCategory(Category category) async {
    try {
      final created = await _localDataSource.createCategory(
        category.copyWith(isDefault: false).toDto(),
      );
      final result = created.toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to create category.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<void>> deleteCategory(String id) async {
    try {
      await _localDataSource.deleteCategory(id);
      await enqueueSyncDeleteBestEffort(
        queue: _syncQueue,
        entityType: SyncEntityType.category,
        entityId: id,
        logger: _logger,
      );
      return const AppResult.success(null);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to delete category.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<List<Category>>> getCategories({
    CategoryType? type,
    bool includeArchived = false,
  }) async {
    try {
      final categories = await _localDataSource.getCategories(
        type: type,
        includeArchived: includeArchived,
      );
      return AppResult.success(
        categories
            .map((category) => category.toDomain())
            .toList(growable: false),
      );
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load categories.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Category?>> getCategoryById(String id) async {
    try {
      final category = await _localDataSource.getCategoryById(id);
      return AppResult.success(category?.toDomain());
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load category.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<List<Category>>> getDefaultCategories({
    CategoryType? type,
  }) async {
    try {
      final categories = await _localDataSource.getDefaultCategories(
        type: type,
      );
      return AppResult.success(
        categories
            .map((category) => category.toDomain())
            .toList(growable: false),
      );
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load default categories.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<List<Category>>> resetDefaultCategories() async {
    try {
      final categories = await _localDataSource.resetDefaultCategories();
      final results = categories
          .map((category) => category.toDomain())
          .toList(growable: false);
      for (final category in results) {
        await _queueUpsert(category);
      }
      return AppResult.success(results);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to reset default categories.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Category>> updateCategory(Category category) async {
    try {
      final updated = await _localDataSource.updateCategory(category.toDto());
      final result = updated.toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to update category.', error, stackTrace);
    }
  }

  AppResult<T> _failure<T>(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.error(message, error, stackTrace);
    if (error is AppException) {
      return AppResult.failure(
        Failure(message: error.message, code: error.code),
      );
    }
    return AppResult.failure(Failure(message: message));
  }

  Future<void> _queueUpsert(Category category) {
    return enqueueSyncUpsertBestEffort(
      queue: _syncQueue,
      entityType: SyncEntityType.category,
      entityId: category.id,
      payload: category.toJson(),
      logger: _logger,
    );
  }
}
