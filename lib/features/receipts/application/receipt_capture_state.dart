import '../../../core/error/failure.dart';
import '../domain/entities/receipt_analysis_draft.dart';

enum ReceiptCaptureStage {
  selectingAndPreparing,
  savingDraft,
  loadingContext,
  analyzing,
}

class ReceiptCaptureState {
  const ReceiptCaptureState({
    this.isBusy = false,
    this.stage,
    this.draft,
    this.failure,
  });

  final bool isBusy;
  final ReceiptCaptureStage? stage;
  final ReceiptAnalysisDraft? draft;
  final Failure? failure;

  ReceiptCaptureState copyWith({
    bool? isBusy,
    ReceiptAnalysisDraft? draft,
    Failure? failure,
    bool clearFailure = false,
    ReceiptCaptureStage? stage,
    bool clearStage = false,
  }) {
    return ReceiptCaptureState(
      isBusy: isBusy ?? this.isBusy,
      stage: clearStage ? null : stage ?? this.stage,
      draft: draft ?? this.draft,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
