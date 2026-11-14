import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import '../../../../shared/presentation/formatters/finance_formatters.dart';

/// Formats financial calendar dates in the account-configured timezone.
///
/// Transaction dates are stored as UTC instants representing local calendar
/// boundaries. Converting them through the device timezone can display the
/// previous day, so preview and verified-result cards share this formatter.
abstract final class AiFinancialDateFormatter {
  static String label({
    required DateTime date,
    required String timeZoneName,
    required String localeName,
    required String todayLabel,
    DateTime? now,
  }) {
    final location = _location(timeZoneName);
    final localDate = time_zone.TZDateTime.from(date.toUtc(), location);
    final localNow = time_zone.TZDateTime.from(
      (now ?? DateTime.now()).toUtc(),
      location,
    );
    if (localDate.year == localNow.year &&
        localDate.month == localNow.month &&
        localDate.day == localNow.day) {
      return todayLabel;
    }
    return FinanceFormatters.compactDate(localDate, localeName);
  }

  static time_zone.Location _location(String requestedName) {
    _ensureTimeZonesInitialized();
    final normalized = requestedName.trim();
    final canonical =
        _timeZoneAliases[normalized] ??
        (normalized.isEmpty ? _defaultTimeZoneName : normalized);
    try {
      return time_zone.getLocation(canonical);
    } on Object {
      return time_zone.getLocation(_defaultTimeZoneName);
    }
  }

  static void _ensureTimeZonesInitialized() {
    if (_timeZonesInitialized) return;
    time_zone_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }

  static const _defaultTimeZoneName = 'Africa/Tripoli';
  static bool _timeZonesInitialized = false;
  static const _timeZoneAliases = <String, String>{
    'Libya Standard Time': _defaultTimeZoneName,
    'EET': _defaultTimeZoneName,
  };
}
