import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cashpilot_ai/features/receipts/data/services/isolate_receipt_image_preparation_worker.dart';
import 'package:cashpilot_ai/features/receipts/domain/config/receipt_image_config.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/prepared_receipt_image.dart';
import 'package:cashpilot_ai/features/receipts/domain/failures/receipt_failure_codes.dart';
import 'package:cashpilot_ai/features/receipts/domain/services/receipt_image_capture_service.dart';
import 'package:cashpilot_ai/features/receipts/domain/services/receipt_image_preparation_worker.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/prepare_receipt_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  const useCase = PrepareReceiptImageUseCase(
    worker: IsolateReceiptImagePreparationWorker(),
  );

  test('valid receipt is normalized to a deterministic JPEG result', () async {
    final source = _solidImage(width: 800, height: 1000);
    final sourceBytes = image.encodePng(source);

    final prepared = await useCase(
      CapturedReceiptImage(
        bytes: sourceBytes,
        suggestedMimeType: 'image/png; charset=binary',
      ),
    );

    expect(prepared.mimeType, 'image/jpeg');
    expect(prepared.width, 800);
    expect(prepared.height, 1000);
    expect(prepared.sha256, sha256.convert(prepared.bytes).toString());
    expect(image.decodeJpg(prepared.bytes), isNotNull);
  });

  test(
    'large receipt is resized within bounds and keeps aspect ratio',
    () async {
      final source = _solidImage(width: 3000, height: 1500);

      final prepared = await useCase(
        CapturedReceiptImage(
          bytes: image.encodePng(source),
          suggestedMimeType: 'image/png',
        ),
      );

      expect(prepared.width, 2048);
      expect(prepared.height, 1024);
      expect(prepared.bytes.length, lessThan(8 * 1024 * 1024));
    },
  );

  test('invalid image bytes return the existing typed safe failure', () async {
    await expectLater(
      useCase(
        const CapturedReceiptImage(
          bytes: <int>[1, 2, 3, 4],
          suggestedMimeType: 'image/jpeg',
        ),
      ),
      throwsA(
        isA<ReceiptException>()
            .having(
              (error) => error.code,
              'code',
              ReceiptFailureCodes.invalidImage,
            )
            .having(
              (error) => error.safeMessage,
              'safeMessage',
              'The selected image could not be decoded.',
            ),
      ),
    );
  });

  test('orientation is baked and private image metadata is removed', () async {
    const privateDescription = 'private-receipt-location-and-device';
    final source = _solidImage(width: 600, height: 800)
      ..exif.imageIfd.orientation = 6
      ..exif.imageIfd.imageDescription = privateDescription
      ..textData = <String, String>{'Comment': privateDescription};
    final sourceBytes = image.encodeJpg(source, quality: 95);
    expect(
      image.decodeJpgExif(sourceBytes)?.imageIfd.imageDescription,
      privateDescription,
    );

    final prepared = await useCase(
      CapturedReceiptImage(bytes: sourceBytes, suggestedMimeType: 'image/jpeg'),
    );

    expect(prepared.width, 800);
    expect(prepared.height, 600);
    final outputExif = image.decodeJpgExif(prepared.bytes);
    expect(outputExif == null || outputExif.isEmpty, isTrue);
    expect(
      utf8.decode(prepared.bytes, allowMalformed: true),
      isNot(contains(privateDescription)),
    );
  });

  test('low-resolution dimensions are rejected after orientation', () async {
    final source = _solidImage(width: 479, height: 800);

    await expectLater(
      useCase(
        CapturedReceiptImage(
          bytes: image.encodePng(source),
          suggestedMimeType: 'image/png',
        ),
      ),
      throwsA(
        isA<ReceiptException>().having(
          (error) => error.code,
          'code',
          ReceiptFailureCodes.lowResolution,
        ),
      ),
    );
  });

  test(
    'cancellation detaches immediately and purges a late worker result',
    () async {
      final worker = _ControlledPreparationWorker();
      final cancellableUseCase = PrepareReceiptImageUseCase(worker: worker);
      final cancellation = Completer<void>();
      final operation = cancellableUseCase(
        const CapturedReceiptImage(
          bytes: <int>[1],
          suggestedMimeType: 'image/jpeg',
        ),
        cancellationSignal: cancellation.future,
      );
      await worker.started.future;

      cancellation.complete();
      await expectLater(
        operation.timeout(const Duration(seconds: 1)),
        throwsA(isA<ReceiptImagePreparationCancelledException>()),
      );
      expect(worker.isCompleted, isFalse);

      final lateBytes = Uint8List.fromList(<int>[9, 8, 7]);
      worker.complete(
        PreparedReceiptImage(
          bytes: lateBytes,
          mimeType: 'image/jpeg',
          width: 800,
          height: 1000,
          sha256: 'hash',
        ),
      );
      await pumpEventQueue();

      expect(lateBytes, everyElement(0));
    },
  );
}

image.Image _solidImage({required int width, required int height}) {
  final source = image.Image(width: width, height: height);
  image.fill(source, color: image.ColorRgb8(248, 248, 248));
  return source;
}

final class _ControlledPreparationWorker
    implements ReceiptImagePreparationWorker {
  final Completer<void> started = Completer<void>();
  final Completer<PreparedReceiptImage> _result =
      Completer<PreparedReceiptImage>();

  bool get isCompleted => _result.isCompleted;

  void complete(PreparedReceiptImage image) {
    _result.complete(image);
  }

  @override
  Future<PreparedReceiptImage> prepare({
    required CapturedReceiptImage captured,
    required ReceiptImageConfig config,
  }) {
    started.complete();
    return _result.future;
  }
}
