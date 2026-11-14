enum TransactionType { expense, income, transferOut, transferIn }

extension TransactionTypeX on TransactionType {
  String get storageValue => name;
}

abstract final class TransactionTypeMapper {
  static TransactionType fromStorage(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () =>
          throw FormatException('Unsupported transaction type: $value'),
    );
  }
}
