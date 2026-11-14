import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../sync/data/legacy_sync_queue_migration.dart';
import '../domain/owner_scope.dart';
import 'owner_scope_health_service.dart';
import 'scoped_app_database_session.dart';

class LegacyDataInventory {
  LegacyDataInventory(
    Map<String, int> counts, {
    this.unexpectedSyncQueueRows = 0,
  }) : counts = Map<String, int>.unmodifiable(counts);

  final Map<String, int> counts;
  final int unexpectedSyncQueueRows;

  int get total => counts.values.fold(0, (sum, value) => sum + value);
  bool get hasLegacyData => total > 0;
  bool get hasUnexpectedSyncQueueRows => unexpectedSyncQueueRows > 0;
}

class LegacyDataClaimResult {
  const LegacyDataClaimResult({
    required this.claimedCount,
    required this.auditId,
  });

  final int claimedCount;
  final String auditId;
}

/// Native-only legacy claim workflow. The service is bound to a trusted
/// scoped session and never accepts an ownerScopeId or model-provided value.
class LegacyDataClaimService {
  const LegacyDataClaimService({
    required ScopedAppDatabaseSession session,
    required ConfirmedOwnerScope? Function() currentConfirmedScope,
  }) : _session = session,
       _currentConfirmedScope = currentConfirmedScope;

  final ScopedAppDatabaseSession _session;
  final ConfirmedOwnerScope? Function() _currentConfirmedScope;

  AppDatabase get _database => _session.database;

  Future<LegacyDataInventory> inspectBoundedCounts() async {
    _session.assertActive();
    final expectedScope = _session.confirmedScope;
    final counts = <String, int>{};
    for (final entry in _claimStatements.entries) {
      final whereClause = entry.key == 'categories'
          ? 'owner_scope_id IS NULL AND is_default = 0'
          : 'owner_scope_id IS NULL';
      final row = await _database
          .customSelect(
            'SELECT COUNT(*) AS value FROM ${entry.key} WHERE $whereClause',
          )
          .getSingle();
      counts[entry.key] = row.read<int>('value');
    }
    final syncQueueInventory = await _inspectLegacySyncQueue(
      expectedScope.id.value,
    );
    // This is inventory only. Sync rows are intentionally absent from the
    // blanket claim map because each row must be attributed from its own
    // legacy owner identity before it can be migrated.
    counts['sync_queue'] = syncQueueInventory.claimableCount;
    _session.assertActive();
    return LegacyDataInventory(
      counts,
      unexpectedSyncQueueRows: syncQueueInventory.unexpectedCount,
    );
  }

  Future<LegacyDataClaimResult> claim({
    required bool protectedConfirmationAccepted,
  }) async {
    if (!protectedConfirmationAccepted) {
      throw const OwnerScopeException(OwnerScopeFailure.authNotConfirmed);
    }
    _session.assertActive();
    final scopeBefore = _session.confirmedScope;
    _assertCurrentScope(scopeBefore);

    final auditId = const Uuid().v7();
    var claimed = 0;
    await _session.runGuardedWrite(
      () => _database.transaction(() async {
        _assertCurrentScope(scopeBefore);
        await _validateLegacyReferences();
        final before = await inspectBoundedCounts();
        if (before.hasUnexpectedSyncQueueRows) {
          // App startup normally migrates the legacy outbox globally before a
          // scoped session exists. A leftover row that cannot be attributed to
          // this owner must remain untouched and fail closed; assigning it to
          // the signed-in owner would cross account boundaries.
          throw const OwnerScopeException(
            OwnerScopeFailure.integrityCheckFailed,
          );
        }
        if (!before.hasLegacyData) {
          throw const OwnerScopeException(
            OwnerScopeFailure.legacyDataAlreadyClaimed,
          );
        }
        for (final entry in _claimStatements.entries) {
          if (entry.key == 'transactions') {
            claimed += await _database.claimLegacyTransactions(
              ownerScopeId: scopeBefore.id.value,
            );
            continue;
          }
          final sql = entry.value;
          claimed += await _database.customUpdate(
            sql,
            variables: <Variable<Object>>[
              Variable<String>(scopeBefore.id.value),
            ],
            updates: {_tableForSql(sql)},
          );
        }
        claimed += await LegacySyncQueueMigration.runForScope(
          _database,
          syncQueueTable: _database.syncQueue,
          ownerScopeValue: scopeBefore.id.value,
        );
        final after = await inspectBoundedCounts();
        if (after.hasLegacyData || after.hasUnexpectedSyncQueueRows) {
          throw const OwnerScopeException(
            OwnerScopeFailure.integrityCheckFailed,
          );
        }
        final postClaimHealth = await OwnerScopeHealthService(_database)
            .evaluate(
              snapshot: OwnerScopeSnapshot(
                status: OwnerScopeStatus.safe,
                scope: scopeBefore,
              ),
              session: _session,
            );
        _assertCurrentScope(scopeBefore);
        if (!postClaimHealth.isSafe) {
          throw OwnerScopeException(
            postClaimHealth.failure ?? OwnerScopeFailure.integrityCheckFailed,
          );
        }
        final now = DateTime.now().toUtc();
        await _database
            .into(_database.ownerScopeMigrationAudits)
            .insert(
              OwnerScopeMigrationAuditsCompanion.insert(
                id: auditId,
                ownerScopeId: scopeBefore.id.value,
                status: 'succeeded',
                boundedCountsJson: jsonEncode(before.counts),
                createdAt: now,
                updatedAt: now,
              ),
            );
        // This is the final transaction checkpoint. A logout, account switch,
        // or session revocation that happened during any awaited write rolls
        // the whole claim (including the audit record) back atomically.
        _assertCurrentScope(scopeBefore);
      }),
    );
    return LegacyDataClaimResult(claimedCount: claimed, auditId: auditId);
  }

  Future<_LegacySyncQueueInventory> _inspectLegacySyncQueue(
    String expectedScopeValue,
  ) async {
    final rows = await _database.customSelect('''
      SELECT owner_user_id
      FROM sync_queue
      WHERE owner_scope_id IS NULL
    ''').get();
    var claimableCount = 0;
    var unexpectedCount = 0;
    for (final row in rows) {
      try {
        final derivedScope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          row.read<String>('owner_user_id'),
        );
        if (derivedScope.id.value == expectedScopeValue) {
          claimableCount += 1;
        } else {
          unexpectedCount += 1;
        }
      } on Object {
        unexpectedCount += 1;
      }
    }
    return _LegacySyncQueueInventory(
      claimableCount: claimableCount,
      unexpectedCount: unexpectedCount,
    );
  }

  void _assertCurrentScope(ConfirmedOwnerScope expected) {
    _session.assertActive();
    final current = _currentConfirmedScope();
    if (current == null || current.id != expected.id) {
      throw const OwnerScopeException(OwnerScopeFailure.activeScopeChanged);
    }
  }

  Future<void> _validateLegacyReferences() async {
    final row = await _database.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM transactions t
          LEFT JOIN accounts a ON a.id = t.account_id
          WHERE t.owner_scope_id IS NULL AND a.id IS NULL) +
        (SELECT COUNT(*) FROM transactions t
          LEFT JOIN categories c ON c.id = t.category_id
          WHERE t.owner_scope_id IS NULL AND c.id IS NULL) +
        (SELECT COUNT(*) FROM budgets b
          LEFT JOIN categories c ON c.id = b.category_id
          WHERE b.owner_scope_id IS NULL AND c.id IS NULL) +
        (SELECT COUNT(*) FROM goal_contributions gc
          LEFT JOIN goals g ON g.id = gc.goal_id
          WHERE gc.owner_scope_id IS NULL AND g.id IS NULL) +
        (SELECT COUNT(*) FROM receipt_line_items li
          LEFT JOIN receipts r ON r.id = li.receipt_id
          WHERE li.owner_scope_id IS NULL AND r.id IS NULL) +
        (SELECT COUNT(*) FROM transaction_splits s
          LEFT JOIN receipts r ON r.id = s.receipt_id
          WHERE s.owner_scope_id IS NULL AND r.id IS NULL)
        AS value
    ''').getSingle();
    if (row.read<int>('value') != 0) {
      throw const OwnerScopeException(OwnerScopeFailure.integrityCheckFailed);
    }
  }

  static const Map<String, String> _claimStatements = <String, String>{
    'accounts':
        'UPDATE accounts SET owner_scope_id = ? WHERE owner_scope_id IS NULL',
    'categories':
        'UPDATE categories SET owner_scope_id = ? '
        'WHERE owner_scope_id IS NULL AND is_default = 0',
    'payees':
        'UPDATE payees SET owner_scope_id = ? WHERE owner_scope_id IS NULL',
    'transactions':
        'UPDATE transactions SET owner_scope_id = ? '
        'WHERE owner_scope_id IS NULL',
    'exchange_rates':
        'UPDATE exchange_rates SET owner_scope_id = ? '
        'WHERE owner_scope_id IS NULL',
    'budgets':
        'UPDATE budgets SET owner_scope_id = ? WHERE owner_scope_id IS NULL',
    'goals': 'UPDATE goals SET owner_scope_id = ? WHERE owner_scope_id IS NULL',
    'goal_contributions':
        'UPDATE goal_contributions SET owner_scope_id = ? '
        'WHERE owner_scope_id IS NULL',
    'receipts':
        'UPDATE receipts SET owner_scope_id = ? WHERE owner_scope_id IS NULL',
    'receipt_line_items':
        'UPDATE receipt_line_items SET owner_scope_id = ? '
        'WHERE owner_scope_id IS NULL',
    'transaction_splits':
        'UPDATE transaction_splits SET owner_scope_id = ? '
        'WHERE owner_scope_id IS NULL',
  };

  TableInfo<Table, Object?> _tableForSql(String sql) {
    if (sql.startsWith('UPDATE accounts ')) return _database.accounts;
    if (sql.startsWith('UPDATE categories ')) return _database.categories;
    if (sql.startsWith('UPDATE payees ')) return _database.payees;
    if (sql.startsWith('UPDATE transactions ')) return _database.transactions;
    if (sql.startsWith('UPDATE exchange_rates ')) {
      return _database.exchangeRates;
    }
    if (sql.startsWith('UPDATE budgets ')) return _database.budgets;
    if (sql.startsWith('UPDATE goals ')) return _database.goals;
    if (sql.startsWith('UPDATE goal_contributions ')) {
      return _database.goalContributions;
    }
    if (sql.startsWith('UPDATE receipts ')) return _database.receipts;
    if (sql.startsWith('UPDATE receipt_line_items ')) {
      return _database.receiptLineItems;
    }
    if (sql.startsWith('UPDATE transaction_splits ')) {
      return _database.transactionSplits;
    }
    return _database.syncQueue;
  }
}

final class _LegacySyncQueueInventory {
  const _LegacySyncQueueInventory({
    required this.claimableCount,
    required this.unexpectedCount,
  });

  final int claimableCount;
  final int unexpectedCount;
}
