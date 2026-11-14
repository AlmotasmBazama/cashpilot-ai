import 'package:decimal/decimal.dart';

abstract final class AccountFormatters {
  static String amount(Decimal amount) {
    return amount.toString();
  }

  static String currency(String currencyCode) {
    return currencyCode.toUpperCase();
  }
}
