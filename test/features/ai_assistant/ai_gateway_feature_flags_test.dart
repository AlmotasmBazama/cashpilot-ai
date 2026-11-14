import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_gateway_feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Groq and current web are disabled by default', () {
    final flags = AiGatewayFeatureFlags.resolve();

    expect(flags.aiGroqGatewayEnabled, isFalse);
    expect(flags.aiGroqGeneralChatEnabled, isFalse);
    expect(flags.aiGroqFinancialExplanationEnabled, isFalse);
    expect(flags.aiGroqToolSelectionEnabled, isFalse);
    expect(flags.aiGroqArabicSpecialistEnabled, isFalse);
    expect(flags.aiCurrentWebEnabled, isFalse);
    expect(flags.aiFirebaseReceiptVisionEnabled, isTrue);
    expect(flags.aiFirebaseTextFallbackEnabled, isFalse);
  });

  test('staging flags are explicit and rollback independently', () {
    final enabled = AiGatewayFeatureFlags.resolve(
      groqGatewayValue: 'true',
      generalChatValue: 'true',
      financialExplanationValue: 'true',
      toolSelectionValue: 'true',
      arabicSpecialistValue: 'true',
      currentWebValue: 'false',
      firebaseReceiptVisionValue: 'true',
      firebaseTextFallbackValue: 'true',
    );

    expect(enabled.aiGroqGatewayEnabled, isTrue);
    expect(enabled.aiGroqGeneralChatEnabled, isTrue);
    expect(enabled.financialGatewayEnabledFor('en'), isTrue);
    expect(enabled.financialGatewayEnabledFor('ar_LY'), isTrue);
    expect(enabled.aiCurrentWebEnabled, isFalse);
    expect(enabled.aiFirebaseReceiptVisionEnabled, isTrue);
    expect(enabled.aiFirebaseTextFallbackEnabled, isTrue);

    final rolledBack = AiGatewayFeatureFlags.resolve(
      groqGatewayValue: 'false',
      generalChatValue: 'true',
      financialExplanationValue: 'true',
      toolSelectionValue: 'true',
      arabicSpecialistValue: 'true',
    );
    expect(rolledBack.aiGroqGatewayEnabled, isFalse);
    expect(rolledBack.financialGatewayEnabledFor('ar'), isFalse);
  });

  test('release gateway URL must use HTTPS', () {
    expect(
      AiGatewayRuntimeConfig.resolve(
        baseUrl: 'http://gateway.example',
        isReleaseMode: true,
      ).isConfigured,
      isFalse,
    );
    expect(
      AiGatewayRuntimeConfig.resolve(
        baseUrl: 'https://gateway.example',
        isReleaseMode: true,
      ).isConfigured,
      isTrue,
    );
    expect(
      AiGatewayRuntimeConfig.resolve(
        baseUrl: 'http://127.0.0.1:8080',
        isProfileMode: true,
      ).isConfigured,
      isFalse,
    );
    expect(
      AiGatewayRuntimeConfig.resolve(
        baseUrl: 'http://127.0.0.1:8080',
      ).isConfigured,
      isTrue,
    );
    expect(
      AiGatewayRuntimeConfig.resolve(
        baseUrl: 'https://gateway.example',
      ).requestTimeout,
      greaterThan(const Duration(seconds: 30)),
    );
  });

  test('financial explanation is independent from tool selection', () {
    final explanationOnly = AiGatewayFeatureFlags.resolve(
      groqGatewayValue: 'true',
      financialExplanationValue: 'true',
    );
    final selectionOnly = AiGatewayFeatureFlags.resolve(
      groqGatewayValue: 'true',
      toolSelectionValue: 'true',
    );

    expect(explanationOnly.financialGatewayEnabledFor('en'), isTrue);
    expect(selectionOnly.financialGatewayEnabledFor('en'), isFalse);
  });
}
