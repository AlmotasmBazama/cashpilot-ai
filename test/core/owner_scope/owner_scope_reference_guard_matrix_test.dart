import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

const _canonicalDefaultCategoryId = '01900000-0000-7000-8000-000000000001';

void main() {
  test('canonical built-in global category remains insertable', () async {
    final fixture = await _GuardFixture.open();
    addTearDown(fixture.database.close);

    expect(
      await fixture.database
          .customSelect('''SELECT COUNT(*) AS value FROM categories
              WHERE id = '$_canonicalDefaultCategoryId' ''')
          .getSingle()
          .then((row) => row.read<int>('value')),
      1,
    );
  });

  for (final guardCase in _referenceGuardCases) {
    test('${guardCase.name} is rejected by database guards', () async {
      final fixture = await _GuardFixture.open();
      addTearDown(fixture.database.close);

      await expectLater(
        fixture.database.customStatement(guardCase.sql(fixture)),
        throwsA(isA<Object>()),
        reason: guardCase.name,
      );
    });
  }
}

final _referenceGuardCases = <_ReferenceGuardCase>[
  _ReferenceGuardCase(
    'forged global default category insert',
    (fixture) => '''INSERT INTO categories (
      id, owner_scope_id, name, type, icon, color, is_default, sort_order,
      created_at, updated_at
    ) VALUES ('forged-global', NULL, 'Forged', 'expense', 'food', 1, 1, 1,
      1, 1)''',
  ),
  _ReferenceGuardCase(
    'cross-scope category parent insert',
    (fixture) =>
        '''INSERT INTO categories (
      id, owner_scope_id, name, type, icon, color, parent_category_id,
      is_default, sort_order, created_at, updated_at
    ) VALUES ('category-cross', '${fixture.ownerA}', 'Cross', 'expense',
      'food', 1, 'category-b', 0, 1, 1, 1)''',
  ),
  _ReferenceGuardCase(
    'cross-scope category parent update',
    (fixture) => '''UPDATE categories SET parent_category_id = 'category-b'
      WHERE id = 'category-a' ''',
  ),
  _ReferenceGuardCase(
    'cross-scope receipt line category insert',
    (fixture) =>
        '''INSERT INTO receipt_line_items (
      id, owner_scope_id, receipt_id, description, normalized_description,
      category_id, category_suggestion_source
    ) VALUES ('line-cross', '${fixture.ownerA}', 'receipt-a', 'Line', 'line',
      'category-b', 'manual')''',
  ),
  _ReferenceGuardCase(
    'cross-scope receipt line category update',
    (fixture) => '''UPDATE receipt_line_items SET category_id = 'category-b'
      WHERE id = 'line-a' ''',
  ),
  _ReferenceGuardCase(
    'cross-scope goal contribution transaction insert',
    (fixture) =>
        '''INSERT INTO goal_contributions (
      id, owner_scope_id, goal_id, amount, currency, credited_amount, date,
      linked_transaction_id, created_at, updated_at
    ) VALUES ('contribution-cross', '${fixture.ownerA}', 'goal-a', '1', 'LYD',
      '1', 1, 'transaction-b', 1, 1)''',
  ),
  _ReferenceGuardCase(
    'cross-scope goal contribution transaction update',
    (fixture) => '''UPDATE goal_contributions
      SET linked_transaction_id = 'transaction-b'
      WHERE id = 'contribution-a' ''',
  ),
  _ReferenceGuardCase(
    'AI command owner update',
    (fixture) => '''UPDATE ai_agent_commands
      SET owner_scope_id = '${fixture.ownerB}' WHERE id = 'command-a' ''',
  ),
  _ReferenceGuardCase(
    'AI preview command update',
    (fixture) => '''UPDATE ai_agent_previews SET command_id = 'command-b'
      WHERE id = 'preview-a' ''',
  ),
  _ReferenceGuardCase(
    'AI confirmation proof command update',
    (fixture) => '''UPDATE ai_agent_confirmation_proofs
      SET command_id = 'command-b' WHERE id = 'proof-a' ''',
  ),
  _ReferenceGuardCase(
    'AI execution attempt command update',
    (fixture) => '''UPDATE ai_agent_execution_attempts
      SET command_id = 'command-b' WHERE id = 'attempt-a' ''',
  ),
  _ReferenceGuardCase(
    'AI execution attempt operation update',
    (fixture) => '''UPDATE ai_agent_execution_attempts
      SET business_operation_id = 'operation-b' WHERE id = 'attempt-a' ''',
  ),
  _ReferenceGuardCase(
    'AI execution result attempt update',
    (fixture) => '''UPDATE ai_agent_execution_results
      SET attempt_id = 'attempt-b' WHERE id = 'result-a' ''',
  ),
  _ReferenceGuardCase(
    'AI plan step plan update',
    (fixture) => '''UPDATE ai_agent_plan_steps SET plan_id = 'plan-b'
      WHERE id = 'step-a' ''',
  ),
  _ReferenceGuardCase(
    'AI plan step command update',
    (fixture) => '''UPDATE ai_agent_plan_steps SET command_id = 'command-b'
      WHERE id = 'step-a' ''',
  ),
  _ReferenceGuardCase(
    'AI audit command update',
    (fixture) => '''UPDATE ai_agent_audit_events SET command_id = 'command-b'
      WHERE id = 'audit-a' ''',
  ),
  _ReferenceGuardCase(
    'AI idempotency command update',
    (fixture) => '''UPDATE ai_agent_idempotency_records
      SET command_id = 'command-b' WHERE id = 'idempotency-a' ''',
  ),
  _ReferenceGuardCase(
    'AI idempotency result insert',
    (fixture) =>
        '''INSERT INTO ai_agent_idempotency_records (
      id, owner_scope_id, command_id, command_revision, action_type,
      idempotency_hash, status, execution_result_id, created_at, updated_at
    ) VALUES ('idempotency-cross', '${fixture.ownerA}', 'command-a', 0,
      'create_expense', 'cross-hash', 'completed', 'result-b', 1, 1)''',
  ),
  _ReferenceGuardCase(
    'AI idempotency result update',
    (fixture) => '''UPDATE ai_agent_idempotency_records
      SET execution_result_id = 'result-b' WHERE id = 'idempotency-a' ''',
  ),
  _ReferenceGuardCase(
    'AI business operation command update',
    (fixture) => '''UPDATE ai_agent_business_operations
      SET command_id = 'command-b' WHERE id = 'operation-a' ''',
  ),
  _ReferenceGuardCase(
    'sync queue target update',
    (fixture) => '''UPDATE sync_queue SET entity_id = 'account-b'
      WHERE id = 'queue-a' ''',
  ),
];

final class _GuardFixture {
  const _GuardFixture({
    required this.database,
    required this.ownerA,
    required this.ownerB,
  });

  final AppDatabase database;
  final String ownerA;
  final String ownerB;

  static Future<_GuardFixture> open() async {
    final database = AppDatabase(
      executor: NativeDatabase.memory(),
      enforceOwnerScopeGuards: true,
      enforceFinancialIntegrityGuards: false,
    );
    final ownerA = scopedTestSession(
      database,
      syntheticFirebaseUid: 'reference-guard-owner-a',
    ).ownerScopeValue;
    final ownerB = scopedTestSession(
      database,
      syntheticFirebaseUid: 'reference-guard-owner-b',
    ).ownerScopeValue;
    final fixture = _GuardFixture(
      database: database,
      ownerA: ownerA,
      ownerB: ownerB,
    );
    await fixture._seed();
    return fixture;
  }

  Future<void> _seed() async {
    final statements = <String>[
      '''INSERT INTO categories (
        id, owner_scope_id, name, type, icon, color, is_default, is_archived,
        sort_order, created_at, updated_at
      ) VALUES ('$_canonicalDefaultCategoryId', NULL, 'Food', 'expense',
        'food', 4293212469, 1, 0, 1010, 1, 1)''',
      '''INSERT INTO accounts (
        id, owner_scope_id, name, type, currency_code, balance, icon, color,
        created_at, updated_at
      ) VALUES ('account-a', '$ownerA', 'A', 'cash', 'LYD', '0', 'wallet',
        1, 1, 1)''',
      '''INSERT INTO accounts (
        id, owner_scope_id, name, type, currency_code, balance, icon, color,
        created_at, updated_at
      ) VALUES ('account-b', '$ownerB', 'B', 'cash', 'LYD', '0', 'wallet',
        1, 1, 1)''',
      '''INSERT INTO categories (
        id, owner_scope_id, name, type, icon, color, is_default, sort_order,
        created_at, updated_at
      ) VALUES ('category-a', '$ownerA', 'A', 'expense', 'food', 1, 0, 1,
        1, 1)''',
      '''INSERT INTO categories (
        id, owner_scope_id, name, type, icon, color, is_default, sort_order,
        created_at, updated_at
      ) VALUES ('category-b', '$ownerB', 'B', 'expense', 'food', 1, 0, 1,
        1, 1)''',
      '''INSERT INTO transactions (
        id, owner_scope_id, account_id, category_id, amount, currency_code,
        type, payment_method, source, status, transaction_date, created_at,
        updated_at
      ) VALUES ('transaction-a', '$ownerA', 'account-a', 'category-a', '1',
        'LYD', 'expense', 'cash', 'manual', 'posted', 1, 1, 1)''',
      '''INSERT INTO transactions (
        id, owner_scope_id, account_id, category_id, amount, currency_code,
        type, payment_method, source, status, transaction_date, created_at,
        updated_at
      ) VALUES ('transaction-b', '$ownerB', 'account-b', 'category-b', '1',
        'LYD', 'expense', 'cash', 'manual', 'posted', 1, 1, 1)''',
      '''INSERT INTO goals (
        id, owner_scope_id, title, type, target_amount, current_amount,
        currency, linked_account_id, icon, color, status, created_at, updated_at
      ) VALUES ('goal-a', '$ownerA', 'A', 'savings', '10', '0', 'LYD',
        'account-a', 'goal', 1, 'active', 1, 1)''',
      '''INSERT INTO goal_contributions (
        id, owner_scope_id, goal_id, amount, currency, credited_amount, date,
        linked_transaction_id, created_at, updated_at
      ) VALUES ('contribution-a', '$ownerA', 'goal-a', '1', 'LYD', '1', 1,
        'transaction-a', 1, 1)''',
      '''INSERT INTO receipts (
        id, owner_scope_id, document_type, payment_status,
        image_retention_choice, status, created_at, updated_at
      ) VALUES ('receipt-a', '$ownerA', 'receipt', 'paid', 'delete', 'draft',
        1, 1)''',
      '''INSERT INTO receipt_line_items (
        id, owner_scope_id, receipt_id, description, normalized_description,
        category_id, category_suggestion_source
      ) VALUES ('line-a', '$ownerA', 'receipt-a', 'Line', 'line', 'category-a',
        'manual')''',
      ..._agentSeedStatements(ownerA, ownerB),
      '''INSERT INTO sync_queue (
        id, owner_scope_id, owner_user_id, entity_type, entity_id, operation,
        payload_json, created_at, updated_at
      ) VALUES ('queue-a', '$ownerA', 'ephemeral-auth-subject', 'account',
        'account-a', 'upsert', '{}', 1, 1)''',
    ];
    for (final statement in statements) {
      await database.customStatement(statement);
    }
  }
}

List<String> _agentSeedStatements(String ownerA, String ownerB) => <String>[
  for (final owner in <(String, String)>[(ownerA, 'a'), (ownerB, 'b')]) ...[
    '''INSERT INTO ai_agent_commands (
      id, owner_scope_id, conversation_id, command_type, tool_id,
      normalized_arguments_json, permission, risk, status, revision,
      expires_at, created_at, updated_at
    ) VALUES ('command-${owner.$2}', '${owner.$1}', 'conversation-${owner.$2}',
      'action', 'create_expense', '{}', 'createDraft', 'medium', 'draft', 0,
      4102444800, 1, 1)''',
    '''INSERT INTO ai_agent_plans (
      id, owner_scope_id, conversation_id, status, expires_at, created_at,
      updated_at
    ) VALUES ('plan-${owner.$2}', '${owner.$1}', 'conversation-${owner.$2}',
      'draft', 4102444800, 1, 1)''',
    '''INSERT INTO ai_agent_business_operations (
      id, owner_scope_id, command_id, command_revision, action_type,
      entity_type, expected_entity_ids_json, verification_method, status,
      automatic_resume_allowed, automatic_retry_prohibited, created_at,
      updated_at
    ) VALUES ('operation-${owner.$2}', '${owner.$1}', 'command-${owner.$2}', 0,
      'create_expense', 'transaction', '[]', 'exact_ids', 'pending', 0, 1,
      1, 1)''',
    '''INSERT INTO ai_agent_execution_attempts (
      id, owner_scope_id, command_id, idempotency_key, command_revision,
      action_type, status, claimed_at, created_at, updated_at
    ) VALUES ('attempt-${owner.$2}', '${owner.$1}', 'command-${owner.$2}',
      'key-${owner.$2}', 0, 'create_expense', 'completed', 1, 1, 1)''',
    '''INSERT INTO ai_agent_execution_results (
      id, owner_scope_id, command_id, attempt_id, status, verified,
      entity_type, affected_count, safe_result_json, created_at, updated_at
    ) VALUES ('result-${owner.$2}', '${owner.$1}', 'command-${owner.$2}',
      'attempt-${owner.$2}', 'succeeded', 1, 'transaction', 1, '{}', 1, 1)''',
  ],
  '''INSERT INTO ai_agent_previews (
    id, owner_scope_id, command_id, revision, status, state_fingerprint,
    payload_json, expires_at, created_at, updated_at
  ) VALUES ('preview-a', '$ownerA', 'command-a', 0, 'active', 'fingerprint',
    '{}', 4102444800, 1, 1)''',
  '''INSERT INTO ai_agent_confirmation_proofs (
    id, owner_scope_id, command_id, preview_revision, confirmation_method,
    proof_hash, proof_salt, status, expires_at, created_at, updated_at
  ) VALUES ('proof-a', '$ownerA', 'command-a', 0, 'explicit', 'hash', 'salt',
    'active', 4102444800, 1, 1)''',
  '''INSERT INTO ai_agent_plan_steps (
    id, owner_scope_id, plan_id, command_id, position, status, created_at,
    updated_at
  ) VALUES ('step-a', '$ownerA', 'plan-a', 'command-a', 0, 'pending', 1, 1)''',
  '''INSERT INTO ai_agent_audit_events (
    id, owner_scope_id, command_id, action_type, entity_type, result,
    confirmation_method, created_at, updated_at
  ) VALUES ('audit-a', '$ownerA', 'command-a', 'create_expense', 'transaction',
    'succeeded', 'explicit', 1, 1)''',
  '''INSERT INTO ai_agent_idempotency_records (
    id, owner_scope_id, command_id, command_revision, action_type,
    idempotency_hash, status, execution_result_id, created_at, updated_at
  ) VALUES ('idempotency-a', '$ownerA', 'command-a', 0, 'create_expense',
    'hash-a', 'completed', 'result-a', 1, 1)''',
];

final class _ReferenceGuardCase {
  const _ReferenceGuardCase(this.name, this.sql);

  final String name;
  final String Function(_GuardFixture fixture) sql;
}
