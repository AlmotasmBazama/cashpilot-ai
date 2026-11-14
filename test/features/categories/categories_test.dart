import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/features/categories/categories.dart';
import 'package:cashpilot_ai/features/categories/data/datasources/local/categories_local_data_source.dart';
import 'package:cashpilot_ai/features/categories/data/repositories/categories_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;
  late CategoriesRepository repository;

  setUp(() {
    database = AppDatabase(
      executor: NativeDatabase.memory(),
      enforceOwnerScopeGuards: true,
    );
    repository = CategoriesRepositoryImpl(
      localDataSource: DriftCategoriesLocalDataSource(
        scopedTestSession(database),
      ),
      logger: AppLogger.instance,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('seeds built-in default categories automatically', () async {
    final result = await repository.getDefaultCategories();
    final defaults = result.expectSuccess();

    expect(defaults.length, defaultCategoryDefinitions.length);
    expect(defaults.length, 49);
    expect(
      defaults.where((category) => category.type == CategoryType.expense),
      hasLength(30),
    );
    expect(
      defaults.where((category) => category.type == CategoryType.income),
      hasLength(18),
    );
    expect(
      defaults.where((category) => category.type == CategoryType.transfer),
      hasLength(1),
    );
    expect(defaults.every((category) => category.isDefault), isTrue);
  });

  test('concurrent first-use default seeding is idempotent', () async {
    final ownerBRepository = CategoriesRepositoryImpl(
      localDataSource: DriftCategoriesLocalDataSource(
        scopedTestSession(database, syntheticFirebaseUid: 'owner-b'),
      ),
      logger: AppLogger.instance,
    );

    final results = await Future.wait([
      for (var attempt = 0; attempt < 10; attempt++) ...[
        repository.getDefaultCategories(),
        ownerBRepository.getDefaultCategories(),
      ],
    ]);

    for (final result in results) {
      expect(result.expectSuccess(), hasLength(49));
    }
    expect(
      (await repository.getDefaultCategories()).expectSuccess(),
      hasLength(49),
    );
  });

  test('blocks deleting default categories', () async {
    final defaults = (await repository.getDefaultCategories()).expectSuccess();
    final deleteResult = await repository.deleteCategory(defaults.first.id);

    expect(deleteResult, isA<AppFailure<void>>());
    expect(
      (await repository.getCategoryById(defaults.first.id)).expectSuccess(),
      isNotNull,
    );
  });

  test('OF-021 rejects mutation of shared defaults for every owner', () async {
    final food = (await repository.getDefaultCategories(
      type: CategoryType.expense,
    )).expectSuccess().firstWhere((category) => category.name == 'Food');

    final updateResult = await repository.updateCategory(
      food.copyWith(name: 'Owner A override', isArchived: true),
    );

    expect(updateResult, isA<AppFailure<Category>>());

    final ownerBRepository = CategoriesRepositoryImpl(
      localDataSource: DriftCategoriesLocalDataSource(
        scopedTestSession(database, syntheticFirebaseUid: 'owner-b'),
      ),
      logger: AppLogger.instance,
    );
    final ownerBFood = (await ownerBRepository.getDefaultCategories(
      type: CategoryType.expense,
    )).expectSuccess().firstWhere((category) => category.id == food.id);

    expect(ownerBFood.name, 'Food');
    expect(ownerBFood.isArchived, isFalse);
  });

  test(
    'OF-021 database guard rejects direct shared-default mutation',
    () async {
      final food = (await repository.getDefaultCategories(
        type: CategoryType.expense,
      )).expectSuccess().firstWhere((category) => category.name == 'Food');

      await expectLater(
        database.customStatement(
          'UPDATE categories SET name = ? WHERE id = ?',
          <Object?>['Direct mutation', food.id],
        ),
        throwsA(anything),
      );
      await expectLater(
        database.customStatement(
          'DELETE FROM categories WHERE id = ?',
          <Object?>[food.id],
        ),
        throwsA(anything),
      );

      final unchanged = (await repository.getCategoryById(
        food.id,
      )).expectSuccess();
      expect(unchanged?.name, 'Food');
    },
  );

  test('creates user categories and supports nesting', () async {
    final parent = (await repository.createCategory(
      userCategory(
        id: '01910000-0000-7000-8000-000000000001',
        name: 'Family',
        sortOrder: 9000,
      ),
    )).expectSuccess();
    final child = (await repository.createCategory(
      userCategory(
        id: '01910000-0000-7000-8000-000000000002',
        name: 'Kids',
        parentCategoryId: parent.id,
        sortOrder: 9010,
      ),
    )).expectSuccess();
    final loadedChild = (await repository.getCategoryById(
      child.id,
    )).expectSuccess();

    expect(parent.isDefault, isFalse);
    expect(child.parentCategoryId, parent.id);
    expect(loadedChild?.parentCategoryId, parent.id);
  });

  test(
    'reset restores default categories without removing user categories',
    () async {
      final food = (await repository.getDefaultCategories(
        type: CategoryType.expense,
      )).expectSuccess().firstWhere((category) => category.name == 'Food');
      final custom = (await repository.createCategory(
        userCategory(
          id: '01910000-0000-7000-8000-000000000003',
          name: 'Custom',
          sortOrder: 9100,
        ),
      )).expectSuccess();

      final resetDefaults = (await repository.resetDefaultCategories())
          .expectSuccess();
      final resetFood = resetDefaults.firstWhere(
        (category) => category.id == food.id,
      );
      final loadedCustom = (await repository.getCategoryById(
        custom.id,
      )).expectSuccess();

      expect(resetFood.name, 'Food');
      expect(resetFood.isArchived, isFalse);
      expect(resetDefaults.length, defaultCategoryDefinitions.length);
      expect(loadedCustom, isNotNull);
      expect(loadedCustom?.name, 'Custom');
    },
  );
}

Category userCategory({
  required String id,
  required String name,
  String? parentCategoryId,
  int sortOrder = 0,
}) {
  return Category.create(
    id: id,
    name: name,
    type: CategoryType.expense,
    icon: const CategoryIcon(key: 'custom'),
    color: const CategoryColor(argb: 0xFF006C67),
    parentCategoryId: parentCategoryId,
    sortOrder: sortOrder,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

extension AppResultTestX<T> on AppResult<T> {
  T expectSuccess() {
    return switch (this) {
      AppSuccess<T>(:final data) => data,
      AppFailure<T>(:final failure) => throw TestFailure(
        'Expected success but got failure: ${failure.message}',
      ),
    };
  }
}
