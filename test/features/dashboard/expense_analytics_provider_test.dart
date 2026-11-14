import 'dart:async';

import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/dashboard/application/expense_analytics_providers.dart';
import 'package:cashpilot_ai/features/dashboard/domain/entities/expense_analytics.dart';
import 'package:cashpilot_ai/features/dashboard/domain/repositories/expense_analytics_repository.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/base_currency_provider.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'weekly and monthly providers resolve their requested local periods',
    () async {
      final repository = _RecordingRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      final weekly = await _readPeriod(container, ExpenseAnalyticsPeriod.week);
      final monthly = await _readPeriod(
        container,
        ExpenseAnalyticsPeriod.month,
      );

      expect(
        (weekly as AppSuccess<ExpenseAnalyticsSnapshot>).data.selectedPeriod,
        ExpenseAnalyticsPeriod.week,
      );
      expect(
        (monthly as AppSuccess<ExpenseAnalyticsSnapshot>).data.selectedPeriod,
        ExpenseAnalyticsPeriod.month,
      );
      expect(repository.queries, hasLength(2));
      expect(
        repository.queries.first.ranges.current.start.weekday,
        DateTime.monday,
      );
      expect(repository.queries.last.ranges.current.start.day, 1);
      expect(repository.queries.last.baseCurrencyCode, 'LYD');
    },
  );

  test('two listeners reuse one selected-period subscription', () async {
    final repository = _RecordingRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final provider = expenseAnalyticsProvider(ExpenseAnalyticsPeriod.month);
    final first = container.listen(provider, (_, _) {}, fireImmediately: true);
    final second = container.listen(provider, (_, _) {}, fireImmediately: true);
    addTearDown(first.close);
    addTearDown(second.close);

    await container.read(provider.future);

    expect(repository.watchCount, 1);
  });

  test(
    'table updates advance the projection window after Home opens',
    () async {
      final repository = _RecordingRepository(live: true);
      var now = DateTime.utc(2026, 8, 23, 12);
      final container = _container(repository, clock: () => now);
      addTearDown(container.dispose);
      addTearDown(repository.updates.close);
      final provider = expenseAnalyticsProvider(ExpenseAnalyticsPeriod.month);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      expect(
        (initial as AppSuccess<ExpenseAnalyticsSnapshot>)
            .data
            .currentDateRange
            .end
            .toUtc(),
        now,
      );

      now = now.add(const Duration(minutes: 5));
      final refreshed = Completer<ExpenseAnalyticsSnapshot>();
      final listener = container.listen(provider, (_, next) {
        final result = next.value;
        if (result is AppSuccess<ExpenseAnalyticsSnapshot> &&
            result.data.currentDateRange.end.isAtSameMomentAs(now) &&
            !refreshed.isCompleted) {
          refreshed.complete(result.data);
        }
      });
      addTearDown(listener.close);
      repository.updates.add(
        AppResult.success(_snapshot(repository.queries.single)),
      );
      final snapshot = await refreshed.future.timeout(
        const Duration(seconds: 5),
      );
      expect(snapshot.currentDateRange.end.toUtc(), now);
      expect(repository.loadedQueries.single.ranges.current.end.toUtc(), now);
      expect(repository.watchCount, 1);
    },
  );

  testWidgets('calendar rollover refreshes without a database write', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    var now = DateTime.utc(2026, 8, 31, 21, 59, 30);
    final container = _container(repository, clock: () => now);
    final provider = expenseAnalyticsProvider(ExpenseAnalyticsPeriod.month);
    final subscription = container.listen(provider, (_, _) {});
    await tester.pump();
    expect(repository.queries.single.ranges.current.start.month, 8);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(repository.queries.last.ranges.current.start.month, 9);
    expect(repository.watchCount, 2);
    subscription.close();
    container.dispose();
  });

  test(
    'invalidating a failed period creates one clean retry subscription',
    () async {
      final repository = _RecordingRepository(failFirst: true);
      final container = _container(repository);
      addTearDown(container.dispose);
      final provider = expenseAnalyticsProvider(ExpenseAnalyticsPeriod.month);
      final subscription = container.listen(
        provider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final first = await container.read(provider.future);
      expect(first, isA<AppFailure<ExpenseAnalyticsSnapshot>>());
      container.invalidate(provider);
      final retried = await container.read(provider.future);

      expect(retried, isA<AppSuccess<ExpenseAnalyticsSnapshot>>());
      expect(repository.watchCount, 2);
    },
  );
}

Future<AppResult<ExpenseAnalyticsSnapshot>> _readPeriod(
  ProviderContainer container,
  ExpenseAnalyticsPeriod period,
) async {
  final provider = expenseAnalyticsProvider(period);
  final subscription = container.listen(
    provider,
    (_, _) {},
    fireImmediately: true,
  );
  try {
    return await container.read(provider.future);
  } finally {
    subscription.close();
  }
}

ProviderContainer _container(
  _RecordingRepository repository, {
  DateTime Function()? clock,
}) {
  return ProviderContainer(
    overrides: [
      currentAuthUserProvider.overrideWithValue(null),
      effectiveBaseCurrencyCodeProvider.overrideWithValue('LYD'),
      expenseAnalyticsClockProvider.overrideWithValue(
        clock ?? () => DateTime.utc(2026, 8, 23, 12),
      ),
      expenseAnalyticsRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

final class _RecordingRepository implements ExpenseAnalyticsRepository {
  _RecordingRepository({this.failFirst = false, this.live = false});

  final bool failFirst;
  final bool live;
  final List<ExpenseAnalyticsQuery> queries = [];
  final List<ExpenseAnalyticsQuery> loadedQueries = [];
  final updates = StreamController<AppResult<ExpenseAnalyticsSnapshot>>();
  int watchCount = 0;

  @override
  Stream<AppResult<ExpenseAnalyticsSnapshot>> watch(
    ExpenseAnalyticsQuery query,
  ) async* {
    watchCount += 1;
    queries.add(query);
    if (failFirst && watchCount == 1) {
      yield const AppResult.failure(Failure(message: 'temporary'));
      return;
    }
    yield AppResult.success(_snapshot(query));
    if (live) yield* updates.stream;
  }

  @override
  Future<AppResult<ExpenseAnalyticsSnapshot>> load(
    ExpenseAnalyticsQuery query,
  ) async {
    loadedQueries.add(query);
    return AppResult.success(_snapshot(query));
  }
}

ExpenseAnalyticsSnapshot _snapshot(ExpenseAnalyticsQuery query) {
  return ExpenseAnalyticsSnapshot(
    selectedPeriod: query.ranges.period,
    currentDateRange: query.ranges.current,
    previousDateRange: query.ranges.previous,
    totalExpense: Decimal.parse('10'),
    previousTotalExpense: Decimal.parse('5'),
    percentageChange: Decimal.parse('100'),
    comparisonDirection: ExpenseComparisonDirection.increased,
    topCategories: const [],
    otherTotal: Decimal.zero,
    otherPercentage: Decimal.zero,
    currencyCode: query.baseCurrencyCode,
    isPartial: false,
    warnings: const [],
    hasCurrentExpenses: true,
    metrics: const ExpenseAnalyticsQueryMetrics(
      sourceRowCount: 2,
      aggregateRowCount: 2,
      processingDuration: Duration.zero,
    ),
  );
}
