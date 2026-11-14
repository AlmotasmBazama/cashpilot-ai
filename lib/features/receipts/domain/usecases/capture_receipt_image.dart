import '../entities/prepared_receipt_image.dart';
import '../enums/receipt_image_source.dart';
import '../failures/receipt_failure_codes.dart';
import '../services/receipt_image_capture_service.dart';
import 'prepare_receipt_image.dart';

class CaptureReceiptImageUseCase {
  const CaptureReceiptImageUseCase({
    required ReceiptImageCaptureService captureService,
    required ReceiptPermissionService permissionService,
    required PrepareReceiptImageUseCase prepareImage,
  }) : _captureService = captureService,
       _permissionService = permissionService,
       _prepareImage = prepareImage;

  final ReceiptImageCaptureService _captureService;
  final ReceiptPermissionService _permissionService;
  final PrepareReceiptImageUseCase _prepareImage;

  Future<PreparedReceiptImage?> call({Future<void>? cancellationSignal}) async {
    final availability = await _captureService.checkAvailability(
      ReceiptImageSource.camera,
    );
    if (availability != ReceiptCaptureAvailability.available) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.unsupportedPlatform,
        safeMessage: 'Camera receipt capture is unavailable.',
      );
    }
    final permission = await _permissionService.requestFor(
      ReceiptImageSource.camera,
    );
    if (permission != ReceiptPermissionState.granted) {
      throw ReceiptException(
        code: permission == ReceiptPermissionState.permanentlyDenied
            ? ReceiptFailureCodes.permissionPermanentlyDenied
            : ReceiptFailureCodes.permissionDenied,
        safeMessage: 'Camera permission is required to scan a receipt.',
      );
    }
    final captured = await _captureService.captureFromCamera();
    return captured == null
        ? null
        : _prepareImage(captured, cancellationSignal: cancellationSignal);
  }
}
