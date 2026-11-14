import '../../../finance_engine/domain/value_objects/money.dart';

class CurrencyConversionQuery {
  const CurrencyConversionQuery({
    required this.sourceAmount,
    required this.targetCurrencyCode,
  });

  final Money sourceAmount;
  final String targetCurrencyCode;
}
