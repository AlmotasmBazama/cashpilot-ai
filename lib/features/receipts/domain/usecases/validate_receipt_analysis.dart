import '../entities/receipt_analysis_draft.dart';
import '../entities/receipt_validation_result.dart';
import '../services/receipt_arithmetic_validator.dart';

class ValidateReceiptAnalysisUseCase {
  const ValidateReceiptAnalysisUseCase({
    ReceiptArithmeticValidator validator = const ReceiptArithmeticValidator(),
  }) : _validator = validator;

  final ReceiptArithmeticValidator _validator;

  ReceiptValidationResult call(ReceiptAnalysisDraft draft) {
    return _validator.validate(draft);
  }
}
