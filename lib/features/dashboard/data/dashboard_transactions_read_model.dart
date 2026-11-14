import 'dart:collection';

import 'package:drift/drift.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/transaction_row_domain_mapper.dart';

/// A bounded, owner-scoped read model for dashboard and report calculations.
///
/// It loads the reporting window plus a small recent tail. Historical rows
/// outside both sets stay in SQLite instead of being mapped into Dart merely
/// for [DashboardSnapshot] to discard them.
final class DashboardTransactionsReadModel {
  const DashboardTransactionsReadModel(this._session, this._transactionMapper);

  final ScopedAppDatabaseSession _session;
  final TransactionRowDomainMapper _transactionMapper;

  Stream<AppResult<List<Transaction>>> watch({
    required DateTime reportingWindowStart,
    int recentLimit = 5,
  }) async* {
    if (recentLimit <= 0) {
      throw ArgumentError.value(
        recentLimit,
        'recentLimit',
        'Must be positive.',
      );
    }
    try {
      final database = _session.database;
      final scope = _session.ownerScopeValue;
      final query = database.customSelect(
        '''
          SELECT transactions.*,
            (
              SELECT COUNT(*)
              FROM transactions AS scoped_count
              WHERE scoped_count.owner_scope_id = ?
            ) AS total_transaction_count
          FROM transactions
          WHERE owner_scope_id = ?
            AND (
              transaction_date >= ?
              OR id IN (
                SELECT id
                FROM transactions
                WHERE owner_scope_id = ?
                ORDER BY transaction_date DESC, created_at DESC
                LIMIT ?
              )
            )
          ORDER BY transaction_date DESC, created_at DESC
        ''',
        variables: <Variable<Object>>[
          Variable<String>(scope),
          Variable<String>(scope),
          Variable<DateTime>(reportingWindowStart.toUtc()),
          Variable<String>(scope),
          Variable<int>(recentLimit),
        ],
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.transactions,
        },
      );
      await for (final rows in _session.guardStream(query.watch())) {
        final totalTransactionCount = rows.isEmpty
            ? 0
            : rows.first.read<int>('total_transaction_count');
        yield AppResult.success(
          DashboardTransactionWindow(
            rows.map(
              (row) =>
                  _transactionMapper.map(database.transactions.map(row.data)),
            ),
            totalTransactionCount: totalTransactionCount,
          ),
        );
      }
    } on Object {
      yield const AppResult.failure(
        Failure(message: 'Unable to load dashboard transactions.'),
      );
    }
  }
}

/// A bounded transaction list with its exact owner-scoped SQL count attached.
///
/// It remains a [List<Transaction>] so existing provider overrides and
/// full-list callers preserve their public contract and length fallback.
final class DashboardTransactionWindow extends ListBase<Transaction> {
  DashboardTransactionWindow(
    Iterable<Transaction> transactions, {
    required this.totalTransactionCount,
  }) : _transactions = List<Transaction>.unmodifiable(transactions),
       assert(totalTransactionCount >= 0);

  final List<Transaction> _transactions;
  final int totalTransactionCount;

  @override
  int get length => _transactions.length;

  @override
  set length(int value) => throw UnsupportedError('Unmodifiable list');

  @override
  Transaction operator [](int index) => _transactions[index];

  @override
  void operator []=(int index, Transaction value) {
    throw UnsupportedError('Unmodifiable list');
  }
}

DateTime dashboardReportingWindowStart(DateTime now) {
  final localNow = now.toLocal();
  final currentYearStart = DateTime(localNow.year);
  final sixMonthTrendStart = DateTime(localNow.year, localNow.month - 5);
  final localStart = currentYearStart.isBefore(sixMonthTrendStart)
      ? currentYearStart
      : sixMonthTrendStart;
  return localStart.toUtc();
}
