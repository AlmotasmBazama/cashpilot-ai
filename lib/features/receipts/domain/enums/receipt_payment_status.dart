enum ReceiptPaymentStatus { paid, unpaid, partiallyPaid, unclear }

extension ReceiptPaymentStatusX on ReceiptPaymentStatus {
  String get storageValue {
    return this == ReceiptPaymentStatus.partiallyPaid ? 'partially_paid' : name;
  }
}

abstract final class ReceiptPaymentStatusMapper {
  static ReceiptPaymentStatus fromStorage(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('-', '_');
    return ReceiptPaymentStatus.values.firstWhere(
      (status) =>
          status.storageValue == normalized || status.name == normalized,
      orElse: () => ReceiptPaymentStatus.unclear,
    );
  }
}
