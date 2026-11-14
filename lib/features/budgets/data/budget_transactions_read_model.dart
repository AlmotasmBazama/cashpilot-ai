import 'package:drift/drift.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/domain/enums/transaction_status.dart';
import '../../transactions/domain/enums/transaction_type.dart';
import '../../transactions/transaction_row_domain_mapper.dart';
import '../domain/entities/budget.dart';
import '../domain/services/budget_period_resolver.dart';

final class BudgetTransactionWindow {
  const BudgetTransactionWindow({
    required this.categoryId,
    required this.start,
    required this.end,
  });

  final String categoryId;
  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetTransactionWindow &&
          other.categoryId == categoryId &&
          other.start == start &&
          other.end == end;

  @override
  int get hashCode => Object.hash(categoryId, start, end);
}

/// A stable Riverpod family key containing the minimal union of budget
/// category/time windows needed for the current progress calculation.
final class BudgetTransactionWindowRequest {
  BudgetTransactionWindowRequest(Iterable<BudgetTransactionWindow> windows)
    : windows = List<BudgetTransactionWindow>.unmodifiable(
        _mergeWindows(windows),
      );

  factory BudgetTransactionWindowRequest.fromBudgets({
    required Iterable<Budget> budgets,
    required DateTime now,
    BudgetPeriodResolver periodResolver = const BudgetPeriodResolver(),
  }) {
    return BudgetTransactionWindowRequest(
      budgets.map((budget) {
        final period = periodResolver.resolve(budget, now);
        return BudgetTransactionWindow(
          categoryId: budget.categoryId,
          start: period.start.toUtc(),
          end: period.end.toUtc(),
        );
      }),
    );
  }

  final List<BudgetTransactionWindow> windows;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BudgetTransactionWindowRequest ||
        other.windows.length != windows.length) {
      return false;
    }
    for (var index = 0; index < windows.length; index++) {
      if (windows[index] != other.windows[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(windows);

  static List<BudgetTransactionWindow> _mergeWindows(
    Iterable<BudgetTransactionWindow> source,
  ) {
    final sorted =
        source
            .map(
              (window) => BudgetTransactionWindow(
                categoryId: window.categoryId,
                start: window.start.toUtc(),
                end: window.end.toUtc(),
              ),
            )
            .where((window) => window.start.isBefore(window.end))
            .toList()
          ..sort((a, b) {
            final category = a.categoryId.compareTo(b.categoryId);
            return category != 0 ? category : a.start.compareTo(b.start);
          });
    final merged = <BudgetTransactionWindow>[];
    for (final window in sorted) {
      if (merged.isEmpty) {
        merged.add(window);
        continue;
      }
      final previous = merged.last;
      if (previous.categoryId == window.categoryId &&
          !window.start.isAfter(previous.end)) {
        merged[merged.length - 1] = BudgetTransactionWindow(
          categoryId: previous.categoryId,
          start: previous.start,
          end: window.end.isAfter(previous.end) ? window.end : previous.end,
        );
      } else {
        merged.add(window);
      }
    }
    return merged;
  }
}

/// Loads only posted expenses that can contribute to at least one requested
/// budget period. Decimal summation and exchange-rate handling remain in the
/// existing domain calculator, so this optimization changes row breadth only.
final class BudgetTransactionsReadModel {
  const BudgetTransactionsReadModel(this._session, this._transactionMapper);

  final ScopedAppDatabaseSession _session;
  final TransactionRowDomainMapper _transactionMapper;

  Stream<AppResult<List<Transaction>>> watch(
    BudgetTransactionWindowRequest request,
  ) async* {
    if (request.windows.isEmpty) {
      yield const AppResult.success(<Transaction>[]);
      return;
    }

    try {
      final database = _session.database;
      final scope = _session.ownerScopeValue;
      final variables = <Variable<Object>>[
        Variable<String>(scope),
        Variable<String>(TransactionType.expense.storageValue),
        Variable<String>(TransactionStatus.posted.storageValue),
      ];
      final windowClauses = <String>[];
      for (final window in request.windows) {
        windowClauses.add(
          '(category_id = ? AND transaction_date >= ? '
          'AND transaction_date < ?)',
        );
        variables.addAll(<Variable<Object>>[
          Variable<String>(window.categoryId),
          Variable<DateTime>(window.start),
          Variable<DateTime>(window.end),
        ]);
      }
      final select = database.customSelect(
        '''
          SELECT transactions.*
          FROM transactions
          WHERE owner_scope_id = ?
            AND type = ?
            AND status = ?
            AND (${windowClauses.join('\nOR ')})
          ORDER BY transaction_date DESC, created_at DESC, id DESC
        ''',
        variables: variables,
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.transactions,
        },
      );

      await for (final rows in _session.guardStream(select.watch())) {
        yield AppResult.success(
          rows
              .map(
                (row) =>
                    _transactionMapper.map(database.transactions.map(row.data)),
              )
              .toList(growable: false),
        );
      }
    } on Object {
      yield const AppResult.failure(
        Failure(message: 'Unable to load budget transactions.'),
      );
    }
  }
}
