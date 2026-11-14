enum AccountType {
  cash,
  bank,
  creditCard,
  debitCard,
  savings,
  investment,
  digitalWallet,
  crypto,
  other,
}

extension AccountTypeX on AccountType {
  String get storageValue => name;

  String get label {
    return switch (this) {
      AccountType.cash => 'Cash',
      AccountType.bank => 'Bank',
      AccountType.creditCard => 'Credit Card',
      AccountType.debitCard => 'Debit Card',
      AccountType.savings => 'Savings',
      AccountType.investment => 'Investment',
      AccountType.digitalWallet => 'Digital Wallet',
      AccountType.crypto => 'Crypto',
      AccountType.other => 'Other',
    };
  }
}

abstract final class AccountTypeMapper {
  static AccountType fromStorage(String value) {
    return AccountType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => throw FormatException('Unsupported account type: $value'),
    );
  }
}
