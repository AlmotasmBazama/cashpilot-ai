enum TransactionStatus { pending, posted, cancelled, failed }

extension TransactionStatusX on TransactionStatus {
  String get storageValue => name;
}

abstract final class TransactionStatusMapper {
  static TransactionStatus fromStorage(String value) {
    return TransactionStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => TransactionStatus.pending,
    );
  }
}
