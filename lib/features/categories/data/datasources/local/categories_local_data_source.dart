import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../domain/defaults/default_category_definitions.dart';
import '../../../domain/enums/category_type.dart';
import '../../dtos/category_dto.dart';
import '../../mappers/category_mapper.dart';

abstract interface class CategoriesLocalDataSource {
  Future<CategoryDto> createCategory(CategoryDto category);

  Future<CategoryDto> updateCategory(CategoryDto category);

  Future<void> deleteCategory(String id);

  Future<List<CategoryDto>> getCategories({
    CategoryType? type,
    bool includeArchived = false,
  });

  Future<CategoryDto?> getCategoryById(String id);

  Future<List<CategoryDto>> getDefaultCategories({CategoryType? type});

  Future<List<CategoryDto>> resetDefaultCategories();
}

class DriftCategoriesLocalDataSource implements CategoriesLocalDataSource {
  const DriftCategoriesLocalDataSource(this._session);

  final ScopedAppDatabaseSession _session;
  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  Future<CategoryDto> createCategory(CategoryDto category) async {
    return _session.runGuardedWrite(() async {
      await _seedDefaultCategoriesIfNeeded();
      await _database
          .into(_database.categories)
          .insert(category.toCompanion().copyWith(ownerScopeId: Value(_scope)));
      return category;
    });
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _session.runGuardedWrite(() async {
      await _seedDefaultCategoriesIfNeeded();
      await _database.transaction(() async {
        final category = await _getCategoryRowById(id);

        if (category == null) {
          throw AppException.cache(
            message: 'Category not found for deletion.',
            code: 'category_not_found',
          );
        }

        if (category.isDefault) {
          throw AppException.validation(
            message: 'Default categories cannot be deleted.',
            code: 'default_category_delete_blocked',
          );
        }

        if (await _hasCategoryDependencies(id)) {
          throw AppException.validation(
            message:
                'Category is still used by financial records and cannot be deleted.',
            code: 'category_delete_referenced',
          );
        }

        final deleted =
            await (_database.delete(_database.categories)..where(
                  (row) => row.ownerScopeId.equals(_scope) & row.id.equals(id),
                ))
                .go();
        if (deleted != 1) {
          throw AppException.cache(
            message: 'Category not found for deletion.',
            code: 'category_not_found',
          );
        }
      });
    });
  }

  Future<bool> _hasCategoryDependencies(String id) async {
    final row = await _database.customSelect(
      '''SELECT CASE WHEN
        EXISTS (SELECT 1 FROM categories
          WHERE parent_category_id = ?) OR
        EXISTS (SELECT 1 FROM payees
          WHERE default_category_id = ?) OR
        EXISTS (SELECT 1 FROM transactions
          WHERE category_id = ?) OR
        EXISTS (SELECT 1 FROM budgets
          WHERE category_id = ?) OR
        EXISTS (SELECT 1 FROM receipt_line_items
          WHERE category_id = ?) OR
        EXISTS (SELECT 1 FROM transaction_splits
          WHERE category_id = ?)
        THEN 1 ELSE 0 END AS value''',
      variables: List<Variable<Object>>.generate(
        6,
        (_) => Variable<String>(id),
        growable: false,
      ),
    ).getSingle();
    return row.read<int>('value') == 1;
  }

  @override
  Future<CategoryDto?> getCategoryById(String id) async {
    await _seedDefaultCategoriesIfNeeded();
    return (await _getCategoryRowById(id))?.toDto();
  }

  @override
  Future<List<CategoryDto>> getCategories({
    CategoryType? type,
    bool includeArchived = false,
  }) async {
    await _seedDefaultCategoriesIfNeeded();
    final query = _database.select(_database.categories);
    query.where(
      (category) =>
          category.ownerScopeId.equals(_scope) |
          (category.ownerScopeId.isNull() & category.isDefault.equals(true)),
    );

    if (type != null) {
      query.where((category) => category.type.equals(type.storageValue));
    }

    if (!includeArchived) {
      query.where((category) => category.isArchived.equals(false));
    }

    _orderCategories(query);

    final rows = await query.get();
    return rows.map((row) => row.toDto()).toList(growable: false);
  }

  @override
  Future<List<CategoryDto>> getDefaultCategories({CategoryType? type}) async {
    await _seedDefaultCategoriesIfNeeded();
    final query = _database.select(_database.categories)
      ..where(
        (category) =>
            category.isDefault.equals(true) & category.ownerScopeId.isNull(),
      );

    if (type != null) {
      query.where((category) => category.type.equals(type.storageValue));
    }

    _orderCategories(query);

    final rows = await query.get();
    return rows.map((row) => row.toDto()).toList(growable: false);
  }

  @override
  Future<List<CategoryDto>> resetDefaultCategories() async {
    // Built-in defaults are shared read-only reference data. Only seed missing
    // definitions; never let an owner-scoped action rewrite global rows.
    await _seedDefaultCategoriesIfNeeded();
    return getDefaultCategories();
  }

  @override
  Future<CategoryDto> updateCategory(CategoryDto category) async {
    return _session.runGuardedWrite(() async {
      await _seedDefaultCategoriesIfNeeded();
      final existing = await _getCategoryRowById(category.id);

      if (existing == null) {
        throw AppException.cache(
          message: 'Category not found for update.',
          code: 'category_not_found',
        );
      }

      if (existing.isDefault) {
        throw AppException.validation(
          message: 'Default categories cannot be updated.',
          code: 'default_category_update_blocked',
        );
      }

      final updated = category.copyWith(isDefault: false);

      final updatedRows =
          await (_database.update(_database.categories)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) & row.id.equals(updated.id),
              ))
              .write(
                updated.toCompanion().copyWith(ownerScopeId: Value(_scope)),
              );

      if (updatedRows == 0) {
        throw AppException.cache(
          message: 'Category not found for update.',
          code: 'category_not_found',
        );
      }

      return updated;
    });
  }

  Future<CategoryRow?> _getCategoryRowById(String id) {
    return (_database.select(_database.categories)..where(
          (category) =>
              category.id.equals(id) &
              (category.ownerScopeId.equals(_scope) |
                  (category.ownerScopeId.isNull() &
                      category.isDefault.equals(true))),
        ))
        .getSingleOrNull();
  }

  Future<void> _seedDefaultCategoriesIfNeeded() async {
    await _session.runGuardedWrite(() async {
      final existingDefaults =
          await (_database.select(_database.categories)..where(
                (category) =>
                    category.isDefault.equals(true) &
                    category.ownerScopeId.isNull(),
              ))
              .get();
      final existingIds = existingDefaults
          .map((category) => category.id)
          .toSet();
      final missingCategories = buildDefaultCategories()
          .where((category) => !existingIds.contains(category.id))
          .map((category) => category.toDto())
          .toList(growable: false);

      if (missingCategories.isEmpty) {
        return;
      }

      await _database.transaction(() async {
        for (final category in missingCategories) {
          await _database
              .into(_database.categories)
              .insert(
                category.toCompanion().copyWith(
                  ownerScopeId: const Value(null),
                ),
                // Account opening and the category screen can request the
                // canonical defaults concurrently on first use. Both writers
                // calculate the same deterministic rows, so the loser must
                // observe success instead of caching a duplicate-key failure.
                mode: InsertMode.insertOrIgnore,
              );
        }
      });
    });
  }

  void _orderCategories(
    SimpleSelectStatement<$CategoriesTable, CategoryRow> query,
  ) {
    query.orderBy([
      (category) => OrderingTerm(expression: category.type),
      (category) => OrderingTerm(expression: category.sortOrder),
      (category) => OrderingTerm(expression: category.name),
    ]);
  }
}
