import 'dart:convert';
import 'dart:typed_data';

import 'package:cashpilot_ai/features/receipts/data/providers/firebase_receipt_analysis_provider.dart';
import 'package:cashpilot_ai/features/receipts/domain/config/receipt_analysis_model_config.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/prepared_receipt_image.dart';
import 'package:cashpilot_ai/features/receipts/domain/failures/receipt_failure_codes.dart';
import 'package:cashpilot_ai/features/receipts/domain/repositories/receipt_analysis_provider.dart';
import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'provider sends only sanitized bounded context with inline image',
    () async {
      late firebase_ai.Content capturedSystem;
      late List<firebase_ai.Content> capturedContents;
      late firebase_ai.GenerationConfig capturedConfig;
      final provider = FirebaseReceiptAnalysisProvider(
        config: _config(),
        generateContent:
            ({
              required modelName,
              required contents,
              required systemInstruction,
              required generationConfig,
            }) async {
              capturedSystem = systemInstruction;
              capturedContents = contents;
              capturedConfig = generationConfig;
              return _response(_payload());
            },
      );

      final draft = await provider.analyzeReceipt(
        draftId: 'receipt-1',
        image: _image(),
        context: const ReceiptAnalysisContext(
          supportedCurrencies: ['usd', 'LYD', 'not-currency'],
          categoryDescriptions: [
            'Groceries and food',
            'person@example.com',
            'token=secretvalue123456789',
            'account 123456789',
          ],
          locale: 'en-US',
        ),
        assertEgressAllowed: () {},
      );

      final systemText =
          (capturedSystem.parts.single as firebase_ai.TextPart).text;
      expect(systemText, contains('Groceries and food'));
      expect(systemText, contains('USD'));
      expect(systemText, contains('LYD'));
      expect(systemText, isNot(contains('person@example.com')));
      expect(systemText, isNot(contains('secretvalue123456789')));
      expect(systemText, isNot(contains('123456789')));
      expect(
        capturedContents.single.parts.whereType<firebase_ai.InlineDataPart>(),
        hasLength(1),
      );
      expect(capturedConfig.responseMimeType, 'application/json');
      expect(capturedConfig.responseSchema, isNotNull);
      expect(draft.merchantName, 'Test Shop');
    },
  );

  test(
    'provider retries transient failures only within the configured bound',
    () async {
      var attempts = 0;
      final provider = FirebaseReceiptAnalysisProvider(
        config: _config(
          retryBackoff: const [
            Duration(milliseconds: 1),
            Duration(milliseconds: 1),
          ],
        ),
        retryDelay: (_) async {},
        generateContent:
            ({
              required modelName,
              required contents,
              required systemInstruction,
              required generationConfig,
            }) async {
              attempts += 1;
              if (attempts < 3) {
                throw Exception('503 internal');
              }
              return _response(_payload());
            },
      );

      await provider.analyzeReceipt(
        draftId: 'receipt-1',
        image: _image(),
        context: const ReceiptAnalysisContext(
          supportedCurrencies: ['USD'],
          categoryDescriptions: ['Groceries'],
          locale: 'en',
        ),
        assertEgressAllowed: () {},
      );

      expect(attempts, 3);
    },
  );

  test('provider maps App Check failures to a safe code', () async {
    final provider = FirebaseReceiptAnalysisProvider(
      config: _config(),
      generateContent:
          ({
            required modelName,
            required contents,
            required systemInstruction,
            required generationConfig,
          }) async {
            throw Exception('App Check attestation rejected internal detail');
          },
    );

    expect(
      () => provider.analyzeReceipt(
        draftId: 'receipt-1',
        image: _image(),
        context: const ReceiptAnalysisContext(
          supportedCurrencies: ['USD'],
          categoryDescriptions: ['Groceries'],
          locale: 'en',
        ),
        assertEgressAllowed: () {},
      ),
      throwsA(
        isA<ReceiptException>()
            .having(
              (error) => error.code,
              'code',
              ReceiptFailureCodes.appCheckBlocked,
            )
            .having(
              (error) => error.safeMessage,
              'message',
              isNot(contains('internal detail')),
            ),
      ),
    );
  });

  test('A to B switch during backoff sends zero receipt bytes as B', () async {
    var currentOwner = 'A';
    var guardCalls = 0;
    final transportOwners = <String>[];
    final provider = FirebaseReceiptAnalysisProvider(
      config: _config(retryBackoff: const [Duration.zero]),
      retryDelay: (_) async {
        currentOwner = 'B';
      },
      generateContent:
          ({
            required modelName,
            required contents,
            required systemInstruction,
            required generationConfig,
          }) async {
            transportOwners.add(currentOwner);
            throw Exception('503 internal');
          },
    );

    await expectLater(
      provider.analyzeReceipt(
        draftId: 'receipt-owner-a',
        image: _image(),
        context: const ReceiptAnalysisContext(
          supportedCurrencies: ['USD'],
          categoryDescriptions: ['Groceries'],
          locale: 'en',
        ),
        assertEgressAllowed: () {
          guardCalls += 1;
          if (currentOwner != 'A') {
            throw StateError('captured receipt owner is no longer current');
          }
        },
      ),
      throwsA(isA<ReceiptException>()),
    );

    expect(guardCalls, 2);
    expect(transportOwners, const <String>['A']);
  });
}

ReceiptAnalysisModelConfig _config({
  List<Duration> retryBackoff = const <Duration>[],
}) {
  return ReceiptAnalysisModelConfig(
    modelName: 'test-model',
    temperature: 0.05,
    maxOutputTokens: 4096,
    timeout: const Duration(seconds: 1),
    structuredOutputEnabled: true,
    maximumImageSize: 1024,
    retryBackoff: retryBackoff,
  );
}

PreparedReceiptImage _image() {
  return PreparedReceiptImage(
    bytes: Uint8List.fromList(const [1, 2, 3]),
    mimeType: 'image/jpeg',
    width: 800,
    height: 1200,
    sha256: 'hash',
  );
}

firebase_ai.GenerateContentResponse _response(Map<String, Object?> payload) {
  return firebase_ai.GenerateContentResponse([
    firebase_ai.Candidate(
      firebase_ai.Content.model([firebase_ai.TextPart(jsonEncode(payload))]),
      null,
      null,
      firebase_ai.FinishReason.stop,
      null,
    ),
  ], null);
}

Map<String, Object?> _payload() => <String, Object?>{
  'documentType': 'purchase_receipt',
  'paymentStatus': 'paid',
  'merchantName': 'Test Shop',
  'purchaseDate': '2026-07-20',
  'currency': 'USD',
  'subtotal': '10',
  'tax': '0',
  'discount': '0',
  'serviceCharge': '0',
  'tip': '0',
  'otherFees': '0',
  'total': '10',
  'confidence': 0.9,
  'warnings': <String>[],
  'lineItems': <Object?>[
    <String, Object?>{
      'description': 'Milk',
      'totalPrice': '10',
      'categoryHint': 'Groceries',
      'categoryConfidence': 0.9,
      'warnings': <String>[],
    },
  ],
};
