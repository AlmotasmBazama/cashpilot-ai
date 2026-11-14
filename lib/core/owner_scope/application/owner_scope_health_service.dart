import '../../database/app_database.dart';
import '../../../features/categories/domain/defaults/default_category_definitions.dart';
import '../domain/owner_scope.dart';
import 'scoped_app_database_session.dart';

class OwnerScopeHealthService {
  const OwnerScopeHealthService(this._database);

  static const minimumScopedSchemaVersion = 16;

  final AppDatabase _database;

  Future<OwnerScopeHealth> evaluate({
    required OwnerScopeSnapshot snapshot,
    required ScopedAppDatabaseSession? session,
  }) async {
    if (snapshot.scope == null) {
      return OwnerScopeHealth(
        status: snapshot.status,
        failure: snapshot.failure ?? OwnerScopeFailure.authNotConfirmed,
      );
    }
    if (_database.schemaVersion < minimumScopedSchemaVersion) {
      return const OwnerScopeHealth(
        status: OwnerScopeStatus.corrupted,
        failure: OwnerScopeFailure.schemaUnsupported,
      );
    }
    if (session == null ||
        !session.isActive ||
        session.confirmedScope.id != snapshot.scope!.id) {
      return const OwnerScopeHealth(
        status: OwnerScopeStatus.initializing,
        failure: OwnerScopeFailure.scopedSessionUnavailable,
      );
    }

    try {
      final durableSchemaAvailable = await _hasAllTables(const <String>{
        'ai_agent_commands',
        'ai_agent_previews',
        'ai_agent_confirmation_proofs',
        'ai_agent_execution_attempts',
        'ai_agent_execution_results',
        'ai_agent_plans',
        'ai_agent_plan_steps',
        'ai_agent_audit_events',
        'ai_agent_idempotency_records',
        'ai_agent_business_operations',
      });
      if (!durableSchemaAvailable) {
        return const OwnerScopeHealth(
          status: OwnerScopeStatus.corrupted,
          failure: OwnerScopeFailure.durableAgentSchemaUnavailable,
        );
      }

      final legacyCount = await _singleInt('''
      SELECT
        (SELECT COUNT(*) FROM accounts WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM categories
          WHERE owner_scope_id IS NULL AND is_default = 0) +
        (SELECT COUNT(*) FROM payees WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM transactions WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM exchange_rates WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM budgets WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM goals WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM goal_contributions WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM receipts WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM receipt_line_items WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM transaction_splits WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM sync_queue WHERE owner_scope_id IS NULL)
        AS value
    ''');
      if (legacyCount > 0) {
        return const OwnerScopeHealth(
          status: OwnerScopeStatus.legacyDataUnclaimed,
          failure: OwnerScopeFailure.legacyDataRequiresClaim,
        );
      }

      if (await _database.hasMalformedTransferGroupsForOwner(
        snapshot.scope!.id.value,
      )) {
        return const OwnerScopeHealth(
          status: OwnerScopeStatus.corrupted,
          failure: OwnerScopeFailure.integrityCheckFailed,
        );
      }

      final violations = await _singleInt('''
      SELECT
        (SELECT COUNT(*) FROM categories c
          WHERE c.is_default = 1 AND c.owner_scope_id IS NOT NULL) +
        (SELECT COUNT(*) FROM categories c
          WHERE c.parent_category_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM categories p WHERE p.id = c.parent_category_id AND (
              (p.is_default = 1 AND p.owner_scope_id IS NULL) OR
              (p.is_default = 0 AND p.owner_scope_id = c.owner_scope_id)))) +
        (SELECT COUNT(*) FROM payees p
          WHERE p.default_account_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM accounts a WHERE a.id = p.default_account_id
              AND a.owner_scope_id = p.owner_scope_id)) +
        (SELECT COUNT(*) FROM payees p
          WHERE p.default_category_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM categories c WHERE c.id = p.default_category_id AND (
              (c.is_default = 1 AND c.owner_scope_id IS NULL) OR
              (c.is_default = 0 AND c.owner_scope_id = p.owner_scope_id)))) +
        (SELECT COUNT(*) FROM transactions t WHERE NOT EXISTS (
          SELECT 1 FROM accounts a WHERE a.id = t.account_id
            AND a.owner_scope_id = t.owner_scope_id)) +
        (SELECT COUNT(*) FROM transactions t WHERE NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = t.category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL) OR
            (c.is_default = 0 AND c.owner_scope_id = t.owner_scope_id)))) +
        (SELECT COUNT(*) FROM transactions t
          WHERE t.payee_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM payees p WHERE p.id = t.payee_id
              AND p.owner_scope_id = t.owner_scope_id)) +
        (SELECT COUNT(*) FROM budgets b WHERE NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = b.category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL) OR
            (c.is_default = 0 AND c.owner_scope_id = b.owner_scope_id)))) +
        (SELECT COUNT(*) FROM goals g
          WHERE g.linked_account_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM accounts a WHERE a.id = g.linked_account_id
              AND a.owner_scope_id = g.owner_scope_id)) +
        (SELECT COUNT(*) FROM goal_contributions gc WHERE NOT EXISTS (
          SELECT 1 FROM goals g WHERE g.id = gc.goal_id
            AND g.owner_scope_id = gc.owner_scope_id)) +
        (SELECT COUNT(*) FROM goal_contributions gc
          WHERE gc.linked_transaction_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM transactions t WHERE t.id = gc.linked_transaction_id
              AND t.owner_scope_id = gc.owner_scope_id)) +
        (SELECT COUNT(*) FROM receipts r
          WHERE r.merchant_payee_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM payees p WHERE p.id = r.merchant_payee_id
              AND p.owner_scope_id = r.owner_scope_id)) +
        (SELECT COUNT(*) FROM receipts r
          WHERE r.linked_transaction_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM transactions t WHERE t.id = r.linked_transaction_id
              AND t.owner_scope_id = r.owner_scope_id)) +
        (SELECT COUNT(*) FROM receipt_line_items li WHERE NOT EXISTS (
          SELECT 1 FROM receipts r WHERE r.id = li.receipt_id
            AND r.owner_scope_id = li.owner_scope_id)) +
        (SELECT COUNT(*) FROM receipt_line_items li
          WHERE li.category_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM categories c WHERE c.id = li.category_id AND (
              (c.is_default = 1 AND c.owner_scope_id IS NULL) OR
              (c.is_default = 0 AND c.owner_scope_id = li.owner_scope_id)))) +
        (SELECT COUNT(*) FROM transaction_splits s WHERE NOT EXISTS (
          SELECT 1 FROM receipts r WHERE r.id = s.receipt_id
            AND r.owner_scope_id = s.owner_scope_id)) +
        (SELECT COUNT(*) FROM transaction_splits s
          WHERE s.transaction_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM transactions t WHERE t.id = s.transaction_id
              AND t.owner_scope_id = s.owner_scope_id)) +
        (SELECT COUNT(*) FROM transaction_splits s WHERE NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = s.category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL) OR
            (c.is_default = 0 AND c.owner_scope_id = s.owner_scope_id)))) +
        (SELECT COUNT(*) FROM sync_queue q
          WHERE q.operation = 'upsert' AND (
            q.entity_type NOT IN ('account', 'transaction', 'category',
              'payee', 'budget', 'goal', 'exchangeRate', 'settings') OR
            (q.entity_type = 'account' AND NOT EXISTS (
              SELECT 1 FROM accounts a WHERE a.id = q.entity_id
                AND a.owner_scope_id = q.owner_scope_id)) OR
            (q.entity_type = 'transaction' AND NOT EXISTS (
              SELECT 1 FROM transactions t WHERE t.id = q.entity_id
                AND t.owner_scope_id = q.owner_scope_id)) OR
            (q.entity_type = 'category' AND NOT EXISTS (
              SELECT 1 FROM categories c WHERE c.id = q.entity_id AND (
                (c.is_default = 1 AND c.owner_scope_id IS NULL) OR
                (c.is_default = 0 AND c.owner_scope_id = q.owner_scope_id)))) OR
            (q.entity_type = 'payee' AND NOT EXISTS (
              SELECT 1 FROM payees p WHERE p.id = q.entity_id
                AND p.owner_scope_id = q.owner_scope_id)) OR
            (q.entity_type = 'budget' AND NOT EXISTS (
              SELECT 1 FROM budgets b WHERE b.id = q.entity_id
                AND b.owner_scope_id = q.owner_scope_id)) OR
            (q.entity_type = 'goal' AND NOT EXISTS (
              SELECT 1 FROM goals g WHERE g.id = q.entity_id
                AND g.owner_scope_id = q.owner_scope_id)) OR
            (q.entity_type = 'exchangeRate' AND NOT EXISTS (
              SELECT 1 FROM exchange_rates e WHERE e.id = q.entity_id
                AND e.owner_scope_id = q.owner_scope_id)))) +
        (SELECT COUNT(*) FROM ai_agent_previews p WHERE NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = p.command_id
            AND c.owner_scope_id = p.owner_scope_id)) +
        (SELECT COUNT(*) FROM ai_agent_confirmation_proofs p WHERE NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = p.command_id
            AND c.owner_scope_id = p.owner_scope_id)) +
        (SELECT COUNT(*) FROM ai_agent_execution_attempts a WHERE NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = a.command_id
            AND c.owner_scope_id = a.owner_scope_id)) +
        (SELECT COUNT(*) FROM ai_agent_execution_attempts a
          WHERE a.business_operation_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM ai_agent_business_operations o
            WHERE o.id = a.business_operation_id
              AND o.command_id = a.command_id
              AND o.owner_scope_id = a.owner_scope_id)) +
        (SELECT COUNT(*) FROM ai_agent_execution_results r WHERE NOT EXISTS (
          SELECT 1 FROM ai_agent_execution_attempts a
          WHERE a.id = r.attempt_id AND a.command_id = r.command_id
            AND a.owner_scope_id = r.owner_scope_id)) +
        (SELECT COUNT(*) FROM ai_agent_plan_steps s WHERE NOT EXISTS (
          SELECT 1 FROM ai_agent_plans p WHERE p.id = s.plan_id
            AND p.owner_scope_id = s.owner_scope_id)) +
        (SELECT COUNT(*) FROM ai_agent_plan_steps s WHERE NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = s.command_id
            AND c.owner_scope_id = s.owner_scope_id)) +
        (SELECT COUNT(*) FROM ai_agent_audit_events e WHERE NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = e.command_id
            AND c.owner_scope_id = e.owner_scope_id)) +
        (SELECT COUNT(*) FROM ai_agent_idempotency_records i WHERE NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = i.command_id
            AND c.owner_scope_id = i.owner_scope_id)) +
        (SELECT COUNT(*) FROM ai_agent_idempotency_records i
          WHERE i.execution_result_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM ai_agent_execution_results r
            WHERE r.id = i.execution_result_id
              AND r.command_id = i.command_id
              AND r.owner_scope_id = i.owner_scope_id)) +
        (SELECT COUNT(*) FROM ai_agent_business_operations o WHERE NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = o.command_id
            AND c.owner_scope_id = o.owner_scope_id))
        AS value
    ''');
      if (violations > 0 || await _hasUnexpectedGlobalDefaults()) {
        return const OwnerScopeHealth(
          status: OwnerScopeStatus.crossScopeViolation,
          failure: OwnerScopeFailure.integrityCheckFailed,
        );
      }

      return const OwnerScopeHealth(
        status: OwnerScopeStatus.safe,
        safeDetails: <String, bool>{
          'confirmedScope': true,
          'scopedSchema': true,
          'legacyClaimComplete': true,
          'scopedSessionActive': true,
          'durableAgentSchema': true,
          'transferGroupIntegrity': true,
          'crossScopeIntegrity': true,
        },
      );
    } on Object {
      return const OwnerScopeHealth(
        status: OwnerScopeStatus.corrupted,
        failure: OwnerScopeFailure.integrityCheckFailed,
      );
    }
  }

  Future<bool> _hasUnexpectedGlobalDefaults() async {
    final rows = await _database.customSelect('''
      SELECT id, name, type, icon, color, parent_category_id, is_archived,
        sort_order
      FROM categories
      WHERE owner_scope_id IS NULL AND is_default = 1
    ''').get();
    final definitions = <String, DefaultCategoryDefinition>{
      for (final definition in defaultCategoryDefinitions)
        definition.id: definition,
    };
    return rows.any((row) {
      final definition = definitions[row.read<String>('id')];
      return definition == null ||
          row.read<String>('name') != definition.name ||
          row.read<String>('type') != definition.type.name ||
          row.read<String>('icon') != definition.iconKey ||
          row.read<int>('color') != definition.colorArgb ||
          row.readNullable<String>('parent_category_id') != null ||
          row.read<int>('is_archived') != 0 ||
          row.read<int>('sort_order') != definition.sortOrder;
    });
  }

  Future<bool> _hasAllTables(Set<String> required) async {
    final rows = await _database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = rows.map((row) => row.read<String>('name')).toSet();
    return names.containsAll(required);
  }

  Future<int> _singleInt(String sql) async {
    final row = await _database.customSelect(sql).getSingle();
    return row.read<int>('value');
  }
}
