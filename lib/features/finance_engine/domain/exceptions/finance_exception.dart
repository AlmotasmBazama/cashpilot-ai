class FinanceException implements Exception {
  const FinanceException({required this.code, required this.message});

  const FinanceException.accountNotFound(String accountId)
    : this(
        code: FinanceFailureCodes.accountNotFound,
        message: 'Account not found: $accountId',
      );

  const FinanceException.currencyMismatch({
    required String expectedCurrencyCode,
    required String actualCurrencyCode,
  }) : this(
         code: FinanceFailureCodes.currencyMismatch,
         message:
             'Currency mismatch. Expected $expectedCurrencyCode, got $actualCurrencyCode.',
       );

  const FinanceException.exchangeRateUnavailable({
    required String fromCurrencyCode,
    required String toCurrencyCode,
  }) : this(
         code: FinanceFailureCodes.exchangeRateUnavailable,
         message:
             'Exchange rate unavailable for $fromCurrencyCode to $toCurrencyCode.',
       );

  const FinanceException.insufficientBalance(String accountId)
    : this(
        code: FinanceFailureCodes.insufficientBalance,
        message: 'Insufficient balance for account: $accountId',
      );

  const FinanceException.invalidAmount()
    : this(
        code: FinanceFailureCodes.invalidAmount,
        message: 'Amount must be greater than zero.',
      );

  const FinanceException.invalidCreditLimit()
    : this(
        code: FinanceFailureCodes.invalidCreditLimit,
        message: 'Credit limit must be greater than or equal to zero.',
      );

  const FinanceException.invalidCurrencyCode()
    : this(
        code: FinanceFailureCodes.invalidCurrencyCode,
        message: 'Currency code must not be empty.',
      );

  const FinanceException.invalidExchangeRate()
    : this(
        code: FinanceFailureCodes.invalidExchangeRate,
        message: 'Exchange rate must be greater than zero.',
      );

  const FinanceException.inconsistentTransferAmount()
    : this(
        code: FinanceFailureCodes.inconsistentTransferAmount,
        message:
            'Target amount must exactly equal source amount multiplied by the exchange rate.',
      );

  const FinanceException.sameAccountTransfer()
    : this(
        code: FinanceFailureCodes.sameAccountTransfer,
        message: 'Source and target accounts must be different.',
      );

  final String code;
  final String message;

  @override
  String toString() => 'FinanceException: [$code] $message';
}

abstract final class FinanceFailureCodes {
  static const accountNotFound = 'account_not_found';
  static const currencyMismatch = 'currency_mismatch';
  static const exchangeRateUnavailable = 'exchange_rate_unavailable';
  static const insufficientBalance = 'insufficient_balance';
  static const invalidAmount = 'invalid_amount';
  static const invalidCreditLimit = 'invalid_credit_limit';
  static const invalidCurrencyCode = 'invalid_currency_code';
  static const invalidExchangeRate = 'invalid_exchange_rate';
  static const inconsistentTransferAmount = 'inconsistent_transfer_amount';
  static const sameAccountTransfer = 'same_account_transfer';
}
