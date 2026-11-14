import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_assistant_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/datasources/firebase_ai_provider_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/datasources/local_parser_only_ai_provider_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/datasources/mock_ai_provider_data_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiRuntimeConfig', () {
    test('debug and tests default to the local parser', () {
      final config = AiRuntimeConfig.resolve();

      expect(config.providerMode, AiProviderMode.localParserOnly);
      expect(config.diagnosticsEnabled, isTrue);
      expect(config.generalConversationAutoRoutingEnabled, isTrue);
    });

    test('release and staging-style profile default to Firebase Gemini', () {
      expect(
        AiRuntimeConfig.resolve(isReleaseMode: true).providerMode,
        AiProviderMode.firebaseGemini,
      );
      expect(
        AiRuntimeConfig.resolve(isProfileMode: true).providerMode,
        AiProviderMode.firebaseGemini,
      );
    });

    test('explicit modes select mock, local, and Firebase Gemini', () {
      final mock = AiRuntimeConfig.resolve(providerValue: 'mock');
      final local = AiRuntimeConfig.resolve(providerValue: 'localParserOnly');
      final firebase = AiRuntimeConfig.resolve(providerValue: 'firebaseGemini');

      expect(mock.providerMode, AiProviderMode.mock);
      expect(local.providerMode, AiProviderMode.localParserOnly);
      expect(firebase.providerMode, AiProviderMode.firebaseGemini);
      expect(mock.generalConversationAutoRoutingEnabled, isFalse);
      expect(local.generalConversationAutoRoutingEnabled, isFalse);
      expect(firebase.generalConversationAutoRoutingEnabled, isFalse);
    });

    test('explicit auto, Groq, and Firebase chat preferences are parsed', () {
      final automatic = AiRuntimeConfig.resolve(providerValue: 'auto');
      final groq = AiRuntimeConfig.resolve(providerValue: 'groq');
      final firebase = AiRuntimeConfig.resolve(providerValue: 'firebase');

      expect(
        automatic.resolvedConversationProviderPreference,
        AiConversationProviderPreference.auto,
      );
      expect(automatic.providerMode, AiProviderMode.localParserOnly);
      expect(
        groq.resolvedConversationProviderPreference,
        AiConversationProviderPreference.groq,
      );
      expect(groq.providerMode, AiProviderMode.localParserOnly);
      expect(
        firebase.resolvedConversationProviderPreference,
        AiConversationProviderPreference.firebase,
      );
      expect(firebase.providerMode, AiProviderMode.firebaseGemini);
    });

    test('unknown debug value fails closed to local parser', () {
      expect(
        AiRuntimeConfig.resolve(providerValue: 'unexpected').providerMode,
        AiProviderMode.localParserOnly,
      );
    });
  });

  test('model config keeps economical low-temperature defaults', () {
    final config = AiModelConfig.resolve();

    expect(config.modelName, AiModelConfig.defaultEconomicalModel);
    expect(config.temperature, 0.1);
    expect(config.maxOutputTokens, 512);
    expect(config.structuredOutputEnabled, isTrue);
    expect(config.streamingEnabled, isFalse);
  });

  test('Riverpod selects each configured data source without widget logic', () {
    ProviderContainer containerFor(AiProviderMode mode) {
      return ProviderContainer(
        overrides: [
          aiRuntimeConfigProvider.overrideWithValue(
            AiRuntimeConfig(providerMode: mode, diagnosticsEnabled: true),
          ),
        ],
      );
    }

    final mock = containerFor(AiProviderMode.mock);
    final local = containerFor(AiProviderMode.localParserOnly);
    final firebase = containerFor(AiProviderMode.firebaseGemini);
    addTearDown(mock.dispose);
    addTearDown(local.dispose);
    addTearDown(firebase.dispose);

    expect(
      mock.read(aiProviderDataSourceProvider),
      isA<MockAiProviderDataSource>(),
    );
    expect(
      local.read(aiProviderDataSourceProvider),
      isA<LocalParserOnlyAiProviderDataSource>(),
    );
    expect(
      firebase.read(aiProviderDataSourceProvider),
      isA<FirebaseAiProviderDataSource>(),
    );
  });
}
