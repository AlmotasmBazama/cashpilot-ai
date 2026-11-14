import 'package:cashpilot_ai/shared/domain/currency/localized_decimal_parser.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalizedDecimalParser', () {
    const validInputs = <String, String>{
      '1234.56': '1234.56',
      '1234,56': '1234.56',
      '1,234.56': '1234.56',
      '1.234,56': '1234.56',
      '1,234': '1.234',
      '1.234': '1.234',
      '١٬٢٣٤': '1234',
      '۱٬۲۳۴': '1234',
      '١٬٢٣٤٫٥٦': '1234.56',
      '۱۲۳۴٫۵۶': '1234.56',
      '٩٬٨٧٦٫٥٤': '9876.54',
      '۹٬۸۷۶٫۵۴': '9876.54',
      '\u200F−١٢٫٥': '-12.5',
    };

    for (final entry in validInputs.entries) {
      test('parses ${entry.key}', () {
        expect(
          LocalizedDecimalParser.tryParse(entry.key),
          Decimal.parse(entry.value),
        );
      });
    }

    test('rejects malformed or empty values', () {
      for (final value in <String>[
        '',
        ' ',
        '1..2',
        '1.2.3',
        '1,2,3',
        '12,34,567.89',
        '١٫٢٫٣',
        '١٢٬٣٤',
        '۱۲٬۳۴',
        '۱٬۲۳٬۴۵۶٫۷۸',
        '١٢x',
        '--5',
      ]) {
        expect(LocalizedDecimalParser.tryParse(value), isNull, reason: value);
      }
    });
  });
}
