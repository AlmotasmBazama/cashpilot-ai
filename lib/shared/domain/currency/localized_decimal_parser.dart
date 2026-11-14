import 'package:decimal/decimal.dart';

/// Parses decimal values entered with common Arabic or Latin digit formats.
///
/// U+066C is an explicit grouping mark and is accepted only in structurally
/// valid groups. Without a locale, one ASCII comma or dot retains the existing
/// decimal interpretation (`1,234` and `1.234` both mean `1.234`).
///
/// This only normalizes presentation syntax. Domain validation remains
/// responsible for deciding whether the parsed value is allowed.
abstract final class LocalizedDecimalParser {
  static Decimal? tryParse(String input) {
    var normalized = _normalizeCharacters(input);
    if (normalized.isEmpty) {
      return null;
    }

    final withNormalizedSeparators = _normalizeSeparators(normalized);
    if (withNormalizedSeparators == null ||
        !_decimalPattern.hasMatch(withNormalizedSeparators)) {
      return null;
    }
    return Decimal.tryParse(withNormalizedSeparators);
  }

  static final RegExp _decimalPattern = RegExp(
    r'^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$',
  );

  static final RegExp _ignoredCharacters = RegExp(
    r'[\s\u00A0\u061C\u200E\u200F\u202A-\u202E\u202F\u2066-\u2069]',
  );

  static String _normalizeCharacters(String input) {
    final buffer = StringBuffer();
    for (final rune in input.trim().runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer
        .toString()
        .replaceAll(_ignoredCharacters, '')
        .replaceAll('\u2212', '-')
        .replaceAll('\u066B', '.');
  }

  static String? _normalizeSeparators(String value) {
    final sign = value.startsWith('-') || value.startsWith('+') ? value[0] : '';
    final unsigned = sign.isEmpty ? value : value.substring(1);
    if (unsigned.contains(_arabicGroupingSeparator)) {
      return _normalizeExplicitArabicGrouping(sign, unsigned);
    }
    final dotCount = _separatorCount(unsigned, '.');
    final commaCount = _separatorCount(unsigned, ',');
    if (dotCount == 0 && commaCount == 0) {
      return value;
    }

    if (dotCount > 0 && commaCount > 0) {
      final decimalSeparator =
          unsigned.lastIndexOf('.') > unsigned.lastIndexOf(',') ? '.' : ',';
      final groupingSeparator = decimalSeparator == '.' ? ',' : '.';
      if (_separatorCount(unsigned, decimalSeparator) != 1) {
        return null;
      }
      final decimalIndex = unsigned.lastIndexOf(decimalSeparator);
      final integerPart = unsigned.substring(0, decimalIndex);
      final fractionalPart = unsigned.substring(decimalIndex + 1);
      if (fractionalPart.contains(groupingSeparator) ||
          (integerPart.contains(groupingSeparator) &&
              !_isGroupedInteger(integerPart, groupingSeparator))) {
        return null;
      }
      return '$sign${integerPart.replaceAll(groupingSeparator, '')}'
          '.$fractionalPart';
    }

    final separator = dotCount > 0 ? '.' : ',';
    final separatorCount = dotCount + commaCount;
    if (separatorCount == 1) {
      return separator == ',' ? value.replaceAll(',', '.') : value;
    }
    if (!_isGroupedInteger(unsigned, separator)) {
      return null;
    }
    return '$sign${unsigned.replaceAll(separator, '')}';
  }

  static String? _normalizeExplicitArabicGrouping(
    String sign,
    String unsigned,
  ) {
    final dotCount = _separatorCount(unsigned, '.');
    final commaCount = _separatorCount(unsigned, ',');
    if (dotCount + commaCount > 1) {
      return null;
    }
    final decimalSeparator = dotCount == 1
        ? '.'
        : commaCount == 1
        ? ','
        : null;
    final decimalIndex = decimalSeparator == null
        ? -1
        : unsigned.indexOf(decimalSeparator);
    if (decimalIndex >= 0 &&
        decimalIndex < unsigned.lastIndexOf(_arabicGroupingSeparator)) {
      return null;
    }
    final integerPart = decimalIndex < 0
        ? unsigned
        : unsigned.substring(0, decimalIndex);
    if (!_isGroupedInteger(integerPart, _arabicGroupingSeparator)) {
      return null;
    }
    final normalizedInteger = integerPart.replaceAll(
      _arabicGroupingSeparator,
      '',
    );
    if (decimalIndex < 0) {
      return '$sign$normalizedInteger';
    }
    final fractionalPart = unsigned.substring(decimalIndex + 1);
    return '$sign$normalizedInteger.$fractionalPart';
  }

  static int _separatorCount(String value, String separator) {
    return value.length - value.replaceAll(separator, '').length;
  }

  static bool _isGroupedInteger(String value, String separator) {
    final parts = value.split(separator);
    return parts.length > 1 &&
        parts.first.isNotEmpty &&
        parts.first.length <= 3 &&
        parts.every(_digitsPattern.hasMatch) &&
        parts.skip(1).every((part) => part.length == 3);
  }

  static final RegExp _digitsPattern = RegExp(r'^\d+$');
  static const _arabicGroupingSeparator = '\u066C';
}
