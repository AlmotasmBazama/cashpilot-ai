abstract final class AccountFailureCodes {
  static const negativeOpeningBalance = 'account_negative_opening_balance';
  static const openingBalanceLedgerRequired =
      'account_opening_balance_ledger_required';
  static const openingBalanceEntryFailed =
      'account_opening_balance_entry_failed';
  static const protectedFieldMutation = 'account_protected_field_mutation';
  static const nonZeroBalance = 'account_non_zero_balance';
  static const hasDependencies = 'account_has_dependencies';
  static const notFound = 'account_not_found';
}
