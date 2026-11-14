import 'package:decimal/decimal.dart';
import 'package:uuid/uuid.dart';

import 'receipt_line_item.dart';
import 'transaction_split.dart';
import '../enums/image_retention_choice.dart';
import '../enums/receipt_document_type.dart';
import '../enums/receipt_draft_status.dart';
import '../enums/receipt_payment_status.dart';
import '../enums/receipt_warning.dart';

class ReceiptAnalysisDraft {
  const ReceiptAnalysisDraft({
    required this.id,
    required this.documentType,
    required this.paymentStatus,
    required this.confidence,
    required this.warnings,
    required this.lineItems,
    required this.splits,
    required this.duplicateCandidateIds,
    required this.imageRetentionChoice,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.merchantName,
    this.merchantPayeeId,
    this.merchantAddress,
    this.merchantTaxId,
    this.receiptNumber,
    this.invoiceNumber,
    this.purchaseDate,
    this.dueDate,
    this.currency,
    this.subtotal,
    this.tax,
    this.discount,
    this.serviceCharge,
    this.tip,
    this.otherFees,
    this.total,
    this.amountPaid,
    this.amountDue,
    this.paymentMethodHint,
    this.accountHint,
    this.localImageReference,
    this.imageHash,
    this.linkedTransactionId,
  });

  factory ReceiptAnalysisDraft.create({
    ReceiptDocumentType documentType = ReceiptDocumentType.unknown,
    ReceiptPaymentStatus paymentStatus = ReceiptPaymentStatus.unclear,
    String? merchantName,
    String? merchantPayeeId,
    String? merchantAddress,
    String? merchantTaxId,
    String? receiptNumber,
    String? invoiceNumber,
    DateTime? purchaseDate,
    DateTime? dueDate,
    String? currency,
    Decimal? subtotal,
    Decimal? tax,
    Decimal? discount,
    Decimal? serviceCharge,
    Decimal? tip,
    Decimal? otherFees,
    Decimal? total,
    Decimal? amountPaid,
    Decimal? amountDue,
    String? paymentMethodHint,
    String? accountHint,
    int confidence = 0,
    List<ReceiptWarning> warnings = const <ReceiptWarning>[],
    List<ReceiptLineItem> lineItems = const <ReceiptLineItem>[],
    List<TransactionSplit> splits = const <TransactionSplit>[],
    List<String> duplicateCandidateIds = const <String>[],
    ImageRetentionChoice imageRetentionChoice = ImageRetentionChoice.undecided,
    String? localImageReference,
    String? imageHash,
    ReceiptDraftStatus status = ReceiptDraftStatus.captured,
    String? linkedTransactionId,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now().toUtc();
    final receiptId = id ?? const Uuid().v7();
    return ReceiptAnalysisDraft(
      id: receiptId,
      documentType: documentType,
      paymentStatus: paymentStatus,
      merchantName: merchantName?.trim(),
      merchantPayeeId: merchantPayeeId,
      merchantAddress: merchantAddress?.trim(),
      merchantTaxId: merchantTaxId?.trim(),
      receiptNumber: receiptNumber?.trim(),
      invoiceNumber: invoiceNumber?.trim(),
      purchaseDate: purchaseDate?.toUtc(),
      dueDate: dueDate?.toUtc(),
      currency: currency?.trim().toUpperCase(),
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      serviceCharge: serviceCharge,
      tip: tip,
      otherFees: otherFees,
      total: total,
      amountPaid: amountPaid,
      amountDue: amountDue,
      paymentMethodHint: paymentMethodHint?.trim(),
      accountHint: accountHint?.trim(),
      confidence: confidence.clamp(0, 100),
      warnings: List.unmodifiable(warnings),
      lineItems: List.unmodifiable(lineItems),
      splits: List.unmodifiable(splits),
      duplicateCandidateIds: List.unmodifiable(duplicateCandidateIds),
      imageRetentionChoice: imageRetentionChoice,
      localImageReference: localImageReference,
      imageHash: imageHash,
      status: status,
      linkedTransactionId: linkedTransactionId,
      createdAt: (createdAt ?? now).toUtc(),
      updatedAt: (updatedAt ?? now).toUtc(),
    );
  }

  final String id;
  final ReceiptDocumentType documentType;
  final ReceiptPaymentStatus paymentStatus;
  final String? merchantName;
  final String? merchantPayeeId;
  final String? merchantAddress;
  final String? merchantTaxId;
  final String? receiptNumber;
  final String? invoiceNumber;
  final DateTime? purchaseDate;
  final DateTime? dueDate;
  final String? currency;
  final Decimal? subtotal;
  final Decimal? tax;
  final Decimal? discount;
  final Decimal? serviceCharge;
  final Decimal? tip;
  final Decimal? otherFees;
  final Decimal? total;
  final Decimal? amountPaid;
  final Decimal? amountDue;
  final String? paymentMethodHint;
  final String? accountHint;
  final int confidence;
  final List<ReceiptWarning> warnings;
  final List<ReceiptLineItem> lineItems;
  final List<TransactionSplit> splits;
  final List<String> duplicateCandidateIds;
  final ImageRetentionChoice imageRetentionChoice;
  final String? localImageReference;
  final String? imageHash;
  final ReceiptDraftStatus status;
  final String? linkedTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isInvoice =>
      documentType == ReceiptDocumentType.invoice ||
      documentType == ReceiptDocumentType.utilityBill;

  bool get needsPaymentClarification =>
      isInvoice && paymentStatus == ReceiptPaymentStatus.unclear;

  ReceiptAnalysisDraft copyWith({
    ReceiptDocumentType? documentType,
    ReceiptPaymentStatus? paymentStatus,
    String? merchantName,
    String? merchantPayeeId,
    String? merchantAddress,
    String? merchantTaxId,
    String? receiptNumber,
    String? invoiceNumber,
    DateTime? purchaseDate,
    DateTime? dueDate,
    String? currency,
    Decimal? subtotal,
    Decimal? tax,
    Decimal? discount,
    Decimal? serviceCharge,
    Decimal? tip,
    Decimal? otherFees,
    Decimal? total,
    Decimal? amountPaid,
    Decimal? amountDue,
    String? paymentMethodHint,
    String? accountHint,
    int? confidence,
    List<ReceiptWarning>? warnings,
    List<ReceiptLineItem>? lineItems,
    List<TransactionSplit>? splits,
    List<String>? duplicateCandidateIds,
    ImageRetentionChoice? imageRetentionChoice,
    String? localImageReference,
    String? imageHash,
    ReceiptDraftStatus? status,
    String? linkedTransactionId,
    DateTime? updatedAt,
  }) {
    return ReceiptAnalysisDraft(
      id: id,
      documentType: documentType ?? this.documentType,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      merchantName: merchantName ?? this.merchantName,
      merchantPayeeId: merchantPayeeId ?? this.merchantPayeeId,
      merchantAddress: merchantAddress ?? this.merchantAddress,
      merchantTaxId: merchantTaxId ?? this.merchantTaxId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      dueDate: dueDate ?? this.dueDate,
      currency: currency ?? this.currency,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      tip: tip ?? this.tip,
      otherFees: otherFees ?? this.otherFees,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      amountDue: amountDue ?? this.amountDue,
      paymentMethodHint: paymentMethodHint ?? this.paymentMethodHint,
      accountHint: accountHint ?? this.accountHint,
      confidence: confidence ?? this.confidence,
      warnings: warnings ?? this.warnings,
      lineItems: lineItems ?? this.lineItems,
      splits: splits ?? this.splits,
      duplicateCandidateIds:
          duplicateCandidateIds ?? this.duplicateCandidateIds,
      imageRetentionChoice: imageRetentionChoice ?? this.imageRetentionChoice,
      localImageReference: localImageReference ?? this.localImageReference,
      imageHash: imageHash ?? this.imageHash,
      status: status ?? this.status,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      createdAt: createdAt,
      updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
    );
  }
}
