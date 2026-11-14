import 'dart:async';

import '../config/receipt_image_config.dart';
import '../entities/prepared_receipt_image.dart';
import '../failures/receipt_failure_codes.dart';
import '../services/receipt_image_capture_service.dart';
import '../services/receipt_image_preparation_worker.dart';

final class ReceiptImagePreparationCancelledException implements Exception {
  const ReceiptImagePreparationCancelledException();
}

class PrepareReceiptImageUseCase {
  const PrepareReceiptImageUseCase({
    required ReceiptImagePreparationWorker worker,
    this.config = ReceiptImageConfig.standard,
  }) : _worker = worker;

  final ReceiptImagePreparationWorker _worker;
  final ReceiptImageConfig config;

  Future<PreparedReceiptImage> call(
    CapturedReceiptImage captured, {
    Future<void>? cancellationSignal,
  }) async {
    _validateSourceEnvelope(captured);
    final preparation = _worker.prepare(captured: captured, config: config);
    if (cancellationSignal == null) {
      return preparation;
    }
    final outcome = await Future.any<_ReceiptImagePreparationOutcome>(
      <Future<_ReceiptImagePreparationOutcome>>[
        preparation.then<_ReceiptImagePreparationOutcome>(
          _ReceiptImagePreparationCompleted.new,
          onError: (Object error, StackTrace stackTrace) =>
              _ReceiptImagePreparationFailed(error, stackTrace),
        ),
        cancellationSignal.then<_ReceiptImagePreparationOutcome>(
          (_) => const _ReceiptImagePreparationCancelled(),
        ),
      ],
    );
    switch (outcome) {
      case _ReceiptImagePreparationCompleted(:final image):
        return image;
      case _ReceiptImagePreparationFailed(:final error, :final stackTrace):
        Error.throwWithStackTrace(error, stackTrace);
      case _ReceiptImagePreparationCancelled():
        // compute() cannot be force-cancelled portably. Detach immediately and
        // purge any late sanitized bytes so an old owner cannot retain them.
        unawaited(
          preparation.then<void>(
            (image) => image.bytes.fillRange(0, image.bytes.length, 0),
            onError: (Object _, StackTrace _) {},
          ),
        );
        throw const ReceiptImagePreparationCancelledException();
    }
  }

  void _validateSourceEnvelope(CapturedReceiptImage captured) {
    final sourceMimeType = captured.suggestedMimeType
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (sourceMimeType != null &&
        sourceMimeType.isNotEmpty &&
        !config.supportedMimeTypes.contains(sourceMimeType)) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.unsupportedImage,
        safeMessage: 'Choose a JPEG, PNG, or WebP receipt image.',
      );
    }
    if (captured.bytes.isEmpty ||
        captured.bytes.length > config.maxFileBytes * 4) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidImage,
        safeMessage: 'The selected image is empty or too large.',
      );
    }
  }
}

sealed class _ReceiptImagePreparationOutcome {
  const _ReceiptImagePreparationOutcome();
}

final class _ReceiptImagePreparationCompleted
    extends _ReceiptImagePreparationOutcome {
  const _ReceiptImagePreparationCompleted(this.image);

  final PreparedReceiptImage image;
}

final class _ReceiptImagePreparationFailed
    extends _ReceiptImagePreparationOutcome {
  const _ReceiptImagePreparationFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

final class _ReceiptImagePreparationCancelled
    extends _ReceiptImagePreparationOutcome {
  const _ReceiptImagePreparationCancelled();
}
