import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/app_exception.dart';
import 'package:cashpilot_ai/core/owner_scope/application/legacy_data_claim_service.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/transactions/transactions.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

const _ownerUid = 'of005-adversarial-owner';
const _occurredAt = '2026-02-03T00:00:00.000Z';

void main() {
  group('OF-005 production database capabilities', () {
    test('raw one-leg status update fails closed with guards on', () async {
      final database = await _guardedMemoryDatabase();
      addTearDown(database.close);
      final scope = scopedTestSession(
        database,
        syntheticFirebaseUid: _ownerUid,
      ).ownerScopeValue;
      const groupId = 'guarded-raw-group';
      await _insertPendingPair(database, scope: scope, groupId: groupId);

      await expectLater(
        database.customStatement(
          "UPDATE transactions SET status = 'posted', updated_at = 2 "
          "WHERE id = 'guarded-out'",
        ),
        throwsA(anything),
      );

      final rows = await _groupRows(database, groupId);
      expect(rows, hasLength(2));
      expect(rows.every((row) => row.status == 'pending'), isTrue);
    });

    test(
      'pair insertion capability rejects financially malformed pairs',
      () async {
        final malformedPairs = <_MalformedPair>[
          const _MalformedPair(name: 'same account', incomingAccount: 'source'),
          const _MalformedPair(name: 'zero source amount', outgoingAmount: '0'),
          const _MalformedPair(
            name: 'negative target amount',
            incomingAmount: '-1',
          ),
          const _MalformedPair(name: 'zero exchange rate', outgoingRate: '0'),
          const _MalformedPair(
            name: 'fingerprinted same-currency unequal amounts',
            incomingAmount: '11',
          ),
          const _MalformedPair(
            name: 'fingerprinted same-currency non-unit rate',
            outgoingAmount: '10',
            incomingAmount: '20',
            outgoingRate: '2',
            incomingRate: '2',
          ),
          const _MalformedPair(
            name: 'mismatched rate direction',
            incomingRateFrom: 'EUR',
          ),
          const _MalformedPair(
            name: 'mismatched payment method',
            incomingPaymentMethod: 'cash',
          ),
          const _MalformedPair(
            name: 'target account currency differs from incoming leg',
            incomingCurrencyCode: 'EUR',
            rateTo: 'EUR',
          ),
        ];

        for (var index = 0; index < malformedPairs.length; index += 1) {
          final malformed = malformedPairs[index];
          final database = await _guardedMemoryDatabase();
          try {
            final scope = scopedTestSession(
              database,
              syntheticFirebaseUid: _ownerUid,
            ).ownerScopeValue;
            final groupId = 'invalid-capability-$index';
            await expectLater(
              database.insertTransferPair(
                ownerScopeId: scope,
                payloadFingerprint: _fingerprint('invalid-$index'),
                outgoing: _transferLeg(
                  ownerScopeId: scope,
                  id: 'invalid-$index-out',
                  accountId: 'source',
                  groupId: groupId,
                  type: TransactionType.transferOut.storageValue,
                  amount: malformed.outgoingAmount,
                  rate: malformed.outgoingRate,
                  rateTo: malformed.rateTo,
                ),
                incoming: _transferLeg(
                  ownerScopeId: scope,
                  id: 'invalid-$index-in',
                  accountId: malformed.incomingAccount,
                  groupId: groupId,
                  type: TransactionType.transferIn.storageValue,
                  amount: malformed.incomingAmount,
                  currencyCode: malformed.incomingCurrencyCode,
                  rateFrom: malformed.incomingRateFrom,
                  rateTo: malformed.rateTo,
                  rate: malformed.incomingRate,
                  paymentMethod: malformed.incomingPaymentMethod,
                ),
              ),
              throwsA(anything),
              reason: malformed.name,
            );
            expect(
              await _groupRows(database, groupId),
              isEmpty,
              reason: malformed.name,
            );
          } finally {
            await database.close();
          }
        }
      },
    );

    test(
      'privacy deletion capability is the only raw-delete escape for a pair',
      () async {
        final database = await _guardedMemoryDatabase();
        addTearDown(database.close);
        final scope = scopedTestSession(
          database,
          syntheticFirebaseUid: _ownerUid,
        ).ownerScopeValue;
        const groupId = 'privacy-delete-group';
        await _insertPendingPair(database, scope: scope, groupId: groupId);

        await expectLater(
          database.customStatement(
            "DELETE FROM transactions WHERE id = 'guarded-out'",
          ),
          throwsA(anything),
        );
        final deleted = await database.deleteTransactionsForOwnerDataDeletion(
          ownerScopeId: scope,
          operationId: 'privacy-operation',
        );

        expect(deleted, 2);
        expect(await _groupRows(database, groupId), isEmpty);
      },
    );

    test(
      'v16 null-fingerprint rate contradiction migrates unchanged and quarantines',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'cashpilot-of005-v16-terms-',
        );
        final file = File(
          '${directory.path}${Platform.pathSeparator}cashpilot.sqlite',
        );
        final seedDatabase = AppDatabase(executor: NativeDatabase(file));
        final scope = scopedTestSession(
          seedDatabase,
          syntheticFirebaseUid: _ownerUid,
        ).ownerScopeValue;
        try {
          await _seedDefaultTransferCategory(seedDatabase);
          await _seedAccount(seedDatabase, id: 'source', balance: '100');
          await _seedAccount(
            seedDatabase,
            id: 'target',
            balance: '20',
            currencyCode: 'EUR',
          );
          await seedDatabase
              .into(seedDatabase.transactions)
              .insert(
                _transferLeg(
                  ownerScopeId: scope,
                  id: 'v16-terms-out',
                  accountId: 'source',
                  groupId: 'v16-contradictory-terms',
                  type: TransactionType.transferOut.storageValue,
                  amount: '10',
                  rateTo: 'EUR',
                  rate: '2',
                ),
              );
          await seedDatabase
              .into(seedDatabase.transactions)
              .insert(
                _transferLeg(
                  ownerScopeId: scope,
                  id: 'v16-terms-in',
                  accountId: 'target',
                  groupId: 'v16-contradictory-terms',
                  type: TransactionType.transferIn.storageValue,
                  amount: '15',
                  currencyCode: 'EUR',
                  rateTo: 'EUR',
                  rate: '2',
                ),
              );
        } finally {
          await seedDatabase.close();
        }

        final database = AppDatabase(
          executor: NativeDatabase(
            file,
            setup: (rawDatabase) {
              rawDatabase.execute(
                'ALTER TABLE transactions '
                'DROP COLUMN transfer_payload_fingerprint',
              );
              rawDatabase.execute('PRAGMA user_version = 16');
            },
          ),
          enforceOwnerScopeGuards: true,
          enforceFinancialIntegrityGuards: true,
        );
        try {
          await database.customSelect('SELECT 1').get();

          expect(
            await database.hasMalformedTransferGroupsForOwner(scope),
            isTrue,
          );
          final rows = await _groupRows(database, 'v16-contradictory-terms');
          expect(rows, hasLength(2));
          expect(
            rows.every((row) => row.transferPayloadFingerprint == null),
            isTrue,
          );
          expect(
            rows.singleWhere((row) => row.type == 'transferOut').amount,
            '10',
          );
          expect(
            rows.singleWhere((row) => row.type == 'transferIn').amount,
            '15',
          );
          await expectLater(
            database.updateAccountBalanceProjection(
              ownerScopeId: scope,
              accountId: 'source',
              balance: '99',
              updatedAt: DateTime.utc(2026, 2, 4),
            ),
            throwsA(
              isA<AppException>().having(
                (error) => error.code,
                'code',
                TransactionFailureCodes.transferScopeIntegrityQuarantined,
              ),
            ),
          );
        } finally {
          await database.close();
          await directory.delete(recursive: true);
        }
      },
    );
  });

  group('OF-005 legacy claim after a real reopen', () {
    test(
      'a canonical null-owner pair claims atomically with guards on',
      () async {
        final fixture = await _openLegacyPairFixture(
          const _LegacyPairShape(name: 'valid'),
        );
        addTearDown(() => fixture.dispose());
        final session = scopedTestSession(
          fixture.database,
          syntheticFirebaseUid: _ownerUid,
        );
        final service = LegacyDataClaimService(
          session: session,
          currentConfirmedScope: () => session.confirmedScope,
        );

        final result = await service.claim(protectedConfirmationAccepted: true);

        expect(result.claimedCount, 4);
        final rows = await _groupRows(fixture.database, 'legacy-valid');
        expect(rows, hasLength(2));
        expect(
          rows.every((row) => row.ownerScopeId == session.ownerScopeValue),
          isTrue,
        );
      },
    );

    test(
      'raw owner claim and claim-permit field smuggling stay blocked',
      () async {
        final fixture = await _openLegacyPairFixture(
          const _LegacyPairShape(name: 'permit abuse'),
          accountsAlreadyScoped: true,
        );
        addTearDown(() => fixture.dispose());
        final scope = scopedTestSession(
          fixture.database,
          syntheticFirebaseUid: _ownerUid,
        ).ownerScopeValue;

        await expectLater(
          fixture.database.customStatement(
            '''UPDATE transactions SET owner_scope_id = ?
               WHERE id = 'permit-abuse-out' ''',
            <Object?>[scope],
          ),
          throwsA(anything),
        );

        await fixture.database.customStatement(
          '''INSERT INTO cashpilot_transfer_legacy_claim_permits
               (target_owner_scope_id) VALUES (?)''',
          <Object?>[scope],
        );
        try {
          await expectLater(
            fixture.database.customStatement(
              '''UPDATE transactions
                 SET owner_scope_id = ?, status = 'posted'
                 WHERE id = 'permit-abuse-out' ''',
              <Object?>[scope],
            ),
            throwsA(anything),
          );
          await expectLater(
            fixture.database.customStatement(
              '''UPDATE transactions
                 SET owner_scope_id = ?, updated_at = updated_at + 1
                 WHERE id = 'permit-abuse-out' ''',
              <Object?>[scope],
            ),
            throwsA(anything),
          );
        } finally {
          await fixture.database.customStatement(
            '''DELETE FROM cashpilot_transfer_legacy_claim_permits
               WHERE target_owner_scope_id = ?''',
            <Object?>[scope],
          );
        }

        final rows = await _groupRows(fixture.database, 'legacy-permit-abuse');
        expect(rows, hasLength(2));
        expect(rows.every((row) => row.ownerScopeId == null), isTrue);
        expect(rows.every((row) => row.status == 'pending'), isTrue);
      },
    );

    final rejectedShapes = <_LegacyPairShape>[
      const _LegacyPairShape(
        name: 'status mismatch',
        outgoingStatus: 'pending',
        incomingStatus: 'posted',
      ),
      const _LegacyPairShape(name: 'same account', incomingAccount: 'source'),
      const _LegacyPairShape(name: 'zero amount', outgoingAmount: '0'),
      const _LegacyPairShape(
        name: 'negative target amount',
        incomingAmount: '-1',
      ),
      const _LegacyPairShape(name: 'negative rate', outgoingRate: '-1'),
      const _LegacyPairShape(name: 'mismatched rates', incomingRate: '2'),
      const _LegacyPairShape(
        name: 'same-currency amount contradiction',
        incomingAmount: '11',
      ),
      const _LegacyPairShape(
        name: 'same-currency non-unit rate',
        incomingAmount: '20',
        outgoingRate: '2',
        incomingRate: '2',
      ),
      const _LegacyPairShape(
        name: 'cross-currency amount-rate contradiction',
        incomingAmount: '15',
        outgoingRate: '2',
        incomingRate: '2',
        incomingCurrencyCode: 'EUR',
        targetAccountCurrencyCode: 'EUR',
        rateTo: 'EUR',
      ),
      const _LegacyPairShape(
        name: 'mismatched fingerprints',
        outgoingFingerprintSeed: 'legacy-out',
        incomingFingerprintSeed: 'legacy-in',
      ),
      const _LegacyPairShape(
        name: 'matching non-null fingerprints',
        outgoingFingerprintSeed: 'legacy-both',
        incomingFingerprintSeed: 'legacy-both',
      ),
      const _LegacyPairShape(
        name: 'target account currency mismatch',
        targetAccountCurrencyCode: 'EUR',
      ),
      const _LegacyPairShape(name: 'payee metadata', outgoingPayeeId: 'payee'),
      const _LegacyPairShape(
        name: 'income source metadata',
        incomingIncomeSourceType: 'salary',
      ),
      const _LegacyPairShape(
        name: 'location metadata',
        outgoingLocation: 'Tripoli',
      ),
      const _LegacyPairShape(
        name: 'attachment metadata',
        incomingAttachmentCount: 1,
      ),
      const _LegacyPairShape(
        name: 'AI confidence metadata',
        outgoingAiConfidence: 80,
      ),
      const _LegacyPairShape(
        name: 'review metadata',
        incomingNeedsReview: true,
      ),
    ];

    for (final shape in rejectedShapes) {
      test('${shape.name} is rejected and leaves both owners null', () async {
        final fixture = await _openLegacyPairFixture(shape);
        addTearDown(() => fixture.dispose());
        final session = scopedTestSession(
          fixture.database,
          syntheticFirebaseUid: _ownerUid,
        );
        final service = LegacyDataClaimService(
          session: session,
          currentConfirmedScope: () => session.confirmedScope,
        );

        Object? claimError;
        try {
          await service.claim(protectedConfirmationAccepted: true);
        } on Object catch (error) {
          claimError = error;
        }

        final rows = await _groupRows(fixture.database, 'legacy-${shape.slug}');
        expect(claimError, isNotNull, reason: shape.name);
        expect(rows, hasLength(2), reason: shape.name);
        expect(
          rows.every((row) => row.ownerScopeId == null),
          isTrue,
          reason: shape.name,
        );
      });
    }
  });

  test('transfer capability callsites stay on the reviewed boundaries', () {
    expect(_dotCallsiteFiles('insertTransferPair'), <String>[
      'lib/features/transactions/data/datasources/local/transactions_local_data_source.dart',
    ]);
    expect(_dotCallsiteFiles('updateTransferPair'), <String>[
      'lib/features/transactions/data/datasources/local/transactions_local_data_source.dart',
      'lib/features/transactions/data/services/local_transfer_pair_lifecycle.dart',
    ]);
    expect(_dotCallsiteFiles('deleteTransferPair'), <String>[
      'lib/features/transactions/data/datasources/local/transactions_local_data_source.dart',
      'lib/features/transactions/data/services/local_transfer_pair_lifecycle.dart',
    ]);
    expect(_dotCallsiteFiles('claimLegacyTransactions'), <String>[
      'lib/core/owner_scope/application/legacy_data_claim_service.dart',
    ]);
    expect(_dotCallsiteFiles('deleteTransactionsForOwnerDataDeletion'), <
      String
    >[
      'lib/features/data_deletion/data/datasources/account_deletion_scope_recovery_finalizer.dart',
      'lib/features/data_deletion/data/datasources/local_user_data_deletion_data_source.dart',
    ]);
  });
}

AppDatabase _guardedFileDatabase(File file) {
  return AppDatabase(
    executor: NativeDatabase(file),
    enforceOwnerScopeGuards: true,
    enforceFinancialIntegrityGuards: true,
  );
}

Future<AppDatabase> _guardedMemoryDatabase() async {
  final database = AppDatabase(
    executor: NativeDatabase.memory(),
    enforceOwnerScopeGuards: true,
    enforceFinancialIntegrityGuards: true,
  );
  await _seedDefaultTransferCategory(database);
  await _seedAccount(database, id: 'source', balance: '0');
  await _seedAccount(database, id: 'target', balance: '0');
  return database;
}

Future<void> _insertPendingPair(
  AppDatabase database, {
  required String scope,
  required String groupId,
}) {
  return database.insertTransferPair(
    ownerScopeId: scope,
    payloadFingerprint: _fingerprint(groupId),
    outgoing: _transferLeg(
      ownerScopeId: scope,
      id: 'guarded-out',
      accountId: 'source',
      groupId: groupId,
      type: TransactionType.transferOut.storageValue,
    ),
    incoming: _transferLeg(
      ownerScopeId: scope,
      id: 'guarded-in',
      accountId: 'target',
      groupId: groupId,
      type: TransactionType.transferIn.storageValue,
    ),
  );
}

TransactionsCompanion _transferLeg({
  required String? ownerScopeId,
  required String id,
  required String accountId,
  required String? groupId,
  required String type,
  String amount = '10',
  String status = 'pending',
  String categoryId = defaultTransferCategoryId,
  String paymentMethod = 'bankTransfer',
  String source = 'manual',
  String currencyCode = 'USD',
  String? rateFrom = 'USD',
  String? rateTo = 'USD',
  String? rate = '1',
  String? fingerprint,
  String? payeeId,
  String? incomeSourceType,
  String? location,
  int attachmentCount = 0,
  int? aiConfidence,
  bool needsReview = false,
}) {
  final timestamp = DateTime.parse(_occurredAt);
  return TransactionsCompanion(
    id: Value(id),
    ownerScopeId: Value(ownerScopeId),
    accountId: Value(accountId),
    categoryId: Value(categoryId),
    payeeId: Value(payeeId),
    amount: Value(amount),
    currencyCode: Value(currencyCode),
    type: Value(type),
    paymentMethod: Value(paymentMethod),
    source: Value(source),
    status: Value(status),
    incomeSourceType: Value(incomeSourceType),
    transferGroupId: Value(groupId),
    transferPayloadFingerprint: Value(fingerprint),
    exchangeRateFromCurrencyCode: Value(rateFrom),
    exchangeRateToCurrencyCode: Value(rateTo),
    exchangeRate: Value(rate),
    exchangeRateAsOf: Value(timestamp),
    note: const Value('canonical transfer'),
    transactionDate: Value(timestamp),
    location: Value(location),
    attachmentCount: Value(attachmentCount),
    aiConfidence: Value(aiConfidence),
    needsReview: Value(needsReview),
    createdAt: Value(timestamp),
    updatedAt: Value(timestamp),
  );
}

Future<void> _seedAccount(
  AppDatabase database, {
  required String id,
  required String balance,
  String currencyCode = 'USD',
  String? ownerScopeId,
}) {
  final resolvedOwner =
      ownerScopeId ??
      scopedTestSession(
        database,
        syntheticFirebaseUid: _ownerUid,
      ).ownerScopeValue;
  final timestamp = DateTime.utc(2026, 1, 1);
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion(
          id: Value(id),
          ownerScopeId: Value(resolvedOwner),
          name: Value(id),
          type: const Value('cash'),
          currencyCode: Value(currencyCode),
          balance: Value(balance),
          icon: const Value('wallet'),
          color: const Value(0xFF006C67),
          isArchived: const Value(false),
          createdAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
}

Future<void> _seedLegacyAccount(
  AppDatabase database, {
  required String id,
  required String balance,
  String currencyCode = 'USD',
  String? ownerScopeId,
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
          currencyCode: Value(currencyCode),
          balance: Value(balance),
          icon: const Value('wallet'),
          color: const Value(0xFF006C67),
          isArchived: const Value(false),
          createdAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
}

Future<void> _seedDefaultTransferCategory(AppDatabase database) {
  final definition = defaultCategoryDefinitions.singleWhere(
    (candidate) => candidate.id == defaultTransferCategoryId,
  );
  final timestamp = DateTime.utc(2026, 1, 1);
  return database
      .into(database.categories)
      .insert(
        CategoriesCompanion(
          id: Value(definition.id),
          ownerScopeId: const Value(null),
          name: Value(definition.name),
          type: Value(definition.type.name),
          icon: Value(definition.iconKey),
          color: Value(definition.colorArgb),
          isDefault: const Value(true),
          isArchived: const Value(false),
          sortOrder: Value(definition.sortOrder),
          createdAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
}

Future<List<TransactionRow>> _groupRows(AppDatabase database, String groupId) {
  return (database.select(
    database.transactions,
  )..where((row) => row.transferGroupId.equals(groupId))).get();
}

String _fingerprint(String value) {
  // A deterministic lowercase SHA-256-shaped test commitment. The production
  // payload is deliberately not duplicated in tests.
  final seed = value.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  final nibble = (seed % 16).toRadixString(16);
  return List<String>.filled(64, nibble).join();
}

Future<_LegacyFixture> _openLegacyPairFixture(
  _LegacyPairShape shape, {
  bool accountsAlreadyScoped = false,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'cashpilot-of005-legacy-',
  );
  final file = File(
    '${directory.path}${Platform.pathSeparator}cashpilot.sqlite',
  );
  final seedDatabase = AppDatabase(executor: NativeDatabase(file));
  try {
    await _seedDefaultTransferCategory(seedDatabase);
    final seededAccountOwner = accountsAlreadyScoped
        ? scopedTestSession(
            seedDatabase,
            syntheticFirebaseUid: _ownerUid,
          ).ownerScopeValue
        : null;
    await _seedLegacyAccount(
      seedDatabase,
      id: 'source',
      balance: '100',
      ownerScopeId: seededAccountOwner,
    );
    await _seedLegacyAccount(
      seedDatabase,
      id: 'target',
      balance: '20',
      currencyCode: shape.targetAccountCurrencyCode,
      ownerScopeId: seededAccountOwner,
    );
    final groupId = 'legacy-${shape.slug}';
    await seedDatabase
        .into(seedDatabase.transactions)
        .insert(
          _transferLeg(
            ownerScopeId: null,
            id: '${shape.slug}-out',
            accountId: 'source',
            groupId: groupId,
            type: TransactionType.transferOut.storageValue,
            amount: shape.outgoingAmount,
            status: shape.outgoingStatus,
            rateTo: shape.rateTo,
            rate: shape.outgoingRate,
            payeeId: shape.outgoingPayeeId,
            location: shape.outgoingLocation,
            aiConfidence: shape.outgoingAiConfidence,
            fingerprint: shape.outgoingFingerprintSeed == null
                ? null
                : _fingerprint(shape.outgoingFingerprintSeed!),
          ),
        );
    await seedDatabase
        .into(seedDatabase.transactions)
        .insert(
          _transferLeg(
            ownerScopeId: null,
            id: '${shape.slug}-in',
            accountId: shape.incomingAccount,
            groupId: groupId,
            type: TransactionType.transferIn.storageValue,
            amount: shape.incomingAmount,
            status: shape.incomingStatus,
            currencyCode: shape.incomingCurrencyCode,
            rateTo: shape.rateTo,
            rate: shape.incomingRate,
            incomeSourceType: shape.incomingIncomeSourceType,
            attachmentCount: shape.incomingAttachmentCount,
            needsReview: shape.incomingNeedsReview,
            fingerprint: shape.incomingFingerprintSeed == null
                ? null
                : _fingerprint(shape.incomingFingerprintSeed!),
          ),
        );
  } finally {
    await seedDatabase.close();
  }

  return _LegacyFixture(
    database: _guardedFileDatabase(file),
    directory: directory,
  );
}

List<String> _dotCallsiteFiles(String method) {
  final expression = RegExp('\\.$method\\s*\\(');
  final paths = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final matches = expression.allMatches(entity.readAsStringSync()).length;
    final normalized = entity.path.replaceAll('\\', '/');
    for (var index = 0; index < matches; index += 1) {
      paths.add(normalized);
    }
  }
  paths.sort();
  return paths;
}

final class _LegacyFixture {
  const _LegacyFixture({required this.database, required this.directory});

  final AppDatabase database;
  final Directory directory;

  Future<void> dispose() async {
    await database.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

final class _LegacyPairShape {
  const _LegacyPairShape({
    required this.name,
    this.outgoingStatus = 'pending',
    this.incomingStatus = 'pending',
    this.incomingAccount = 'target',
    this.outgoingAmount = '10',
    this.incomingAmount = '10',
    this.outgoingRate = '1',
    this.incomingRate = '1',
    this.outgoingFingerprintSeed,
    this.incomingFingerprintSeed,
    this.incomingCurrencyCode = 'USD',
    this.targetAccountCurrencyCode = 'USD',
    this.rateTo = 'USD',
    this.outgoingPayeeId,
    this.incomingIncomeSourceType,
    this.outgoingLocation,
    this.incomingAttachmentCount = 0,
    this.outgoingAiConfidence,
    this.incomingNeedsReview = false,
  });

  final String name;
  final String outgoingStatus;
  final String incomingStatus;
  final String incomingAccount;
  final String outgoingAmount;
  final String incomingAmount;
  final String outgoingRate;
  final String incomingRate;
  final String? outgoingFingerprintSeed;
  final String? incomingFingerprintSeed;
  final String incomingCurrencyCode;
  final String targetAccountCurrencyCode;
  final String rateTo;
  final String? outgoingPayeeId;
  final String? incomingIncomeSourceType;
  final String? outgoingLocation;
  final int incomingAttachmentCount;
  final int? outgoingAiConfidence;
  final bool incomingNeedsReview;

  String get slug => name.replaceAll(' ', '-');
}

final class _MalformedPair {
  const _MalformedPair({
    required this.name,
    this.incomingAccount = 'target',
    this.outgoingAmount = '10',
    this.incomingAmount = '10',
    this.outgoingRate = '1',
    this.incomingRate = '1',
    this.incomingRateFrom = 'USD',
    this.incomingPaymentMethod = 'bankTransfer',
    this.incomingCurrencyCode = 'USD',
    this.rateTo = 'USD',
  });

  final String name;
  final String incomingAccount;
  final String outgoingAmount;
  final String incomingAmount;
  final String outgoingRate;
  final String incomingRate;
  final String incomingRateFrom;
  final String incomingPaymentMethod;
  final String incomingCurrencyCode;
  final String rateTo;
}
