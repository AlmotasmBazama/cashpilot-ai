import 'package:cashpilot_ai/features/dashboard/domain/entities/expense_analytics.dart';
import 'package:cashpilot_ai/features/dashboard/domain/services/expense_analytics_period_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final resolver = ExpenseAnalyticsPeriodResolver();

  test('weekly period uses local Monday and the immediately previous week', () {
    final ranges = resolver.resolve(
      period: ExpenseAnalyticsPeriod.week,
      now: DateTime.utc(2026, 8, 23, 12, 30),
      timeZoneName: 'Africa/Tripoli',
    );

    expect(ranges.timeZoneName, 'Africa/Tripoli');
    expect(ranges.current.start.toUtc(), DateTime.utc(2026, 8, 16, 22));
    expect(ranges.current.end.toUtc(), DateTime.utc(2026, 8, 23, 12, 30));
    expect(ranges.previous.start.toUtc(), DateTime.utc(2026, 8, 9, 22));
    expect(ranges.previous.end, ranges.current.start);
  });

  test('monthly period uses local calendar boundaries and current moment', () {
    final ranges = resolver.resolve(
      period: ExpenseAnalyticsPeriod.month,
      now: DateTime.utc(2026, 8, 23, 12, 30),
      timeZoneName: 'Africa/Tripoli',
    );

    expect(ranges.current.start.toUtc(), DateTime.utc(2026, 7, 31, 22));
    expect(ranges.current.end.toUtc(), DateTime.utc(2026, 8, 23, 12, 30));
    expect(ranges.previous.start.toUtc(), DateTime.utc(2026, 6, 30, 22));
    expect(ranges.previous.end, ranges.current.start);
  });

  test('invalid or empty timezone safely falls back to Tripoli', () {
    for (final value in <String>['', 'Not/A_Real_Zone']) {
      final ranges = resolver.resolve(
        period: ExpenseAnalyticsPeriod.month,
        now: DateTime.utc(2026, 8, 23),
        timeZoneName: value,
      );
      expect(ranges.timeZoneName, 'Africa/Tripoli');
    }
  });

  test('weekly boundaries remain local midnight across daylight saving', () {
    final sunday = resolver.resolve(
      period: ExpenseAnalyticsPeriod.week,
      now: DateTime.utc(2026, 3, 8, 18),
      timeZoneName: 'America/New_York',
    );
    expect(sunday.current.start.toUtc(), DateTime.utc(2026, 3, 2, 5));
    expect(sunday.current.start.hour, 0);

    final followingWeek = resolver.resolve(
      period: ExpenseAnalyticsPeriod.week,
      now: DateTime.utc(2026, 3, 9, 18),
      timeZoneName: 'America/New_York',
    );
    expect(followingWeek.current.start.toUtc(), DateTime.utc(2026, 3, 9, 4));
    expect(followingWeek.previous.start.toUtc(), DateTime.utc(2026, 3, 2, 5));
    expect(followingWeek.previous.start.hour, 0);
    expect(followingWeek.previous.end, followingWeek.current.start);
  });
}
