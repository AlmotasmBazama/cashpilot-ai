enum ReceiptWarning {
  lowImageQuality,
  unreadableText,
  missingTotal,
  arithmeticMismatch,
  currencyUnclear,
  dateUnclear,
  merchantUnclear,
  duplicatePossible,
  itemTotalMismatch,
  unsupportedDocument,
  paymentStatusUnclear,
  negativeValue,
  partialExtraction,
  other,
}

extension ReceiptWarningX on ReceiptWarning {
  String get storageValue {
    return switch (this) {
      ReceiptWarning.lowImageQuality => 'low_image_quality',
      ReceiptWarning.unreadableText => 'unreadable_text',
      ReceiptWarning.missingTotal => 'missing_total',
      ReceiptWarning.arithmeticMismatch => 'arithmetic_mismatch',
      ReceiptWarning.currencyUnclear => 'currency_unclear',
      ReceiptWarning.dateUnclear => 'date_unclear',
      ReceiptWarning.merchantUnclear => 'merchant_unclear',
      ReceiptWarning.duplicatePossible => 'duplicate_possible',
      ReceiptWarning.itemTotalMismatch => 'item_total_mismatch',
      ReceiptWarning.unsupportedDocument => 'unsupported_document',
      ReceiptWarning.paymentStatusUnclear => 'payment_status_unclear',
      ReceiptWarning.negativeValue => 'negative_value',
      ReceiptWarning.partialExtraction => 'partial_extraction',
      ReceiptWarning.other => 'other',
    };
  }
}

abstract final class ReceiptWarningMapper {
  static ReceiptWarning fromStorage(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    return ReceiptWarning.values.firstWhere(
      (warning) =>
          warning.storageValue == normalized || warning.name == normalized,
      orElse: () => ReceiptWarning.other,
    );
  }
}
