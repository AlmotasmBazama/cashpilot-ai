import 'package:decimal/decimal.dart';

import '../../../../core/error/result.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../entities/insight_analysis_result.dart';

typedef InsightMoneyConverter =
    Future<AppResult<Money>> Function(Money money, String toCurrencyCode);

class InsightConversion {
  const InsightConversion({this.amount, this.missingRate});
  final Decimal? amount;
  final InsightMissingRatePair? missingRate;
}

class InsightConversionService {
  const InsightConversionService();

  Future<InsightConversion> convertTransaction({
    required Transaction transaction,
    required String baseCurrency,
    required InsightMoneyConverter convertMoney,
  }) async {
    final from = transaction.amount.normalizedCurrencyCode;
    final to = baseCurrency.toUpperCase();
    if (from == to) {
      return InsightConversion(amount: transaction.amount.amount);
    }
    final historical = transaction.exchangeRate;
    if (historical != null && historical.rate > Decimal.zero) {
      final rateFrom = historical.fromCurrencyCode.toUpperCase();
      final rateTo = historical.toCurrencyCode.toUpperCase();
      if (rateFrom == from && rateTo == to) {
        return InsightConversion(
          amount: transaction.amount.amount * historical.rate,
        );
      }
      if (rateTo == from && rateFrom == to) {
        return InsightConversion(
          amount: (transaction.amount.amount / historical.rate).toDecimal(
            scaleOnInfinitePrecision: 12,
          ),
        );
      }
    }
    try {
      final result = await convertMoney(transaction.amount, to);
      return switch (result) {
        AppSuccess<Money>(:final data) => InsightConversion(
          amount: data.amount,
        ),
        AppFailure<Money>() => InsightConversion(
          missingRate: InsightMissingRatePair(from, to),
        ),
      };
    } on Object {
      return InsightConversion(missingRate: InsightMissingRatePair(from, to));
    }
  }
}
