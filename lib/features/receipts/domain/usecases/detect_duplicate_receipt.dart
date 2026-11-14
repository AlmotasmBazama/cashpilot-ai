import '../../../../core/error/result.dart';
import '../entities/receipt_analysis_draft.dart';
import '../entities/receipt_duplicate_result.dart';
import '../repositories/receipt_repository.dart';

class DetectDuplicateReceiptUseCase {
  const DetectDuplicateReceiptUseCase(this._repository);

  final ReceiptRepository _repository;

  Future<AppResult<ReceiptDuplicateResult>> call(ReceiptAnalysisDraft draft) {
    return _repository.findDuplicateCandidates(draft);
  }
}
