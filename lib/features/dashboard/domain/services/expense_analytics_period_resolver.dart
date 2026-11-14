import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import '../entities/expense_analytics.dart';

class ExpenseAnalyticsPeriodResolver {
  ExpenseAnalyticsPeriodResolver() {
    _ensureTimeZonesInitialized();
  }

  static const defaultTimeZoneName = 'Africa/Tripoli';
  static bool _timeZonesInitialized = false;

  ExpenseAnalyticsRanges resolve({
    required ExpenseAnalyticsPeriod period,
    required DateTime now,
    required String timeZoneName,
  }) {
    final location = _location(timeZoneName);
    final localNow = time_zone.TZDateTime.from(now.toUtc(), location);
    final currentStart = switch (period) {
      ExpenseAnalyticsPeriod.week => _startOfWeek(localNow, location),
      ExpenseAnalyticsPeriod.month => time_zone.TZDateTime(
        location,
        localNow.year,
        localNow.month,
      ),
    };
    final previousStart = switch (period) {
      ExpenseAnalyticsPeriod.week => time_zone.TZDateTime(
        location,
        currentStart.year,
        currentStart.month,
        currentStart.day - 7,
      ),
      ExpenseAnalyticsPeriod.month => time_zone.TZDateTime(
        location,
        localNow.year,
        localNow.month - 1,
      ),
    };

    return ExpenseAnalyticsRanges(
      period: period,
      current: ExpenseAnalyticsDateRange(start: currentStart, end: localNow),
      previous: ExpenseAnalyticsDateRange(
        start: previousStart,
        end: currentStart,
      ),
      timeZoneName: location.name,
    );
  }

  time_zone.TZDateTime _startOfWeek(
    time_zone.TZDateTime at,
    time_zone.Location location,
  ) {
    return time_zone.TZDateTime(
      location,
      at.year,
      at.month,
      at.day - (at.weekday - DateTime.monday),
    );
  }

  time_zone.Location _location(String requestedName) {
    final normalized = requestedName.trim();
    try {
      return time_zone.getLocation(
        normalized.isEmpty ? defaultTimeZoneName : normalized,
      );
    } on Object {
      return time_zone.getLocation(defaultTimeZoneName);
    }
  }

  static void _ensureTimeZonesInitialized() {
    if (_timeZonesInitialized) {
      return;
    }
    time_zone_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }
}
