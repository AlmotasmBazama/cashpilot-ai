import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../finance_engine/domain/exceptions/finance_exception.dart';
import '../../../finance_engine/domain/services/finance_validation_service.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../payment_methods/payment_methods.dart' show PaymentMethod;
import '../../../transactions/domain/enums/transaction_source.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../entities/receipt_analysis_draft.dart';
import '../entities/receipt_transaction_draft.dart';
import '../enums/receipt_document_type.dart';
import '../enums/receipt_payment_status.dart';
import '../failures/receipt_failure_codes.dart';
import '../services/receipt_split_allocator.dart';

class BuildReceiptTransactionDraftUseCase {
  const BuildReceiptTransactionDraftUseCase({
    ReceiptSplitAllocator splitAllocator = const ReceiptSplitAllocator(),
    FinanceValidationService financeValidationService =
        const FinanceValidationService(),
  }) : _splitAllocator = splitAllocator,
       _financeValidationService = financeValidationService;

  final ReceiptSplitAllocator _splitAllocator;
  final FinanceValidationService _financeValidationService;

  ReceiptTransactionDraft call({
    required ReceiptAnalysisDraft draft,
    required Account account,
    required List<Category> categories,
    required PaymentMethod paymentMethod,
    required bool warningsAcknowledged,
    bool duplicateAcknowledged = false,
    Money? explicitAccountAmount,
    ExchangeRate? explicitExchangeRate,
  }) {
    if (draft.total == null || draft.currency == null) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.missingTotal,
        safeMessage: 'Review the receipt total and currency first.',
      );
    }
    if (draft.documentType == ReceiptDocumentType.unknown ||
        draft.documentType == ReceiptDocumentType.paymentConfirmation) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidDraft,
        safeMessage:
            'This document cannot create a new transaction automatically.',
      );
    }
    if (draft.paymentStatus == ReceiptPaymentStatus.partiallyPaid ||
        draft.needsPaymentClarification) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidDraft,
        safeMessage: 'Clarify the invoice payment status before continuing.',
      );
    }
    if (draft.warnings.isNotEmpty && !warningsAcknowledged) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.confirmationRequired,
        safeMessage: 'Acknowledge the receipt warnings before continuing.',
      );
    }
    if (draft.duplicateCandidateIds.isNotEmpty && !duplicateAcknowledged) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.confirmationRequired,
        safeMessage: 'Review and acknowledge the possible duplicate first.',
      );
    }

    final receiptCurrency = draft.currency!.toUpperCase();
    final accountCurrency = account.currencyCode.toUpperCase();
    final crossCurrency = receiptCurrency != accountCurrency;
    final hasExplicitAmount = explicitAccountAmount != null;
    final hasExplicitRate = explicitExchangeRate != null;
    if (hasExplicitAmount != hasExplicitRate ||
        (crossCurrency && !hasExplicitAmount)) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.currencyMismatch,
        safeMessage:
            'Enter the account amount and exchange rate for this receipt.',
      );
    }
    if (explicitAccountAmount != null &&
        explicitAccountAmount.currencyCode.toUpperCase() != accountCurrency) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.currencyMismatch,
        safeMessage: 'The converted amount must use the account currency.',
      );
    }
    if (explicitAccountAmount != null && explicitExchangeRate != null) {
      try {
        _financeValidationService.validateTransferAmountRateConsistency(
          sourceAmount: Money(
            amount: draft.total!.abs(),
            currencyCode: receiptCurrency,
          ),
          targetAmount: explicitAccountAmount,
          exchangeRate: explicitExchangeRate,
        );
      } on FinanceException {
        throw const ReceiptException(
          code: ReceiptFailureCodes.currencyMismatch,
          safeMessage:
              'The converted amount and exchange rate must match exactly.',
        );
      }
    }

    final isRefund =
        draft.documentType == ReceiptDocumentType.refundReceipt ||
        draft.documentType == ReceiptDocumentType.creditNote;
    final transactionType = isRefund
        ? TransactionType.income
        : TransactionType.expense;
    final splits = _splitAllocator.allocate(draft);
    final primaryCategory = isRefund
        ? _categoryByName(categories, 'Refund', CategoryType.income)
        : _categoryById(categories, splits.first.categoryId);
    if (primaryCategory == null) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidDraft,
        safeMessage: 'Choose valid categories before continuing.',
      );
    }
    final status =
        draft.isInvoice && draft.paymentStatus == ReceiptPaymentStatus.unpaid
        ? TransactionStatus.pending
        : TransactionStatus.posted;
    final amount =
        explicitAccountAmount ??
        Money(amount: draft.total!.abs(), currencyCode: receiptCurrency);
    final transaction = Transaction.create(
      id: draft.linkedTransactionId,
      accountId: account.id,
      categoryId: primaryCategory.id,
      payeeId: draft.merchantPayeeId,
      amount: amount,
      type: transactionType,
      paymentMethod: paymentMethod,
      source: TransactionSource.aiGenerated,
      status: status,
      incomeSourceType: isRefund ? IncomeSourceType.refund : null,
      exchangeRate: explicitExchangeRate,
      note: draft.merchantName,
      // Missing OCR dates must not fall back to `DateTime.now()`: retries and
      // restart reconciliation need the same immutable transaction payload.
      transactionDate: draft.purchaseDate ?? draft.createdAt,
      attachmentCount: draft.localImageReference == null ? 0 : 1,
      aiConfidence: draft.confidence,
      needsReview: draft.warnings.isNotEmpty,
    );
    return ReceiptTransactionDraft(
      receipt: draft,
      transaction: transaction,
      splits: splits,
      requiresConfirmation: true,
    );
  }

  Category? _categoryById(List<Category> categories, String id) {
    return categories
        .where((category) => category.id == id && !category.isArchived)
        .firstOrNull;
  }

  Category? _categoryByName(
    List<Category> categories,
    String name,
    CategoryType type,
  ) {
    return categories
        .where(
          (category) =>
              category.type == type &&
              category.name.toLowerCase() == name.toLowerCase() &&
              !category.isArchived,
        )
        .firstOrNull;
  }
}
