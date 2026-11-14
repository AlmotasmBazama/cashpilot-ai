part of 'app_database.dart';

/// Installs the connection-local guards for account creation, identity,
/// archival, and deletion around the balance-projection capability.
///
/// Statement text and execution order remain part of the existing database
/// contract. This private extension is resolved at compile time and allocates
/// no runtime delegate.
extension _AppDatabaseAccountLifecycleGuards on AppDatabase {
  Future<void> _createAccountFinancialIntegrityGuards() async {
    final newBalanceIsZero = _sqliteDecimalTextIsZero('NEW.balance');
    final oldBalanceIsZero = _sqliteDecimalTextIsZero('OLD.balance');

    // TEMP capabilities are connection-local and transaction-scoped. They are
    // deliberately absent from the durable schema, backups, and migrations.
    await _createAccountBalanceProjectionPermitTable();
    await customStatement('''
      CREATE TEMP TABLE IF NOT EXISTS
        cashpilot_owner_account_deletion_permits (
          owner_scope_id TEXT PRIMARY KEY NOT NULL,
          operation_id TEXT NOT NULL
        ) WITHOUT ROWID
    ''');

    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS accounts_zero_balance_insert
      BEFORE INSERT ON accounts
      WHEN NEW.balance IS NOT '0'
      BEGIN
        SELECT RAISE(ABORT, 'opening_balance_ledger_required');
      END
    ''');
    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS accounts_replace_forbidden
      BEFORE INSERT ON accounts
      WHEN EXISTS (SELECT 1 FROM accounts existing WHERE existing.id = NEW.id)
      BEGIN
        SELECT RAISE(ABORT, 'account_replace_forbidden');
      END
    ''');
    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS accounts_protected_fields_update
      BEFORE UPDATE OF id, type, currency_code, created_at ON accounts
      WHEN NEW.id IS NOT OLD.id OR
        NEW.type IS NOT OLD.type OR
        NEW.currency_code IS NOT OLD.currency_code OR
        NEW.created_at IS NOT OLD.created_at
      BEGIN
        SELECT RAISE(ABORT, 'account_protected_field');
      END
    ''');
    await _createAccountBalanceProjectionWriteGuards();
    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS accounts_safe_archive
      BEFORE UPDATE OF is_archived ON accounts
      WHEN OLD.is_archived = 0 AND NEW.is_archived = 1 AND (
        NOT ($newBalanceIsZero) OR
        EXISTS (SELECT 1 FROM transactions dependency
          WHERE dependency.account_id = OLD.id) OR
        EXISTS (SELECT 1 FROM payees dependency
          WHERE dependency.default_account_id = OLD.id) OR
        EXISTS (SELECT 1 FROM goals dependency
          WHERE dependency.linked_account_id = OLD.id)
      )
      BEGIN
        SELECT RAISE(ABORT, 'account_close_requires_zero_or_no_dependencies');
      END
    ''');
    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS accounts_safe_delete
      BEFORE DELETE ON accounts
      WHEN (
        NOT ($oldBalanceIsZero) AND NOT EXISTS (
          SELECT 1 FROM cashpilot_owner_account_deletion_permits permit
          WHERE permit.owner_scope_id IS OLD.owner_scope_id
        )
      ) OR
      EXISTS (SELECT 1 FROM transactions dependency
        WHERE dependency.account_id = OLD.id) OR
      EXISTS (SELECT 1 FROM payees dependency
        WHERE dependency.default_account_id = OLD.id) OR
      EXISTS (SELECT 1 FROM goals dependency
        WHERE dependency.linked_account_id = OLD.id)
      BEGIN
        SELECT RAISE(ABORT, 'account_close_requires_zero_or_no_dependencies');
      END
    ''');
  }
}

String _sqliteDecimalTextIsZero(String expression) {
  final value = 'TRIM($expression)';
  return '''
    $value <> '' AND
    $value NOT GLOB '*[^0.+-]*' AND
    INSTR($value, '0') > 0 AND
    (LENGTH($value) - LENGTH(REPLACE($value, '.', ''))) <= 1 AND
    (
      (LENGTH($value) - LENGTH(REPLACE($value, '+', ''))) +
      (LENGTH($value) - LENGTH(REPLACE($value, '-', '')))
    ) <= 1 AND
    (INSTR($value, '+') = 0 OR INSTR($value, '+') = 1) AND
    (INSTR($value, '-') = 0 OR INSTR($value, '-') = 1) AND
    REPLACE(
      REPLACE(REPLACE(REPLACE($value, '0', ''), '.', ''), '+', ''),
      '-', ''
    ) = ''
  ''';
}
