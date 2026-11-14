import 'package:decimal/decimal.dart';

import '../entities/account_balance_state.dart';
import '../exceptions/finance_exception.dart';
import '../value_objects/exchange_rate.dart';
import '../value_objects/money.dart';

class FinanceValidationService {
  const FinanceValidationService();

  void validateAccountConfiguration(AccountBalanceState account) {
    _validateAccountPolicy(account);

    final minimumAllowedBalance = account.minimumAllowedBalance;
    if (minimumAllowedBalance != null &&
        account.balance < minimumAllowedBalance) {
      throw FinanceException.insufficientBalance(account.accountId);
    }
  }

  void _validateAccountPolicy(AccountBalanceState account) {
    validateCurrencyCode(account.currencyCode);

    final creditLimit = account.creditLimit;
    if (creditLimit != null && creditLimit < Decimal.zero) {
      throw const FinanceException.invalidCreditLimit();
    }
  }

  void validateAmount(Money amount) {
    validateCurrencyCode(amount.currencyCode);

    if (amount.amount <= Decimal.zero) {
      throw const FinanceException.invalidAmount();
    }
  }

  void validateCredit(AccountBalanceState account, Money amount) {
    // A positive credit always moves the balance toward safety. Validate the
    // persisted policy metadata, but do not reject a repair solely because a
    // legacy row already starts below today's minimum balance policy.
    _validateAccountPolicy(account);
    validateAmountCurrency(account, amount);
    validateAmount(amount);
  }

  void validateDebit(AccountBalanceState account, Money amount) {
    validateAccountConfiguration(account);
    validateAmountCurrency(account, amount);
    validateAmount(amount);
    validateSufficientBalance(account, amount);
  }

  void validateExchangeRate(ExchangeRate exchangeRate) {
    validateCurrencyCode(exchangeRate.fromCurrencyCode);
    validateCurrencyCode(exchangeRate.toCurrencyCode);

    if (exchangeRate.rate <= Decimal.zero) {
      throw const FinanceException.invalidExchangeRate();
    }
  }

  void validateTransfer({
    required AccountBalanceState sourceAccount,
    required AccountBalanceState targetAccount,
    required Money sourceAmount,
    required Money targetAmount,
    required ExchangeRate exchangeRate,
  }) {
    if (sourceAccount.accountId == targetAccount.accountId) {
      throw const FinanceException.sameAccountTransfer();
    }

    validateDebit(sourceAccount, sourceAmount);
    validateCredit(targetAccount, targetAmount);
    _validateTransferMetadata(
      sourceAmount: sourceAmount,
      targetAmount: targetAmount,
      exchangeRate: exchangeRate,
    );
  }

  void validateTransferReversal({
    required AccountBalanceState sourceAccount,
    required AccountBalanceState targetAccount,
    required Money sourceAmount,
    required Money targetAmount,
    required ExchangeRate exchangeRate,
  }) {
    if (sourceAccount.accountId == targetAccount.accountId) {
      throw const FinanceException.sameAccountTransfer();
    }

    validateCredit(sourceAccount, sourceAmount);
    validateDebit(targetAccount, targetAmount);
    _validateTransferMetadata(
      sourceAmount: sourceAmount,
      targetAmount: targetAmount,
      exchangeRate: exchangeRate,
    );
  }

  /// Enforces the authoritative relationship when a caller independently
  /// supplies both the destination amount and the exchange rate.
  ///
  /// No tolerance or binary floating-point conversion is used. Money remains
  /// unquantized in the current Finance Engine, so a caller that wants a
  /// rounded destination amount must supply that amount alone and let the
  /// processor derive its informational rate.
  void validateTransferAmountRateConsistency({
    required Money sourceAmount,
    required Money targetAmount,
    required ExchangeRate exchangeRate,
  }) {
    _validateTransferMetadata(
      sourceAmount: sourceAmount,
      targetAmount: targetAmount,
      exchangeRate: exchangeRate,
    );

    final expectedTargetAmount = sourceAmount.amount * exchangeRate.rate;
    if (targetAmount.amount != expectedTargetAmount) {
      throw const FinanceException.inconsistentTransferAmount();
    }
  }

  void _validateTransferMetadata({
    required Money sourceAmount,
    required Money targetAmount,
    required ExchangeRate exchangeRate,
  }) {
    validateExchangeRate(exchangeRate);

    if (exchangeRate.fromCurrencyCode.toUpperCase() !=
        sourceAmount.normalizedCurrencyCode) {
      throw FinanceException.currencyMismatch(
        expectedCurrencyCode: exchangeRate.fromCurrencyCode,
        actualCurrencyCode: sourceAmount.currencyCode,
      );
    }

    if (exchangeRate.toCurrencyCode.toUpperCase() !=
        targetAmount.normalizedCurrencyCode) {
      throw FinanceException.currencyMismatch(
        expectedCurrencyCode: exchangeRate.toCurrencyCode,
        actualCurrencyCode: targetAmount.currencyCode,
      );
    }
  }

  void validateAmountCurrency(AccountBalanceState account, Money amount) {
    if (account.currencyCode.toUpperCase() != amount.normalizedCurrencyCode) {
      throw FinanceException.currencyMismatch(
        expectedCurrencyCode: account.currencyCode,
        actualCurrencyCode: amount.currencyCode,
      );
    }
  }

  void validateCurrencyCode(String currencyCode) {
    if (currencyCode.trim().isEmpty) {
      throw const FinanceException.invalidCurrencyCode();
    }
  }

  void validateSufficientBalance(AccountBalanceState account, Money amount) {
    if (!account.canDebit(amount.amount)) {
      throw FinanceException.insufficientBalance(account.accountId);
    }
  }
}
