import '../config/receipt_image_config.dart';
import '../entities/prepared_receipt_image.dart';
import 'receipt_image_capture_service.dart';

/// Executes receipt pixel processing away from the caller's UI work.
abstract interface class ReceiptImagePreparationWorker {
  Future<PreparedReceiptImage> prepare({
    required CapturedReceiptImage captured,
    required ReceiptImageConfig config,
  });
}
