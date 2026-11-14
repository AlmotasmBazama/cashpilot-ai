part of 'app_database.dart';

/// Installs the complete durable owner-scope write, reference, and extended
/// reference guard family without changing statement text or execution order.
///
/// The extension is library-private and resolved at compile time; AppDatabase
/// retains the same on-open orchestration and schema contract.
extension _AppDatabaseOwnerScopeGuardDdl on AppDatabase {
  Future<void> _createOwnerScopeWriteGuards() async {
    const guardedTables = <String>[
      'accounts',
      'payees',
      'transactions',
      'exchange_rates',
      'budgets',
      'goals',
      'goal_contributions',
      'receipts',
      'receipt_line_items',
      'transaction_splits',
      'sync_queue',
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
    ];
    for (final table in guardedTables) {
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS ${table}_owner_required_insert
        BEFORE INSERT ON $table
        WHEN NEW.owner_scope_id IS NULL
        BEGIN
          SELECT RAISE(ABORT, 'owner_scope_required');
        END
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS ${table}_owner_immutable_update
        BEFORE UPDATE OF owner_scope_id ON $table
        WHEN NEW.owner_scope_id IS NULL OR
          (OLD.owner_scope_id IS NOT NULL AND
           NEW.owner_scope_id IS NOT OLD.owner_scope_id)
        BEGIN
          SELECT RAISE(ABORT, 'owner_scope_immutable');
        END
      ''');
    }
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS categories_owner_required_insert
      BEFORE INSERT ON categories
      WHEN NEW.owner_scope_id IS NULL AND NEW.is_default = 0
      BEGIN
        SELECT RAISE(ABORT, 'owner_scope_required');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS categories_owner_scoped_default_guard_insert
      BEFORE INSERT ON categories
      WHEN NEW.owner_scope_id IS NOT NULL AND NEW.is_default = 1
      BEGIN
        SELECT RAISE(ABORT, 'owner_scoped_category_cannot_be_default');
      END
    ''');
    final canonicalDefaultPredicate = defaultCategoryDefinitions
        .map(
          (definition) =>
              '''(
            NEW.id = ${_sqliteText(definition.id)} AND
            NEW.name = ${_sqliteText(definition.name)} AND
            NEW.type = ${_sqliteText(definition.type.name)} AND
            NEW.icon = ${_sqliteText(definition.iconKey)} AND
            NEW.color = ${definition.colorArgb} AND
            NEW.parent_category_id IS NULL AND
            NEW.is_archived = 0 AND
            NEW.sort_order = ${definition.sortOrder}
          )''',
        )
        .join(' OR ');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS categories_canonical_default_guard_insert
      BEFORE INSERT ON categories
      WHEN NEW.owner_scope_id IS NULL AND NEW.is_default = 1 AND NOT (
        $canonicalDefaultPredicate
      )
      BEGIN
        SELECT RAISE(ABORT, 'noncanonical_default_category');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS categories_owner_immutable_update
      BEFORE UPDATE OF owner_scope_id, is_default ON categories
      WHEN (NEW.owner_scope_id IS NULL AND NEW.is_default = 0) OR
        (OLD.owner_scope_id IS NOT NULL AND
         NEW.owner_scope_id IS NOT OLD.owner_scope_id) OR
        (OLD.is_default = 1 AND NEW.owner_scope_id IS NOT NULL)
      BEGIN
        SELECT RAISE(ABORT, 'owner_scope_immutable');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS categories_custom_default_promotion_guard_update
      BEFORE UPDATE OF owner_scope_id, is_default ON categories
      WHEN NEW.owner_scope_id IS NOT NULL AND NEW.is_default = 1
      BEGIN
        SELECT RAISE(ABORT, 'owner_scoped_category_cannot_be_default');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS categories_default_immutable_update
      BEFORE UPDATE ON categories
      WHEN OLD.owner_scope_id IS NULL AND OLD.is_default = 1
      BEGIN
        SELECT RAISE(ABORT, 'default_category_immutable');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS categories_default_immutable_delete
      BEFORE DELETE ON categories
      WHEN OLD.owner_scope_id IS NULL AND OLD.is_default = 1
      BEGIN
        SELECT RAISE(ABORT, 'default_category_immutable');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS categories_referenced_delete_guard
      BEFORE DELETE ON categories
      WHEN NOT (OLD.is_default = 1 AND OLD.owner_scope_id IS NULL) AND (
        EXISTS (SELECT 1 FROM categories dependency
          WHERE dependency.parent_category_id = OLD.id) OR
        EXISTS (SELECT 1 FROM payees dependency
          WHERE dependency.default_category_id = OLD.id) OR
        EXISTS (SELECT 1 FROM transactions dependency
          WHERE dependency.category_id = OLD.id) OR
        EXISTS (SELECT 1 FROM budgets dependency
          WHERE dependency.category_id = OLD.id) OR
        EXISTS (SELECT 1 FROM receipt_line_items dependency
          WHERE dependency.category_id = OLD.id) OR
        EXISTS (SELECT 1 FROM transaction_splits dependency
          WHERE dependency.category_id = OLD.id)
      )
      BEGIN
        SELECT RAISE(ABORT, 'category_delete_referenced');
      END
    ''');
  }

  Future<void> _createOwnerScopeReferenceGuards() async {
    const statements = <String>[
      '''CREATE TRIGGER IF NOT EXISTS transactions_scope_refs_insert
        BEFORE INSERT ON transactions BEGIN
          SELECT CASE WHEN NOT EXISTS (
            SELECT 1 FROM accounts a WHERE a.id = NEW.account_id
              AND a.owner_scope_id = NEW.owner_scope_id
          ) THEN RAISE(ABORT, 'owner_scope_account_reference') END;
          SELECT CASE WHEN NOT EXISTS (
            SELECT 1 FROM categories c WHERE c.id = NEW.category_id AND
              (c.is_default = 1 OR c.owner_scope_id = NEW.owner_scope_id)
          ) THEN RAISE(ABORT, 'owner_scope_category_reference') END;
          SELECT CASE WHEN NEW.payee_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM payees p WHERE p.id = NEW.payee_id
              AND p.owner_scope_id = NEW.owner_scope_id
          ) THEN RAISE(ABORT, 'owner_scope_payee_reference') END;
          SELECT CASE WHEN NEW.transfer_group_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM transactions t
            WHERE t.transfer_group_id = NEW.transfer_group_id
              AND t.owner_scope_id IS NOT NEW.owner_scope_id
          ) THEN RAISE(ABORT, 'owner_scope_transfer_reference') END;
        END''',
      '''CREATE TRIGGER IF NOT EXISTS transactions_scope_refs_update
        BEFORE UPDATE ON transactions BEGIN
          SELECT CASE WHEN NOT EXISTS (
            SELECT 1 FROM accounts a WHERE a.id = NEW.account_id
              AND a.owner_scope_id = NEW.owner_scope_id
          ) THEN RAISE(ABORT, 'owner_scope_account_reference') END;
          SELECT CASE WHEN NOT EXISTS (
            SELECT 1 FROM categories c WHERE c.id = NEW.category_id AND
              (c.is_default = 1 OR c.owner_scope_id = NEW.owner_scope_id)
          ) THEN RAISE(ABORT, 'owner_scope_category_reference') END;
          SELECT CASE WHEN NEW.payee_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM payees p WHERE p.id = NEW.payee_id
              AND p.owner_scope_id = NEW.owner_scope_id
          ) THEN RAISE(ABORT, 'owner_scope_payee_reference') END;
        END''',
      '''CREATE TRIGGER IF NOT EXISTS transactions_transfer_scope_collision_update
        BEFORE UPDATE OF owner_scope_id, transfer_group_id ON transactions
        WHEN NEW.transfer_group_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM transactions t
          WHERE t.rowid IS NOT OLD.rowid
            AND t.transfer_group_id = NEW.transfer_group_id
            AND t.owner_scope_id IS NOT NEW.owner_scope_id
            AND (
              NEW.transfer_group_id IS NOT OLD.transfer_group_id OR
              OLD.owner_scope_id IS NOT NULL OR
              t.owner_scope_id IS NOT NULL
            )
        )
        BEGIN
          SELECT RAISE(ABORT, 'owner_scope_transfer_reference');
        END''',
      '''CREATE TRIGGER IF NOT EXISTS payees_scope_refs_insert
        BEFORE INSERT ON payees BEGIN
          SELECT CASE WHEN NEW.default_account_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM accounts a WHERE a.id = NEW.default_account_id
              AND a.owner_scope_id = NEW.owner_scope_id
          ) THEN RAISE(ABORT, 'owner_scope_account_reference') END;
          SELECT CASE WHEN NEW.default_category_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM categories c WHERE c.id = NEW.default_category_id
              AND (c.is_default = 1 OR c.owner_scope_id = NEW.owner_scope_id)
          ) THEN RAISE(ABORT, 'owner_scope_category_reference') END;
        END''',
      '''CREATE TRIGGER IF NOT EXISTS budgets_scope_refs_insert
        BEFORE INSERT ON budgets WHEN NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.category_id
            AND (c.is_default = 1 OR c.owner_scope_id = NEW.owner_scope_id)
        ) BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS goals_scope_refs_insert
        BEFORE INSERT ON goals WHEN NEW.linked_account_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM accounts a
            WHERE a.id = NEW.linked_account_id
              AND a.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_account_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS goal_contributions_scope_refs_insert
        BEFORE INSERT ON goal_contributions WHEN NOT EXISTS (
          SELECT 1 FROM goals g WHERE g.id = NEW.goal_id
            AND g.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_goal_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS receipts_scope_refs_insert
        BEFORE INSERT ON receipts BEGIN
          SELECT CASE WHEN NEW.merchant_payee_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM payees p WHERE p.id = NEW.merchant_payee_id
              AND p.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_payee_reference') END;
          SELECT CASE WHEN NEW.linked_transaction_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM transactions t WHERE t.id = NEW.linked_transaction_id
              AND t.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_transaction_reference') END;
        END''',
      '''CREATE TRIGGER IF NOT EXISTS receipt_line_items_scope_refs_insert
        BEFORE INSERT ON receipt_line_items WHEN NOT EXISTS (
          SELECT 1 FROM receipts r WHERE r.id = NEW.receipt_id
            AND r.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_receipt_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS transaction_splits_scope_refs_insert
        BEFORE INSERT ON transaction_splits BEGIN
          SELECT CASE WHEN NOT EXISTS (
            SELECT 1 FROM receipts r WHERE r.id = NEW.receipt_id
              AND r.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_receipt_reference') END;
          SELECT CASE WHEN NEW.transaction_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM transactions t WHERE t.id = NEW.transaction_id
              AND t.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_transaction_reference') END;
          SELECT CASE WHEN NOT EXISTS (
            SELECT 1 FROM categories c WHERE c.id = NEW.category_id
              AND (c.is_default = 1 OR c.owner_scope_id = NEW.owner_scope_id))
          THEN RAISE(ABORT, 'owner_scope_category_reference') END;
        END''',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  Future<void> _createOwnerScopeExtendedGuards() async {
    final canonicalDefaultIds = defaultCategoryDefinitions
        .map((definition) => _sqliteText(definition.id))
        .join(', ');
    final statements = <String>[
      '''CREATE TRIGGER IF NOT EXISTS payees_scope_refs_update
        BEFORE UPDATE ON payees BEGIN
          SELECT CASE WHEN NEW.default_account_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM accounts a WHERE a.id = NEW.default_account_id
              AND a.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_account_reference') END;
          SELECT CASE WHEN NEW.default_category_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM categories c WHERE c.id = NEW.default_category_id
              AND (c.is_default = 1 OR c.owner_scope_id = NEW.owner_scope_id))
          THEN RAISE(ABORT, 'owner_scope_category_reference') END;
        END''',
      '''CREATE TRIGGER IF NOT EXISTS budgets_scope_refs_update
        BEFORE UPDATE ON budgets WHEN NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.category_id
            AND (c.is_default = 1 OR c.owner_scope_id = NEW.owner_scope_id))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS goals_scope_refs_update
        BEFORE UPDATE ON goals WHEN NEW.linked_account_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM accounts a
            WHERE a.id = NEW.linked_account_id
              AND a.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_account_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS goal_contributions_scope_refs_update
        BEFORE UPDATE ON goal_contributions WHEN NOT EXISTS (
          SELECT 1 FROM goals g WHERE g.id = NEW.goal_id
            AND g.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_goal_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS receipts_scope_refs_update
        BEFORE UPDATE ON receipts BEGIN
          SELECT CASE WHEN NEW.merchant_payee_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM payees p WHERE p.id = NEW.merchant_payee_id
              AND p.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_payee_reference') END;
          SELECT CASE WHEN NEW.linked_transaction_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM transactions t WHERE t.id = NEW.linked_transaction_id
              AND t.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_transaction_reference') END;
        END''',
      '''CREATE TRIGGER IF NOT EXISTS receipt_line_items_scope_refs_update
        BEFORE UPDATE ON receipt_line_items WHEN NOT EXISTS (
          SELECT 1 FROM receipts r WHERE r.id = NEW.receipt_id
            AND r.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_receipt_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS transaction_splits_scope_refs_update
        BEFORE UPDATE ON transaction_splits BEGIN
          SELECT CASE WHEN NOT EXISTS (
            SELECT 1 FROM receipts r WHERE r.id = NEW.receipt_id
              AND r.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_receipt_reference') END;
          SELECT CASE WHEN NEW.transaction_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM transactions t WHERE t.id = NEW.transaction_id
              AND t.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_transaction_reference') END;
          SELECT CASE WHEN NOT EXISTS (
            SELECT 1 FROM categories c WHERE c.id = NEW.category_id
              AND (c.is_default = 1 OR c.owner_scope_id = NEW.owner_scope_id))
          THEN RAISE(ABORT, 'owner_scope_category_reference') END;
        END''',
      '''CREATE TRIGGER IF NOT EXISTS sync_queue_scope_ref_insert
        BEFORE INSERT ON sync_queue WHEN NEW.operation = 'upsert' BEGIN
          SELECT CASE WHEN NEW.entity_type = 'account' AND NOT EXISTS (
            SELECT 1 FROM accounts a WHERE a.id = NEW.entity_id
              AND a.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'transaction' AND NOT EXISTS (
            SELECT 1 FROM transactions t WHERE t.id = NEW.entity_id
              AND t.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'category' AND NOT EXISTS (
            SELECT 1 FROM categories c WHERE c.id = NEW.entity_id AND
              (c.is_default = 1 OR c.owner_scope_id = NEW.owner_scope_id))
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'payee' AND NOT EXISTS (
            SELECT 1 FROM payees p WHERE p.id = NEW.entity_id
              AND p.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'budget' AND NOT EXISTS (
            SELECT 1 FROM budgets b WHERE b.id = NEW.entity_id
              AND b.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'goal' AND NOT EXISTS (
            SELECT 1 FROM goals g WHERE g.id = NEW.entity_id
              AND g.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'exchangeRate' AND NOT EXISTS (
            SELECT 1 FROM exchange_rates e WHERE e.id = NEW.entity_id
              AND e.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
        END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_previews_scope_ref_insert
        BEFORE INSERT ON ai_agent_previews WHEN NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = NEW.command_id
            AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_command_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_proofs_scope_ref_insert
        BEFORE INSERT ON ai_agent_confirmation_proofs WHEN NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = NEW.command_id
            AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_command_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_attempts_scope_ref_insert
        BEFORE INSERT ON ai_agent_execution_attempts WHEN NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = NEW.command_id
            AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_command_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_results_scope_ref_insert
        BEFORE INSERT ON ai_agent_execution_results WHEN NOT EXISTS (
          SELECT 1 FROM ai_agent_execution_attempts a
          WHERE a.id = NEW.attempt_id AND a.command_id = NEW.command_id
            AND a.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_attempt_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_plan_steps_scope_ref_insert
        BEFORE INSERT ON ai_agent_plan_steps WHEN NOT EXISTS (
          SELECT 1 FROM ai_agent_plans p WHERE p.id = NEW.plan_id
            AND p.owner_scope_id = NEW.owner_scope_id)
          OR NOT EXISTS (SELECT 1 FROM ai_agent_commands c
            WHERE c.id = NEW.command_id
              AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_plan_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_audits_scope_ref_insert
        BEFORE INSERT ON ai_agent_audit_events WHEN NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = NEW.command_id
            AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_command_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_idempotency_scope_ref_insert
        BEFORE INSERT ON ai_agent_idempotency_records WHEN NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = NEW.command_id
            AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_command_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_business_ops_scope_ref_insert
        BEFORE INSERT ON ai_agent_business_operations WHEN NOT EXISTS (
          SELECT 1 FROM ai_agent_commands c WHERE c.id = NEW.command_id
            AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_command_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_attempt_operation_scope_ref_insert
        BEFORE INSERT ON ai_agent_execution_attempts
        WHEN NEW.business_operation_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM ai_agent_business_operations o
          WHERE o.id = NEW.business_operation_id
            AND o.command_id = NEW.command_id
            AND o.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_operation_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS categories_parent_scope_ref_insert
        BEFORE INSERT ON categories
        WHEN NEW.parent_category_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.parent_category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS categories_parent_scope_ref_update
        BEFORE UPDATE OF owner_scope_id, parent_category_id ON categories
        WHEN NEW.parent_category_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.parent_category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS transactions_exact_category_ref_insert
        BEFORE INSERT ON transactions WHEN NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS transactions_exact_category_ref_update
        BEFORE UPDATE OF owner_scope_id, category_id ON transactions
        WHEN NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS payees_exact_category_ref_insert
        BEFORE INSERT ON payees
        WHEN NEW.default_category_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.default_category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS payees_exact_category_ref_update
        BEFORE UPDATE OF owner_scope_id, default_category_id ON payees
        WHEN NEW.default_category_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.default_category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS budgets_exact_category_ref_insert
        BEFORE INSERT ON budgets WHEN NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS budgets_exact_category_ref_update
        BEFORE UPDATE OF owner_scope_id, category_id ON budgets
        WHEN NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS receipt_items_category_ref_insert
        BEFORE INSERT ON receipt_line_items
        WHEN NEW.category_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS receipt_items_category_ref_update
        BEFORE UPDATE OF owner_scope_id, category_id ON receipt_line_items
        WHEN NEW.category_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS splits_exact_category_ref_insert
        BEFORE INSERT ON transaction_splits WHEN NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS splits_exact_category_ref_update
        BEFORE UPDATE OF owner_scope_id, category_id ON transaction_splits
        WHEN NOT EXISTS (
          SELECT 1 FROM categories c WHERE c.id = NEW.category_id AND (
            (c.is_default = 1 AND c.owner_scope_id IS NULL
              AND c.id IN ($canonicalDefaultIds)) OR
            (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_category_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS contributions_transaction_ref_insert
        BEFORE INSERT ON goal_contributions
        WHEN NEW.linked_transaction_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM transactions t
          WHERE t.id = NEW.linked_transaction_id
            AND t.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_transaction_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS contributions_transaction_ref_update
        BEFORE UPDATE OF owner_scope_id, linked_transaction_id
        ON goal_contributions
        WHEN NEW.linked_transaction_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM transactions t
          WHERE t.id = NEW.linked_transaction_id
            AND t.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_transaction_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS sync_queue_scope_ref_update
        BEFORE UPDATE OF owner_scope_id, operation, entity_type, entity_id
        ON sync_queue WHEN NEW.operation = 'upsert' BEGIN
          SELECT CASE WHEN NEW.entity_type NOT IN (
            'account', 'transaction', 'category', 'payee', 'budget', 'goal',
            'exchangeRate', 'settings'
          ) THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'account' AND NOT EXISTS (
            SELECT 1 FROM accounts a WHERE a.id = NEW.entity_id
              AND a.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'transaction' AND NOT EXISTS (
            SELECT 1 FROM transactions t WHERE t.id = NEW.entity_id
              AND t.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'category' AND NOT EXISTS (
            SELECT 1 FROM categories c WHERE c.id = NEW.entity_id AND (
              (c.is_default = 1 AND c.owner_scope_id IS NULL
                AND c.id IN ($canonicalDefaultIds)) OR
              (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'payee' AND NOT EXISTS (
            SELECT 1 FROM payees p WHERE p.id = NEW.entity_id
              AND p.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'budget' AND NOT EXISTS (
            SELECT 1 FROM budgets b WHERE b.id = NEW.entity_id
              AND b.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'goal' AND NOT EXISTS (
            SELECT 1 FROM goals g WHERE g.id = NEW.entity_id
              AND g.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
          SELECT CASE WHEN NEW.entity_type = 'exchangeRate' AND NOT EXISTS (
            SELECT 1 FROM exchange_rates e WHERE e.id = NEW.entity_id
              AND e.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_sync_reference') END;
        END''',
      '''CREATE TRIGGER IF NOT EXISTS sync_queue_supported_upsert_insert
        BEFORE INSERT ON sync_queue
        WHEN NEW.operation = 'upsert' AND NEW.entity_type NOT IN (
          'account', 'transaction', 'category', 'payee', 'budget', 'goal',
          'exchangeRate', 'settings')
        BEGIN SELECT RAISE(ABORT, 'owner_scope_sync_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS sync_queue_exact_category_ref_insert
        BEFORE INSERT ON sync_queue
        WHEN NEW.operation = 'upsert' AND NEW.entity_type = 'category'
          AND NOT EXISTS (
            SELECT 1 FROM categories c WHERE c.id = NEW.entity_id AND (
              (c.is_default = 1 AND c.owner_scope_id IS NULL
                AND c.id IN ($canonicalDefaultIds)) OR
              (c.is_default = 0 AND c.owner_scope_id = NEW.owner_scope_id)))
        BEGIN SELECT RAISE(ABORT, 'owner_scope_sync_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_previews_scope_ref_update
        BEFORE UPDATE OF owner_scope_id, command_id ON ai_agent_previews
        WHEN NOT EXISTS (SELECT 1 FROM ai_agent_commands c
          WHERE c.id = NEW.command_id AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_command_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_proofs_scope_ref_update
        BEFORE UPDATE OF owner_scope_id, command_id
        ON ai_agent_confirmation_proofs
        WHEN NOT EXISTS (SELECT 1 FROM ai_agent_commands c
          WHERE c.id = NEW.command_id AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_command_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_attempts_scope_ref_update
        BEFORE UPDATE OF owner_scope_id, command_id
        ON ai_agent_execution_attempts
        WHEN NOT EXISTS (SELECT 1 FROM ai_agent_commands c
          WHERE c.id = NEW.command_id AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_command_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_attempt_operation_scope_ref_update
        BEFORE UPDATE OF owner_scope_id, command_id, business_operation_id
        ON ai_agent_execution_attempts
        WHEN NEW.business_operation_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM ai_agent_business_operations o
          WHERE o.id = NEW.business_operation_id
            AND o.command_id = NEW.command_id
            AND o.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_operation_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_results_scope_ref_update
        BEFORE UPDATE OF owner_scope_id, command_id, attempt_id
        ON ai_agent_execution_results
        WHEN NOT EXISTS (SELECT 1 FROM ai_agent_execution_attempts a
          WHERE a.id = NEW.attempt_id AND a.command_id = NEW.command_id
            AND a.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_attempt_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_plan_steps_scope_ref_update
        BEFORE UPDATE OF owner_scope_id, plan_id, command_id
        ON ai_agent_plan_steps
        WHEN NOT EXISTS (SELECT 1 FROM ai_agent_plans p
          WHERE p.id = NEW.plan_id AND p.owner_scope_id = NEW.owner_scope_id)
          OR NOT EXISTS (SELECT 1 FROM ai_agent_commands c
            WHERE c.id = NEW.command_id
              AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_plan_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_audits_scope_ref_update
        BEFORE UPDATE OF owner_scope_id, command_id ON ai_agent_audit_events
        WHEN NOT EXISTS (SELECT 1 FROM ai_agent_commands c
          WHERE c.id = NEW.command_id AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_command_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_idempotency_result_ref_insert
        BEFORE INSERT ON ai_agent_idempotency_records
        WHEN NEW.execution_result_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM ai_agent_execution_results r
          WHERE r.id = NEW.execution_result_id
            AND r.command_id = NEW.command_id
            AND r.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_result_reference'); END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_idempotency_scope_ref_update
        BEFORE UPDATE OF owner_scope_id, command_id, execution_result_id
        ON ai_agent_idempotency_records BEGIN
          SELECT CASE WHEN NOT EXISTS (
            SELECT 1 FROM ai_agent_commands c WHERE c.id = NEW.command_id
              AND c.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_command_reference') END;
          SELECT CASE WHEN NEW.execution_result_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM ai_agent_execution_results r
            WHERE r.id = NEW.execution_result_id
              AND r.command_id = NEW.command_id
              AND r.owner_scope_id = NEW.owner_scope_id)
          THEN RAISE(ABORT, 'owner_scope_result_reference') END;
        END''',
      '''CREATE TRIGGER IF NOT EXISTS agent_business_ops_scope_ref_update
        BEFORE UPDATE OF owner_scope_id, command_id
        ON ai_agent_business_operations
        WHEN NOT EXISTS (SELECT 1 FROM ai_agent_commands c
          WHERE c.id = NEW.command_id AND c.owner_scope_id = NEW.owner_scope_id)
        BEGIN SELECT RAISE(ABORT, 'owner_scope_command_reference'); END''',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }
}

String _sqliteText(String value) => "'${value.replaceAll("'", "''")}'";
