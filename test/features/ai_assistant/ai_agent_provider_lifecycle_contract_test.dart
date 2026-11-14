import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_assistant_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_gateway_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/routed_ai_agent_model_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_runtime_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('legacy facade preserves exact runtime provider names', () {
    expect(aiAgentLimitsProvider.name, 'aiAgentLimitsProvider');
    expect(aiAgentFeatureFlagsProvider.name, 'aiAgentFeatureFlagsProvider');
    expect(aiGatewayFeatureFlagsProvider.name, 'aiGatewayFeatureFlagsProvider');
    expect(
      aiGatewayRuntimeConfigProvider.name,
      'aiGatewayRuntimeConfigProvider',
    );
    expect(
      aiFirebasePlatformConfiguredProvider.name,
      'aiFirebasePlatformConfiguredProvider',
    );
    expect(aiFirebaseInitializedProvider.name, 'aiFirebaseInitializedProvider');
    expect(
      aiAppCheckActivationSnapshotProvider.name,
      'aiAppCheckActivationSnapshotProvider',
    );
    expect(
      aiAppCheckRuntimeAvailableProvider.name,
      'aiAppCheckRuntimeAvailableProvider',
    );
    expect(
      aiConversationAuthenticationAvailableProvider.name,
      'aiConversationAuthenticationAvailableProvider',
    );
    expect(
      aiGeneralConversationRoutePlanProvider.name,
      'aiGeneralConversationRoutePlanProvider',
    );
    expect(
      aiAssistantCapabilitiesProvider.name,
      'aiAssistantCapabilitiesProvider',
    );
    expect(aiGatewayHttpClientProvider.name, 'aiGatewayHttpClientProvider');
    expect(aiGatewayTokenProvider.name, 'aiGatewayTokenProvider');
    expect(
      aiGatewaySafeDiagnosticLogProvider.name,
      'aiGatewaySafeDiagnosticLogProvider',
    );
    expect(groqGatewayClientProvider.name, 'groqGatewayClientProvider');
    expect(groqGatewayDataSourceProvider.name, 'groqGatewayDataSourceProvider');
    expect(
      groqConversationGatewayProvider.name,
      'groqConversationGatewayProvider',
    );
    expect(
      groqAiAgentModelGatewayProvider.name,
      'groqAiAgentModelGatewayProvider',
    );
    expect(
      firebaseAiAgentModelGatewayProvider.name,
      'firebaseAiAgentModelGatewayProvider',
    );
    expect(aiAgentModelGatewayProvider.name, 'aiAgentModelGatewayProvider');
  });

  test('gateway provider disposal clears both routed provider sessions', () {
    final firebase = _ResettableGateway();
    final groq = _ResettableGateway();
    final container = ProviderContainer(
      overrides: [
        aiAgentAccountScopeProvider.overrideWithValue('a' * 64),
        aiRuntimeConfigProvider.overrideWithValue(
          AiRuntimeConfig.resolve(providerValue: 'auto'),
        ),
        aiAssistantCapabilitiesProvider.overrideWithValue(
          const AiAssistantCapabilities.testDefaults(),
        ),
        aiGatewayFeatureFlagsProvider.overrideWithValue(
          AiGatewayFeatureFlags.resolve(
            groqGatewayValue: 'true',
            generalChatValue: 'true',
          ),
        ),
        aiGatewayRuntimeConfigProvider.overrideWithValue(
          AiGatewayRuntimeConfig.resolve(
            baseUrl: 'https://gateway.example.test',
          ),
        ),
        aiGatewaySafeDiagnosticLogProvider.overrideWithValue(null),
        firebaseAiAgentModelGatewayProvider.overrideWithValue(firebase),
        groqAiAgentModelGatewayProvider.overrideWithValue(groq),
        aiGeneralConversationRoutePlanProvider.overrideWithValue(_groqPlan),
      ],
    );

    expect(
      container.read(aiAgentModelGatewayProvider),
      isA<RoutedAiAgentModelGateway>(),
    );
    expect(firebase.clearCount, 0);
    expect(groq.clearCount, 0);

    container.dispose();

    expect(firebase.clearCount, 1);
    expect(groq.clearCount, 1);
  });

  test('auto-disposed HTTP provider closes its owned client', () async {
    final container = ProviderContainer();
    container.listen<http.Client>(
      aiGatewayHttpClientProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final client = container.read(aiGatewayHttpClientProvider);

    container.dispose();

    await expectLater(
      Future<void>(() async {
        await client.send(
          http.Request('GET', Uri.parse('https://closed.invalid')),
        );
      }),
      throwsA(
        isA<http.ClientException>().having(
          (failure) => failure.message.toLowerCase(),
          'message',
          contains('closed'),
        ),
      ),
    );
  });
}

const _groqPlan = AiProviderRoutePlan(
  task: ModelTask.generalConversation,
  primaryProvider: AiActiveProvider.groq,
  primaryAvailable: true,
  preflightProvider: AiActiveProvider.groq,
  fallbackProvider: null,
  fallbackAvailable: false,
  fallbackPolicy: AiRuntimeFallbackPolicy.none,
  primaryUnavailableReason: null,
  routeUnavailableReason: null,
);

class _ResettableGateway implements ResettableAiAgentModelGateway {
  int clearCount = 0;

  @override
  void clearSessions() {
    clearCount += 1;
  }

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) {
    throw UnsupportedError('Lifecycle contract never starts a model session.');
  }
}
