import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_image_source.dart';
import 'package:cashpilot_ai/features/receipts/domain/failures/receipt_failure_codes.dart';
import 'package:cashpilot_ai/features/receipts/data/services/isolate_receipt_image_preparation_worker.dart';
import 'package:cashpilot_ai/features/receipts/domain/services/receipt_image_capture_service.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/capture_receipt_image.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/import_receipt_image.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/prepare_receipt_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('camera permission denial stops capture before image access', () async {
    final capture = _FakeCaptureService();
    final permission = _FakePermissionService(
      state: ReceiptPermissionState.denied,
    );
    final useCase = CaptureReceiptImageUseCase(
      captureService: capture,
      permissionService: permission,
      prepareImage: const PrepareReceiptImageUseCase(
        worker: IsolateReceiptImagePreparationWorker(),
      ),
    );

    await expectLater(
      useCase(),
      throwsA(
        isA<ReceiptException>().having(
          (error) => error.code,
          'code',
          ReceiptFailureCodes.permissionDenied,
        ),
      ),
    );
    expect(permission.requestCount, 1);
    expect(capture.cameraCount, 0);
  });

  test(
    'gallery import needs no broad permission service and prepares JPEG',
    () async {
      final capture = _FakeCaptureService(image: _readableImage());
      final useCase = ImportReceiptImageUseCase(
        captureService: capture,
        prepareImage: const PrepareReceiptImageUseCase(
          worker: IsolateReceiptImagePreparationWorker(),
        ),
      );

      final prepared = await useCase();

      expect(capture.galleryCount, 1);
      expect(prepared?.mimeType, 'image/jpeg');
      expect(prepared?.sha256, hasLength(64));
    },
  );

  test('unreadable selected bytes fail safely', () async {
    await expectLater(
      const PrepareReceiptImageUseCase(
        worker: IsolateReceiptImagePreparationWorker(),
      )(
        const CapturedReceiptImage(
          bytes: <int>[1, 2, 3],
          suggestedMimeType: 'image/jpeg',
        ),
      ),
      throwsA(
        isA<ReceiptException>().having(
          (error) => error.code,
          'code',
          ReceiptFailureCodes.invalidImage,
        ),
      ),
    );
  });
}

CapturedReceiptImage _readableImage() {
  final source = image.Image(width: 800, height: 1000);
  image.fill(source, color: image.ColorRgb8(255, 255, 255));
  return CapturedReceiptImage(
    bytes: image.encodePng(source),
    suggestedMimeType: 'image/png',
  );
}

class _FakeCaptureService implements ReceiptImageCaptureService {
  _FakeCaptureService({this.image});

  final CapturedReceiptImage? image;
  int cameraCount = 0;
  int galleryCount = 0;

  @override
  Future<ReceiptCaptureAvailability> checkAvailability(
    ReceiptImageSource source,
  ) async {
    return ReceiptCaptureAvailability.available;
  }

  @override
  Future<CapturedReceiptImage?> captureFromCamera() async {
    cameraCount += 1;
    return image;
  }

  @override
  Future<CapturedReceiptImage?> pickFromGallery() async {
    galleryCount += 1;
    return image;
  }

  @override
  Future<CapturedReceiptImage?> scanDocument() async => null;
}

class _FakePermissionService implements ReceiptPermissionService {
  _FakePermissionService({required this.state});

  final ReceiptPermissionState state;
  int requestCount = 0;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<ReceiptPermissionState> requestFor(ReceiptImageSource source) async {
    requestCount += 1;
    return state;
  }

  @override
  Future<ReceiptPermissionState> statusFor(ReceiptImageSource source) async {
    return state;
  }
}
