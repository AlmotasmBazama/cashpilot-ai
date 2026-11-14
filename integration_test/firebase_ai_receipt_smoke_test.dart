// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/receipts/data/providers/firebase_receipt_analysis_provider.dart';
import 'package:cashpilot_ai/features/receipts/domain/config/receipt_analysis_model_config.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/prepared_receipt_image.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_document_type.dart';
import 'package:cashpilot_ai/features/receipts/domain/repositories/receipt_analysis_provider.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/resolve_receipt_categories.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/validate_receipt_analysis.dart';
import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live Firebase AI extracts a synthetic mixed-category receipt safely',
    (tester) async {
      if (AiRuntimeConfig.current.providerMode !=
          AiProviderMode.firebaseGemini) {
        fail('The live Firebase Gemini provider is not selected.');
      }
      if (firebaseAppCheckDebugToken.isEmpty) {
        fail('A registered App Check debug token was not supplied.');
      }
      await const DefaultFirebaseInitializer().initialize();
      final appCheckState = await defaultFirebaseAppCheckActivationController
          .activate();
      expect(
        appCheckState.isAvailable,
        isTrue,
        reason: 'App Check activation failed: ${appCheckState.safeCode}',
      );

      final prepared = _syntheticReceipt();
      final provider = FirebaseReceiptAnalysisProvider(
        config: ReceiptAnalysisModelConfig.current(
          fallbackModel: AiModelConfig.current.modelName,
        ),
      );
      final categories = buildDefaultCategories();
      final extracted = await provider.analyzeReceipt(
        draftId: 'synthetic-receipt-smoke',
        image: prepared,
        context: ReceiptAnalysisContext(
          supportedCurrencies: const ['USD', 'LYD'],
          categoryDescriptions: categories
              .map((category) => category.name)
              .toList(growable: false),
          locale: 'en',
        ),
        // Live smoke owns one fixed test session; production calls inject the
        // authenticated owner/session fence from AnalyzeReceiptImageUseCase.
        assertEgressAllowed: () {},
      );
      final categorized = const ResolveReceiptCategoriesUseCase()(
        draft: extracted,
        categories: categories,
      );
      final validated = const ValidateReceiptAnalysisUseCase()(categorized);

      expect(extracted.documentType, ReceiptDocumentType.purchaseReceipt);
      expect(extracted.currency, 'USD');
      expect(extracted.total, Decimal.parse('20.00'));
      expect(extracted.lineItems, hasLength(3));
      final namesById = {
        for (final category in categories) category.id: category.name,
      };
      final resolvedNames = categorized.lineItems
          .map((item) => namesById[item.categoryId])
          .toSet();
      expect(
        resolvedNames,
        containsAll(<String>['Groceries', 'Home', 'Beauty']),
      );
      expect(validated.expectedTotal, Decimal.parse('20.00'));
      print(
        'FIREBASE_RECEIPT_DIAG completed=true '
        'providerResponded=true '
        'documentTypeReady=true '
        'moneyValidated=true '
        'mixedCategoriesReady=true',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

PreparedReceiptImage _syntheticReceipt() {
  final canvas = image.Image(width: 900, height: 1300);
  image.fill(canvas, color: image.ColorRgb8(255, 255, 255));
  final black = image.ColorRgb8(0, 0, 0);
  image.drawString(
    canvas,
    'DEMO MARKET',
    font: image.arial48,
    x: 250,
    y: 90,
    color: black,
  );
  const lines = <String>[
    'SYNTHETIC TEST RECEIPT',
    'Receipt: TEST-2026-001',
    'Date: 2026-07-20',
    '',
    'Fresh Milk                 5.00',
    'Laundry Detergent          8.00',
    'Shampoo                    7.00',
    '',
    'Subtotal                  20.00',
    'Tax                        0.00',
    'TOTAL                     20.00 USD',
    '',
    'PAID - CASH',
    'NOT A REAL PURCHASE',
  ];
  var y = 180;
  for (final line in lines) {
    if (line.isNotEmpty) {
      image.drawString(
        canvas,
        line,
        font: image.arial24,
        x: 90,
        y: y,
        color: black,
      );
    }
    y += 62;
  }
  final bytes = Uint8List.fromList(image.encodeJpg(canvas, quality: 92));
  return PreparedReceiptImage(
    bytes: bytes,
    mimeType: 'image/jpeg',
    width: canvas.width,
    height: canvas.height,
    sha256: sha256.convert(bytes).toString(),
  );
}
