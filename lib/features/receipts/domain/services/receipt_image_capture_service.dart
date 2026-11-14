import '../enums/receipt_image_source.dart';

class CapturedReceiptImage {
  const CapturedReceiptImage({
    required this.bytes,
    required this.suggestedMimeType,
  });

  final List<int> bytes;
  final String? suggestedMimeType;
}

abstract interface class ReceiptImageCaptureService {
  Future<CapturedReceiptImage?> captureFromCamera();

  Future<CapturedReceiptImage?> pickFromGallery();

  Future<CapturedReceiptImage?> scanDocument();

  Future<ReceiptCaptureAvailability> checkAvailability(
    ReceiptImageSource source,
  );
}

abstract interface class ReceiptPermissionService {
  Future<ReceiptPermissionState> statusFor(ReceiptImageSource source);

  Future<ReceiptPermissionState> requestFor(ReceiptImageSource source);

  Future<bool> openSettings();
}
