import 'package:decimal/decimal.dart';

import 'receipt_analysis_draft.dart';

class ReceiptValidationResult {
  const ReceiptValidationResult({
    required this.draft,
    required this.lineItemsTotal,
    required this.expectedTotal,
    required this.isReadyForConfirmation,
  });

  final ReceiptAnalysisDraft draft;
  final Decimal? lineItemsTotal;
  final Decimal? expectedTotal;
  final bool isReadyForConfirmation;
}
