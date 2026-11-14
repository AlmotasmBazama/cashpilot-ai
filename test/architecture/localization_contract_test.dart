import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _icuArgumentPattern = RegExp(
  r'\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:,|\})',
);

void main() {
  group('localization ARB contract', () {
    late Map<String, dynamic> english;
    late Map<String, dynamic> arabic;

    setUpAll(() {
      english = _readArb('lib/l10n/app_en.arb');
      arabic = _readArb('lib/l10n/app_ar.arb');
    });

    test('English and Arabic expose the same non-locale keys', () {
      final englishKeys = _contractKeys(english);
      final arabicKeys = _contractKeys(arabic);

      expect(arabicKeys, unorderedEquals(englishKeys));
    });

    test('matching messages expose the same ICU placeholder names', () {
      final messageKeys =
          english.keys.where((key) => !key.startsWith('@')).toList()..sort();
      final mismatches = <String>[];

      for (final key in messageKeys) {
        final englishMessage = english[key];
        final arabicMessage = arabic[key];
        if (englishMessage is! String || arabicMessage is! String) {
          mismatches.add('$key: message values must be strings');
          continue;
        }

        final englishNames = _icuPlaceholderNames(englishMessage);
        final arabicNames = _icuPlaceholderNames(arabicMessage);
        if (!_sameSet(englishNames, arabicNames)) {
          mismatches.add(
            '$key: en=${_sorted(englishNames)}, ar=${_sorted(arabicNames)}',
          );
        }
      }

      expect(
        mismatches,
        isEmpty,
        reason: mismatches.isEmpty ? null : mismatches.join('\n'),
      );
    });
  });
}

Map<String, dynamic> _readArb(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  return (decoded as Map<String, dynamic>);
}

Set<String> _contractKeys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@@')).toSet();

Set<String> _icuPlaceholderNames(String message) => _icuArgumentPattern
    .allMatches(message)
    .map((match) => match.group(1)!)
    .toSet();

bool _sameSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

List<String> _sorted(Set<String> values) => values.toList()..sort();
