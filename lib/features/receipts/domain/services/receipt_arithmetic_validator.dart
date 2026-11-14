import 'package:decimal/decimal.dart';

import '../entities/receipt_analysis_draft.dart';
import '../entities/receipt_line_item.dart';
import '../entities/receipt_validation_result.dart';
import '../enums/receipt_document_type.dart';
import '../enums/receipt_draft_status.dart';
import '../enums/receipt_warning.dart';

class ReceiptArithmeticValidator {
  const ReceiptArithmeticValidator();

  ReceiptValidationResult validate(ReceiptAnalysisDraft draft) {
    final draftWarnings = draft.warnings.toSet();
    final validatedItems = <ReceiptLineItem>[];
    var hasLineTotals = false;
    var lineItemsTotal = Decimal.zero;
    for (final item in draft.lineItems) {
      final warnings = item.warnings.toSet();
      final quantity = item.quantity;
      final unitPrice = item.unitPrice;
      final total = item.totalPrice;
      if (quantity != null && quantity <= Decimal.zero) {
        warnings.add(ReceiptWarning.negativeValue);
      }
      for (final value in <Decimal?>[
        unitPrice,
        item.discount,
        item.tax,
        total,
      ]) {
        if (value != null &&
            value < Decimal.zero &&
            !draft.documentType.permitsNegativeValues) {
          warnings.add(ReceiptWarning.negativeValue);
        }
      }
      if (total != null) {
        hasLineTotals = true;
        lineItemsTotal += total;
      }
      if (quantity != null && unitPrice != null && total != null) {
        final expected =
            quantity * unitPrice -
            (item.discount ?? Decimal.zero) +
            (item.tax ?? Decimal.zero);
        if (!_withinTolerance(expected, total)) {
          warnings.add(ReceiptWarning.itemTotalMismatch);
          draftWarnings.add(ReceiptWarning.itemTotalMismatch);
        }
      }
      validatedItems.add(
        item.copyWith(warnings: warnings.toList(growable: false)),
      );
    }

    final subtotal = draft.subtotal;
    if (subtotal != null &&
        hasLineTotals &&
        !_withinTolerance(subtotal, lineItemsTotal)) {
      draftWarnings.add(ReceiptWarning.arithmeticMismatch);
    }
    final effectiveSubtotal =
        subtotal ?? (hasLineTotals ? lineItemsTotal : null);
    final expectedTotal = effectiveSubtotal == null
        ? null
        : effectiveSubtotal +
              (draft.tax ?? Decimal.zero) +
              (draft.serviceCharge ?? Decimal.zero) +
              (draft.tip ?? Decimal.zero) +
              (draft.otherFees ?? Decimal.zero) -
              (draft.discount ?? Decimal.zero);
    if (draft.total == null) {
      draftWarnings.add(ReceiptWarning.missingTotal);
    } else if (expectedTotal != null &&
        !_withinTolerance(expectedTotal, draft.total!)) {
      draftWarnings.add(ReceiptWarning.arithmeticMismatch);
    }
    if (draft.total case final total?) {
      final amountPaid = draft.amountPaid;
      final amountDue = draft.amountDue;
      if (amountPaid != null &&
          amountDue != null &&
          !_withinTolerance(amountPaid + amountDue, total)) {
        draftWarnings.add(ReceiptWarning.arithmeticMismatch);
      }
    }

    final ready =
        draft.total != null &&
        draft.currency != null &&
        draft.documentType != ReceiptDocumentType.unknown &&
        !draft.needsPaymentClarification &&
        !draftWarnings.contains(ReceiptWarning.negativeValue);
    final validated = draft.copyWith(
      lineItems: validatedItems,
      warnings: draftWarnings.toList(growable: false),
      status: ready
          ? ReceiptDraftStatus.readyForConfirmation
          : ReceiptDraftStatus.reviewRequired,
    );
    return ReceiptValidationResult(
      draft: validated,
      lineItemsTotal: hasLineTotals ? lineItemsTotal : null,
      expectedTotal: expectedTotal,
      isReadyForConfirmation: ready,
    );
  }

  bool _withinTolerance(Decimal left, Decimal right) {
    return (left - right).abs() <= Decimal.parse('0.01');
  }
}
