enum ReceiptDraftStatus {
  captured,
  analyzing,
  reviewRequired,
  readyForConfirmation,
  confirmed,
  failed,
  cancelled,
}

extension ReceiptDraftStatusX on ReceiptDraftStatus {
  String get storageValue {
    return switch (this) {
      ReceiptDraftStatus.reviewRequired => 'review_required',
      ReceiptDraftStatus.readyForConfirmation => 'ready_for_confirmation',
      _ => name,
    };
  }
}

abstract final class ReceiptDraftStatusMapper {
  static ReceiptDraftStatus fromStorage(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    return ReceiptDraftStatus.values.firstWhere(
      (status) =>
          status.storageValue == normalized || status.name == normalized,
      orElse: () => ReceiptDraftStatus.failed,
    );
  }
}
