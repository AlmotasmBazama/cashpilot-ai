import 'package:drift/drift.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../domain/entities/transaction_history_page.dart';
import '../domain/enums/transaction_status.dart';
import '../domain/enums/transaction_type.dart';
import 'mappers/transaction_mapper.dart';

/// Owner-scoped, live transaction history with a bounded growing window.
///
/// Search, type/status filters, and the selected global order are applied by
/// SQLite before [TransactionHistoryRequest.limit]. Increasing that limit is
/// therefore a deterministic load-more operation, while inserts and refreshes
/// rebuild the same prefix without offset drift or duplicate rows.
final class TransactionHistoryReadModel {
  const TransactionHistoryReadModel(this._session);

  final ScopedAppDatabaseSession _session;

  Stream<AppResult<TransactionHistoryPage>> watch(
    TransactionHistoryRequest request,
  ) async* {
    if (request.limit <= 0) {
      throw ArgumentError.value(request.limit, 'limit', 'Must be positive.');
    }

    try {
      final database = _session.database;
      final scope = _session.ownerScopeValue;
      final conditions = <String>['owner_scope_id = ?'];
      final variables = <Variable<Object>>[Variable<String>(scope)];
      final query = request.query.trim().toLowerCase();
      if (query.isNotEmpty) {
        final escaped = query
            .replaceAll(r'\', r'\\')
            .replaceAll('%', r'\%')
            .replaceAll('_', r'\_');
        final pattern = '%$escaped%';
        conditions.add('''(
          lower(coalesce(note, '')) LIKE ? ESCAPE char(92)
          OR lower(coalesce(location, '')) LIKE ? ESCAPE char(92)
          OR lower(coalesce(payee_id, '')) LIKE ? ESCAPE char(92)
          OR lower(currency_code) LIKE ? ESCAPE char(92)
        )''');
        variables.addAll(<Variable<Object>>[
          Variable<String>(pattern),
          Variable<String>(pattern),
          Variable<String>(pattern),
          Variable<String>(pattern),
        ]);
      }

      final types = _typesFor(request.filter);
      if (types != null) {
        conditions.add(
          'type IN (${List<String>.filled(types.length, '?').join(', ')})',
        );
        variables.addAll(
          types.map<Variable<Object>>(
            (type) => Variable<String>(type.storageValue),
          ),
        );
      }
      if (request.filter == TransactionHistoryFilter.pending) {
        conditions.add('status = ?');
        variables.add(Variable<String>(TransactionStatus.pending.storageValue));
      }

      variables.add(Variable<int>(request.limit));
      final select = database.customSelect(
        '''
          SELECT transactions.*, COUNT(*) OVER () AS total_count
          FROM transactions
          WHERE ${conditions.join('\nAND ')}
          ORDER BY ${_orderBy(request.sort)}
          LIMIT ?
        ''',
        variables: variables,
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.transactions,
        },
      );

      await for (final rows in _session.guardStream(select.watch())) {
        final totalCount = rows.isEmpty
            ? 0
            : rows.first.read<int>('total_count');
        yield AppResult.success(
          TransactionHistoryPage(
            transactions: rows.map(
              (row) => database.transactions.map(row.data).toDto().toDomain(),
            ),
            totalCount: totalCount,
          ),
        );
      }
    } on Object {
      yield const AppResult.failure(
        Failure(message: 'Unable to load transaction history.'),
      );
    }
  }

  Set<TransactionType>? _typesFor(TransactionHistoryFilter filter) {
    return switch (filter) {
      TransactionHistoryFilter.income => const <TransactionType>{
        TransactionType.income,
      },
      TransactionHistoryFilter.expense => const <TransactionType>{
        TransactionType.expense,
      },
      TransactionHistoryFilter.transfer => const <TransactionType>{
        TransactionType.transferIn,
        TransactionType.transferOut,
      },
      TransactionHistoryFilter.all || TransactionHistoryFilter.pending => null,
    };
  }

  String _orderBy(TransactionHistorySort sort) {
    return switch (sort) {
      TransactionHistorySort.newest =>
        'transaction_date DESC, created_at DESC, id DESC',
      TransactionHistorySort.oldest =>
        'transaction_date ASC, created_at ASC, id ASC',
      // Amounts are persisted as canonical positive Decimal strings. Compare
      // integer digit count, integer digits, then fractional digits so global
      // ordering remains exact without converting financial values to double.
      TransactionHistorySort.amountHigh =>
        '''
        length(
          ltrim(
            CASE
              WHEN instr(amount, '.') = 0 THEN amount
              ELSE substr(amount, 1, instr(amount, '.') - 1)
            END,
            '0'
          )
        ) DESC,
        ltrim(
          CASE
            WHEN instr(amount, '.') = 0 THEN amount
            ELSE substr(amount, 1, instr(amount, '.') - 1)
          END,
          '0'
        ) COLLATE BINARY DESC,
        CASE
          WHEN instr(amount, '.') = 0 THEN ''
          ELSE rtrim(substr(amount, instr(amount, '.') + 1), '0')
        END COLLATE BINARY DESC,
        transaction_date DESC,
        created_at DESC,
        id DESC
      ''',
    };
  }
}
