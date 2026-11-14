import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../../../categories/domain/entities/category_suggestion.dart';
import '../../../categories/domain/catalog/category_taxonomy.dart';
import '../../domain/entities/receipt_analysis_draft.dart';
import '../../domain/entities/receipt_line_item.dart';
import '../../domain/enums/image_retention_choice.dart';
import '../../domain/enums/receipt_document_type.dart';
import '../../domain/enums/receipt_draft_status.dart';
import '../../domain/enums/receipt_payment_status.dart';
import '../../domain/enums/receipt_warning.dart';
import '../../domain/failures/receipt_failure_codes.dart';

class ReceiptAnalysisTransport {
  const ReceiptAnalysisTransport._();

  static ReceiptAnalysisDraft parse({
    required String draftId,
    required String content,
  }) {
    final jsonText = _extractJson(content);
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidJson,
        safeMessage: 'Receipt analysis returned invalid data.',
      );
    }
    if (decoded is! Map) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.unsupportedSchema,
        safeMessage: 'Receipt analysis returned an unsupported shape.',
      );
    }
    final json = Map<String, Object?>.from(decoded);
    final documentType = ReceiptDocumentTypeMapper.tryFromStorage(
      _requiredString(json, 'documentType'),
    );
    if (documentType == null) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.unsupportedSchema,
        safeMessage: 'Receipt analysis returned an unsupported document type.',
      );
    }

    final warnings = _warnings(json['warnings']);
    final total = _money(
      json,
      'total',
      allowNegative: documentType.permitsNegativeValues,
    );
    if (total == null && !warnings.contains(ReceiptWarning.missingTotal)) {
      warnings.add(ReceiptWarning.missingTotal);
    }
    final lineItems = _lineItems(
      receiptId: draftId,
      value: json['lineItems'],
      allowNegative: documentType.permitsNegativeValues,
    );
    final paymentStatus = ReceiptPaymentStatusMapper.fromStorage(
      _string(json['paymentStatus']),
    );
    final resolvedWarnings = <ReceiptWarning>[
      ...warnings,
      if ((documentType == ReceiptDocumentType.invoice ||
              documentType == ReceiptDocumentType.utilityBill) &&
          paymentStatus == ReceiptPaymentStatus.unclear &&
          !warnings.contains(ReceiptWarning.paymentStatusUnclear))
        ReceiptWarning.paymentStatusUnclear,
    ];

    return ReceiptAnalysisDraft.create(
      id: draftId,
      documentType: documentType,
      paymentStatus: paymentStatus,
      merchantName: _string(json['merchantName']),
      merchantAddress: _string(json['merchantAddress']),
      merchantTaxId: _string(json['merchantTaxId']),
      receiptNumber: _string(json['receiptNumber']),
      invoiceNumber: _string(json['invoiceNumber']),
      purchaseDate: _date(json['purchaseDate']),
      dueDate: _date(json['dueDate']),
      currency: _currency(json['currency']),
      subtotal: _money(
        json,
        'subtotal',
        allowNegative: documentType.permitsNegativeValues,
      ),
      tax: _money(json, 'tax', allowNegative: false),
      discount: _money(json, 'discount', allowNegative: false),
      serviceCharge: _money(json, 'serviceCharge', allowNegative: false),
      tip: _money(json, 'tip', allowNegative: false),
      otherFees: _money(json, 'otherFees', allowNegative: false),
      total: total,
      amountPaid: _money(
        json,
        'amountPaid',
        allowNegative: documentType.permitsNegativeValues,
      ),
      amountDue: _money(json, 'amountDue', allowNegative: false),
      paymentMethodHint: _string(json['paymentMethodHint']),
      accountHint: _string(json['accountHint']),
      confidence: _confidence(json['confidence']),
      warnings: resolvedWarnings.toSet().toList(growable: false),
      lineItems: lineItems,
      imageRetentionChoice: ImageRetentionChoice.undecided,
      status:
          total == null ||
              documentType == ReceiptDocumentType.unknown ||
              paymentStatus == ReceiptPaymentStatus.unclear &&
                  (documentType == ReceiptDocumentType.invoice ||
                      documentType == ReceiptDocumentType.utilityBill)
          ? ReceiptDraftStatus.reviewRequired
          : ReceiptDraftStatus.readyForConfirmation,
    );
  }

  static String _extractJson(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidJson,
        safeMessage: 'Receipt analysis returned invalid data.',
      );
    }
    return content.substring(start, end + 1);
  }

  static List<ReceiptLineItem> _lineItems({
    required String receiptId,
    required Object? value,
    required bool allowNegative,
  }) {
    if (value == null) {
      return const <ReceiptLineItem>[];
    }
    if (value is! List) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.unsupportedSchema,
        safeMessage: 'Receipt line items have an unsupported shape.',
      );
    }
    final items = <ReceiptLineItem>[];
    for (var index = 0; index < value.length; index++) {
      final raw = value[index];
      if (raw is! Map) {
        throw const ReceiptException(
          code: ReceiptFailureCodes.unsupportedSchema,
          safeMessage: 'Receipt line items have an unsupported shape.',
        );
      }
      final json = Map<String, Object?>.from(raw);
      final description = _requiredString(json, 'description');
      final categoryConfidence = _confidence(json['categoryConfidence']);
      final categoryHint = _string(json['categoryHint']);
      items.add(
        ReceiptLineItem.create(
          receiptId: receiptId,
          description: description,
          normalizedDescription: CategoryTaxonomy.normalize(description),
          quantity: _money(json, 'quantity', allowNegative: false),
          unit: _string(json['unit']),
          unitPrice: _money(json, 'unitPrice', allowNegative: allowNegative),
          discount: _money(json, 'discount', allowNegative: false),
          tax: _money(json, 'tax', allowNegative: false),
          totalPrice: _money(json, 'totalPrice', allowNegative: allowNegative),
          categoryHint: categoryHint,
          categoryConfidence: categoryConfidence,
          categorySuggestionSource: categoryHint == null
              ? CategorySuggestionSource.fallback
              : CategorySuggestionSource.aiSemantic,
          categoryAlternatives: _stringList(json['categoryAlternatives']),
          skuOrBarcode: _string(json['skuOrBarcode']),
          warnings: _warnings(json['warnings']),
          sortOrder: index,
        ),
      );
    }
    return items;
  }

  static Decimal? _money(
    Map<String, Object?> json,
    String key, {
    required bool allowNegative,
  }) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ReceiptException(
        code: ReceiptFailureCodes.unsupportedSchema,
        safeMessage: '$key must be encoded as a string.',
      );
    }
    final text = value.trim();
    if (text.isEmpty ||
        text.toLowerCase().contains('nan') ||
        text.toLowerCase().contains('inf') ||
        text.contains(RegExp('[eE]')) ||
        !RegExp(r'^-?\d+(?:\.\d{1,6})?$').hasMatch(text)) {
      throw ReceiptException(
        code: ReceiptFailureCodes.unsupportedSchema,
        safeMessage: '$key is not a supported decimal value.',
      );
    }
    final parsed = Decimal.tryParse(text);
    if (parsed == null || (!allowNegative && parsed < Decimal.zero)) {
      throw ReceiptException(
        code: ReceiptFailureCodes.unsupportedSchema,
        safeMessage: '$key is not a supported decimal value.',
      );
    }
    return parsed;
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = _string(json[key]);
    if (value == null) {
      throw ReceiptException(
        code: ReceiptFailureCodes.unsupportedSchema,
        safeMessage: '$key is required.',
      );
    }
    return value;
  }

  static String? _string(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static String? _currency(Object? value) {
    final currency = _string(value)?.toUpperCase();
    if (currency == null) {
      return null;
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.unsupportedSchema,
        safeMessage: 'Receipt currency is invalid.',
      );
    }
    return currency;
  }

  static DateTime? _date(Object? value) {
    final text = _string(value);
    if (text == null) {
      return null;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.unsupportedSchema,
        safeMessage: 'Receipt date is invalid.',
      );
    }
    final parsed = DateTime.tryParse('${text}T00:00:00Z')?.toUtc();
    if (parsed == null || parsed.toIso8601String().split('T').first != text) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.unsupportedSchema,
        safeMessage: 'Receipt date is invalid.',
      );
    }
    return parsed;
  }

  static int _confidence(Object? value) {
    final text = switch (value) {
      num() => value.toString(),
      String() => value,
      _ => null,
    };
    final parsed = text == null ? null : Decimal.tryParse(text);
    if (parsed == null) {
      return 0;
    }
    final percent = parsed <= Decimal.one
        ? parsed * Decimal.fromInt(100)
        : parsed;
    return percent.round().toBigInt().toInt().clamp(0, 100);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(3)
        .toList(growable: false);
  }

  static List<ReceiptWarning> _warnings(Object? value) {
    if (value == null) {
      return <ReceiptWarning>[];
    }
    if (value is! List) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.unsupportedSchema,
        safeMessage: 'Receipt warnings have an unsupported shape.',
      );
    }
    return value
        .whereType<String>()
        .map(ReceiptWarningMapper.fromStorage)
        .toSet()
        .toList(growable: true);
  }
}
