import 'package:decimal/decimal.dart';

import '../../../core/error/result.dart';
import '../../../shared/domain/currency/localized_decimal_parser.dart';
import '../../accounts/domain/entities/account.dart';
import '../../categories/domain/entities/category.dart';
import '../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../finance_engine/domain/value_objects/money.dart';
import '../../payment_methods/payment_methods.dart' show PaymentMethod;
import '../domain/entities/receipt_analysis_draft.dart';
import '../domain/entities/receipt_transaction_draft.dart';
import '../domain/enums/receipt_draft_status.dart';
import '../domain/repositories/receipt_repository.dart';
import '../domain/usecases/validate_receipt_analysis.dart';

typedef ReceiptTransactionDraftBuilder =
    ReceiptTransactionDraft Function({
      required ReceiptAnalysisDraft draft,
      required Account account,
      required List<Category> categories,
      required PaymentMethod paymentMethod,
      required bool warningsAcknowledged,
      bool duplicateAcknowledged,
      Money? explicitAccountAmount,
      ExchangeRate? explicitExchangeRate,
    });

typedef ReceiptTransactionConfirmer =
    Future<AppResult<ConfirmedReceiptTransaction>> Function(
      ReceiptTransactionDraft draft, {
      required bool confirmed,
    });

/// Owns the review-to-persistence and review-to-confirmation application flow.
///
/// UI state, localization and navigation remain presentation concerns. This
/// collaborator owns construction and validation of the edited aggregate and
/// the exact Decimal/Money/exchange-rate inputs passed to the existing receipt
/// transaction use cases.
final class ReceiptReviewWorkflow {
  ReceiptReviewWorkflow({
    required ReceiptRepository repository,
    required ReceiptTransactionDraftBuilder buildTransactionDraft,
    required ReceiptTransactionConfirmer confirmTransaction,
    ValidateReceiptAnalysisUseCase validateAnalysis =
        const ValidateReceiptAnalysisUseCase(),
    DateTime Function() now = DateTime.now,
  }) : _repository = repository,
       _buildTransactionDraft = buildTransactionDraft,
       _confirmTransaction = confirmTransaction,
       _validateAnalysis = validateAnalysis,
       _now = now;

  final ReceiptRepository _repository;
  final ReceiptTransactionDraftBuilder _buildTransactionDraft;
  final ReceiptTransactionConfirmer _confirmTransaction;
  final ValidateReceiptAnalysisUseCase _validateAnalysis;
  final DateTime Function() _now;

  ReceiptReviewDraftPreparation prepareDraft(ReceiptReviewDraftInput input) {
    final currency = input.currencyText.trim().toUpperCase();
    final total = LocalizedDecimalParser.tryParse(input.totalText);
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        total == null ||
        total == Decimal.zero) {
      return const ReceiptReviewDraftRejected();
    }

    final current = input.current;
    final edited = ReceiptAnalysisDraft(
      id: current.id,
      documentType: current.documentType,
      paymentStatus: current.paymentStatus,
      merchantName: _nullIfEmpty(input.merchantNameText),
      merchantPayeeId: current.merchantPayeeId,
      merchantAddress: current.merchantAddress,
      merchantTaxId: current.merchantTaxId,
      receiptNumber: current.receiptNumber,
      invoiceNumber: current.invoiceNumber,
      purchaseDate: DateTime.tryParse(input.purchaseDateText.trim())?.toUtc(),
      dueDate: current.dueDate,
      currency: currency,
      subtotal: LocalizedDecimalParser.tryParse(input.subtotalText),
      tax: LocalizedDecimalParser.tryParse(input.taxText),
      discount: LocalizedDecimalParser.tryParse(input.discountText),
      serviceCharge: current.serviceCharge,
      tip: LocalizedDecimalParser.tryParse(input.tipText),
      otherFees: current.otherFees,
      total: total,
      amountPaid: current.amountPaid,
      amountDue: current.amountDue,
      paymentMethodHint: current.paymentMethodHint,
      accountHint: current.accountHint,
      confidence: current.confidence,
      warnings: current.warnings,
      lineItems: current.lineItems,
      splits: current.splits,
      duplicateCandidateIds: current.duplicateCandidateIds,
      imageRetentionChoice: current.imageRetentionChoice,
      localImageReference: current.localImageReference,
      imageHash: current.imageHash,
      status: ReceiptDraftStatus.reviewRequired,
      linkedTransactionId: current.linkedTransactionId,
      createdAt: current.createdAt,
      updatedAt: _now().toUtc(),
    );
    return ReceiptReviewDraftReady(_validateAnalysis(edited).draft);
  }

  Future<AppResult<ReceiptAnalysisDraft>> saveDraft(
    ReceiptReviewDraftReady preparation,
  ) {
    return _repository.updateAnalysisDraft(preparation.draft);
  }

  Future<AppResult<ConfirmedReceiptTransaction>> confirm(
    ReceiptReviewConfirmationInput input,
  ) {
    final saved = input.saved;
    final account = input.account;
    final crossCurrency =
        saved.currency!.toUpperCase() != account.currencyCode.toUpperCase();
    final converted = crossCurrency
        ? LocalizedDecimalParser.tryParse(input.accountAmountText)
        : null;
    final rate = crossCurrency
        ? LocalizedDecimalParser.tryParse(input.exchangeRateText)
        : null;
    final transactionDraft = _buildTransactionDraft(
      draft: saved,
      account: account,
      categories: input.categories,
      paymentMethod: input.paymentMethod,
      warningsAcknowledged: input.warningsAcknowledged,
      duplicateAcknowledged: input.warningsAcknowledged,
      explicitAccountAmount: converted == null
          ? null
          : Money(amount: converted.abs(), currencyCode: account.currencyCode),
      explicitExchangeRate: rate == null
          ? null
          : ExchangeRate(
              fromCurrencyCode: saved.currency!,
              toCurrencyCode: account.currencyCode,
              rate: rate,
              asOf: saved.purchaseDate,
            ),
    );
    return _confirmTransaction(transactionDraft, confirmed: true);
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

final class ReceiptReviewDraftInput {
  const ReceiptReviewDraftInput({
    required this.current,
    required this.merchantNameText,
    required this.purchaseDateText,
    required this.currencyText,
    required this.subtotalText,
    required this.taxText,
    required this.discountText,
    required this.tipText,
    required this.totalText,
  });

  final ReceiptAnalysisDraft current;
  final String merchantNameText;
  final String purchaseDateText;
  final String currencyText;
  final String subtotalText;
  final String taxText;
  final String discountText;
  final String tipText;
  final String totalText;
}

sealed class ReceiptReviewDraftPreparation {
  const ReceiptReviewDraftPreparation();
}

final class ReceiptReviewDraftRejected extends ReceiptReviewDraftPreparation {
  const ReceiptReviewDraftRejected();
}

final class ReceiptReviewDraftReady extends ReceiptReviewDraftPreparation {
  const ReceiptReviewDraftReady(this.draft);

  final ReceiptAnalysisDraft draft;
}

final class ReceiptReviewConfirmationInput {
  const ReceiptReviewConfirmationInput({
    required this.saved,
    required this.account,
    required this.categories,
    required this.paymentMethod,
    required this.warningsAcknowledged,
    required this.accountAmountText,
    required this.exchangeRateText,
  });

  final ReceiptAnalysisDraft saved;
  final Account account;
  final List<Category> categories;
  final PaymentMethod paymentMethod;
  final bool warningsAcknowledged;
  final String accountAmountText;
  final String exchangeRateText;
}
