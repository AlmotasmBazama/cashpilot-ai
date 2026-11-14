import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/sync/application/sync_mutation_queue.dart';
import 'package:cashpilot_ai/core/sync/domain/sync_types.dart';
import 'package:cashpilot_ai/features/categories/categories.dart';
import 'package:cashpilot_ai/features/categories/data/datasources/local/categories_local_data_source.dart';
import 'package:cashpilot_ai/features/categories/data/repositories/categories_repository_impl.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

const _targetCategoryId = '01910000-0000-7000-8000-000000000022';
const _childCategoryId = '01910000-0000-7000-8000-000000000023';

void main() {
  group('OF-022 referenced category deletion', () {
    for (final dependency in _CategoryDependency.values) {
      test(
        '${dependency.label} blocks repository and direct deletion',
        () async {
          final fixture = await _CategoryFixture.open();
          addTearDown(fixture.close);
          await fixture.seed(dependency);

          final result = await fixture.repository.deleteCategory(
            _targetCategoryId,
          );

          final failure = _expectFailure(result);
          expect(failure.code, 'category_delete_referenced');
          expect(fixture.syncQueue.deletes, isEmpty);
          await expectLater(
            fixture.database.customStatement(
              'DELETE FROM categories WHERE id = ?',
              const <Object?>[_targetCategoryId],
            ),
            throwsA(
              predicate<Object>(
                (error) =>
                    error.toString().contains('category_delete_referenced'),
                'a category_delete_referenced SQLite abort',
              ),
            ),
          );
          expect(await fixture.targetCategory(), isNotNull);
        },
      );
    }

    test(
      'unreferenced custom category deletes and emits one tombstone',
      () async {
        final fixture = await _CategoryFixture.open();
        addTearDown(fixture.close);

        final result = await fixture.repository.deleteCategory(
          _targetCategoryId,
        );

        expect(result, isA<AppSuccess<void>>());
        expect(fixture.syncQueue.deletes, const <String>[_targetCategoryId]);
        expect(await fixture.targetCategory(), isNull);
      },
    );

    test(
      'owner-scoped custom category cannot become a shared default',
      () async {
        final fixture = await _CategoryFixture.open();
        addTearDown(fixture.close);

        await expectLater(
          fixture.database.customStatement(
            'UPDATE categories SET is_default = 1 WHERE id = ?',
            const <Object?>[_targetCategoryId],
          ),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains(
                'owner_scoped_category_cannot_be_default',
              ),
              'an owner_scoped_category_cannot_be_default SQLite abort',
            ),
          ),
        );

        expect((await fixture.targetCategory())?.isDefault, isFalse);
      },
    );
  });

  test('existing v17 database receives the new owner guard triggers', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cashpilot-owner-guard-reopen-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}cashpilot.sqlite',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final unguarded = AppDatabase(
      executor: NativeDatabase(file),
      enforceOwnerScopeGuards: false,
      enforceFinancialIntegrityGuards: false,
    );
    await unguarded.customSelect('SELECT 1').getSingle();
    expect(
      (await unguarded.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      17,
    );
    await unguarded.close();

    final guarded = AppDatabase(
      executor: NativeDatabase(file),
      enforceOwnerScopeGuards: true,
      enforceFinancialIntegrityGuards: false,
    );
    addTearDown(guarded.close);
    final triggers = await guarded
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'trigger'")
        .get();
    final names = triggers.map((row) => row.read<String>('name')).toSet();

    expect(
      names,
      containsAll(const <String>{
        'categories_referenced_delete_guard',
        'categories_owner_scoped_default_guard_insert',
        'categories_custom_default_promotion_guard_update',
        'transactions_transfer_scope_collision_update',
      }),
    );
  });
}

enum _CategoryDependency {
  parentCategory('child category'),
  payeeDefaultCategory('payee default category'),
  transaction('transaction'),
  budget('budget'),
  receiptLineItem('receipt line item'),
  transactionSplit('transaction split');

  const _CategoryDependency(this.label);

  final String label;
}

final class _CategoryFixture {
  const _CategoryFixture({
    required this.database,
    required this.repository,
    required this.syncQueue,
    required this.ownerScopeId,
  });

  final AppDatabase database;
  final CategoriesRepository repository;
  final _RecordingSyncMutationQueue syncQueue;
  final String ownerScopeId;

  static Future<_CategoryFixture> open() async {
    final database = AppDatabase(
      executor: NativeDatabase.memory(),
      enforceOwnerScopeGuards: true,
      enforceFinancialIntegrityGuards: false,
    );
    final session = scopedTestSession(database);
    final syncQueue = _RecordingSyncMutationQueue();
    final repository = CategoriesRepositoryImpl(
      localDataSource: DriftCategoriesLocalDataSource(session),
      logger: AppLogger.instance,
      syncQueue: syncQueue,
    );
    final result = await repository.createCategory(
      _customCategory(id: _targetCategoryId, name: 'Referenced category'),
    );
    if (result case AppFailure<Category>(:final failure)) {
      await database.close();
      throw TestFailure('Unable to seed category: ${failure.message}');
    }
    return _CategoryFixture(
      database: database,
      repository: repository,
      syncQueue: syncQueue,
      ownerScopeId: session.ownerScopeValue,
    );
  }

  Future<void> seed(_CategoryDependency dependency) async {
    switch (dependency) {
      case _CategoryDependency.parentCategory:
        _expectSuccess(
          await repository.createCategory(
            _customCategory(
              id: _childCategoryId,
              name: 'Child category',
              parentCategoryId: _targetCategoryId,
            ),
          ),
        );
        return;
      case _CategoryDependency.payeeDefaultCategory:
        await database
            .into(database.payees)
            .insert(
              PayeesCompanion.insert(
                id: 'of022-payee',
                ownerScopeId: Value(ownerScopeId),
                name: 'OF-022 Payee',
                normalizedName: 'of-022 payee',
                defaultCategoryId: const Value(_targetCategoryId),
                createdAt: _timestamp,
                updatedAt: _timestamp,
              ),
            );
        return;
      case _CategoryDependency.transaction:
        await _seedAccount();
        await database
            .into(database.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: 'of022-transaction',
                ownerScopeId: Value(ownerScopeId),
                accountId: 'of022-account',
                categoryId: _targetCategoryId,
                amount: '10',
                currencyCode: 'USD',
                type: 'expense',
                paymentMethod: 'cash',
                source: 'manual',
                status: 'pending',
                transactionDate: _timestamp,
                createdAt: _timestamp,
                updatedAt: _timestamp,
              ),
            );
        return;
      case _CategoryDependency.budget:
        await database
            .into(database.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: 'of022-budget',
                ownerScopeId: Value(ownerScopeId),
                name: 'OF-022 Budget',
                categoryId: _targetCategoryId,
                amount: '100',
                currency: 'USD',
                periodType: 'monthly',
                startDate: _timestamp,
                endDate: DateTime.utc(2026, 1, 31),
                alertThresholdPercent: 80,
                createdAt: _timestamp,
                updatedAt: _timestamp,
              ),
            );
        return;
      case _CategoryDependency.receiptLineItem:
        await _seedReceipt();
        await database
            .into(database.receiptLineItems)
            .insert(
              ReceiptLineItemsCompanion.insert(
                id: 'of022-line-item',
                ownerScopeId: Value(ownerScopeId),
                receiptId: 'of022-receipt',
                description: 'Referenced item',
                normalizedDescription: 'referenced item',
                categoryId: const Value(_targetCategoryId),
                categorySuggestionSource: 'manual',
              ),
            );
        return;
      case _CategoryDependency.transactionSplit:
        await _seedReceipt();
        await database
            .into(database.transactionSplits)
            .insert(
              TransactionSplitsCompanion.insert(
                id: 'of022-split',
                ownerScopeId: Value(ownerScopeId),
                receiptId: 'of022-receipt',
                categoryId: _targetCategoryId,
                amount: '10',
              ),
            );
        return;
    }
  }

  Future<CategoryRow?> targetCategory() {
    return (database.select(
      database.categories,
    )..where((row) => row.id.equals(_targetCategoryId))).getSingleOrNull();
  }

  Future<void> close() => database.close();

  Future<void> _seedAccount() {
    return database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'of022-account',
            ownerScopeId: Value(ownerScopeId),
            name: 'OF-022 Account',
            type: 'cash',
            currencyCode: 'USD',
            balance: '0',
            icon: 'wallet',
            color: 0xFF006C67,
            createdAt: _timestamp,
            updatedAt: _timestamp,
          ),
        );
  }

  Future<void> _seedReceipt() {
    return database
        .into(database.receipts)
        .insert(
          ReceiptsCompanion.insert(
            id: 'of022-receipt',
            ownerScopeId: Value(ownerScopeId),
            documentType: 'receipt',
            paymentStatus: 'paid',
            imageRetentionChoice: 'none',
            status: 'draft',
            createdAt: _timestamp,
            updatedAt: _timestamp,
          ),
        );
  }
}

final class _RecordingSyncMutationQueue implements SyncMutationQueue {
  final List<String> deletes = <String>[];

  @override
  Future<void> enqueueDelete(SyncEntityType entityType, String entityId) async {
    if (entityType == SyncEntityType.category) {
      deletes.add(entityId);
    }
  }

  @override
  Future<void> enqueueUpsert(
    SyncEntityType entityType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {}
}

final _timestamp = DateTime.utc(2026, 1, 1);

Category _customCategory({
  required String id,
  required String name,
  String? parentCategoryId,
}) {
  return Category.create(
    id: id,
    name: name,
    type: CategoryType.expense,
    icon: const CategoryIcon(key: 'custom'),
    color: const CategoryColor(argb: 0xFF006C67),
    parentCategoryId: parentCategoryId,
    createdAt: _timestamp,
    updatedAt: _timestamp,
  );
}

Failure _expectFailure<T>(AppResult<T> result) {
  return switch (result) {
    AppFailure<T>(:final failure) => failure,
    AppSuccess<T>() => throw TestFailure('Expected failure, got success.'),
  };
}

T _expectSuccess<T>(AppResult<T> result) {
  return switch (result) {
    AppSuccess<T>(:final data) => data,
    AppFailure<T>(:final failure) => throw TestFailure(
      'Expected success, got failure: ${failure.message}',
    ),
  };
}
