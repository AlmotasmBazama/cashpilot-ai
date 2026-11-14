import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;

import '../../../../core/firebase/firebase_ai_backend.dart';
import '../dtos/receipt_analysis_transport.dart';
import '../../domain/config/receipt_analysis_model_config.dart';
import '../../domain/entities/prepared_receipt_image.dart';
import '../../domain/entities/receipt_analysis_draft.dart';
import '../../domain/failures/receipt_failure_codes.dart';
import '../../domain/repositories/receipt_analysis_provider.dart';

typedef FirebaseReceiptGenerateContent =
    Future<firebase_ai.GenerateContentResponse> Function({
      required String modelName,
      required List<firebase_ai.Content> contents,
      required firebase_ai.Content systemInstruction,
      required firebase_ai.GenerationConfig generationConfig,
    });

class FirebaseReceiptAnalysisProvider implements ReceiptAnalysisProvider {
  FirebaseReceiptAnalysisProvider({
    required ReceiptAnalysisModelConfig config,
    FirebaseReceiptGenerateContent? generateContent,
    Future<void> Function(Duration duration)? retryDelay,
    FirebaseAiBackendConfig? backendConfig,
  }) : _config = config,
       _generateContent = generateContent,
       _retryDelay = retryDelay,
       _backendConfig = backendConfig ?? FirebaseAiBackendConfig.current;

  final ReceiptAnalysisModelConfig _config;
  final FirebaseReceiptGenerateContent? _generateContent;
  final Future<void> Function(Duration duration)? _retryDelay;
  final FirebaseAiBackendConfig _backendConfig;

  @override
  ReceiptAnalysisModelConfig get modelConfig => _config;

  @override
  Future<bool> validateAvailability() async {
    return _config.modelName.trim().isNotEmpty &&
        _config.structuredOutputEnabled;
  }

  @override
  Future<ReceiptAnalysisDraft> analyzeReceipt({
    required String draftId,
    required PreparedReceiptImage image,
    required ReceiptAnalysisContext context,
    required void Function() assertEgressAllowed,
  }) async {
    if (image.bytes.isEmpty || image.bytes.length > _config.maximumImageSize) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidImage,
        safeMessage: 'The prepared receipt image is invalid.',
      );
    }
    final safeContext = _safeContext(context);
    final contents = <firebase_ai.Content>[
      firebase_ai.Content.multi(<firebase_ai.Part>[
        const firebase_ai.TextPart(_receiptPrompt),
        firebase_ai.InlineDataPart(image.mimeType, image.bytes),
      ]),
    ];
    final systemInstruction = firebase_ai.Content.system(
      'Allowed receipt context (JSON): ${jsonEncode(safeContext)}',
    );
    final generationConfig = firebase_ai.GenerationConfig(
      temperature: _config.temperature,
      maxOutputTokens: _config.maxOutputTokens,
      responseMimeType: 'application/json',
      responseSchema: _receiptSchema,
    );
    try {
      final response = await _generateWithRetry(
        contents: contents,
        systemInstruction: systemInstruction,
        generationConfig: generationConfig,
        assertEgressAllowed: assertEgressAllowed,
      );
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        final finishReason = response.candidates.firstOrNull?.finishReason;
        if (_isContentRejected(finishReason)) {
          throw const ReceiptException(
            code: ReceiptFailureCodes.contentRejected,
            safeMessage: 'The receipt image could not be analyzed safely.',
          );
        }
        throw const ReceiptException(
          code: ReceiptFailureCodes.unreadable,
          safeMessage: 'No readable receipt data was found.',
        );
      }
      return ReceiptAnalysisTransport.parse(draftId: draftId, content: text);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapException(error), stackTrace);
    }
  }

  Future<firebase_ai.GenerateContentResponse> _generateWithRetry({
    required List<firebase_ai.Content> contents,
    required firebase_ai.Content systemInstruction,
    required firebase_ai.GenerationConfig generationConfig,
    required void Function() assertEgressAllowed,
  }) async {
    for (var attempt = 0; ; attempt += 1) {
      try {
        // This is deliberately inside the retry loop and immediately before
        // the Firebase call. A receipt captured under A must never be sent by
        // a retry after the active owner/session has changed to B.
        assertEgressAllowed();
        final generator = _generateContent;
        if (generator != null) {
          return await generator(
            modelName: _config.modelName,
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
          ).timeout(_config.timeout);
        }
        final model = _backendConfig.client().generativeModel(
          model: _config.modelName,
          systemInstruction: systemInstruction,
          generationConfig: generationConfig,
        );
        return await model.generateContent(contents).timeout(_config.timeout);
      } on Object catch (error) {
        if (!_isRetryable(error) || attempt >= _config.retryBackoff.length) {
          rethrow;
        }
        await (_retryDelay ?? Future<void>.delayed)(
          _config.retryBackoff[attempt],
        );
      }
    }
  }

  Map<String, Object?> _safeContext(ReceiptAnalysisContext context) {
    final currencies = context.supportedCurrencies
        .map((code) => code.trim().toUpperCase())
        .where((code) => RegExp(r'^[A-Z]{3}$').hasMatch(code))
        .take(30)
        .toList(growable: false);
    final categoryDescriptions = context.categoryDescriptions
        .map((value) => value.trim())
        .where(
          (value) =>
              value.isNotEmpty &&
              !_emailPattern.hasMatch(value) &&
              !_tokenPattern.hasMatch(value) &&
              _digitPattern.allMatches(value).length < 7,
        )
        .map((value) => value.length <= 240 ? value : value.substring(0, 240))
        .take(50)
        .toList(growable: false);
    final locale =
        RegExp(
          r'^[A-Za-z]{2,3}(?:[-_][A-Za-z0-9]{2,8})*$',
        ).hasMatch(context.locale)
        ? context.locale
        : 'en';
    return <String, Object?>{
      'locale': locale,
      'supportedCurrencies': currencies,
      'categoryDescriptions': categoryDescriptions,
      'documentTypes': const <String>[
        'purchase_receipt: evidence of a purchase',
        'invoice: request for payment, not proof of payment',
        'credit_note: seller-issued purchase reduction or reversal',
        'refund_receipt: evidence of money returned',
        'utility_bill: service bill that may be unpaid',
        'payment_confirmation: evidence of a payment that may already exist',
        'unknown: insufficient evidence',
      ],
    };
  }

  ReceiptException _mapException(Object error) {
    if (error is ReceiptException) {
      return error;
    }
    final message = error.toString().toLowerCase();
    if (error is TimeoutException || message.contains('timed out')) {
      return const ReceiptException(
        code: ReceiptFailureCodes.timeout,
        safeMessage:
            'Receipt analysis timed out. Try again or enter it manually.',
      );
    }
    if (error is firebase_ai.QuotaExceeded ||
        message.contains('429') ||
        message.contains('quota') ||
        message.contains('rate limit')) {
      return const ReceiptException(
        code: ReceiptFailureCodes.rateLimited,
        safeMessage: 'Receipt analysis is temporarily rate limited.',
      );
    }
    if (message.contains('app check') ||
        message.contains('appcheck') ||
        message.contains('attestation')) {
      return const ReceiptException(
        code: ReceiptFailureCodes.appCheckBlocked,
        safeMessage: 'App Check could not verify receipt analysis.',
      );
    }
    if (message.contains('blocked due to safety') ||
        message.contains('prohibited content') ||
        message.contains('content filter')) {
      return const ReceiptException(
        code: ReceiptFailureCodes.contentRejected,
        safeMessage: 'The receipt image could not be analyzed safely.',
      );
    }
    if (message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('offline') ||
        message.contains('failed host lookup')) {
      return const ReceiptException(
        code: ReceiptFailureCodes.networkFailure,
        safeMessage: 'Receipt analysis could not reach the network.',
      );
    }
    return const ReceiptException(
      code: ReceiptFailureCodes.providerUnavailable,
      safeMessage: 'Receipt analysis is currently unavailable.',
    );
  }

  bool _isRetryable(Object error) {
    if (error is firebase_ai.QuotaExceeded || error is TimeoutException) {
      return false;
    }
    final message = error.toString().toLowerCase();
    return message.contains('500') ||
        message.contains('502') ||
        message.contains('503') ||
        message.contains('504') ||
        message.contains('internal');
  }

  bool _isContentRejected(firebase_ai.FinishReason? reason) {
    return switch (reason) {
      firebase_ai.FinishReason.safety ||
      firebase_ai.FinishReason.blocklist ||
      firebase_ai.FinishReason.prohibitedContent ||
      firebase_ai.FinishReason.imageSafety ||
      firebase_ai.FinishReason.imageProhibitedContent => true,
      _ => false,
    };
  }
}

final firebase_ai.Schema _receiptSchema = firebase_ai.Schema.object(
  properties: <String, firebase_ai.Schema>{
    'documentType': firebase_ai.Schema.enumString(
      enumValues: const <String>[
        'purchase_receipt',
        'invoice',
        'credit_note',
        'refund_receipt',
        'utility_bill',
        'payment_confirmation',
        'unknown',
      ],
    ),
    'paymentStatus': firebase_ai.Schema.enumString(
      enumValues: const <String>['paid', 'unpaid', 'partially_paid', 'unclear'],
      nullable: true,
    ),
    'merchantName': firebase_ai.Schema.string(nullable: true),
    'merchantAddress': firebase_ai.Schema.string(nullable: true),
    'merchantTaxId': firebase_ai.Schema.string(nullable: true),
    'receiptNumber': firebase_ai.Schema.string(nullable: true),
    'invoiceNumber': firebase_ai.Schema.string(nullable: true),
    'purchaseDate': firebase_ai.Schema.string(nullable: true),
    'dueDate': firebase_ai.Schema.string(nullable: true),
    'currency': firebase_ai.Schema.string(nullable: true),
    'subtotal': firebase_ai.Schema.string(nullable: true),
    'tax': firebase_ai.Schema.string(nullable: true),
    'discount': firebase_ai.Schema.string(nullable: true),
    'serviceCharge': firebase_ai.Schema.string(nullable: true),
    'tip': firebase_ai.Schema.string(nullable: true),
    'otherFees': firebase_ai.Schema.string(nullable: true),
    'total': firebase_ai.Schema.string(nullable: true),
    'amountPaid': firebase_ai.Schema.string(nullable: true),
    'amountDue': firebase_ai.Schema.string(nullable: true),
    'paymentMethodHint': firebase_ai.Schema.string(nullable: true),
    'accountHint': firebase_ai.Schema.string(nullable: true),
    'confidence': firebase_ai.Schema.number(nullable: true),
    'warnings': firebase_ai.Schema.array(
      items: firebase_ai.Schema.enumString(
        enumValues: const <String>[
          'low_image_quality',
          'unreadable_text',
          'missing_total',
          'arithmetic_mismatch',
          'currency_unclear',
          'date_unclear',
          'merchant_unclear',
          'duplicate_possible',
          'item_total_mismatch',
          'unsupported_document',
          'payment_status_unclear',
          'negative_value',
          'partial_extraction',
          'other',
        ],
      ),
    ),
    'lineItems': firebase_ai.Schema.array(
      items: firebase_ai.Schema.object(
        properties: <String, firebase_ai.Schema>{
          'description': firebase_ai.Schema.string(),
          'quantity': firebase_ai.Schema.string(nullable: true),
          'unit': firebase_ai.Schema.string(nullable: true),
          'unitPrice': firebase_ai.Schema.string(nullable: true),
          'discount': firebase_ai.Schema.string(nullable: true),
          'tax': firebase_ai.Schema.string(nullable: true),
          'totalPrice': firebase_ai.Schema.string(nullable: true),
          'categoryHint': firebase_ai.Schema.string(nullable: true),
          'categoryConfidence': firebase_ai.Schema.number(nullable: true),
          'categoryAlternatives': firebase_ai.Schema.array(
            items: firebase_ai.Schema.string(),
            nullable: true,
          ),
          'skuOrBarcode': firebase_ai.Schema.string(nullable: true),
          'warnings': firebase_ai.Schema.array(
            items: firebase_ai.Schema.string(),
            nullable: true,
          ),
        },
        optionalProperties: const <String>[
          'quantity',
          'unit',
          'unitPrice',
          'discount',
          'tax',
          'totalPrice',
          'categoryHint',
          'categoryConfidence',
          'categoryAlternatives',
          'skuOrBarcode',
          'warnings',
        ],
      ),
    ),
  },
  optionalProperties: const <String>[
    'paymentStatus',
    'merchantName',
    'merchantAddress',
    'merchantTaxId',
    'receiptNumber',
    'invoiceNumber',
    'purchaseDate',
    'dueDate',
    'currency',
    'subtotal',
    'tax',
    'discount',
    'serviceCharge',
    'tip',
    'otherFees',
    'total',
    'amountPaid',
    'amountDue',
    'paymentMethodHint',
    'accountHint',
    'confidence',
  ],
);

const _receiptPrompt = '''
Extract only information visibly supported by this receipt or invoice image.
Return one JSON object matching the supplied schema and no prose.
Use null for every unknown value. Never guess a total, currency, date, merchant, tax, discount, quantity, payment method, account, or payment status.
All money, quantity, unit-price, tax, discount, fee, and total values must be decimal strings, never JSON numbers.
Preserve readable line-item descriptions in their original language.
Use purchase_receipt only for evidence of a completed purchase.
An invoice or utility bill is not paid unless the image visibly proves payment.
Distinguish credit_note and refund_receipt from an ordinary purchase.
Use payment_confirmation when the image confirms a payment but may correspond to an existing transaction.
Classify every item independently by meaning. Milk, bread, and eggs are groceries. Detergent is household supplies. Shampoo is personal care. Never use a home category as a generic category for food.
Do not invent missing items or silently repair arithmetic. Return warnings and confidence.
Never include prose outside JSON.
''';

final _emailPattern = RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]+');
final _digitPattern = RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]');
final _tokenPattern = RegExp(
  r'(?:token|secret|bearer|auth)[\s_:=.-]+[A-Za-z0-9_-]{12,}'
  r'|AIza[0-9A-Za-z_-]{20,}|eyJ[A-Za-z0-9_-]{10,}\.',
  caseSensitive: false,
);
