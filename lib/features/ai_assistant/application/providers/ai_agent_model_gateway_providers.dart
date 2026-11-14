import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/logging/app_logger.dart';
import '../../data/agent/firebase_ai_agent_model_gateway.dart';
import '../../data/config/ai_runtime_config.dart';
import '../../data/gateway/firebase_gateway_token_provider.dart';
import '../../data/gateway/groq_ai_agent_model_gateway.dart';
import '../../data/gateway/groq_conversation_gateway.dart';
import '../../data/gateway/groq_gateway_client.dart';
import '../../data/gateway/groq_gateway_data_source.dart';
import '../../data/gateway/routed_ai_agent_model_gateway.dart';
import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';
import 'ai_agent_runtime_providers.dart';
import 'ai_agent_scope_providers.dart';
import 'ai_assistant_providers.dart';

final aiGatewayHttpClientProvider = Provider.autoDispose<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
}, name: 'aiGatewayHttpClientProvider');

final aiGatewayTokenProvider = Provider<AiGatewayTokenProvider>(
  (ref) => FirebaseAiGatewayTokenProvider(
    auth: ref.watch(firebaseAuthProvider),
    appCheckReadiness: ref.watch(firebaseAppCheckReadinessCoordinatorProvider),
  ),
  name: 'aiGatewayTokenProvider',
);

final aiGatewaySafeDiagnosticLogProvider = Provider<void Function(String)?>((
  ref,
) {
  final diagnosticsEnabled = ref.watch(
    aiRuntimeConfigProvider.select((config) => config.diagnosticsEnabled),
  );
  return diagnosticsEnabled ? ref.watch(appLoggerProvider).debug : null;
}, name: 'aiGatewaySafeDiagnosticLogProvider');

final groqGatewayClientProvider = Provider<GroqGatewayClient>(
  (ref) => GroqGatewayClient(
    config: ref.watch(aiGatewayRuntimeConfigProvider),
    tokenProvider: ref.watch(aiGatewayTokenProvider),
    httpClient: ref.watch(aiGatewayHttpClientProvider),
    safeDiagnosticLog: ref.watch(aiGatewaySafeDiagnosticLogProvider),
  ),
  name: 'groqGatewayClientProvider',
);

final groqGatewayDataSourceProvider = Provider<GroqGatewayDataSource>(
  (ref) => GroqGatewayDataSource(ref.watch(groqGatewayClientProvider)),
  name: 'groqGatewayDataSourceProvider',
);

final groqConversationGatewayProvider = Provider<AiConversationGateway>(
  (ref) => GroqConversationGateway(ref.watch(groqGatewayDataSourceProvider)),
  name: 'groqConversationGatewayProvider',
);

final groqAiAgentModelGatewayProvider = Provider<AiAgentModelGateway>((ref) {
  final flags = ref.watch(aiGatewayFeatureFlagsProvider);
  return GroqAiAgentModelGateway(
    gateway: ref.watch(groqConversationGatewayProvider),
    clientVersion: ref.watch(aiGatewayRuntimeConfigProvider).clientVersion,
    toolSelectionEnabled: flags.aiGroqToolSelectionEnabled,
    financialExplanationEnabled: flags.aiGroqFinancialExplanationEnabled,
  );
}, name: 'groqAiAgentModelGatewayProvider');

final firebaseAiAgentModelGatewayProvider = Provider<AiAgentModelGateway?>((
  ref,
) {
  final runtime = ref.watch(aiRuntimeConfigProvider);
  final preference = runtime.resolvedConversationProviderPreference;
  final flags = ref.watch(aiGatewayFeatureFlagsProvider);
  final automatic = preference == AiConversationProviderPreference.auto;
  final groqRequestSelected =
      (preference == AiConversationProviderPreference.groq || automatic) &&
      flags.aiGroqGatewayEnabled &&
      (flags.aiGroqGeneralChatEnabled ||
          flags.aiGroqFinancialExplanationEnabled);
  final remoteProviderConfigured =
      preference != AiConversationProviderPreference.disabled &&
      (preference == AiConversationProviderPreference.firebase ||
          (flags.aiFirebaseTextFallbackEnabled && groqRequestSelected) ||
          flags.aiCurrentWebEnabled);
  return remoteProviderConfigured &&
          ref.watch(aiFirebasePlatformConfiguredProvider) &&
          ref.watch(aiFirebaseInitializedProvider) &&
          ref.watch(aiAppCheckRuntimeAvailableProvider) &&
          ref.watch(aiConversationAuthenticationAvailableProvider)
      ? FirebaseAiAgentModelGateway(
          config: ref.watch(firebaseAiConfigProvider),
          safeDiagnosticLog: ref.watch(aiGatewaySafeDiagnosticLogProvider),
        )
      : null;
}, name: 'firebaseAiAgentModelGatewayProvider');

final aiAgentModelGatewayProvider = Provider<AiAgentModelGateway?>((ref) {
  // Rebuild and dispose reusable provider sessions on every auth-scope change.
  // The scope value is intentionally not passed to either provider.
  ref.watch(aiAgentAccountScopeProvider);
  final runtime = ref.watch(aiRuntimeConfigProvider);
  final preference = runtime.resolvedConversationProviderPreference;
  final capabilities = ref.watch(aiAssistantCapabilitiesProvider);
  ref
      .watch(aiGatewaySafeDiagnosticLogProvider)
      ?.call(
        'AI runtime preference=${preference.name} '
        'selectedProvider=${capabilities.activeProvider.name} '
        'generalAvailable=${capabilities.generalConversationAvailable} '
        'unavailableReason=${capabilities.unavailableReason?.name ?? 'none'}',
      );
  final gateway = RoutedAiAgentModelGateway(
    flags: ref.watch(aiGatewayFeatureFlagsProvider),
    firebaseGateway: ref.watch(firebaseAiAgentModelGatewayProvider),
    groqGateway: ref.watch(groqAiAgentModelGatewayProvider),
    groqConfigured: ref.watch(aiGatewayRuntimeConfigProvider).isConfigured,
    conversationPreference: preference,
    generalConversationPlan: ref.watch(aiGeneralConversationRoutePlanProvider),
  );
  ref.onDispose(gateway.clearSessions);
  return gateway;
}, name: 'aiAgentModelGatewayProvider');
