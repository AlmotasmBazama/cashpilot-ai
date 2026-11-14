import 'package:decimal/decimal.dart';

import '../entities/receipt_analysis_draft.dart';
import '../enums/receipt_draft_status.dart';

class RecalculateReceiptTotalsUseCase {
  const RecalculateReceiptTotalsUseCase();

  ReceiptAnalysisDraft call(ReceiptAnalysisDraft draft) {
    final lineTotal = draft.lineItems
        .map((item) => item.totalPrice)
        .whereType<Decimal>()
        .fold<Decimal>(Decimal.zero, (sum, amount) => sum + amount);
    final subtotal = draft.lineItems.any((item) => item.totalPrice != null)
        ? lineTotal
        : draft.subtotal;
    final total = subtotal == null
        ? null
        : subtotal +
              (draft.tax ?? Decimal.zero) +
              (draft.serviceCharge ?? Decimal.zero) +
              (draft.tip ?? Decimal.zero) +
              (draft.otherFees ?? Decimal.zero) -
              (draft.discount ?? Decimal.zero);
    return draft.copyWith(
      subtotal: subtotal,
      total: total,
      status: ReceiptDraftStatus.reviewRequired,
    );
  }
}
