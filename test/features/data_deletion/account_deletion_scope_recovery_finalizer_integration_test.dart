import 'dart:convert';
import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/storage/owner_scoped_storage_keys.dart';
import 'package:cashpilot_ai/core/storage/settings_keys.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/core/sync/application/owner_deletion_quarantine_store.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_session_guard.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_scope_recovery_finalizer.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/data_deletion_operation_state_store.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_local_image_store.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test(
    'UID-free recovery deletes only A across every approved local surface and is idempotent',
    () async {
      final fixture = await _Fixture.create('owner-isolation');
      addTearDown(fixture.dispose);
      await fixture.seedAll();

      expect(await _ownerScopedTableNames(fixture.database), _approvedTables);
      for (final table in _approvedTables) {
        expect(await fixture.count(table, _scopeA), 1, reason: '$table A seed');
        expect(await fixture.count(table, _scopeB), 1, reason: '$table B seed');
      }

      final lease = await fixture.operationFence.fenceAndDrain(
        ownerScopeValue: _scopeA,
        operationId: _operationA,
        durable: true,
      );
      expect(fixture.operationFence.tryAcquireWriter(_scopeA), isNull);
      fixture.operationFence.tryAcquireWriter(_scopeB)!.release();

      for (var pass = 0; pass < 2; pass += 1) {
        await fixture.finalizer.deleteLocalRows(_targetA);
        expect(await fixture.finalizer.verifyLocalRowsEmpty(_targetA), isTrue);
        await fixture.finalizer.deleteReceiptFiles(_targetA);
        await fixture.finalizer.clearPreferences(_targetA);
        await fixture.finalizer.markCompletionOverlay(_targetA);
        await fixture.finalizer.clearOperationState(_targetA);
      }

      for (final table in _approvedTables) {
        expect(await fixture.count(table, _scopeA), 0, reason: '$table A');
        expect(await fixture.count(table, _scopeB), 1, reason: '$table B');
      }
      expect(await fixture.legacyRawUidQueueCount(), 1);
      expect(await File(fixture.imageA).exists(), isFalse);
      expect(await File(fixture.imageB).exists(), isTrue);
      expect(fixture.receiptFactoryScopes, everyElement(_scopeA));

      expect(fixture.box.containsKey(fixture.journalA), isFalse);
      expect(
        fixture.box.containsKey('${fixture.journalA}:chunk:generation:0'),
        isFalse,
      );
      expect(fixture.box.containsKey(fixture.otherOperationJournalA), isTrue);
      expect(fixture.box.containsKey(fixture.journalB), isTrue);

      for (final key in _preferenceKeys(_scopeA)) {
        expect(fixture.box.containsKey(key), isFalse, reason: 'A pref $key');
      }
      for (final key in _preferenceKeys(_scopeB)) {
        expect(fixture.box.containsKey(key), isTrue, reason: 'B pref $key');
      }
      expect(fixture.box.containsKey(_legacyRawUidBackupKey), isTrue);
      expect(fixture.box.get(SettingsKeys.themeMode), 'dark');

      expect(fixture.overlay.lastOwnerScope, _scopeA);
      expect(fixture.overlay.lastAuthGeneration, -1);
      expect(fixture.overlay.lastOperationId, _operationA);
      expect(fixture.box.containsKey(fixture.completedOverlayA), isTrue);
      expect(fixture.box.containsKey(fixture.operationStateA), isFalse);
      expect(fixture.box.containsKey(fixture.operationStateB), isTrue);

      await lease.releaseAndClearQuarantine();
      expect(fixture.operationFence.isFenced(_scopeA), isFalse);
    },
  );

  test(
    'recovery requires the exact operation to own a fully drained writer fence',
    () async {
      final fixture = await _Fixture.create('writer-fence');
      addTearDown(fixture.dispose);
      await _seedOwnedGraph(fixture.database, _scopeA, 'a', _rawUidB);

      final writer = fixture.operationFence.tryAcquireWriter(_scopeA)!;
      final draining = fixture.operationFence.fenceAndDrain(
        ownerScopeValue: _scopeA,
        operationId: _operationA,
        durable: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(writer.isCancelled, isTrue);
      await expectLater(
        fixture.finalizer.deleteLocalRows(_targetA),
        throwsStateError,
      );
      expect(await fixture.count('accounts', _scopeA), 1);
      fixture.operationFence.tryAcquireWriter(_scopeB)!.release();

      writer.release();
      final lease = await draining;
      await expectLater(
        fixture.finalizer.deleteLocalRows(_targetWithWrongOperation),
        throwsStateError,
      );
      expect(await fixture.count('accounts', _scopeA), 1);

      await fixture.finalizer.deleteLocalRows(_targetA);
      expect(await fixture.finalizer.verifyLocalRowsEmpty(_targetA), isTrue);
      await lease.releaseAndClearQuarantine();
    },
  );
}

const _scopeA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _scopeB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _operationA = '01900000-0000-7000-8000-000000000111';
const _operationB = '01900000-0000-7000-8000-000000000222';
const _otherOperation = '01900000-0000-7000-8000-000000000333';
const _rawUidA = 'raw-firebase-uid-a';
const _rawUidB = 'raw-firebase-uid-b';
const _legacyRawUidBackupKey = '${SettingsKeys.backupEnabled}_$_rawUidA';

final _targetA = AccountDeletionRecoveryTarget(
  operationId: _operationA,
  ownerScopeValue: _scopeA,
);
final _targetWithWrongOperation = AccountDeletionRecoveryTarget(
  operationId: _operationB,
  ownerScopeValue: _scopeA,
);

const _approvedTables = <String>{
  'ai_agent_plan_steps',
  'ai_agent_plans',
  'ai_agent_confirmation_proofs',
  'ai_agent_execution_results',
  'ai_agent_execution_attempts',
  'ai_agent_business_operations',
  'ai_agent_idempotency_records',
  'ai_agent_previews',
  'ai_agent_audit_events',
  'ai_agent_commands',
  'transaction_splits',
  'receipt_line_items',
  'receipts',
  'transactions',
  'goal_contributions',
  'goals',
  'budgets',
  'exchange_rates',
  'payees',
  'categories',
  'accounts',
  'sync_queue',
  'owner_scope_migration_audits',
};

final class _Fixture {
  _Fixture._({
    required this.directory,
    required this.box,
    required this.database,
    required this.operationFence,
    required this.overlay,
    required this.finalizer,
    required this.receiptFactoryScopes,
  });

  static Future<_Fixture> create(String name) async {
    final directory = await Directory.systemTemp.createTemp(
      'cashpilot-uid-free-recovery-$name-',
    );
    Hive.init(directory.path);
    final box = await Hive.openBox<dynamic>('uid-free-recovery-$name');
    final database = AppDatabase(executor: NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    final quarantineStore = HiveOwnerDeletionQuarantineStore(box);
    final operationFence = BackupOperationFence(
      quarantineStore: quarantineStore,
    );
    final overlay = _RecordingCompletedOverlay(box);
    final receiptFactoryScopes = <String>[];
    final finalizer = UidFreeAccountDeletionScopeRecoveryFinalizer(
      database: database,
      operationFence: operationFence,
      settingsBox: box,
      completedDeletionOverlay: overlay,
      operationStateStore: HiveDataDeletionOperationStateStore(box),
      receiptImageStoreFactory: (ownerScopeValue) {
        receiptFactoryScopes.add(ownerScopeValue);
        return ReceiptLocalImageStore(
          ownerScopeValue: ownerScopeValue,
          baseDirectory: () async => directory,
        );
      },
    );
    return _Fixture._(
      directory: directory,
      box: box,
      database: database,
      operationFence: operationFence,
      overlay: overlay,
      finalizer: finalizer,
      receiptFactoryScopes: receiptFactoryScopes,
    );
  }

  final Directory directory;
  final Box<dynamic> box;
  final AppDatabase database;
  final BackupOperationFence operationFence;
  final _RecordingCompletedOverlay overlay;
  final UidFreeAccountDeletionScopeRecoveryFinalizer finalizer;
  final List<String> receiptFactoryScopes;
  late final String imageA;
  late final String imageB;

  OwnerScopedStorageKeys get keysA =>
      OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(_scopeA);
  OwnerScopedStorageKeys get keysB =>
      OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(_scopeB);
  String get journalA => keysA.receiptFileDeletionJournal(_operationA);
  String get journalB => keysB.receiptFileDeletionJournal(_operationA);
  String get otherOperationJournalA =>
      keysA.receiptFileDeletionJournal(_otherOperation);
  String get completedOverlayA => keysA.completedAccountDeletion;
  String get operationStateA => keysA.dataDeletionOperationState;
  String get operationStateB => keysB.dataDeletionOperationState;

  Future<void> seedAll() async {
    await _seedOwnedGraph(database, _scopeA, 'a', _rawUidB);
    await _seedOwnedGraph(database, _scopeB, 'b', _rawUidA);
    await database.customStatement(
      '''INSERT INTO sync_queue (
        id, owner_scope_id, owner_user_id, entity_type, entity_id, operation,
        payload_json, created_at, updated_at
      ) VALUES ('legacy-raw-uid-queue', NULL, ?, 'account', 'legacy',
        'delete', '{}', 1, 1)''',
      <Object?>[_rawUidA],
    );

    imageA = await _imageStore(_scopeA).write('receipt-a', const <int>[1, 2]);
    imageB = await _imageStore(_scopeB).write('receipt-b', const <int>[3, 4]);
    await box.put(journalA, 'A manifest');
    await box.put('$journalA:chunk:generation:0', 'A chunk');
    await box.put(otherOperationJournalA, 'A other operation');
    await box.put(journalB, 'B manifest');

    for (final key in _preferenceKeys(_scopeA)) {
      await box.put(key, 'A');
    }
    for (final key in _preferenceKeys(_scopeB)) {
      await box.put(key, 'B');
    }
    await box.put(_legacyRawUidBackupKey, 'must remain');
    await box.put(SettingsKeys.themeMode, 'dark');
    await _seedOperationState(box, operationStateA, _operationA);
    await _seedOperationState(box, operationStateB, _operationB);
  }

  ReceiptLocalImageStore _imageStore(String scope) => ReceiptLocalImageStore(
    ownerScopeValue: scope,
    baseDirectory: () async => directory,
  );

  Future<int> count(String table, String scope) async {
    final result = await database
        .customSelect(
          'SELECT COUNT(*) AS count FROM $table WHERE owner_scope_id = ?',
          variables: <Variable<Object>>[Variable<String>(scope)],
        )
        .getSingle();
    return result.read<int>('count');
  }

  Future<int> legacyRawUidQueueCount() async {
    final result = await database
        .customSelect(
          '''SELECT COUNT(*) AS count FROM sync_queue
             WHERE owner_scope_id IS NULL AND owner_user_id = ?''',
          variables: <Variable<Object>>[Variable<String>(_rawUidA)],
        )
        .getSingle();
    return result.read<int>('count');
  }

  Future<void> dispose() async {
    await database.close();
    await box.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

final class _RecordingCompletedOverlay
    implements CompletedAccountDeletionOverlay {
  _RecordingCompletedOverlay(this.box);

  final Box<dynamic> box;
  String? lastOwnerScope;
  String? lastOperationId;
  int? lastAuthGeneration;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  bool hasTrustedCompletion({
    required String operationId,
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
  }) =>
      operationId == lastOperationId &&
      ownerScope.id.value == lastOwnerScope &&
      capturedAuthGeneration == lastAuthGeneration;

  @override
  Future<void> markCompleted({
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
    required String operationId,
  }) async {
    lastOwnerScope = ownerScope.id.value;
    lastOperationId = operationId;
    lastAuthGeneration = capturedAuthGeneration;
    await box.put(
      OwnerScopedStorageKeys.fromConfirmedOwnerScope(
        ownerScope,
      ).completedAccountDeletion,
      jsonEncode(<String, Object>{'version': 1, 'operationId': operationId}),
    );
  }

  @override
  bool shouldSuppress(firebase_auth.User? user) => false;
}

Future<void> _seedOperationState(
  Box<dynamic> box,
  String key,
  String operationId,
) => box.put(
  key,
  jsonEncode(<String, Object>{
    'version': 1,
    'operationId': operationId,
    'startedAtUtc': DateTime.utc(2026, 8, 10).toIso8601String(),
    'lastCompletedStage': DataDeletionStage.preferencesDeleted.name,
  }),
);

List<String> _preferenceKeys(String scope) {
  final keys = OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(scope);
  return <String>[
    '${SettingsKeys.backupEnabled}_$scope',
    '${SettingsKeys.lastBackupAt}_$scope',
    '${SettingsKeys.backupConsentGeneration}_$scope',
    '${SettingsKeys.backupInitialSnapshotComplete}_$scope',
    ...keys.values,
  ];
}

Future<Set<String>> _ownerScopedTableNames(AppDatabase database) async {
  final tables = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  final result = <String>{};
  for (final table in tables) {
    final name = table.read<String>('name');
    final columns = await database
        .customSelect('PRAGMA table_info($name)')
        .get();
    if (columns.any(
      (column) => column.read<String>('name') == 'owner_scope_id',
    )) {
      result.add(name);
    }
  }
  return result;
}

Future<void> _seedOwnedGraph(
  AppDatabase database,
  String scope,
  String suffix,
  String queueOwnerUserId,
) async {
  String id(String prefix) => '$prefix-$suffix';
  final account = id('account');
  final category = id('category');
  final payee = id('payee');
  final transaction = id('transaction');
  final goal = id('goal');
  final receipt = id('receipt');
  final command = id('agent-command');
  final attempt = id('agent-attempt');
  final result = id('agent-result');
  final plan = id('agent-plan');
  final businessOperation = id('agent-operation');

  await database.customStatement(
    '''INSERT INTO accounts (
      id, owner_scope_id, name, type, currency_code, balance, icon, color,
      created_at, updated_at
    ) VALUES (?, ?, 'Cash', 'cash', 'USD', '10', 'wallet', 1, 1, 1)''',
    <Object?>[account, scope],
  );
  await database.customStatement(
    '''INSERT INTO categories (
      id, owner_scope_id, name, type, icon, color, sort_order, created_at,
      updated_at
    ) VALUES (?, ?, 'Food', 'expense', 'food', 1, 0, 1, 1)''',
    <Object?>[category, scope],
  );
  await database.customStatement(
    '''INSERT INTO payees (
      id, owner_scope_id, name, normalized_name, created_at, updated_at
    ) VALUES (?, ?, 'Shop', ?, 1, 1)''',
    <Object?>[payee, scope, 'shop-$suffix'],
  );
  await database.customStatement(
    '''INSERT INTO transactions (
      id, owner_scope_id, account_id, category_id, payee_id, amount,
      currency_code, type, payment_method, source, status, transaction_date,
      created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, '1', 'USD', 'expense', 'cash', 'manual',
      'posted', 1, 1, 1)''',
    <Object?>[transaction, scope, account, category, payee],
  );
  await database.customStatement(
    '''INSERT INTO exchange_rates (
      id, owner_scope_id, base_currency, quote_currency, rate, source,
      fetched_at, created_at, updated_at
    ) VALUES (?, ?, 'USD', 'LYD', '4.8', 'manual', 1, 1, 1)''',
    <Object?>[id('rate'), scope],
  );
  await database.customStatement(
    '''INSERT INTO budgets (
      id, owner_scope_id, name, category_id, amount, currency, period_type,
      start_date, end_date, alert_threshold_percent, created_at, updated_at
    ) VALUES (?, ?, 'Food', ?, '100', 'USD', 'monthly', 1, 2, 80, 1, 1)''',
    <Object?>[id('budget'), scope, category],
  );
  await database.customStatement(
    '''INSERT INTO goals (
      id, owner_scope_id, title, type, target_amount, current_amount, currency,
      icon, color, status, linked_account_id, created_at, updated_at
    ) VALUES (?, ?, 'Goal', 'savings', '1000', '100', 'USD', 'target', 1,
      'active', ?, 1, 1)''',
    <Object?>[goal, scope, account],
  );
  await database.customStatement(
    '''INSERT INTO goal_contributions (
      id, owner_scope_id, goal_id, amount, currency, credited_amount, date,
      created_at, updated_at
    ) VALUES (?, ?, ?, '10', 'USD', '10', 1, 1, 1)''',
    <Object?>[id('contribution'), scope, goal],
  );
  await database.customStatement(
    '''INSERT INTO receipts (
      id, owner_scope_id, document_type, payment_status, confidence,
      image_retention_choice, status, created_at, updated_at
    ) VALUES (?, ?, 'purchase_receipt', 'paid', 90, 'keep_locally',
      'review_required', 1, 1)''',
    <Object?>[receipt, scope],
  );
  await database.customStatement(
    '''INSERT INTO receipt_line_items (
      id, owner_scope_id, receipt_id, description, normalized_description,
      category_suggestion_source
    ) VALUES (?, ?, ?, 'Milk', 'milk', 'localKeyword')''',
    <Object?>[id('receipt-item'), scope, receipt],
  );
  await database.customStatement(
    '''INSERT INTO transaction_splits (
      id, owner_scope_id, receipt_id, transaction_id, category_id, amount
    ) VALUES (?, ?, ?, ?, ?, '1')''',
    <Object?>[id('split'), scope, receipt, transaction, category],
  );
  await database.customStatement(
    '''INSERT INTO sync_queue (
      id, owner_scope_id, owner_user_id, entity_type, entity_id, operation,
      payload_json, created_at, updated_at
    ) VALUES (?, ?, ?, 'account', ?, 'delete', '{}', 1, 1)''',
    <Object?>[id('queue'), scope, queueOwnerUserId, account],
  );
  await database.customStatement(
    '''INSERT INTO owner_scope_migration_audits (
      id, owner_scope_id, status, bounded_counts_json, created_at, updated_at
    ) VALUES (?, ?, 'completed', '{}', 1, 1)''',
    <Object?>[id('audit'), scope],
  );

  await database.customStatement(
    '''INSERT INTO ai_agent_commands (
      id, owner_scope_id, conversation_id, command_type, tool_id,
      normalized_arguments_json, permission, risk, status, revision,
      expires_at, created_at, updated_at
    ) VALUES (?, ?, ?, 'create', 'create_transaction', '{}',
      'executeConfirmedAction', 'high', 'confirmed', 1, 2, 1, 1)''',
    <Object?>[command, scope, id('conversation')],
  );
  await database.customStatement(
    '''INSERT INTO ai_agent_previews (
      id, owner_scope_id, command_id, revision, status, state_fingerprint,
      payload_json, expires_at, created_at, updated_at
    ) VALUES (?, ?, ?, 1, 'valid', 'fp', '{}', 2, 1, 1)''',
    <Object?>[id('agent-preview'), scope, command],
  );
  await database.customStatement(
    '''INSERT INTO ai_agent_confirmation_proofs (
      id, owner_scope_id, command_id, preview_revision, confirmation_method,
      proof_hash, proof_salt, status, expires_at, created_at, updated_at
    ) VALUES (?, ?, ?, 1, 'explicit', 'hash', 'salt', 'active', 2, 1, 1)''',
    <Object?>[id('agent-proof'), scope, command],
  );
  await database.customStatement(
    '''INSERT INTO ai_agent_business_operations (
      id, owner_scope_id, command_id, command_revision, action_type,
      entity_type, expected_entity_ids_json, verification_method, status,
      automatic_resume_allowed, automatic_retry_prohibited, created_at,
      updated_at
    ) VALUES (?, ?, ?, 1, 'create', 'transaction', '[]', 'readAfterWrite',
      'claimed', 0, 1, 1, 1)''',
    <Object?>[businessOperation, scope, command],
  );
  await database.customStatement(
    '''INSERT INTO ai_agent_execution_attempts (
      id, owner_scope_id, command_id, idempotency_key, command_revision,
      action_type, status, business_operation_id, claimed_at, created_at,
      updated_at
    ) VALUES (?, ?, ?, ?, 1, 'create', 'claimed', ?, 1, 1, 1)''',
    <Object?>[attempt, scope, command, 'key-$suffix', businessOperation],
  );
  await database.customStatement(
    '''INSERT INTO ai_agent_execution_results (
      id, owner_scope_id, command_id, attempt_id, status, verified,
      entity_type, affected_count, safe_result_json, created_at, updated_at
    ) VALUES (?, ?, ?, ?, 'succeeded', 1, 'transaction', 1, '{}', 1, 1)''',
    <Object?>[result, scope, command, attempt],
  );
  await database.customStatement(
    '''INSERT INTO ai_agent_plans (
      id, owner_scope_id, conversation_id, status, atomic, expires_at,
      created_at, updated_at
    ) VALUES (?, ?, ?, 'confirmed', 0, 2, 1, 1)''',
    <Object?>[plan, scope, id('conversation')],
  );
  await database.customStatement(
    '''INSERT INTO ai_agent_plan_steps (
      id, owner_scope_id, plan_id, command_id, position, status, created_at,
      updated_at
    ) VALUES (?, ?, ?, ?, 0, 'ready', 1, 1)''',
    <Object?>[id('agent-step'), scope, plan, command],
  );
  await database.customStatement(
    '''INSERT INTO ai_agent_audit_events (
      id, owner_scope_id, command_id, action_type, entity_type, result,
      confirmation_method, undo_available, created_at, updated_at
    ) VALUES (?, ?, ?, 'create', 'transaction', 'succeeded', 'explicit',
      0, 1, 1)''',
    <Object?>[id('agent-audit'), scope, command],
  );
  await database.customStatement(
    '''INSERT INTO ai_agent_idempotency_records (
      id, owner_scope_id, command_id, command_revision, action_type,
      idempotency_hash, status, execution_result_id, created_at, updated_at
    ) VALUES (?, ?, ?, 1, 'create', ?, 'completed', ?, 1, 1)''',
    <Object?>[
      id('agent-idempotency'),
      scope,
      command,
      'idempotency-$suffix',
      result,
    ],
  );
}
