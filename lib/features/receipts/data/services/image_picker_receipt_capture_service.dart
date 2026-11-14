import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/enums/receipt_image_source.dart';
import '../../domain/failures/receipt_failure_codes.dart';
import '../../domain/services/receipt_image_capture_service.dart';

class ImagePickerReceiptImageCaptureService
    implements ReceiptImageCaptureService {
  ImagePickerReceiptImageCaptureService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<CapturedReceiptImage?> captureFromCamera() {
    return _pick(ImageSource.camera);
  }

  @override
  Future<CapturedReceiptImage?> pickFromGallery() {
    return _pick(ImageSource.gallery);
  }

  @override
  Future<CapturedReceiptImage?> scanDocument() {
    throw const ReceiptException(
      code: ReceiptFailureCodes.unsupportedPlatform,
      safeMessage: 'Document scanning is unavailable on this device.',
    );
  }

  @override
  Future<ReceiptCaptureAvailability> checkAvailability(
    ReceiptImageSource source,
  ) async {
    if (!_isMobilePlatform) {
      return ReceiptCaptureAvailability.unsupportedPlatform;
    }
    if (source == ReceiptImageSource.documentScanner) {
      return ReceiptCaptureAvailability.unavailable;
    }
    return ReceiptCaptureAvailability.available;
  }

  Future<CapturedReceiptImage?> _pick(ImageSource source) async {
    if (!_isMobilePlatform) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.unsupportedPlatform,
        safeMessage: 'Receipt image capture is unsupported on this platform.',
      );
    }
    try {
      final file = await _picker.pickImage(
        source: source,
        requestFullMetadata: false,
      );
      if (file == null) {
        return null;
      }
      return CapturedReceiptImage(
        bytes: await file.readAsBytes(),
        suggestedMimeType: file.mimeType,
      );
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      if (code.contains('denied')) {
        throw const ReceiptException(
          code: ReceiptFailureCodes.permissionDenied,
          safeMessage: 'Image access was denied.',
        );
      }
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidImage,
        safeMessage: 'The image could not be opened.',
      );
    }
  }
}

class PermissionHandlerReceiptPermissionService
    implements ReceiptPermissionService {
  const PermissionHandlerReceiptPermissionService();

  @override
  Future<ReceiptPermissionState> statusFor(ReceiptImageSource source) async {
    if (!_isMobilePlatform) {
      return ReceiptPermissionState.unavailable;
    }
    if (source != ReceiptImageSource.camera) {
      // Android's system photo picker and iOS PHPicker do not require broad
      // library permission for user-selected images.
      return ReceiptPermissionState.granted;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // image_picker owns the iOS camera authorization prompt. Keeping it
      // behind the user's capture tap avoids a separate permission_handler
      // Pod macro and prevents an eager permission request.
      return ReceiptPermissionState.granted;
    }
    return _map(await Permission.camera.status);
  }

  @override
  Future<ReceiptPermissionState> requestFor(ReceiptImageSource source) async {
    if (source != ReceiptImageSource.camera) {
      return statusFor(source);
    }
    if (!_isMobilePlatform) {
      return ReceiptPermissionState.unavailable;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ReceiptPermissionState.granted;
    }
    return _map(await Permission.camera.request());
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  ReceiptPermissionState _map(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited ||
      PermissionStatus.provisional => ReceiptPermissionState.granted,
      PermissionStatus.denied => ReceiptPermissionState.denied,
      PermissionStatus.permanentlyDenied =>
        ReceiptPermissionState.permanentlyDenied,
      PermissionStatus.restricted => ReceiptPermissionState.restricted,
    };
  }
}

bool get _isMobilePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
