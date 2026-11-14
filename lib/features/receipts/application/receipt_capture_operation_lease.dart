import 'dart:async';

import '../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../core/owner_scope/domain/owner_scope.dart';
import '../../../core/sync/application/backup_operation_fence.dart';
import '../domain/entities/prepared_receipt_image.dart';
import '../domain/repositories/receipt_repository.dart';
import '../domain/usecases/analyze_receipt_image.dart';

typedef AcquireReceiptImage =
    Future<PreparedReceiptImage?> Function({Future<void>? cancellationSignal});

typedef DeleteReceiptImageReference = Future<void> Function(String? reference);

/// Feature-internal lease for one owner-bound receipt capture operation.
///
/// It owns only cancellation, sensitive byte purging, local-image cleanup and
/// writer release. The controller remains responsible for stage transitions,
/// repository ordering, analysis and user-visible failure mapping.
final class ReceiptCaptureOperationLease {
  ReceiptCaptureOperationLease({
    required this.generation,
    required this.ownerScope,
    required this.authSessionGeneration,
    required this.session,
    required BackupWriterLease writer,
    required this.repository,
    required AcquireReceiptImage acquireImage,
    required this.analyzeReceipt,
    required bool Function() hasRemoteConsent,
    required DeleteReceiptImageReference deleteImageReference,
  }) : _writer = writer,
       _acquireImage = acquireImage,
       _hasRemoteConsent = hasRemoteConsent,
       _deleteImageReference = deleteImageReference;

  final int generation;
  final ConfirmedOwnerScope ownerScope;
  final int authSessionGeneration;
  final ScopedAppDatabaseSession session;
  final BackupWriterLease _writer;
  final ReceiptRepository repository;
  final AcquireReceiptImage _acquireImage;
  final AnalyzeReceiptImageUseCase? analyzeReceipt;
  final bool Function() _hasRemoteConsent;
  final DeleteReceiptImageReference _deleteImageReference;

  PreparedReceiptImage? _preparedImage;
  String? _localImageReference;
  bool _isCancelled = false;
  final Completer<void> _cancelled = Completer<void>();
  Future<void>? _cleanup;

  bool get isCancelled => _isCancelled;

  bool get isWriterCancelled => _writer.isCancelled;

  Future<void> get whenCancelled => _cancelled.future;

  bool get hasCurrentRemoteConsent => !_isCancelled && _hasRemoteConsent();

  Future<PreparedReceiptImage?> acquireImage({
    Future<void>? cancellationSignal,
  }) {
    return _acquireImage(cancellationSignal: cancellationSignal);
  }

  void trackPreparedImage(PreparedReceiptImage? image) {
    _preparedImage = image;
  }

  void trackLocalImageReference(String reference) {
    _localImageReference = reference;
  }

  String? detachLocalImageReference() {
    final reference = _localImageReference;
    _localImageReference = null;
    return reference;
  }

  void retainLocalImageReference() {
    _localImageReference = null;
  }

  Future<void> deleteImageReference(String? reference) {
    return _deleteImageReference(reference);
  }

  void purgePreparedBytes() {
    final bytes = _preparedImage?.bytes;
    _preparedImage = null;
    if (bytes == null || bytes.isEmpty) {
      return;
    }
    try {
      bytes.fillRange(0, bytes.length, 0);
    } on Object {
      // Dropping the final reference is the safe fallback for immutable bytes.
    }
  }

  void cancel() {
    _isCancelled = true;
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
    purgePreparedBytes();
    final reference = detachLocalImageReference();
    if (reference != null) {
      final previousCleanup = _cleanup;
      _cleanup = () async {
        if (previousCleanup != null) {
          await previousCleanup;
        }
        await _deleteReferenceSafely(reference);
      }();
    }
  }

  Future<void> _deleteReferenceSafely(String reference) async {
    try {
      await _deleteImageReference(reference);
    } on Object {
      // Cleanup is best-effort and must not revive a cancelled capture.
    }
  }

  Future<void> waitForCleanup() => _cleanup ?? Future<void>.value();

  void releaseWriter() => _writer.release();
}
