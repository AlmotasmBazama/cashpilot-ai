import '../entities/prepared_receipt_image.dart';
import '../entities/receipt_analysis_draft.dart';

class ReceiptAnalysisContext {
  const ReceiptAnalysisContext({
    required this.supportedCurrencies,
    required this.categoryDescriptions,
    required this.locale,
  });

  final List<String> supportedCurrencies;
  final List<String> categoryDescriptions;
  final String locale;
}

abstract interface class ReceiptAnalysisProvider {
  Future<ReceiptAnalysisDraft> analyzeReceipt({
    required String draftId,
    required PreparedReceiptImage image,
    required ReceiptAnalysisContext context,
    required void Function() assertEgressAllowed,
  });

  Future<bool> validateAvailability();

  Object get modelConfig;
}
