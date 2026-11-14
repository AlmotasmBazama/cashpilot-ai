import 'package:decimal/decimal.dart';

import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../entities/currency_conversion_query.dart';

class CurrencyConversionQueryParser {
  const CurrencyConversionQueryParser();

  CurrencyConversionQuery? parse(String input) {
    final normalized = CurrencyCatalog.normalizeText(input);
    if (!_isConversionQuestion(input, normalized)) {
      return null;
    }

    final amountMatch = RegExp(r'\d+(?:[\.,]\d+)?').firstMatch(input);
    final amount = Decimal.tryParse(
      amountMatch?.group(0)?.replaceAll(',', '.') ?? '',
    );
    if (amount == null || amount <= Decimal.zero) {
      return null;
    }

    final currencies = _currenciesInOrder(normalized);
    if (currencies.length < 2 || currencies[0] == currencies[1]) {
      return null;
    }

    return CurrencyConversionQuery(
      sourceAmount: Money(amount: amount, currencyCode: currencies[0]),
      targetCurrencyCode: currencies[1],
    );
  }

  bool _isConversionQuestion(String input, String normalized) {
    return input.contains('?') ||
        input.contains('؟') ||
        normalized.contains('how much') ||
        normalized.contains('convert') ||
        normalized.contains('worth') ||
        normalized.contains('equal') ||
        normalized.contains('كم') ||
        normalized.contains('تساوي') ||
        normalized.contains('يساوي') ||
        normalized.contains('يعادل');
  }

  List<String> _currenciesInOrder(String normalizedInput) {
    final matches = <({String code, int index})>[];
    for (final currency in CurrencyCatalog.supported) {
      var firstIndex = -1;
      for (final token in <String>[
        currency.code,
        currency.name,
        ...currency.aliases,
      ]) {
        final index = normalizedInput.indexOf(
          CurrencyCatalog.normalizeText(token),
        );
        if (index >= 0 && (firstIndex < 0 || index < firstIndex)) {
          firstIndex = index;
        }
      }
      if (firstIndex >= 0) {
        matches.add((code: currency.code, index: firstIndex));
      }
    }
    matches.sort((a, b) => a.index.compareTo(b.index));
    return matches.map((match) => match.code).toList(growable: false);
  }
}
