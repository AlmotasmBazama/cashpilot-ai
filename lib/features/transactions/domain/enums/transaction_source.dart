enum TransactionSource {
  manual,
  imported,
  recurring,
  aiGenerated,
  cloudSync,
  system,
}

extension TransactionSourceX on TransactionSource {
  String get storageValue => name;
}

abstract final class TransactionSourceMapper {
  static TransactionSource fromStorage(String value) {
    return TransactionSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => TransactionSource.manual,
    );
  }
}
