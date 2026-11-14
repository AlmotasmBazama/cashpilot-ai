abstract final class ReceiptFailureCodes {
  static const invalidImage = 'receipt_invalid_image';
  static const imageTooLarge = 'receipt_image_too_large';
  static const lowResolution = 'receipt_low_resolution';
  static const unsupportedImage = 'receipt_unsupported_image';
  static const permissionDenied = 'receipt_permission_denied';
  static const permissionPermanentlyDenied =
      'receipt_permission_permanently_denied';
  static const unsupportedPlatform = 'receipt_unsupported_platform';
  static const analysisInProgress = 'receipt_analysis_in_progress';
  static const duplicateAnalysis = 'receipt_duplicate_analysis';
  static const appCheckBlocked = 'receipt_app_check_blocked';
  static const rateLimited = 'receipt_rate_limited';
  static const networkFailure = 'receipt_network_failure';
  static const timeout = 'receipt_timeout';
  static const invalidJson = 'receipt_invalid_json';
  static const unsupportedSchema = 'receipt_unsupported_schema';
  static const unreadable = 'receipt_unreadable';
  static const providerUnavailable = 'receipt_provider_unavailable';
  static const contentRejected = 'receipt_content_rejected';
  static const missingTotal = 'receipt_missing_total';
  static const currencyMismatch = 'receipt_currency_mismatch';
  static const confirmationRequired = 'receipt_confirmation_required';
  static const alreadyConfirmed = 'receipt_already_confirmed';
  static const invalidDraft = 'receipt_invalid_draft';
  static const persistenceFailed = 'receipt_persistence_failed';
  static const metadataFinalizationPending =
      'receipt_metadata_finalization_pending';
  static const imageCleanupPending = 'receipt_image_cleanup_pending';
  static const transactionReservationConflict =
      'receipt_transaction_reservation_conflict';
}

class ReceiptException implements Exception {
  const ReceiptException({required this.code, required this.safeMessage});

  final String code;
  final String safeMessage;

  @override
  String toString() => 'ReceiptException($code)';
}
