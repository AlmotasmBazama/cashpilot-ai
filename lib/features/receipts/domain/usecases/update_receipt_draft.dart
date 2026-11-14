import '../../../../core/error/result.dart';
import '../entities/receipt_analysis_draft.dart';
import '../repositories/receipt_repository.dart';

class UpdateReceiptDraftUseCase {
  const UpdateReceiptDraftUseCase(this._repository);

  final ReceiptRepository _repository;

  Future<AppResult<ReceiptAnalysisDraft>> call(ReceiptAnalysisDraft draft) {
    return _repository.updateAnalysisDraft(draft);
  }
}
