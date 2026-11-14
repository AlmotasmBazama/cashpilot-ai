part of 'app_database.dart';

/// Owns the one-shot capability used to project a finance-engine balance into
/// an account row and the connection-local SQLite guards for that capability.
///
/// [AppDatabase] retains the public entry point. The private extension keeps
/// validation timing, transaction and statement order, permit lifetime, and
/// exception identity without allocating a runtime delegate.
extension _AppDatabaseAccountBalanceProjection on AppDatabase {
  Future<int> _updateAccountBalanceProjection({
    required String ownerScopeId,
    required String accountId,
    required String balance,
    required DateTime updatedAt,
  }) {
    if (ownerScopeId.isEmpty || accountId.isEmpty) {
      throw ArgumentError('A scoped account projection target is required.');
    }

    return transaction(() async {
      await _requireTransferScopeIntegrity(ownerScopeId);
      final current =
          await (select(accounts)..where(
                (row) =>
                    row.ownerScopeId.equals(ownerScopeId) &
                    row.id.equals(accountId),
              ))
              .getSingleOrNull();
      if (current == null) {
        return 0;
      }

      final changesBalance = current.balance != balance;
      if (_enforceFinancialIntegrityGuards && changesBalance) {
        await customStatement(
          '''INSERT INTO cashpilot_account_balance_projection_permits (
               owner_scope_id, account_id, previous_balance, next_balance
             ) VALUES (?, ?, ?, ?)''',
          <Object?>[ownerScopeId, accountId, current.balance, balance],
        );
      }

      try {
        final updatedRows =
            await (update(accounts)..where(
                  (row) =>
                      row.ownerScopeId.equals(ownerScopeId) &
                      row.id.equals(accountId) &
                      row.balance.equals(current.balance),
                ))
                .write(
                  AccountsCompanion(
                    balance: changesBalance
                        ? Value(balance)
                        : const Value.absent(),
                    updatedAt: Value(updatedAt),
                  ),
                );
        if (updatedRows != 1) {
          throw StateError('The account balance projection changed.');
        }

        if (_enforceFinancialIntegrityGuards && changesBalance) {
          final outstanding = await customSelect(
            '''SELECT COUNT(*) AS value
               FROM cashpilot_account_balance_projection_permits
               WHERE owner_scope_id = ? AND account_id = ?''',
            variables: <Variable<Object>>[
              Variable<String>(ownerScopeId),
              Variable<String>(accountId),
            ],
          ).getSingle();
          if (outstanding.read<int>('value') != 0) {
            throw StateError('The account balance permit was not consumed.');
          }
        }
        return updatedRows;
      } finally {
        if (_enforceFinancialIntegrityGuards && changesBalance) {
          await customStatement(
            '''DELETE FROM cashpilot_account_balance_projection_permits
               WHERE owner_scope_id = ? AND account_id = ?''',
            <Object?>[ownerScopeId, accountId],
          );
        }
      }
    });
  }

  Future<void> _createAccountBalanceProjectionPermitTable() async {
    await customStatement('''
      CREATE TEMP TABLE IF NOT EXISTS
        cashpilot_account_balance_projection_permits (
          owner_scope_id TEXT NOT NULL,
          account_id TEXT NOT NULL,
          previous_balance TEXT NOT NULL,
          next_balance TEXT NOT NULL,
          PRIMARY KEY (owner_scope_id, account_id)
        ) WITHOUT ROWID
    ''');
  }

  Future<void> _createAccountBalanceProjectionWriteGuards() async {
    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS accounts_balance_projection_update
      BEFORE UPDATE OF balance ON accounts
      WHEN NEW.balance IS NOT OLD.balance AND NOT EXISTS (
        SELECT 1 FROM cashpilot_account_balance_projection_permits permit
        WHERE permit.owner_scope_id IS OLD.owner_scope_id
          AND permit.account_id = OLD.id
          AND permit.previous_balance = OLD.balance
          AND permit.next_balance = NEW.balance
      )
      BEGIN
        SELECT RAISE(ABORT, 'finance_engine_balance_projection_required');
      END
    ''');
    await customStatement('''
      CREATE TEMP TRIGGER IF NOT EXISTS accounts_balance_projection_consume
      AFTER UPDATE OF balance ON accounts
      WHEN NEW.balance IS NOT OLD.balance
      BEGIN
        DELETE FROM cashpilot_account_balance_projection_permits
        WHERE owner_scope_id IS OLD.owner_scope_id
          AND account_id = OLD.id
          AND previous_balance = OLD.balance
          AND next_balance = NEW.balance;
      END
    ''');
  }
}
