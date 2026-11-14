import 'package:decimal/decimal.dart';

import '../../../../core/error/result.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../entities/budget.dart';
import '../entities/budget_progress.dart';
import '../enums/budget_status.dart';
import '../enums/budget_period_type.dart';
import 'budget_period_resolver.dart';

typedef BudgetMoneyConverter =
    Future<AppResult<Money>> Function(Money money, String toCurrencyCode);

class BudgetProgressCalculator {
  const BudgetProgressCalculator({
    BudgetPeriodResolver periodResolver = const BudgetPeriodResolver(),
  }) : _periodResolver = periodResolver;

  final BudgetPeriodResolver _periodResolver;

  Future<BudgetProgress> calculate({
    required Budget budget,
    required List<Transaction> transactions,
    required DateTime now,
    required BudgetMoneyConverter convertMoney,
  }) async {
    final period = _periodResolver.resolve(budget, now);
    var spent = Decimal.zero;
    final warnings = <String, BudgetMissingRateWarning>{};
    final matching = transactions.where(
      (transaction) =>
          transaction.type == TransactionType.expense &&
          transaction.status == TransactionStatus.posted &&
          transaction.categoryId == budget.categoryId &&
          !transaction.transactionDate.toUtc().isBefore(period.start) &&
          transaction.transactionDate.toUtc().isBefore(period.end),
    );

    for (final transaction in matching) {
      if (transaction.amount.normalizedCurrencyCode == budget.currency) {
        spent += transaction.amount.amount;
        continue;
      }
      final result = await convertMoney(transaction.amount, budget.currency);
      switch (result) {
        case AppSuccess<Money>(:final data):
          spent += data.amount;
        case AppFailure<Money>():
          final warning = BudgetMissingRateWarning(
            fromCurrencyCode: transaction.amount.normalizedCurrencyCode,
            toCurrencyCode: budget.currency,
          );
          warnings[warning.key] = warning;
      }
    }

    final progress = (spent / budget.amount).toDecimal(
      scaleOnInfinitePrecision: 8,
    );
    final percent = progress * Decimal.fromInt(100);
    final status = _status(
      budget,
      percent,
      warnings.isNotEmpty,
      now.toUtc(),
      period,
    );
    return BudgetProgress(
      budget: budget,
      spentAmount: spent,
      remainingAmount: budget.amount - spent,
      progressPercent: percent,
      status: status,
      periodStart: period.start,
      periodEnd: period.end,
      missingRateWarnings: warnings.values.toList(growable: false),
    );
  }

  BudgetStatus _status(
    Budget budget,
    Decimal percent,
    bool isPartial,
    DateTime now,
    BudgetPeriod period,
  ) {
    final outsideCustomPeriod =
        budget.periodType == BudgetPeriodType.custom &&
        (now.isBefore(period.start) || !now.isBefore(period.end));
    if (!budget.isActive || budget.isArchived || outsideCustomPeriod) {
      return BudgetStatus.inactive;
    }
    if (percent >= Decimal.fromInt(100)) {
      return BudgetStatus.exceeded;
    }
    if (isPartial || percent >= Decimal.fromInt(budget.alertThresholdPercent)) {
      return BudgetStatus.warning;
    }
    return BudgetStatus.onTrack;
  }
}
