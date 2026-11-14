import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

const _ownerAUid = 'of032-owner-a';
const _ownerBUid = 'of032-owner-b';
const _categoryId = '01900000-0000-7000-8000-000000000001';
const _collisionGroupId = 'of032-cross-owner-group';
const _sameOwnerGroupId = 'of032-same-owner-group';
const _legacyCollisionGroupId = 'of032-legacy-collision-group';

void main() {
  group('OF-032 transfer group owner guard on UPDATE', () {
    late AppDatabase database;
    late String ownerA;
    late String ownerB;

    setUp(() async {
      database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: false,
      );
      ownerA = scopedTestSession(
        database,
        syntheticFirebaseUid: _ownerAUid,
      ).ownerScopeValue;
      ownerB = scopedTestSession(
        database,
        syntheticFirebaseUid: _ownerBUid,
      ).ownerScopeValue;
      await _seedGlobalCategory(database);
      await _seedAccount(database, id: 'account-a', ownerScopeId: ownerA);
      await _seedAccount(database, id: 'account-b', ownerScopeId: ownerB);
    });

    tearDown(() => database.close());

    test('cross-owner transfer_group_id update aborts atomically', () async {
      await _seedTransaction(
        database,
        id: 'owner-b-group-anchor',
        ownerScopeId: ownerB,
        accountId: 'account-b',
        transferGroupId: _collisionGroupId,
      );
      await _seedTransaction(
        database,
        id: 'owner-a-candidate',
        ownerScopeId: ownerA,
        accountId: 'account-a',
      );

      await expectLater(
        database.customStatement(
          '''UPDATE transactions
             SET transfer_group_id = ?
             WHERE id = ?''',
          <Object?>[_collisionGroupId, 'owner-a-candidate'],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error.toString().contains('owner_scope_transfer_reference'),
            'an owner_scope_transfer_reference SQLite abort',
          ),
        ),
      );

      final candidate = await _transactionById(database, 'owner-a-candidate');
      expect(candidate.ownerScopeId, ownerA);
      expect(candidate.transferGroupId, isNull);
      expect(
        (await _transactionById(
          database,
          'owner-b-group-anchor',
        )).transferGroupId,
        _collisionGroupId,
      );
    });

    test('same-owner transfer_group_id update passes', () async {
      await _seedTransaction(
        database,
        id: 'owner-a-group-anchor',
        ownerScopeId: ownerA,
        accountId: 'account-a',
        transferGroupId: _sameOwnerGroupId,
      );
      await _seedTransaction(
        database,
        id: 'owner-a-same-scope-candidate',
        ownerScopeId: ownerA,
        accountId: 'account-a',
      );

      await database.customStatement(
        '''UPDATE transactions
           SET transfer_group_id = ?
           WHERE id = ?''',
        <Object?>[_sameOwnerGroupId, 'owner-a-same-scope-candidate'],
      );

      final candidate = await _transactionById(
        database,
        'owner-a-same-scope-candidate',
      );
      expect(candidate.ownerScopeId, ownerA);
      expect(candidate.transferGroupId, _sameOwnerGroupId);
    });
  });

  test(
    'legacy group collision rejects claim without partial ownership',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-of032-legacy-collision-',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}cashpilot.sqlite',
      );
      final seedDatabase = AppDatabase(
        executor: NativeDatabase(file),
        enforceOwnerScopeGuards: false,
        enforceFinancialIntegrityGuards: false,
      );
      final ownerA = scopedTestSession(
        seedDatabase,
        syntheticFirebaseUid: _ownerAUid,
      ).ownerScopeValue;
      final ownerB = scopedTestSession(
        seedDatabase,
        syntheticFirebaseUid: _ownerBUid,
      ).ownerScopeValue;
      try {
        await _seedGlobalCategory(seedDatabase);
        await _seedAccount(
          seedDatabase,
          id: 'legacy-source',
          ownerScopeId: ownerA,
        );
        await _seedAccount(
          seedDatabase,
          id: 'legacy-target',
          ownerScopeId: ownerA,
        );
        await _seedAccount(
          seedDatabase,
          id: 'owner-b-account',
          ownerScopeId: ownerB,
        );
        await _seedTransaction(
          seedDatabase,
          id: 'owner-b-collision-anchor',
          ownerScopeId: ownerB,
          accountId: 'owner-b-account',
          transferGroupId: _legacyCollisionGroupId,
        );
        await _seedTransaction(
          seedDatabase,
          id: 'legacy-collision-out',
          ownerScopeId: null,
          accountId: 'legacy-source',
          type: 'transferOut',
          transferGroupId: _legacyCollisionGroupId,
        );
        await _seedTransaction(
          seedDatabase,
          id: 'legacy-collision-in',
          ownerScopeId: null,
          accountId: 'legacy-target',
          type: 'transferIn',
          transferGroupId: _legacyCollisionGroupId,
        );
      } finally {
        await seedDatabase.close();
      }

      final database = AppDatabase(
        executor: NativeDatabase(file),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: false,
      );
      addTearDown(() async {
        await database.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      await expectLater(
        database.claimLegacyTransactions(ownerScopeId: ownerA),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'legacy_transfer_group_collision',
          ),
        ),
      );

      final legacyRows =
          await (database.select(database.transactions)..where(
                (row) => row.id.isIn(const <String>[
                  'legacy-collision-out',
                  'legacy-collision-in',
                ]),
              ))
              .get();
      expect(legacyRows, hasLength(2));
      expect(legacyRows.every((row) => row.ownerScopeId == null), isTrue);
      expect(
        (await _transactionById(
          database,
          'owner-b-collision-anchor',
        )).ownerScopeId,
        ownerB,
      );
    },
  );
}

Future<void> _seedGlobalCategory(AppDatabase database) {
  final timestamp = DateTime.utc(2026, 1, 1);
  return database
      .into(database.categories)
      .insert(
        CategoriesCompanion(
          id: const Value(_categoryId),
          ownerScopeId: const Value(null),
          name: const Value('Food'),
          type: const Value('expense'),
          icon: const Value('food'),
          color: const Value(0xFFE53935),
          isDefault: const Value(true),
          isArchived: const Value(false),
          sortOrder: const Value(1010),
          createdAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
}

Future<void> _seedAccount(
  AppDatabase database, {
  required String id,
  required String ownerScopeId,
}) {
  final timestamp = DateTime.utc(2026, 1, 1);
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion(
          id: Value(id),
          ownerScopeId: Value(ownerScopeId),
          name: Value(id),
          type: const Value('cash'),
          currencyCode: const Value('USD'),
          balance: const Value('100'),
          icon: const Value('wallet'),
          color: const Value(0xFF006C67),
          isArchived: const Value(false),
          createdAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
}

Future<void> _seedTransaction(
  AppDatabase database, {
  required String id,
  required String? ownerScopeId,
  required String accountId,
  String type = 'expense',
  String? transferGroupId,
}) {
  final timestamp = DateTime.utc(2026, 1, 1);
  return database
      .into(database.transactions)
      .insert(
        TransactionsCompanion(
          id: Value(id),
          ownerScopeId: Value(ownerScopeId),
          accountId: Value(accountId),
          categoryId: const Value(_categoryId),
          amount: const Value('10'),
          currencyCode: const Value('USD'),
          type: Value(type),
          paymentMethod: const Value('bankTransfer'),
          source: const Value('manual'),
          status: const Value('pending'),
          transferGroupId: Value(transferGroupId),
          exchangeRateFromCurrencyCode: const Value('USD'),
          exchangeRateToCurrencyCode: const Value('USD'),
          exchangeRate: const Value('1'),
          exchangeRateAsOf: Value(timestamp),
          note: const Value('OF-032 fixture'),
          transactionDate: Value(timestamp),
          attachmentCount: const Value(0),
          needsReview: const Value(false),
          createdAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
}

Future<TransactionRow> _transactionById(AppDatabase database, String id) {
  return (database.select(
    database.transactions,
  )..where((row) => row.id.equals(id))).getSingle();
}
