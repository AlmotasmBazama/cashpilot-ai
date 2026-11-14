import '../entities/prepared_receipt_image.dart';
import '../enums/receipt_image_source.dart';
import '../failures/receipt_failure_codes.dart';
import '../services/receipt_image_capture_service.dart';
import 'prepare_receipt_image.dart';

class ImportReceiptImageUseCase {
  const ImportReceiptImageUseCase({
    required ReceiptImageCaptureService captureService,
    required PrepareReceiptImageUseCase prepareImage,
  }) : _captureService = captureService,
       _prepareImage = prepareImage;

  final ReceiptImageCaptureService _captureService;
  final PrepareReceiptImageUseCase _prepareImage;

  Future<PreparedReceiptImage?> call({Future<void>? cancellationSignal}) async {
    final availability = await _captureService.checkAvailability(
      ReceiptImageSource.gallery,
    );
    if (availability != ReceiptCaptureAvailability.available) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.unsupportedPlatform,
        safeMessage: 'Receipt image import is unavailable.',
      );
    }
    final captured = await _captureService.pickFromGallery();
    return captured == null
        ? null
        : _prepareImage(captured, cancellationSignal: cancellationSignal);
  }
}
