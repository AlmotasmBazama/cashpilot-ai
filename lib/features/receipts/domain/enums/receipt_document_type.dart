enum ReceiptDocumentType {
  purchaseReceipt,
  invoice,
  creditNote,
  refundReceipt,
  utilityBill,
  paymentConfirmation,
  unknown,
}

extension ReceiptDocumentTypeX on ReceiptDocumentType {
  String get storageValue {
    return switch (this) {
      ReceiptDocumentType.purchaseReceipt => 'purchase_receipt',
      ReceiptDocumentType.creditNote => 'credit_note',
      ReceiptDocumentType.refundReceipt => 'refund_receipt',
      ReceiptDocumentType.utilityBill => 'utility_bill',
      ReceiptDocumentType.paymentConfirmation => 'payment_confirmation',
      _ => name,
    };
  }

  bool get permitsNegativeValues =>
      this == ReceiptDocumentType.creditNote ||
      this == ReceiptDocumentType.refundReceipt;
}

abstract final class ReceiptDocumentTypeMapper {
  static ReceiptDocumentType? tryFromStorage(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('-', '_');
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return ReceiptDocumentType.values.where((type) {
      return type.storageValue == normalized || type.name == normalized;
    }).firstOrNull;
  }
}
