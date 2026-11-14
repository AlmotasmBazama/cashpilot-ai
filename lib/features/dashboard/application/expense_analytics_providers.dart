import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../auth/application/providers/auth_providers.dart';
import '../../exchange_rates/application/base_currency_provider.dart';
import '../data/expense_analytics_read_model.dart';
import '../domain/entities/expense_analytics.dart';
import '../domain/repositories/expense_analytics_repository.dart';
import '../domain/services/expense_analytics_period_resolver.dart';

final expenseAnalyticsPeriodResolverProvider =
    Provider<ExpenseAnalyticsPeriodResolver>(
      (_) => ExpenseAnalyticsPeriodResolver(),
      name: 'expenseAnalyticsPeriodResolverProvider',
    );

final expenseAnalyticsClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
  name: 'expenseAnalyticsClockProvider',
);

final expenseAnalyticsRepositoryProvider = Provider<ExpenseAnalyticsRepository>(
  (ref) => DriftExpenseAnalyticsReadModel(
    ref.watch(requiredScopedAppDatabaseSessionProvider),
  ),
  name: 'expenseAnalyticsRepositoryProvider',
);

final expenseAnalyticsProvider = StreamProvider.autoDispose
    .family<AppResult<ExpenseAnalyticsSnapshot>, ExpenseAnalyticsPeriod>((
      ref,
      period,
    ) {
      final timeZoneName = ref.watch(
        currentAuthUserProvider.select((user) => user?.timezone),
      );
      final resolver = ref.watch(expenseAnalyticsPeriodResolverProvider);
      final clock = ref.watch(expenseAnalyticsClockProvider);
      final baseCurrencyCode = ref.watch(effectiveBaseCurrencyCodeProvider);
      final repository = ref.watch(expenseAnalyticsRepositoryProvider);
      ExpenseAnalyticsQuery currentQuery() => ExpenseAnalyticsQuery(
        ranges: resolver.resolve(
          period: period,
          now: clock(),
          timeZoneName:
              timeZoneName ??
              ExpenseAnalyticsPeriodResolver.defaultTimeZoneName,
        ),
        baseCurrencyCode: baseCurrencyCode,
      );
      final query = currentQuery();
      // Refresh the window even when midnight passes without a database write.
      final timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => ref.invalidateSelf(),
      );
      ref.onDispose(timer.cancel);
      return repository.watch(query).asyncMap((snapshot) {
        final refreshed = currentQuery();
        if (refreshed.ranges.current.end.isAtSameMomentAs(
          query.ranges.current.end,
        )) {
          return snapshot;
        }
        // Table updates also arrive for rows outside the original window.
        // Resolve "now" again so expenses entered after Home opened appear.
        return repository.load(refreshed);
      });
    }, name: 'expenseAnalyticsProvider');

final weeklyExpenseAnalyticsProvider =
    Provider<AsyncValue<AppResult<ExpenseAnalyticsSnapshot>>>(
      (ref) => ref.watch(expenseAnalyticsProvider(ExpenseAnalyticsPeriod.week)),
      name: 'weeklyExpenseAnalyticsProvider',
    );

final monthlyExpenseAnalyticsProvider =
    Provider<AsyncValue<AppResult<ExpenseAnalyticsSnapshot>>>(
      (ref) =>
          ref.watch(expenseAnalyticsProvider(ExpenseAnalyticsPeriod.month)),
      name: 'monthlyExpenseAnalyticsProvider',
    );
