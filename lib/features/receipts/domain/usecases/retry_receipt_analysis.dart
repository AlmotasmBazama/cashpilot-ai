import '../../../../core/error/result.dart';
import '../../../categories/domain/entities/category.dart';
import '../entities/prepared_receipt_image.dart';
import '../entities/receipt_analysis_draft.dart';
import '../repositories/receipt_analysis_provider.dart';
import 'analyze_receipt_image.dart';

class RetryReceiptAnalysisUseCase {
  const RetryReceiptAnalysisUseCase(this._analyze);

  final AnalyzeReceiptImageUseCase _analyze;

  Future<AppResult<ReceiptAnalysisDraft>> call({
    required ReceiptAnalysisDraft draft,
    required PreparedReceiptImage image,
    required ReceiptAnalysisContext context,
    required List<Category> categories,
  }) {
    return _analyze(
      draft: draft,
      image: image,
      context: context,
      categories: categories,
    );
  }
}
