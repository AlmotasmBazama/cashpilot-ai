part of 'app_database.dart';

/// Installs the connection-local permit tables and triggers that make a
/// transfer pair the only valid mutation unit for transfer transaction rows.
///
/// This private extension preserves every statement, trigger name, and await
/// position while keeping the generated schema and migration contract intact.
extension _AppDatabaseTransferGuardDdl on AppDatabase {
  Future<void> _createTransferFinancialIntegrityGuards() async {
    await customStatement('''
      CREATE TEMP TABLE IF NOT EXISTS cashpilot_transfer_pair_permits (
        owner_scope_id TEXT NOT NULL,
        transfer_group_id TEXT NOT NULL,
        outgoing_transaction_id TEXT NOT NULL,
        incoming_transaction_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        target_status TEXT,
        outgoing_done INTEGER NOT NULL DEFAULT 0,
        incoming_done INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (owner_scope_id, transfer_group_id)
      ) WITHOUT ROWID
    ''');
    await customStatement('''
      CREATE TEMP TABLE IF NOT EXISTS cashpilot_transfer_legacy_claim_permits (
        target_owner_scope_id TEXT PRIMARY KEY NOT NULL
      ) WITHOUT ROWID
    ''');

    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS transactions_transfer_shape_insert
      BEFORE INSERT ON transactions
      WHEN
        (NEW.type IN ('transferOut', 'transferIn') AND
          (NEW.transfer_group_id IS NULL OR
           LENGTH(TRIM(NEW.transfer_group_id)) = 0)) OR
        (NEW.type NOT IN ('transferOut', 'transferIn') AND
          NEW.transfer_group_id IS NOT NULL) OR
        (NEW.transfer_group_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM cashpilot_transfer_pair_permits permit
          WHERE permit.owner_scope_id IS NEW.owner_scope_id
            AND permit.transfer_group_id = NEW.transfer_group_id
            AND permit.operation = 'create'
            AND ((NEW.type = 'transferOut'
                  AND permit.outgoing_transaction_id = NEW.id
                  AND permit.outgoing_done = 0) OR
                 (NEW.type = 'transferIn'
                  AND permit.incoming_transaction_id = NEW.id
                  AND permit.incoming_done = 0))
        )) OR
        (NEW.transfer_group_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM transactions existing
          WHERE existing.transfer_group_id = NEW.transfer_group_id
            AND (existing.owner_scope_id IS NOT NEW.owner_scope_id OR
                 existing.type = NEW.type)
        )) OR
        (NEW.transfer_group_id IS NOT NULL AND
          (SELECT COUNT(*) FROM transactions existing
           WHERE existing.owner_scope_id IS NEW.owner_scope_id
             AND existing.transfer_group_id = NEW.transfer_group_id) >= 2)
      BEGIN
        SELECT RAISE(ABORT, 'transfer_pair_insert_required');
      END
    ''');
    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS transactions_transfer_insert_done
      AFTER INSERT ON transactions
      WHEN NEW.transfer_group_id IS NOT NULL
      BEGIN
        UPDATE cashpilot_transfer_pair_permits
        SET outgoing_done = CASE WHEN NEW.type = 'transferOut'
              THEN 1 ELSE outgoing_done END,
            incoming_done = CASE WHEN NEW.type = 'transferIn'
              THEN 1 ELSE incoming_done END
        WHERE owner_scope_id IS NEW.owner_scope_id
          AND transfer_group_id = NEW.transfer_group_id
          AND operation = 'create';
      END
    ''');

    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS transactions_transfer_shape_update
      BEFORE UPDATE ON transactions
      WHEN
        ((OLD.type IN ('transferOut', 'transferIn') OR
          NEW.type IN ('transferOut', 'transferIn') OR
          OLD.transfer_group_id IS NOT NULL OR
          NEW.transfer_group_id IS NOT NULL) AND (
          NEW.id IS NOT OLD.id OR
          NEW.account_id IS NOT OLD.account_id OR
          NEW.category_id IS NOT OLD.category_id OR
          NEW.payee_id IS NOT OLD.payee_id OR
          NEW.amount IS NOT OLD.amount OR
          NEW.currency_code IS NOT OLD.currency_code OR
          NEW.type IS NOT OLD.type OR
          NEW.payment_method IS NOT OLD.payment_method OR
          NEW.source IS NOT OLD.source OR
          NEW.income_source_type IS NOT OLD.income_source_type OR
          NEW.transfer_group_id IS NOT OLD.transfer_group_id OR
          NEW.transfer_payload_fingerprint IS NOT
            OLD.transfer_payload_fingerprint OR
          NEW.exchange_rate_from_currency_code IS NOT
            OLD.exchange_rate_from_currency_code OR
          NEW.exchange_rate_to_currency_code IS NOT
            OLD.exchange_rate_to_currency_code OR
          NEW.exchange_rate IS NOT OLD.exchange_rate OR
          NEW.exchange_rate_as_of IS NOT OLD.exchange_rate_as_of OR
          NEW.note IS NOT OLD.note OR
          NEW.transaction_date IS NOT OLD.transaction_date OR
          NEW.location IS NOT OLD.location OR
          NEW.attachment_count IS NOT OLD.attachment_count OR
          NEW.ai_confidence IS NOT OLD.ai_confidence OR
          NEW.needs_review IS NOT OLD.needs_review OR
          NEW.created_at IS NOT OLD.created_at
        )) OR
        (NEW.owner_scope_id IS NOT OLD.owner_scope_id AND NOT (
          OLD.owner_scope_id IS NULL AND NEW.owner_scope_id IS NOT NULL AND
          NEW.status IS OLD.status AND
          NEW.updated_at IS OLD.updated_at AND
          EXISTS (
            SELECT 1 FROM cashpilot_transfer_legacy_claim_permits claim
            WHERE claim.target_owner_scope_id = NEW.owner_scope_id
          )
        )) OR
        ((OLD.type IN ('transferOut', 'transferIn') OR
          OLD.transfer_group_id IS NOT NULL) AND NOT (
          OLD.owner_scope_id IS NULL AND NEW.owner_scope_id IS NOT NULL AND
          NEW.status IS OLD.status AND
          NEW.updated_at IS OLD.updated_at AND
          EXISTS (
            SELECT 1 FROM cashpilot_transfer_legacy_claim_permits claim
            WHERE claim.target_owner_scope_id = NEW.owner_scope_id
          )
        ) AND NOT EXISTS (
          SELECT 1 FROM cashpilot_transfer_pair_permits permit
          WHERE permit.owner_scope_id IS OLD.owner_scope_id
            AND permit.transfer_group_id = OLD.transfer_group_id
            AND permit.operation = 'update'
            AND permit.target_status = NEW.status
            AND ((OLD.type = 'transferOut'
                  AND permit.outgoing_transaction_id = OLD.id
                  AND permit.outgoing_done = 0) OR
                 (OLD.type = 'transferIn'
                  AND permit.incoming_transaction_id = OLD.id
                  AND permit.incoming_done = 0))
        ))
      BEGIN
        SELECT RAISE(ABORT, 'transfer_pair_update_required');
      END
    ''');
    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS transactions_transfer_update_done
      AFTER UPDATE ON transactions
      WHEN OLD.type IN ('transferOut', 'transferIn')
      BEGIN
        UPDATE cashpilot_transfer_pair_permits
        SET outgoing_done = CASE WHEN OLD.type = 'transferOut'
              THEN 1 ELSE outgoing_done END,
            incoming_done = CASE WHEN OLD.type = 'transferIn'
              THEN 1 ELSE incoming_done END
        WHERE owner_scope_id IS OLD.owner_scope_id
          AND transfer_group_id = OLD.transfer_group_id
          AND operation = 'update';
      END
    ''');

    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS transactions_transfer_delete
      BEFORE DELETE ON transactions
      WHEN (OLD.type IN ('transferOut', 'transferIn') OR
            OLD.transfer_group_id IS NOT NULL)
        AND NOT EXISTS (
          SELECT 1 FROM cashpilot_owner_account_deletion_permits deletion
          WHERE deletion.owner_scope_id IS OLD.owner_scope_id
        )
        AND NOT EXISTS (
          SELECT 1 FROM cashpilot_transfer_pair_permits permit
          WHERE permit.owner_scope_id IS OLD.owner_scope_id
            AND permit.transfer_group_id = OLD.transfer_group_id
            AND permit.operation = 'delete'
            AND ((OLD.type = 'transferOut'
                  AND permit.outgoing_transaction_id = OLD.id
                  AND permit.outgoing_done = 0) OR
                 (OLD.type = 'transferIn'
                  AND permit.incoming_transaction_id = OLD.id
                  AND permit.incoming_done = 0))
        )
      BEGIN
        SELECT RAISE(ABORT, 'transfer_pair_delete_required');
      END
    ''');
    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS transactions_transfer_delete_done
      AFTER DELETE ON transactions
      WHEN OLD.type IN ('transferOut', 'transferIn')
      BEGIN
        UPDATE cashpilot_transfer_pair_permits
        SET outgoing_done = CASE WHEN OLD.type = 'transferOut'
              THEN 1 ELSE outgoing_done END,
            incoming_done = CASE WHEN OLD.type = 'transferIn'
              THEN 1 ELSE incoming_done END
        WHERE owner_scope_id IS OLD.owner_scope_id
          AND transfer_group_id = OLD.transfer_group_id
          AND operation = 'delete';
      END
    ''');
  }
}
