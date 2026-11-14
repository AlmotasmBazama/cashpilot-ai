import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/application/legacy_data_claim_service.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_health_service.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'explicit claim migrates only a sync row attributable to current owner',
    () async {
      const ownerUid = 'legacy-sync-current-owner';
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      await _insertLegacySyncRow(
        database,
        id: 'legacy-current',
        ownerUid: ownerUid,
      );
      final session = ScopedAppDatabaseSession(
        database: database,
        scope: OwnerScopeDerivation.fromConfirmedFirebaseUid(ownerUid),
      );
      final service = LegacyDataClaimService(
        session: session,
        currentConfirmedScope: () => session.confirmedScope,
      );
      final snapshot = OwnerScopeSnapshot(
        status: OwnerScopeStatus.safe,
        scope: session.confirmedScope,
      );

      final before = await service.inspectBoundedCounts();
      expect(before.counts['sync_queue'], 1);
      expect(before.total, 1);
      expect(before.hasUnexpectedSyncQueueRows, isFalse);
      expect(
        (await OwnerScopeHealthService(
          database,
        ).evaluate(snapshot: snapshot, session: session)).status,
        OwnerScopeStatus.legacyDataUnclaimed,
      );

      await expectLater(
        service.claim(protectedConfirmationAccepted: false),
        throwsA(
          isA<OwnerScopeException>().having(
            (error) => error.failure,
            'failure',
            OwnerScopeFailure.authNotConfirmed,
          ),
        ),
      );
      expect(
        (await _syncRow(database, 'legacy-current'))['owner_scope_id'],
        isNull,
      );

      final result = await service.claim(protectedConfirmationAccepted: true);
      expect(result.claimedCount, 1);
      final migrated = await _syncRow(database, 'legacy-current');
      expect(migrated['owner_scope_id'], session.ownerScopeValue);
      expect(migrated['owner_user_id'], session.ownerScopeValue);
      expect(migrated['payload_json'], '{}');
      expect((await service.inspectBoundedCounts()).total, 0);
      expect(
        (await OwnerScopeHealthService(
          database,
        ).evaluate(snapshot: snapshot, session: session)).status,
        OwnerScopeStatus.safe,
      );
    },
  );

  test(
    'other-owner legacy sync row fails closed and rolls back domain claim',
    () async {
      const currentUid = 'claim-current-owner';
      const otherUid = 'legacy-sync-other-owner';
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      await database.customStatement('''
        INSERT INTO accounts (
          id, name, type, currency_code, balance, icon, color,
          created_at, updated_at
        ) VALUES (
          'legacy-account', 'Legacy', 'cash', 'LYD', '0', 'wallet', 1,
          1, 1
        )
      ''');
      await _insertLegacySyncRow(
        database,
        id: 'legacy-other',
        ownerUid: otherUid,
      );
      final session = ScopedAppDatabaseSession(
        database: database,
        scope: OwnerScopeDerivation.fromConfirmedFirebaseUid(currentUid),
      );
      final service = LegacyDataClaimService(
        session: session,
        currentConfirmedScope: () => session.confirmedScope,
      );

      final inventory = await service.inspectBoundedCounts();
      expect(inventory.counts['accounts'], 1);
      expect(inventory.counts['sync_queue'], 0);
      expect(inventory.hasUnexpectedSyncQueueRows, isTrue);

      await expectLater(
        service.claim(protectedConfirmationAccepted: true),
        throwsA(
          isA<OwnerScopeException>().having(
            (error) => error.failure,
            'failure',
            OwnerScopeFailure.integrityCheckFailed,
          ),
        ),
      );

      final account = await database
          .customSelect(
            "SELECT owner_scope_id FROM accounts WHERE id = 'legacy-account'",
          )
          .getSingle();
      expect(account.readNullable<String>('owner_scope_id'), isNull);
      final untouched = await _syncRow(database, 'legacy-other');
      expect(untouched['owner_scope_id'], isNull);
      expect(untouched['owner_user_id'], otherUid);
      final audits = await database
          .customSelect(
            'SELECT COUNT(*) AS value FROM owner_scope_migration_audits',
          )
          .getSingle();
      expect(audits.read<int>('value'), 0);
    },
  );

  test(
    'invalid current-owner sync reference rolls back the whole claim',
    () async {
      const ownerUid = 'invalid-upsert-owner';
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      await database.customStatement('''
        INSERT INTO accounts (
          id, name, type, currency_code, balance, icon, color,
          created_at, updated_at
        ) VALUES (
          'legacy-account', 'Legacy', 'cash', 'LYD', '0', 'wallet', 1,
          1, 1
        )
      ''');
      await _insertLegacySyncRow(
        database,
        id: 'invalid-current-upsert',
        ownerUid: ownerUid,
        entityId: 'missing-account',
        operation: 'upsert',
      );
      final session = ScopedAppDatabaseSession(
        database: database,
        scope: OwnerScopeDerivation.fromConfirmedFirebaseUid(ownerUid),
      );
      final service = LegacyDataClaimService(
        session: session,
        currentConfirmedScope: () => session.confirmedScope,
      );

      await expectLater(
        service.claim(protectedConfirmationAccepted: true),
        throwsA(
          isA<OwnerScopeException>().having(
            (error) => error.failure,
            'failure',
            OwnerScopeFailure.integrityCheckFailed,
          ),
        ),
      );

      final account = await database
          .customSelect(
            "SELECT owner_scope_id FROM accounts WHERE id = 'legacy-account'",
          )
          .getSingle();
      expect(account.readNullable<String>('owner_scope_id'), isNull);
      final syncRow = await _syncRow(database, 'invalid-current-upsert');
      expect(syncRow['owner_scope_id'], isNull);
      expect(syncRow['owner_user_id'], ownerUid);
    },
  );
}

Future<void> _insertLegacySyncRow(
  AppDatabase database, {
  required String id,
  required String ownerUid,
  String entityId = 'remote-account',
  String operation = 'delete',
}) {
  return database.customStatement(
    '''INSERT INTO sync_queue (
         id, owner_scope_id, owner_user_id, entity_type, entity_id,
         operation, payload_json, status, attempt_count, created_at,
         updated_at
       ) VALUES (?, NULL, ?, 'account', ?, ?, ?,
         'pending', 0, 1, 1)''',
    <Object?>[
      id,
      ownerUid,
      entityId,
      operation,
      '{"privateNote":"must be scrubbed"}',
    ],
  );
}

Future<Map<String, Object?>> _syncRow(AppDatabase database, String id) async {
  final row = await database
      .customSelect(
        '''SELECT owner_scope_id, owner_user_id, payload_json
           FROM sync_queue WHERE id = ?''',
        variables: <Variable<Object>>[Variable<String>(id)],
      )
      .getSingle();
  return <String, Object?>{
    'owner_scope_id': row.readNullable<String>('owner_scope_id'),
    'owner_user_id': row.read<String>('owner_user_id'),
    'payload_json': row.read<String>('payload_json'),
  };
}
