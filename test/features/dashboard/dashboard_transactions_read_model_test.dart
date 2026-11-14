import 'dart:async';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/dashboard/application/dashboard_providers.dart';
import 'package:cashpilot_ai/features/dashboard/data/dashboard_transactions_read_model.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/transactions/data/datasources/local/transactions_local_data_source.dart';
import 'package:cashpilot_ai/features/transactions/data/mappers/transaction_mapper.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;
  late String ownerScope;
  late DriftTransactionsLocalDataSource legacyFullHistorySource;
  late DashboardTransactionsReadModel readModel;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    final session = scopedTestSession(database);
    ownerScope = session.ownerScopeValue;
    legacyFullHistorySource = DriftTransactionsLocalDataSource(session);
    readModel = DashboardTransactionsReadModel(
      session,
      const DriftTransactionRowDomainMapper(),
    );
  });

  tearDown(() => database.close());

  test(
    'dashboard read model maps only the reporting window from long history',
    () async {
      final reportingStart = DateTime.utc(2026, 1, 1);
      await _seedTransactions(
        database,
        ownerScope: ownerScope,
        prefix: 'historical',
        count: 10000,
        start: DateTime.utc(2020, 1, 1),
      );
      await _seedTransactions(
        database,
        ownerScope: ownerScope,
        prefix: 'current',
        count: 20,
        start: reportingStart,
      );
      await _seedTransactions(
        database,
        ownerScope: 'another-owner',
        prefix: 'another-owner',
        count: 3,
        start: reportingStart,
      );

      Future<int> loadFullHistory() async {
        final rows = await legacyFullHistorySource.getTransactions();
        return rows.map((row) => row.toDomain()).toList(growable: false).length;
      }

      Future<({int mappedCount, int totalCount})> loadBoundedWindow() async {
        final transactionsResult = await readModel
            .watch(reportingWindowStart: reportingStart)
            .first;
        final window =
            (transactionsResult as AppSuccess<List<Transaction>>).data
                as DashboardTransactionWindow;
        return (
          mappedCount: window.length,
          totalCount: window.totalTransactionCount,
        );
      }

      await loadFullHistory();
      await loadBoundedWindow();
      const repeatCount = 5;
      final fullHistoryMicros = <int>[];
      final boundedWindowMicros = <int>[];
      var fullHistoryCount = 0;
      var boundedWindowCount = 0;
      var totalTransactionCount = 0;
      for (var repeat = 0; repeat < repeatCount; repeat++) {
        var stopwatch = Stopwatch()..start();
        fullHistoryCount = await loadFullHistory();
        stopwatch.stop();
        fullHistoryMicros.add(stopwatch.elapsedMicroseconds);

        stopwatch = Stopwatch()..start();
        final boundedResult = await loadBoundedWindow();
        boundedWindowCount = boundedResult.mappedCount;
        totalTransactionCount = boundedResult.totalCount;
        stopwatch.stop();
        boundedWindowMicros.add(stopwatch.elapsedMicroseconds);
      }
      final result = await readModel
          .watch(reportingWindowStart: reportingStart)
          .first;
      final transactions = (result as AppSuccess<List<Transaction>>).data;
      final window = transactions as DashboardTransactionWindow;
      final snapshot = await DashboardSnapshot.from(
        accounts: const [],
        transactions: transactions,
        categories: const [],
        baseCurrencyCode: 'LYD',
        exchangeRateProvider: const SameCurrencyExchangeRateProvider(),
        now: DateTime.utc(2026, 6),
        totalTransactionCount: window.totalTransactionCount,
      );

      expect(fullHistoryCount, 10020);
      expect(boundedWindowCount, 20);
      expect(totalTransactionCount, 10020);
      expect(transactions, hasLength(20));
      expect(snapshot.transactions, hasLength(20));
      expect(snapshot.totalTransactionCount, 10020);
      expect(
        transactions.every(
          (transaction) =>
              !transaction.transactionDate.isBefore(reportingStart),
        ),
        isTrue,
      );
      final fullMedian = _median(fullHistoryMicros);
      final boundedMedian = _median(boundedWindowMicros);
      // Keep the measured comparison visible in focused-test output without
      // making wall-clock timing a flaky assertion.
      // ignore: avoid_print
      print(
        'dashboard_window_measurement: repeats=$repeatCount '
        'before_rows=$fullHistoryCount after_rows=$boundedWindowCount '
        'after_total_count=$totalTransactionCount '
        'before_median_us=$fullMedian after_median_us=$boundedMedian',
      );
    },
  );

  test(
    'dashboard read model keeps five recent rows and streams later writes',
    () async {
      final reportingStart = DateTime.utc(2026, 1, 1);
      await _seedTransactions(
        database,
        ownerScope: ownerScope,
        prefix: 'historical',
        count: 8,
        start: DateTime.utc(2020, 1, 1),
      );
      final iterator = StreamIterator(
        readModel.watch(reportingWindowStart: reportingStart),
      );
      addTearDown(iterator.cancel);

      expect(await iterator.moveNext(), isTrue);
      final initial = (iterator.current as AppSuccess<List<Transaction>>).data;
      final initialWindow = initial as DashboardTransactionWindow;
      expect(initial, hasLength(5));
      expect(initial.first.id, 'historical-7');
      expect(initial.last.id, 'historical-3');
      expect(initialWindow.totalTransactionCount, 8);

      await _seedTransactions(
        database,
        ownerScope: ownerScope,
        prefix: 'current',
        count: 1,
        start: reportingStart,
      );
      expect(await iterator.moveNext(), isTrue);
      final updated = (iterator.current as AppSuccess<List<Transaction>>).data;
      final updatedWindow = updated as DashboardTransactionWindow;
      expect(updated.first.id, 'current-0');
      expect(updated, hasLength(5));
      expect(updatedWindow.totalTransactionCount, 9);
    },
  );
}

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
}) {
  return database.batch((batch) {
    for (var index = 0; index < count; index++) {
      final at = start.add(Duration(minutes: index));
      batch.insert(
        database.transactions,
        TransactionsCompanion(
          id: Value('$prefix-$index'),
          ownerScopeId: Value(ownerScope),
          accountId: const Value('account'),
          categoryId: const Value('category'),
          amount: const Value('1'),
          currencyCode: const Value('LYD'),
          type: const Value('expense'),
          paymentMethod: const Value('cash'),
          source: const Value('manual'),
          status: const Value('posted'),
          transactionDate: Value(at),
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
    }
  });
}
