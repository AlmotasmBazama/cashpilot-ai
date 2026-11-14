import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../../features/finance_engine/domain/value_objects/money.dart';

abstract final class FinanceFormatters {
  static String decimal(Decimal value) {
    return value.toString();
  }

  static String money(Money money) {
    return '${decimal(money.amount)} ${money.currencyCode.toUpperCase()}';
  }

  static String amountWithCurrency(Decimal amount, String currencyCode) {
    return '${decimal(amount)} ${currencyCode.toUpperCase()}';
  }

  static String compactDate(DateTime date, String localeName) {
    return DateFormat.MMMd(localeName).format(date.toLocal());
  }

  static String fullDate(DateTime date, String localeName) {
    return DateFormat.yMMMMd(localeName).format(date.toLocal());
  }

  static String month(DateTime date, String localeName) {
    return DateFormat.MMMM(localeName).format(date.toLocal());
  }

  static String weekdayDate(DateTime date, String localeName) {
    return DateFormat.yMMMMEEEEd(localeName).format(date.toLocal());
  }

  static String dateTime(DateTime date, String localeName) {
    return DateFormat.yMMMd(localeName).add_jm().format(date.toLocal());
  }
}
