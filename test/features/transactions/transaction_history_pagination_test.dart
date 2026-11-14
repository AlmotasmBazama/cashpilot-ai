import 'dart:async';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/transactions/data/datasources/local/transactions_local_data_source.dart';
import 'package:cashpilot_ai/features/transactions/data/mappers/transaction_mapper.dart';
import 'package:cashpilot_ai/features/transactions/data/transaction_history_read_model.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction_history_page.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;
  late String ownerScope;
  late DriftTransactionsLocalDataSource fullHistorySource;
  late TransactionHistoryReadModel readModel;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    final session = scopedTestSession(database);
    ownerScope = session.ownerScopeValue;
    fullHistorySource = DriftTransactionsLocalDataSource(session);
    readModel = TransactionHistoryReadModel(session);
  });

  tearDown(() => database.close());

  test('history loads stable growing prefixes without duplicates', () async {
    await _seedTransactions(
      database,
      ownerScope: ownerScope,
      prefix: 'owner',
      count: 125,
      start: DateTime.utc(2026, 1, 1),
    );
    await _seedTransactions(
      database,
      ownerScope: 'another-owner',
      prefix: 'other',
      count: 10,
      start: DateTime.utc(2027, 1, 1),
    );

    final first = await _load(readModel, limit: 50);
    final second = await _load(readModel, limit: 100);
    final complete = await _load(readModel, limit: 150);
    final oldest = _expectPage(
      await readModel.watch((
        query: '',
        filter: TransactionHistoryFilter.all,
        sort: TransactionHistorySort.oldest,
        limit: 2,
      )).first,
    );

    expect(first.transactions, hasLength(50));
    expect(first.totalCount, 125);
    expect(first.hasMore, isTrue);
    expect(second.transactions, hasLength(100));
    expect(
      second.transactions.take(50).map((transaction) => transaction.id),
      first.transactions.map((transaction) => transaction.id),
    );
    expect(
      second.transactions.map((transaction) => transaction.id).toSet(),
      hasLength(100),
    );
    expect(complete.transactions, hasLength(125));
    expect(complete.hasMore, isFalse);
    expect(complete.transactions.first.id, 'owner-124');
    expect(complete.transactions.last.id, 'owner-0');
    expect(oldest.transactions.map((transaction) => transaction.id), <String>[
      'owner-0',
      'owner-1',
    ]);
    expect(
      complete.transactions.every(
        (transaction) => !transaction.id.startsWith('other-'),
      ),
      isTrue,
    );
  });

  test(
    '275-row history keeps pagination search filter and global sort complete',
    () async {
      await _seedTransactions(
        database,
        ownerScope: ownerScope,
        prefix: 'bulk',
        count: 272,
        start: DateTime.utc(2026, 1, 1),
      );
      for (final id in <String>['equal-date-a', 'equal-date-b']) {
        await _insertTransaction(
          database,
          ownerScope: ownerScope,
          id: id,
          at: DateTime.utc(2028, 1, 1),
          amount: '1',
        );
      }
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'late-page-target',
        at: DateTime.utc(2020, 1, 1),
        amount: '9999',
        type: 'income',
        status: 'pending',
        payeeId: 'later-page-marker',
      );

      final first = await _load(readModel, limit: 50);
      final fifth = await _load(readModel, limit: 250);
      final complete = await _load(readModel, limit: 300);

      expect(first.totalCount, 275);
      expect(first.transactions, hasLength(50));
      expect(
        first.transactions.take(2).map((transaction) => transaction.id),
        <String>['equal-date-b', 'equal-date-a'],
      );
      expect(fifth.transactions, hasLength(250));
      expect(complete.transactions, hasLength(275));
      expect(complete.hasMore, isFalse);
      expect(
        fifth.transactions.take(50).map((transaction) => transaction.id),
        first.transactions.map((transaction) => transaction.id),
      );
      expect(
        complete.transactions.map((transaction) => transaction.id).toSet(),
        hasLength(275),
      );

      final searched = _expectPage(
        await readModel.watch((
          query: 'later-page-marker',
          filter: TransactionHistoryFilter.income,
          sort: TransactionHistorySort.newest,
          limit: 50,
        )).first,
      );
      expect(searched.totalCount, 1);
      expect(searched.transactions.single.id, 'late-page-target');

      final amountSorted = _expectPage(
        await readModel.watch((
          query: '',
          filter: TransactionHistoryFilter.all,
          sort: TransactionHistorySort.amountHigh,
          limit: 1,
        )).first,
      );
      expect(amountSorted.totalCount, 275);
      expect(amountSorted.transactions.single.id, 'late-page-target');
    },
  );

  test('search and filters precede globally exact amount pagination', () async {
    await _seedTransactions(
      database,
      ownerScope: ownerScope,
      prefix: 'newer-non-match',
      count: 80,
      start: DateTime.utc(2027, 1, 1),
      note: 'not a match',
    );
    for (final entry in <({String id, String amount})>[
      (id: 'target-low', amount: '2'),
      (id: 'target-high', amount: '100.0000000000000000001'),
      (id: 'target-middle', amount: '10.9'),
    ]) {
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: entry.id,
        at: DateTime.utc(2020, 1, 1),
        amount: entry.amount,
        type: 'income',
        status: 'pending',
        payeeId: 'merchant-42',
      );
    }

    final page = _expectPage(
      await readModel.watch((
        query: 'merchant-42',
        filter: TransactionHistoryFilter.income,
        sort: TransactionHistorySort.amountHigh,
        limit: 2,
      )).first,
    );

    expect(page.totalCount, 3);
    expect(page.hasMore, isTrue);
    expect(page.transactions.map((transaction) => transaction.id), <String>[
      'target-high',
      'target-middle',
    ]);

    final pending = _expectPage(
      await readModel.watch((
        query: r'%',
        filter: TransactionHistoryFilter.pending,
        sort: TransactionHistorySort.newest,
        limit: 50,
      )).first,
    );
    expect(pending.transactions, isEmpty);
  });

  test('live insert refreshes the bounded prefix and exact total', () async {
    await _seedTransactions(
      database,
      ownerScope: ownerScope,
      prefix: 'initial',
      count: 3,
      start: DateTime.utc(2026, 1, 1),
    );
    final iterator = StreamIterator(
      readModel.watch((
        query: '',
        filter: TransactionHistoryFilter.all,
        sort: TransactionHistorySort.newest,
        limit: 2,
      )),
    );
    addTearDown(iterator.cancel);

    expect(await iterator.moveNext(), isTrue);
    final initial = _expectPage(iterator.current);
    expect(initial.totalCount, 3);
    expect(initial.transactions.map((transaction) => transaction.id), <String>[
      'initial-2',
      'initial-1',
    ]);

    await _insertTransaction(
      database,
      ownerScope: ownerScope,
      id: 'inserted',
      at: DateTime.utc(2026, 2, 1),
      amount: '5',
    );
    expect(await iterator.moveNext(), isTrue);
    final updated = _expectPage(iterator.current);
    expect(updated.totalCount, 4);
    expect(updated.transactions.map((transaction) => transaction.id), <String>[
      'inserted',
      'initial-2',
    ]);
    expect(
      updated.transactions.map((transaction) => transaction.id).toSet(),
      hasLength(updated.transactions.length),
    );
  });

  test('bounded history maps 50 rows instead of full long history', () async {
    await _seedTransactions(
      database,
      ownerScope: ownerScope,
      prefix: 'long-history',
      count: 10000,
      start: DateTime.utc(2020, 1, 1),
    );

    Future<int> loadFullHistory() async {
      final rows = await fullHistorySource.getTransactions();
      return rows.map((row) => row.toDomain()).toList(growable: false).length;
    }

    Future<TransactionHistoryPage> loadBounded() => _load(readModel, limit: 50);

    await loadFullHistory();
    await loadBounded();
    const repeatCount = 5;
    final beforeSamples = <int>[];
    final afterSamples = <int>[];
    var beforeRows = 0;
    var afterRows = 0;
    for (var repeat = 0; repeat < repeatCount; repeat++) {
      var stopwatch = Stopwatch()..start();
      beforeRows = await loadFullHistory();
      stopwatch.stop();
      beforeSamples.add(stopwatch.elapsedMicroseconds);

      stopwatch = Stopwatch()..start();
      afterRows = (await loadBounded()).transactions.length;
      stopwatch.stop();
      afterSamples.add(stopwatch.elapsedMicroseconds);
    }

    expect(beforeRows, 10000);
    expect(afterRows, 50);
    // ignore: avoid_print
    print(
      'transaction_pagination_measurement: method=NativeDatabase.memory '
      'warmup=1 repeats=$repeatCount before_rows=$beforeRows '
      'after_rows=$afterRows before_samples_us=$beforeSamples '
      'after_samples_us=$afterSamples before_median_us=${_median(beforeSamples)} '
      'after_median_us=${_median(afterSamples)}',
    );
  });
}

Future<TransactionHistoryPage> _load(
  TransactionHistoryReadModel readModel, {
  required int limit,
}) async {
  return _expectPage(
    await readModel.watch((
      query: '',
      filter: TransactionHistoryFilter.all,
      sort: TransactionHistorySort.newest,
      limit: limit,
    )).first,
  );
}

TransactionHistoryPage _expectPage(AppResult<TransactionHistoryPage> result) =>
    (result as AppSuccess<TransactionHistoryPage>).data;

int _median(List<int> values) {
  final sorted = values.toList()..sort();
  return sorted[sorted.length ~/ 2];
}

Future<void> _seedTransactions(
  AppDatabase database, {
  required String ownerScope,
  required String prefix,
  required int count,
  required DateTime start,
  String? note,
}) {
  return database.batch((batch) {
    for (var index = 0; index < count; index++) {
      final at = start.add(Duration(minutes: index));
      batch.insert(
        database.transactions,
        _companion(
          ownerScope: ownerScope,
          id: '$prefix-$index',
          at: at,
          amount: '${index + 1}',
          note: note,
        ),
      );
    }
  });
}

Future<void> _insertTransaction(
  AppDatabase database, {
  required String ownerScope,
  required String id,
  required DateTime at,
  required String amount,
  String type = 'expense',
  String status = 'posted',
  String? payeeId,
}) {
  return database
      .into(database.transactions)
      .insert(
        _companion(
          ownerScope: ownerScope,
          id: id,
          at: at,
          amount: amount,
          type: type,
          status: status,
          payeeId: payeeId,
        ),
      );
}

TransactionsCompanion _companion({
  required String ownerScope,
  required String id,
  required DateTime at,
  required String amount,
  String type = 'expense',
  String status = 'posted',
  String? note,
  String? payeeId,
}) {
  return TransactionsCompanion(
    id: Value(id),
    ownerScopeId: Value(ownerScope),
    accountId: const Value('account'),
    categoryId: const Value('category'),
    payeeId: Value(payeeId),
    amount: Value(amount),
    currencyCode: const Value('LYD'),
    type: Value(type),
    paymentMethod: const Value('cash'),
    source: const Value('manual'),
    status: Value(status),
    note: Value(note),
    transactionDate: Value(at),
    createdAt: Value(at),
    updatedAt: Value(at),
  );
}
