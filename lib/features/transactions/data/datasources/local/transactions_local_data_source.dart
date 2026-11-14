import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../domain/enums/transaction_status.dart';
import '../../../domain/enums/transaction_type.dart';
import '../../dtos/transaction_dto.dart';
import '../../mappers/transaction_mapper.dart';

abstract interface class TransactionsLocalDataSource {
  String get ownerScopeValue;

  Future<T> runInTransaction<T>(Future<T> Function() operation);

  Future<TransactionDto> createTransaction(TransactionDto transaction);

  Future<TransferPairDtos> createTransferPair({
    required TransactionDto outgoing,
    required TransactionDto incoming,
    required String payloadFingerprint,
  });

  Future<TransferPairDtos> updateTransferPair({
    required TransactionDto outgoing,
    required TransactionDto incoming,
  });

  Future<void> deleteTransferPair({
    required String transferGroupId,
    required String outgoingTransactionId,
    required String incomingTransactionId,
  });

  Future<TransactionDto> updateTransaction(TransactionDto transaction);

  Future<void> deleteTransaction(String id);

  Future<TransactionDto?> getTransaction(String id);

  Future<ScopedAccountBalanceSnapshot?> getAccountBalanceSnapshot(String id);

  Future<TransferGroupIntegrity> inspectTransferGroup(String transferGroupId);

  Future<List<StoredTransferRecord>> getStoredTransferGroup(
    String transferGroupId,
  );

  Future<List<TransactionDto>> getTransactions({
    String? accountId,
    String? categoryId,
    String? payeeId,
    String? transferGroupId,
    TransactionStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<List<TransactionDto>> searchTransactions(
    String query, {
    int? limit,
    Set<TransactionType>? transactionTypes,
    TransactionStatus? status,
  });
}

class DriftTransactionsLocalDataSource implements TransactionsLocalDataSource {
  const DriftTransactionsLocalDataSource(this._session);

  final ScopedAppDatabaseSession _session;
  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  String get ownerScopeValue => _scope;

  @override
  Future<TransactionDto> createTransaction(TransactionDto transaction) async {
    return _session.runGuardedWrite(() async {
      await _database
          .into(_database.transactions)
          .insert(
            transaction.toCompanion().copyWith(ownerScopeId: Value(_scope)),
          );
      return transaction;
    });
  }

  @override
  Future<TransferPairDtos> createTransferPair({
    required TransactionDto outgoing,
    required TransactionDto incoming,
    required String payloadFingerprint,
  }) {
    return _session.runGuardedWrite(
      () => _database.transaction(() async {
        await _database.insertTransferPair(
          ownerScopeId: _scope,
          outgoing: outgoing.toCompanion().copyWith(
            ownerScopeId: Value(_scope),
            transferPayloadFingerprint: Value(payloadFingerprint),
          ),
          incoming: incoming.toCompanion().copyWith(
            ownerScopeId: Value(_scope),
            transferPayloadFingerprint: Value(payloadFingerprint),
          ),
          payloadFingerprint: payloadFingerprint,
        );
        return TransferPairDtos(outgoing: outgoing, incoming: incoming);
      }),
    );
  }

  @override
  Future<TransferPairDtos> updateTransferPair({
    required TransactionDto outgoing,
    required TransactionDto incoming,
  }) {
    final groupId = outgoing.transferGroupId;
    if (groupId == null || groupId != incoming.transferGroupId) {
      throw StateError('A canonical transfer pair is required.');
    }
    return _session.runGuardedWrite(
      () => _database.transaction(() async {
        await _database.updateTransferPair(
          ownerScopeId: _scope,
          transferGroupId: groupId,
          outgoingTransactionId: outgoing.id,
          incomingTransactionId: incoming.id,
          targetStatus: outgoing.status,
          outgoing: outgoing.toCompanion().copyWith(
            ownerScopeId: Value(_scope),
            transferPayloadFingerprint: const Value.absent(),
          ),
          incoming: incoming.toCompanion().copyWith(
            ownerScopeId: Value(_scope),
            transferPayloadFingerprint: const Value.absent(),
          ),
        );
        return TransferPairDtos(outgoing: outgoing, incoming: incoming);
      }),
    );
  }

  @override
  Future<void> deleteTransferPair({
    required String transferGroupId,
    required String outgoingTransactionId,
    required String incomingTransactionId,
  }) {
    return _session.runGuardedWrite(
      () => _database.deleteTransferPair(
        ownerScopeId: _scope,
        transferGroupId: transferGroupId,
        outgoingTransactionId: outgoingTransactionId,
        incomingTransactionId: incomingTransactionId,
      ),
    );
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final deletedRows = await _session.runGuardedWrite(
      () =>
          (_database.delete(_database.transactions)..where(
                (row) => row.ownerScopeId.equals(_scope) & row.id.equals(id),
              ))
              .go(),
    );

    if (deletedRows == 0) {
      throw AppException.cache(
        message: 'Transaction not found for deletion.',
        code: 'transaction_not_found',
      );
    }
  }

  @override
  Future<TransactionDto?> getTransaction(String id) async {
    final row =
        await (_database.select(_database.transactions)..where(
              (transaction) =>
                  transaction.ownerScopeId.equals(_scope) &
                  transaction.id.equals(id),
            ))
            .getSingleOrNull();

    return row?.toDto();
  }

  @override
  Future<ScopedAccountBalanceSnapshot?> getAccountBalanceSnapshot(
    String id,
  ) async {
    final row =
        await (_database.select(_database.accounts)..where(
              (account) =>
                  account.ownerScopeId.equals(_scope) & account.id.equals(id),
            ))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return ScopedAccountBalanceSnapshot(
      balance: row.balance,
      currencyCode: row.currencyCode,
      isArchived: row.isArchived,
    );
  }

  @override
  Future<TransferGroupIntegrity> inspectTransferGroup(
    String transferGroupId,
  ) async {
    final rows = await _database
        .customSelect(
          '''SELECT owner_scope_id, type, COUNT(*) AS row_count
             FROM transactions
             WHERE transfer_group_id = ?
             GROUP BY owner_scope_id, type''',
          variables: <Variable<Object>>[Variable<String>(transferGroupId)],
          readsFrom: <ResultSetImplementation<Table, Object?>>{
            _database.transactions,
          },
        )
        .get();
    if (rows.isEmpty) {
      return TransferGroupIntegrity.absent;
    }
    if (rows.any(
      (row) => row.readNullable<String>('owner_scope_id') != _scope,
    )) {
      return TransferGroupIntegrity.crossScopeCollision;
    }
    var outgoing = 0;
    var incoming = 0;
    var other = 0;
    for (final row in rows) {
      final count = row.read<int>('row_count');
      switch (row.read<String>('type')) {
        case 'transferOut':
          outgoing += count;
        case 'transferIn':
          incoming += count;
        default:
          other += count;
      }
    }
    return outgoing == 1 && incoming == 1 && other == 0
        ? TransferGroupIntegrity.scopedPair
        : TransferGroupIntegrity.scopedMalformed;
  }

  @override
  Future<List<StoredTransferRecord>> getStoredTransferGroup(
    String transferGroupId,
  ) async {
    final rows =
        await (_database.select(_database.transactions)..where(
              (transaction) =>
                  transaction.ownerScopeId.equals(_scope) &
                  transaction.transferGroupId.equals(transferGroupId),
            ))
            .get();
    return rows
        .map(
          (row) => StoredTransferRecord(
            transaction: row.toDto(),
            payloadFingerprint: row.transferPayloadFingerprint,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<TransactionDto>> getTransactions({
    String? accountId,
    String? categoryId,
    String? payeeId,
    String? transferGroupId,
    TransactionStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = _database.select(_database.transactions);
    query.where((transaction) => transaction.ownerScopeId.equals(_scope));

    if (accountId != null) {
      query.where((transaction) => transaction.accountId.equals(accountId));
    }

    if (categoryId != null) {
      query.where((transaction) => transaction.categoryId.equals(categoryId));
    }

    if (payeeId != null) {
      query.where((transaction) => transaction.payeeId.equals(payeeId));
    }

    if (transferGroupId != null) {
      query.where(
        (transaction) => transaction.transferGroupId.equals(transferGroupId),
      );
    }

    if (status != null) {
      query.where(
        (transaction) => transaction.status.equals(status.storageValue),
      );
    }

    if (fromDate != null) {
      query.where(
        (transaction) =>
            transaction.transactionDate.isBiggerOrEqualValue(fromDate),
      );
    }

    if (toDate != null) {
      query.where(
        (transaction) =>
            transaction.transactionDate.isSmallerOrEqualValue(toDate),
      );
    }

    _orderTransactions(query);
    final rows = await query.get();
    return rows.map((row) => row.toDto()).toList(growable: false);
  }

  @override
  Future<T> runInTransaction<T>(Future<T> Function() operation) {
    return _session.runGuardedWrite(() => _database.transaction(operation));
  }

  @override
  Future<List<TransactionDto>> searchTransactions(
    String query, {
    int? limit,
    Set<TransactionType>? transactionTypes,
    TransactionStatus? status,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (limit != null && limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive.');
    }
    final escaped = normalizedQuery
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';
    final select = _database.select(_database.transactions)
      ..where((transaction) {
        Expression<bool> predicate = transaction.ownerScopeId.equals(_scope);
        if (normalizedQuery.isNotEmpty) {
          predicate =
              predicate &
              (transaction.note.lower().like(pattern, escapeChar: r'\') |
                  transaction.location.lower().like(pattern, escapeChar: r'\') |
                  transaction.payeeId.lower().like(pattern, escapeChar: r'\') |
                  transaction.currencyCode.lower().like(
                    pattern,
                    escapeChar: r'\',
                  ));
        }
        if (transactionTypes != null && transactionTypes.isNotEmpty) {
          predicate =
              predicate &
              transaction.type.isIn(
                transactionTypes.map((type) => type.storageValue),
              );
        }
        if (status != null) {
          predicate =
              predicate & transaction.status.equals(status.storageValue);
        }
        return predicate;
      });
    _orderTransactions(select);
    if (limit != null) {
      select.limit(limit);
    }
    final rows = await select.get();
    return rows.map((row) => row.toDto()).toList(growable: false);
  }

  @override
  Future<TransactionDto> updateTransaction(TransactionDto transaction) async {
    final updatedRows = await _session.runGuardedWrite(
      () =>
          (_database.update(_database.transactions)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.id.equals(transaction.id),
              ))
              .write(
                transaction.toCompanion().copyWith(ownerScopeId: Value(_scope)),
              ),
    );

    if (updatedRows == 0) {
      throw AppException.cache(
        message: 'Transaction not found for update.',
        code: 'transaction_not_found',
      );
    }

    return transaction;
  }

  void _orderTransactions(
    SimpleSelectStatement<$TransactionsTable, TransactionRow> query,
  ) {
    query.orderBy([
      (transaction) => OrderingTerm(
        expression: transaction.transactionDate,
        mode: OrderingMode.desc,
      ),
      (transaction) => OrderingTerm(
        expression: transaction.createdAt,
        mode: OrderingMode.desc,
      ),
    ]);
  }
}

final class TransferPairDtos {
  const TransferPairDtos({required this.outgoing, required this.incoming});

  final TransactionDto outgoing;
  final TransactionDto incoming;
}

final class ScopedAccountBalanceSnapshot {
  const ScopedAccountBalanceSnapshot({
    required this.balance,
    required this.currencyCode,
    required this.isArchived,
  });

  final String balance;
  final String currencyCode;
  final bool isArchived;
}

enum TransferGroupIntegrity {
  absent,
  scopedPair,
  scopedMalformed,
  crossScopeCollision,
}

final class StoredTransferRecord {
  const StoredTransferRecord({
    required this.transaction,
    required this.payloadFingerprint,
  });

  final TransactionDto transaction;
  final String? payloadFingerprint;
}
