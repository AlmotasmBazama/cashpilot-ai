part of 'app_database.dart';

/// Owns the connection-local capabilities that let the privacy workflow
/// remove financially guarded rows for exactly one owner.
///
/// [AppDatabase] keeps the public entry points for source compatibility. This
/// extension intentionally preserves each entry point's historical validation,
/// transaction boundary, permit lifetime, and statement order.
extension _AppDatabaseOwnerDataDeletion on AppDatabase {
  Future<int> _deleteOwnerTransactions({
    required String ownerScopeId,
    required String operationId,
  }) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(ownerScopeId) ||
        !_isCanonicalTransferIdentifier(operationId)) {
      throw ArgumentError('A scoped deletion operation is required.');
    }
    return transaction(() async {
      if (_enforceFinancialIntegrityGuards) {
        await customStatement(
          '''INSERT INTO cashpilot_owner_account_deletion_permits
               (owner_scope_id, operation_id) VALUES (?, ?)''',
          <Object?>[ownerScopeId, operationId],
        );
      }
      try {
        return (delete(
          transactions,
        )..where((row) => row.ownerScopeId.equals(ownerScopeId))).go();
      } finally {
        if (_enforceFinancialIntegrityGuards) {
          await customStatement(
            '''DELETE FROM cashpilot_owner_account_deletion_permits
               WHERE owner_scope_id = ? AND operation_id = ?''',
            <Object?>[ownerScopeId, operationId],
          );
        }
      }
    });
  }

  Future<int> _deleteOwnerAccounts({
    required String ownerScopeId,
    required String operationId,
  }) {
    if (ownerScopeId.isEmpty || operationId.isEmpty) {
      throw ArgumentError('A scoped deletion operation is required.');
    }

    return transaction(() async {
      if (_enforceFinancialIntegrityGuards) {
        await customStatement(
          '''INSERT INTO cashpilot_owner_account_deletion_permits (
               owner_scope_id, operation_id
             ) VALUES (?, ?)''',
          <Object?>[ownerScopeId, operationId],
        );
      }
      try {
        return await (delete(
          accounts,
        )..where((row) => row.ownerScopeId.equals(ownerScopeId))).go();
      } finally {
        if (_enforceFinancialIntegrityGuards) {
          await customStatement(
            '''DELETE FROM cashpilot_owner_account_deletion_permits
               WHERE owner_scope_id = ? AND operation_id = ?''',
            <Object?>[ownerScopeId, operationId],
          );
        }
      }
    });
  }
}
