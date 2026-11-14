import '../entities/account_balance_state.dart';
import '../enums/finance_transaction_direction.dart';
import '../exceptions/finance_exception.dart';
import '../value_objects/exchange_rate.dart';
import '../value_objects/money.dart';

class BalanceCalculator {
  const BalanceCalculator();

  Money add(Money left, Money right) {
    return left + right;
  }

  Money subtract(Money left, Money right) {
    return left - right;
  }

  AccountBalanceState credit(
    AccountBalanceState account,
    Money amount, {
    DateTime? occurredAt,
  }) {
    _ensureAccountCurrency(account, amount);

    return account.copyWith(
      balance: account.balance + amount.amount,
      updatedAt: occurredAt ?? DateTime.now().toUtc(),
    );
  }

  AccountBalanceState debit(
    AccountBalanceState account,
    Money amount, {
    DateTime? occurredAt,
  }) {
    _ensureAccountCurrency(account, amount);

    return account.copyWith(
      balance: account.balance - amount.amount,
      updatedAt: occurredAt ?? DateTime.now().toUtc(),
    );
  }

  AccountBalanceState applyTransaction(
    AccountBalanceState account,
    Money amount, {
    required FinanceTransactionDirection direction,
    DateTime? occurredAt,
  }) {
    return switch (direction) {
      FinanceTransactionDirection.credit => credit(
        account,
        amount,
        occurredAt: occurredAt,
      ),
      FinanceTransactionDirection.debit => debit(
        account,
        amount,
        occurredAt: occurredAt,
      ),
    };
  }

  Money convert(Money source, ExchangeRate exchangeRate) {
    if (exchangeRate.rate <= Money.zero(source.currencyCode).amount) {
      throw const FinanceException.invalidExchangeRate();
    }

    if (source.normalizedCurrencyCode !=
        exchangeRate.fromCurrencyCode.toUpperCase()) {
      throw FinanceException.currencyMismatch(
        expectedCurrencyCode: exchangeRate.fromCurrencyCode,
        actualCurrencyCode: source.currencyCode,
      );
    }

    return Money(
      amount: source.amount * exchangeRate.rate,
      currencyCode: exchangeRate.toCurrencyCode,
    );
  }

  void _ensureAccountCurrency(AccountBalanceState account, Money amount) {
    if (account.currencyCode.toUpperCase() != amount.normalizedCurrencyCode) {
      throw FinanceException.currencyMismatch(
        expectedCurrencyCode: account.currencyCode,
        actualCurrencyCode: amount.currencyCode,
      );
    }
  }
}
