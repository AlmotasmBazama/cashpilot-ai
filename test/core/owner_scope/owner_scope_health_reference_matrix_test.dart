import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_health_service.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  test(
    'category parent cross-scope corruption is never reported safe',
    () async {
      final fixture = await _healthFixture();
      addTearDown(fixture.database.close);
      await fixture.database.customStatement('''
      INSERT INTO categories (
        id, owner_scope_id, name, type, icon, color, is_default,
        sort_order, created_at, updated_at
      ) VALUES ('category-b', '${fixture.ownerB}', 'B', 'expense', 'food',
        1, 0, 0, 1, 1)
    ''');
      await fixture.database.customStatement('''
      INSERT INTO categories (
        id, owner_scope_id, name, type, icon, color, parent_category_id,
        is_default, sort_order, created_at, updated_at
      ) VALUES ('category-a', '${fixture.ownerA}', 'A', 'expense', 'food',
        1, 'category-b', 0, 0, 1, 1)
    ''');

      final health = await fixture.evaluate();

      expect(health.status, OwnerScopeStatus.crossScopeViolation);
      expect(health.failure, OwnerScopeFailure.integrityCheckFailed);
    },
  );

  test(
    'AI preview cross-scope command corruption is never reported safe',
    () async {
      final fixture = await _healthFixture();
      addTearDown(fixture.database.close);
      await fixture.database.customStatement('''
      INSERT INTO ai_agent_commands (
        id, owner_scope_id, conversation_id, command_type, tool_id,
        normalized_arguments_json, permission, risk, status, revision,
        expires_at, created_at, updated_at
      ) VALUES ('command-b', '${fixture.ownerB}', 'conversation-b', 'action',
        'create_expense', '{}', 'createDraft', 'medium', 'draft', 0,
        4102444800, 1, 1)
    ''');
      await fixture.database.customStatement('''
      INSERT INTO ai_agent_previews (
        id, owner_scope_id, command_id, revision, status,
        state_fingerprint, payload_json, expires_at, created_at, updated_at
      ) VALUES ('preview-a', '${fixture.ownerA}', 'command-b', 0, 'active',
        'fingerprint', '{}', 4102444800, 1, 1)
    ''');

      final health = await fixture.evaluate();

      expect(health.status, OwnerScopeStatus.crossScopeViolation);
      expect(health.failure, OwnerScopeFailure.integrityCheckFailed);
    },
  );

  test(
    'owner health returns a closed unsafe result when its audit query fails',
    () async {
      final fixture = await _healthFixture();
      await fixture.database.close();

      final health = await fixture.evaluate();

      expect(health.status, OwnerScopeStatus.corrupted);
      expect(health.failure, OwnerScopeFailure.integrityCheckFailed);
    },
  );

  test('complete same-scope reference fixture is reported safe', () async {
    final fixture = await _healthFixture();
    addTearDown(fixture.database.close);
    await _seedMaterialRoots(fixture);

    final health = await fixture.evaluate();

    expect(health.status, OwnerScopeStatus.safe);
    expect(health.failure, isNull);
  });

  for (final corruption in _materialReferenceCorruptions) {
    test('${corruption.name} corruption is never reported safe', () async {
      final fixture = await _healthFixture();
      addTearDown(fixture.database.close);
      await _seedMaterialRoots(fixture);
      for (final statement in corruption.statements(fixture)) {
        await fixture.database.customStatement(statement);
      }

      final health = await fixture.evaluate();

      expect(
        health.status,
        OwnerScopeStatus.crossScopeViolation,
        reason: corruption.name,
      );
      expect(
        health.failure,
        OwnerScopeFailure.integrityCheckFailed,
        reason: corruption.name,
      );
    });
  }
}

final _materialReferenceCorruptions = <_ReferenceCorruption>[
  _ReferenceCorruption(
    'category parent',
    (fixture) => <String>[
      "UPDATE categories SET parent_category_id = 'category-b' "
          "WHERE id = 'category-a'",
    ],
  ),
  _ReferenceCorruption(
    'payee default account',
    (fixture) => <String>[
      "UPDATE payees SET default_account_id = 'account-b' "
          "WHERE id = 'payee-a'",
    ],
  ),
  _ReferenceCorruption(
    'payee default category',
    (fixture) => <String>[
      "UPDATE payees SET default_category_id = 'category-b' "
          "WHERE id = 'payee-a'",
    ],
  ),
  _ReferenceCorruption(
    'transaction account',
    (fixture) => <String>[
      "UPDATE transactions SET account_id = 'account-b' "
          "WHERE id = 'transaction-a'",
    ],
  ),
  _ReferenceCorruption(
    'orphan transaction account',
    (fixture) => <String>[
      "UPDATE transactions SET account_id = 'missing-account' "
          "WHERE id = 'transaction-a'",
    ],
  ),
  _ReferenceCorruption(
    'transaction category',
    (fixture) => <String>[
      "UPDATE transactions SET category_id = 'category-b' "
          "WHERE id = 'transaction-a'",
    ],
  ),
  _ReferenceCorruption(
    'transaction payee',
    (fixture) => <String>[
      "UPDATE transactions SET payee_id = 'payee-b' "
          "WHERE id = 'transaction-a'",
    ],
  ),
  _ReferenceCorruption(
    'budget category',
    (fixture) => <String>[
      '''INSERT INTO budgets (
        id, owner_scope_id, name, category_id, amount, currency,
        period_type, start_date, end_date, alert_threshold_percent,
        created_at, updated_at
      ) VALUES ('budget-a', '${fixture.ownerA}', 'Budget A', 'category-b',
        '10', 'LYD', 'monthly', 1, 2, 80, 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'goal linked account',
    (fixture) => <String>[
      "UPDATE goals SET linked_account_id = 'account-b' "
          "WHERE id = 'goal-a'",
    ],
  ),
  _ReferenceCorruption(
    'goal contribution goal',
    (fixture) => <String>[
      '''INSERT INTO goal_contributions (
        id, owner_scope_id, goal_id, amount, currency, credited_amount,
        date, created_at, updated_at
      ) VALUES ('contribution-a', '${fixture.ownerA}', 'goal-b', '1',
        'LYD', '1', 1, 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'goal contribution transaction',
    (fixture) => <String>[
      '''INSERT INTO goal_contributions (
        id, owner_scope_id, goal_id, amount, currency, credited_amount,
        date, linked_transaction_id, created_at, updated_at
      ) VALUES ('contribution-a', '${fixture.ownerA}', 'goal-a', '1',
        'LYD', '1', 1, 'transaction-b', 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'receipt merchant payee',
    (fixture) => <String>[
      "UPDATE receipts SET merchant_payee_id = 'payee-b' "
          "WHERE id = 'receipt-a'",
    ],
  ),
  _ReferenceCorruption(
    'receipt linked transaction',
    (fixture) => <String>[
      "UPDATE receipts SET linked_transaction_id = 'transaction-b' "
          "WHERE id = 'receipt-a'",
    ],
  ),
  _ReferenceCorruption(
    'receipt line parent',
    (fixture) => <String>[
      '''INSERT INTO receipt_line_items (
        id, owner_scope_id, receipt_id, description,
        normalized_description, category_id, category_suggestion_source
      ) VALUES ('line-a', '${fixture.ownerA}', 'receipt-b', 'Line', 'line',
        'category-a', 'manual')''',
    ],
  ),
  _ReferenceCorruption(
    'receipt line category',
    (fixture) => <String>[
      '''INSERT INTO receipt_line_items (
        id, owner_scope_id, receipt_id, description,
        normalized_description, category_id, category_suggestion_source
      ) VALUES ('line-a', '${fixture.ownerA}', 'receipt-a', 'Line', 'line',
        'category-b', 'manual')''',
    ],
  ),
  _ReferenceCorruption(
    'transaction split receipt',
    (fixture) => <String>[
      '''INSERT INTO transaction_splits (
        id, owner_scope_id, receipt_id, transaction_id, category_id, amount
      ) VALUES ('split-a', '${fixture.ownerA}', 'receipt-b', 'transaction-a',
        'category-a', '1')''',
    ],
  ),
  _ReferenceCorruption(
    'transaction split transaction',
    (fixture) => <String>[
      '''INSERT INTO transaction_splits (
        id, owner_scope_id, receipt_id, transaction_id, category_id, amount
      ) VALUES ('split-a', '${fixture.ownerA}', 'receipt-a', 'transaction-b',
        'category-a', '1')''',
    ],
  ),
  _ReferenceCorruption(
    'transaction split category',
    (fixture) => <String>[
      '''INSERT INTO transaction_splits (
        id, owner_scope_id, receipt_id, transaction_id, category_id, amount
      ) VALUES ('split-a', '${fixture.ownerA}', 'receipt-a', 'transaction-a',
        'category-b', '1')''',
    ],
  ),
  _ReferenceCorruption(
    'sync queue upsert target',
    (fixture) => <String>[
      '''INSERT INTO sync_queue (
        id, owner_scope_id, owner_user_id, entity_type, entity_id,
        operation, payload_json, status, attempt_count, created_at, updated_at
      ) VALUES ('queue-a', '${fixture.ownerA}', 'ephemeral-auth-subject',
        'account', 'account-b', 'upsert', '{}', 'pending', 0, 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'AI preview command',
    (fixture) => <String>[
      '''INSERT INTO ai_agent_previews (
        id, owner_scope_id, command_id, revision, status, state_fingerprint,
        payload_json, expires_at, created_at, updated_at
      ) VALUES ('preview-a', '${fixture.ownerA}', 'command-b', 0, 'active',
        'fingerprint', '{}', 4102444800, 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'AI confirmation proof command',
    (fixture) => <String>[
      '''INSERT INTO ai_agent_confirmation_proofs (
        id, owner_scope_id, command_id, preview_revision,
        confirmation_method, proof_hash, proof_salt, status, expires_at,
        created_at, updated_at
      ) VALUES ('proof-a', '${fixture.ownerA}', 'command-b', 0, 'explicit',
        'hash', 'salt', 'active', 4102444800, 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'AI execution attempt command',
    (fixture) => <String>[
      '''INSERT INTO ai_agent_execution_attempts (
        id, owner_scope_id, command_id, idempotency_key, command_revision,
        action_type, status, claimed_at, created_at, updated_at
      ) VALUES ('attempt-cross', '${fixture.ownerA}', 'command-b', 'key', 0,
        'create_expense', 'claimed', 1, 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'AI execution attempt business operation',
    (fixture) => <String>[
      '''INSERT INTO ai_agent_execution_attempts (
        id, owner_scope_id, command_id, idempotency_key, command_revision,
        action_type, status, business_operation_id, claimed_at, created_at,
        updated_at
      ) VALUES ('attempt-cross', '${fixture.ownerA}', 'command-a', 'key', 0,
        'create_expense', 'claimed', 'operation-b', 1, 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'AI execution result attempt',
    (fixture) => <String>[
      '''INSERT INTO ai_agent_execution_results (
        id, owner_scope_id, command_id, attempt_id, status, verified,
        entity_type, affected_count, safe_result_json, created_at, updated_at
      ) VALUES ('result-cross', '${fixture.ownerA}', 'command-a', 'attempt-b',
        'succeeded', 1, 'transaction', 1, '{}', 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'AI plan step plan',
    (fixture) => <String>[
      '''INSERT INTO ai_agent_plan_steps (
        id, owner_scope_id, plan_id, command_id, position, status,
        created_at, updated_at
      ) VALUES ('step-a', '${fixture.ownerA}', 'plan-b', 'command-a', 0,
        'pending', 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'AI plan step command',
    (fixture) => <String>[
      '''INSERT INTO ai_agent_plan_steps (
        id, owner_scope_id, plan_id, command_id, position, status,
        created_at, updated_at
      ) VALUES ('step-a', '${fixture.ownerA}', 'plan-a', 'command-b', 0,
        'pending', 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'AI audit event command',
    (fixture) => <String>[
      '''INSERT INTO ai_agent_audit_events (
        id, owner_scope_id, command_id, action_type, entity_type, result,
        confirmation_method, created_at, updated_at
      ) VALUES ('audit-a', '${fixture.ownerA}', 'command-b', 'create_expense',
        'transaction', 'rejected', 'explicit', 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'AI idempotency command',
    (fixture) => <String>[
      '''INSERT INTO ai_agent_idempotency_records (
        id, owner_scope_id, command_id, command_revision, action_type,
        idempotency_hash, status, created_at, updated_at
      ) VALUES ('idempotency-a', '${fixture.ownerA}', 'command-b', 0,
        'create_expense', 'hash', 'claimed', 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'AI idempotency execution result',
    (fixture) => <String>[
      '''INSERT INTO ai_agent_idempotency_records (
        id, owner_scope_id, command_id, command_revision, action_type,
        idempotency_hash, status, execution_result_id, created_at, updated_at
      ) VALUES ('idempotency-a', '${fixture.ownerA}', 'command-a', 0,
        'create_expense', 'hash', 'completed', 'result-b', 1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'AI business operation command',
    (fixture) => <String>[
      '''INSERT INTO ai_agent_business_operations (
        id, owner_scope_id, command_id, command_revision, action_type,
        entity_type, expected_entity_ids_json, verification_method, status,
        automatic_resume_allowed, automatic_retry_prohibited, created_at,
        updated_at
      ) VALUES ('operation-cross', '${fixture.ownerA}', 'command-b', 0,
        'create_expense', 'transaction', '[]', 'exact_ids', 'pending', 0, 1,
        1, 1)''',
    ],
  ),
  _ReferenceCorruption(
    'scoped category promoted to global default shape',
    (fixture) => <String>[
      "UPDATE categories SET is_default = 1 WHERE id = 'category-a'",
    ],
  ),
  _ReferenceCorruption(
    'forged global default category',
    (fixture) => <String>[
      '''INSERT INTO categories (
        id, owner_scope_id, name, type, icon, color, is_default,
        sort_order, created_at, updated_at
      ) VALUES ('forged-global-default', NULL, 'Forged', 'expense', 'food',
        1, 1, 0, 1, 1)''',
    ],
  ),
];

Future<_HealthFixture> _healthFixture() async {
  final database = AppDatabase(
    executor: NativeDatabase.memory(),
    enforceOwnerScopeGuards: false,
    enforceFinancialIntegrityGuards: false,
  );
  await database.customSelect('SELECT 1').get();
  final sessionA = scopedTestSession(
    database,
    syntheticFirebaseUid: 'synthetic-health-owner-a',
  );
  final sessionB = scopedTestSession(
    database,
    syntheticFirebaseUid: 'synthetic-health-owner-b',
  );
  return _HealthFixture(
    database: database,
    session: sessionA,
    ownerA: sessionA.ownerScopeValue,
    ownerB: sessionB.ownerScopeValue,
  );
}

final class _HealthFixture {
  const _HealthFixture({
    required this.database,
    required this.session,
    required this.ownerA,
    required this.ownerB,
  });

  final AppDatabase database;
  final ScopedAppDatabaseSession session;
  final String ownerA;
  final String ownerB;

  Future<OwnerScopeHealth> evaluate() =>
      OwnerScopeHealthService(database).evaluate(
        snapshot: OwnerScopeSnapshot(
          status: OwnerScopeStatus.safe,
          scope: session.confirmedScope,
        ),
        session: session,
      );
}

final class _ReferenceCorruption {
  const _ReferenceCorruption(this.name, this.statements);

  final String name;
  final List<String> Function(_HealthFixture fixture) statements;
}

Future<void> _seedMaterialRoots(_HealthFixture fixture) async {
  final statements = <String>[
    '''INSERT INTO accounts (
      id, owner_scope_id, name, type, currency_code, balance, icon, color,
      created_at, updated_at
    ) VALUES ('account-a', '${fixture.ownerA}', 'Account A', 'cash', 'LYD',
      '0', 'wallet', 1, 1, 1)''',
    '''INSERT INTO accounts (
      id, owner_scope_id, name, type, currency_code, balance, icon, color,
      created_at, updated_at
    ) VALUES ('account-b', '${fixture.ownerB}', 'Account B', 'cash', 'LYD',
      '0', 'wallet', 1, 1, 1)''',
    '''INSERT INTO categories (
      id, owner_scope_id, name, type, icon, color, is_default, sort_order,
      created_at, updated_at
    ) VALUES ('category-a', '${fixture.ownerA}', 'Category A', 'expense',
      'food', 1, 0, 0, 1, 1)''',
    '''INSERT INTO categories (
      id, owner_scope_id, name, type, icon, color, is_default, sort_order,
      created_at, updated_at
    ) VALUES ('category-b', '${fixture.ownerB}', 'Category B', 'expense',
      'food', 1, 0, 0, 1, 1)''',
    '''INSERT INTO payees (
      id, owner_scope_id, name, normalized_name, created_at, updated_at
    ) VALUES ('payee-a', '${fixture.ownerA}', 'Payee A', 'payee a', 1, 1)''',
    '''INSERT INTO payees (
      id, owner_scope_id, name, normalized_name, created_at, updated_at
    ) VALUES ('payee-b', '${fixture.ownerB}', 'Payee B', 'payee b', 1, 1)''',
    '''INSERT INTO transactions (
      id, owner_scope_id, account_id, category_id, amount, currency_code,
      type, payment_method, source, status, transaction_date, created_at,
      updated_at
    ) VALUES ('transaction-a', '${fixture.ownerA}', 'account-a', 'category-a',
      '1', 'LYD', 'expense', 'cash', 'manual', 'posted', 1, 1, 1)''',
    '''INSERT INTO transactions (
      id, owner_scope_id, account_id, category_id, amount, currency_code,
      type, payment_method, source, status, transaction_date, created_at,
      updated_at
    ) VALUES ('transaction-b', '${fixture.ownerB}', 'account-b', 'category-b',
      '1', 'LYD', 'expense', 'cash', 'manual', 'posted', 1, 1, 1)''',
    '''INSERT INTO goals (
      id, owner_scope_id, title, type, target_amount, current_amount,
      currency, linked_account_id, icon, color, status, created_at, updated_at
    ) VALUES ('goal-a', '${fixture.ownerA}', 'Goal A', 'savings', '10', '0',
      'LYD', 'account-a', 'goal', 1, 'active', 1, 1)''',
    '''INSERT INTO goals (
      id, owner_scope_id, title, type, target_amount, current_amount,
      currency, linked_account_id, icon, color, status, created_at, updated_at
    ) VALUES ('goal-b', '${fixture.ownerB}', 'Goal B', 'savings', '10', '0',
      'LYD', 'account-b', 'goal', 1, 'active', 1, 1)''',
    '''INSERT INTO receipts (
      id, owner_scope_id, document_type, payment_status,
      image_retention_choice, status, created_at, updated_at
    ) VALUES ('receipt-a', '${fixture.ownerA}', 'receipt', 'paid', 'delete',
      'draft', 1, 1)''',
    '''INSERT INTO receipts (
      id, owner_scope_id, document_type, payment_status,
      image_retention_choice, status, created_at, updated_at
    ) VALUES ('receipt-b', '${fixture.ownerB}', 'receipt', 'paid', 'delete',
      'draft', 1, 1)''',
    '''INSERT INTO ai_agent_commands (
      id, owner_scope_id, conversation_id, command_type, tool_id,
      normalized_arguments_json, permission, risk, status, revision,
      expires_at, created_at, updated_at
    ) VALUES ('command-a', '${fixture.ownerA}', 'conversation-a', 'action',
      'create_expense', '{}', 'createDraft', 'medium', 'draft', 0,
      4102444800, 1, 1)''',
    '''INSERT INTO ai_agent_commands (
      id, owner_scope_id, conversation_id, command_type, tool_id,
      normalized_arguments_json, permission, risk, status, revision,
      expires_at, created_at, updated_at
    ) VALUES ('command-b', '${fixture.ownerB}', 'conversation-b', 'action',
      'create_expense', '{}', 'createDraft', 'medium', 'draft', 0,
      4102444800, 1, 1)''',
    '''INSERT INTO ai_agent_plans (
      id, owner_scope_id, conversation_id, status, atomic, expires_at,
      created_at, updated_at
    ) VALUES ('plan-a', '${fixture.ownerA}', 'conversation-a', 'draft', 0,
      4102444800, 1, 1)''',
    '''INSERT INTO ai_agent_plans (
      id, owner_scope_id, conversation_id, status, atomic, expires_at,
      created_at, updated_at
    ) VALUES ('plan-b', '${fixture.ownerB}', 'conversation-b', 'draft', 0,
      4102444800, 1, 1)''',
    '''INSERT INTO ai_agent_business_operations (
      id, owner_scope_id, command_id, command_revision, action_type,
      entity_type, expected_entity_ids_json, verification_method, status,
      automatic_resume_allowed, automatic_retry_prohibited, created_at,
      updated_at
    ) VALUES ('operation-a', '${fixture.ownerA}', 'command-a', 0,
      'create_expense', 'transaction', '[]', 'exact_ids', 'pending', 0, 1,
      1, 1)''',
    '''INSERT INTO ai_agent_business_operations (
      id, owner_scope_id, command_id, command_revision, action_type,
      entity_type, expected_entity_ids_json, verification_method, status,
      automatic_resume_allowed, automatic_retry_prohibited, created_at,
      updated_at
    ) VALUES ('operation-b', '${fixture.ownerB}', 'command-b', 0,
      'create_expense', 'transaction', '[]', 'exact_ids', 'pending', 0, 1,
      1, 1)''',
    '''INSERT INTO ai_agent_execution_attempts (
      id, owner_scope_id, command_id, idempotency_key, command_revision,
      action_type, status, claimed_at, created_at, updated_at
    ) VALUES ('attempt-a', '${fixture.ownerA}', 'command-a', 'key-a', 0,
      'create_expense', 'completed', 1, 1, 1)''',
    '''INSERT INTO ai_agent_execution_attempts (
      id, owner_scope_id, command_id, idempotency_key, command_revision,
      action_type, status, claimed_at, created_at, updated_at
    ) VALUES ('attempt-b', '${fixture.ownerB}', 'command-b', 'key-b', 0,
      'create_expense', 'completed', 1, 1, 1)''',
    '''INSERT INTO ai_agent_execution_results (
      id, owner_scope_id, command_id, attempt_id, status, verified,
      entity_type, affected_count, safe_result_json, created_at, updated_at
    ) VALUES ('result-a', '${fixture.ownerA}', 'command-a', 'attempt-a',
      'succeeded', 1, 'transaction', 1, '{}', 1, 1)''',
    '''INSERT INTO ai_agent_execution_results (
      id, owner_scope_id, command_id, attempt_id, status, verified,
      entity_type, affected_count, safe_result_json, created_at, updated_at
    ) VALUES ('result-b', '${fixture.ownerB}', 'command-b', 'attempt-b',
      'succeeded', 1, 'transaction', 1, '{}', 1, 1)''',
  ];

  for (final statement in statements) {
    await fixture.database.customStatement(statement);
  }
}
