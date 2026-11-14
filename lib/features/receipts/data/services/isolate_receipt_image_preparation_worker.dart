import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

import '../../domain/config/receipt_image_config.dart';
import '../../domain/entities/prepared_receipt_image.dart';
import '../../domain/failures/receipt_failure_codes.dart';
import '../../domain/services/receipt_image_capture_service.dart';
import '../../domain/services/receipt_image_preparation_worker.dart';

/// Uses Flutter's cross-platform compute boundary for receipt pixel work.
///
/// On isolate-capable platforms this runs in a worker isolate. Flutter's web
/// implementation yields before running the callback; receipt capture itself
/// is currently unavailable on web, so no web capture path performs this work.
final class IsolateReceiptImagePreparationWorker
    implements ReceiptImagePreparationWorker {
  const IsolateReceiptImagePreparationWorker();

  @override
  Future<PreparedReceiptImage> prepare({
    required CapturedReceiptImage captured,
    required ReceiptImageConfig config,
  }) async {
    final result =
        await compute<_ReceiptImageWorkRequest, _ReceiptImageWorkResult>(
          _prepareReceiptImage,
          _ReceiptImageWorkRequest(
            bytes: captured.bytes,
            suggestedMimeType: captured.suggestedMimeType,
            maxWidth: config.maxWidth,
            maxHeight: config.maxHeight,
            jpegQuality: config.jpegQuality,
            maxFileBytes: config.maxFileBytes,
            minimumReadableWidth: config.minimumReadableWidth,
            minimumReadableHeight: config.minimumReadableHeight,
            supportedMimeTypes: config.supportedMimeTypes,
          ),
          debugLabel: 'receipt-image-preparation',
        );
    if (result.failureCode case final code?) {
      throw ReceiptException(code: code, safeMessage: result.safeMessage!);
    }
    return PreparedReceiptImage(
      bytes: result.bytes!,
      mimeType: 'image/jpeg',
      width: result.width!,
      height: result.height!,
      sha256: result.sha256!,
    );
  }
}

final class _ReceiptImageWorkRequest {
  const _ReceiptImageWorkRequest({
    required this.bytes,
    required this.suggestedMimeType,
    required this.maxWidth,
    required this.maxHeight,
    required this.jpegQuality,
    required this.maxFileBytes,
    required this.minimumReadableWidth,
    required this.minimumReadableHeight,
    required this.supportedMimeTypes,
  });

  final List<int> bytes;
  final String? suggestedMimeType;
  final int maxWidth;
  final int maxHeight;
  final int jpegQuality;
  final int maxFileBytes;
  final int minimumReadableWidth;
  final int minimumReadableHeight;
  final List<String> supportedMimeTypes;
}

final class _ReceiptImageWorkResult {
  const _ReceiptImageWorkResult.success({
    required Uint8List this.bytes,
    required int this.width,
    required int this.height,
    required String this.sha256,
  }) : failureCode = null,
       safeMessage = null;

  const _ReceiptImageWorkResult.failure({
    required String this.failureCode,
    required String this.safeMessage,
  }) : bytes = null,
       width = null,
       height = null,
       sha256 = null;

  final Uint8List? bytes;
  final int? width;
  final int? height;
  final String? sha256;
  final String? failureCode;
  final String? safeMessage;
}

_ReceiptImageWorkResult _prepareReceiptImage(_ReceiptImageWorkRequest request) {
  final sourceMimeType = request.suggestedMimeType
      ?.split(';')
      .first
      .trim()
      .toLowerCase();
  if (sourceMimeType != null &&
      sourceMimeType.isNotEmpty &&
      !request.supportedMimeTypes.contains(sourceMimeType)) {
    return const _ReceiptImageWorkResult.failure(
      failureCode: ReceiptFailureCodes.unsupportedImage,
      safeMessage: 'Choose a JPEG, PNG, or WebP receipt image.',
    );
  }
  final sourceBytes = Uint8List.fromList(request.bytes);
  if (sourceBytes.isEmpty || sourceBytes.length > request.maxFileBytes * 4) {
    return const _ReceiptImageWorkResult.failure(
      failureCode: ReceiptFailureCodes.invalidImage,
      safeMessage: 'The selected image is empty or too large.',
    );
  }

  final image.Image? decoded;
  try {
    decoded = image.decodeImage(sourceBytes, frame: 0);
  } on Object {
    return const _ReceiptImageWorkResult.failure(
      failureCode: ReceiptFailureCodes.invalidImage,
      safeMessage: 'The selected image could not be decoded.',
    );
  }
  if (decoded == null) {
    return const _ReceiptImageWorkResult.failure(
      failureCode: ReceiptFailureCodes.invalidImage,
      safeMessage: 'The selected image could not be decoded.',
    );
  }

  final oriented = image.bakeOrientation(decoded);
  if (oriented.width < request.minimumReadableWidth ||
      oriented.height < request.minimumReadableHeight) {
    return const _ReceiptImageWorkResult.failure(
      failureCode: ReceiptFailureCodes.lowResolution,
      safeMessage: 'The receipt image resolution is too low to read safely.',
    );
  }
  final resizeNeeded =
      oriented.width > request.maxWidth || oriented.height > request.maxHeight;
  final prepared = resizeNeeded
      ? image.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? request.maxWidth : null,
          height: oriented.height > oriented.width ? request.maxHeight : null,
          interpolation: image.Interpolation.average,
        )
      : oriented;

  // The image package preserves EXIF/ICC data through orientation and resize
  // operations. Remove every metadata carrier before the sanitized JPEG is
  // encoded; the user's original gallery asset remains untouched.
  prepared.exif.clear();
  prepared.iccProfile = null;
  prepared.textData = null;
  prepared.extraChannels = null;

  final encoded = Uint8List.fromList(
    image.encodeJpg(prepared, quality: request.jpegQuality),
  );
  if (encoded.isEmpty || encoded.length > request.maxFileBytes) {
    return const _ReceiptImageWorkResult.failure(
      failureCode: ReceiptFailureCodes.imageTooLarge,
      safeMessage: 'The prepared receipt image is too large to analyze.',
    );
  }
  return _ReceiptImageWorkResult.success(
    bytes: encoded,
    width: prepared.width,
    height: prepared.height,
    sha256: sha256.convert(encoded).toString(),
  );
}
