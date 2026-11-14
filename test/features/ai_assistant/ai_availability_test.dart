import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/effective_ai_app_control_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_app_control_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_assistant_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_app_control_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_gateway_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default debug config separates local parsing from automatic chat', () {
    final automatic = AiRuntimeConfig.resolve();
    final explicitLocal = AiRuntimeConfig.resolve(providerValue: 'local');

    expect(automatic.providerMode, AiProviderMode.localParserOnly);
    expect(automatic.generalConversationAutoRoutingEnabled, isTrue);
    expect(explicitLocal.providerMode, AiProviderMode.localParserOnly);
    expect(explicitLocal.generalConversationAutoRoutingEnabled, isFalse);
  });

  test('auto does not activate Firebase conversation without Groq flags', () {
    final container = _container(
      policy: _policy(ownerScopeSafe: true),
      runtime: AiRuntimeConfig.resolve(providerValue: 'auto'),
      gatewayFlags: AiGatewayFeatureFlags.resolve(),
    );
    addTearDown(container.dispose);

    final capabilities = container.read(aiAssistantCapabilitiesProvider);

    expect(capabilities.generalConversationAvailable, isFalse);
    expect(capabilities.personalFinancialAnalysisAvailable, isFalse);
    expect(capabilities.activeProvider, AiActiveProvider.none);
  });

  test(
    'general chat remains available while financial execution is disabled',
    () {
      final container = _container(
        policy: _policy(ownerScopeSafe: true, confirmedExecutionEnabled: false),
      );
      addTearDown(container.dispose);

      final capabilities = container.read(aiAssistantCapabilitiesProvider);

      expect(capabilities.directConversationAvailable, isTrue);
      expect(capabilities.generalConversationAvailable, isTrue);
      expect(capabilities.activeProvider, AiActiveProvider.firebase);
      expect(capabilities.confirmedExecutionAvailable, isFalse);
    },
  );

  test(
    'owner-health and legacy restrictions block finance but not general chat',
    () {
      final container = _container(policy: _policy(ownerScopeSafe: false));
      addTearDown(container.dispose);

      final capabilities = container.read(aiAssistantCapabilitiesProvider);

      expect(capabilities.generalConversationAvailable, isTrue);
      expect(capabilities.personalFinancialAnalysisAvailable, isFalse);
      expect(capabilities.financialDraftsAvailable, isFalse);
      expect(capabilities.confirmedExecutionAvailable, isFalse);
    },
  );

  test('receipt vision and current knowledge are independently gated', () {
    final container = _container(
      policy: _policy(ownerScopeSafe: true),
      gatewayFlags: AiGatewayFeatureFlags.resolve(
        currentWebValue: 'false',
        firebaseReceiptVisionValue: 'false',
      ),
    );
    addTearDown(container.dispose);

    final capabilities = container.read(aiAssistantCapabilitiesProvider);

    expect(capabilities.generalConversationAvailable, isTrue);
    expect(capabilities.currentKnowledgeAvailable, isFalse);
    expect(capabilities.receiptVisionAvailable, isFalse);
  });

  test('missing platform Firebase configuration has a precise reason', () {
    final container = _container(
      policy: _policy(ownerScopeSafe: true),
      platformConfigured: false,
    );
    addTearDown(container.dispose);

    final capabilities = container.read(aiAssistantCapabilitiesProvider);

    expect(capabilities.directConversationAvailable, isTrue);
    expect(capabilities.generalConversationAvailable, isFalse);
    expect(capabilities.platformSupported, isFalse);
    expect(
      capabilities.unavailableReason,
      AiUnavailableReason.platformNotConfigured,
    );
    expect(capabilities.retryable, isFalse);
  });

  test('localParserOnly never pretends to be a general model', () {
    final container = _container(
      policy: _policy(ownerScopeSafe: true),
      runtime: const AiRuntimeConfig(
        providerMode: AiProviderMode.localParserOnly,
        diagnosticsEnabled: true,
      ),
    );
    addTearDown(container.dispose);

    final capabilities = container.read(aiAssistantCapabilitiesProvider);

    expect(capabilities.directConversationAvailable, isTrue);
    expect(capabilities.generalConversationAvailable, isFalse);
    expect(capabilities.activeProvider, AiActiveProvider.localParserOnly);
    expect(capabilities.unavailableReason, AiUnavailableReason.gatewayDisabled);
    expect(capabilities.receiptVisionAvailable, isTrue);
  });

  test('direct local conversation ignores the remote agent flag', () {
    final container = _container(
      policy: _policy(ownerScopeSafe: true),
      agentFlags: const AiAgentFeatureFlags(
        agentEnabled: false,
        readOnlyToolsEnabled: false,
        draftToolsEnabled: false,
        conversationMemoryEnabled: false,
        complexPlanningEnabled: false,
      ),
    );
    addTearDown(container.dispose);

    final capabilities = container.read(aiAssistantCapabilitiesProvider);

    expect(capabilities.directConversationAvailable, isTrue);
    expect(capabilities.generalConversationAvailable, isFalse);
  });

  test('transient App Check activation failure is a retryable preflight', () {
    final container = _container(
      policy: _policy(ownerScopeSafe: true),
      appCheckState: const FirebaseAppCheckActivationState.unavailable(
        FirebaseAppCheckUnavailableReason.activationFailed,
      ),
    );
    addTearDown(container.dispose);

    final capabilities = container.read(aiAssistantCapabilitiesProvider);

    expect(capabilities.generalConversationAvailable, isFalse);
    expect(
      capabilities.unavailableReason,
      AiUnavailableReason.appCheckUnavailable,
    );
    expect(capabilities.retryable, isTrue);
  });

  test('Groq remains eligible while transient App Check can be awaited', () {
    final container = _container(
      policy: _policy(ownerScopeSafe: true),
      runtime: AiRuntimeConfig.resolve(providerValue: 'groq'),
      gatewayFlags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
      ),
      gatewayConfig: AiGatewayRuntimeConfig.resolve(
        baseUrl: 'https://gateway.example.test',
      ),
      appCheckState: const FirebaseAppCheckActivationState.unavailable(
        FirebaseAppCheckUnavailableReason.activationFailed,
      ),
    );
    addTearDown(container.dispose);

    final capabilities = container.read(aiAssistantCapabilitiesProvider);
    final plan = container.read(aiGeneralConversationRoutePlanProvider);

    expect(plan.preflightProvider, AiActiveProvider.groq);
    expect(capabilities.generalConversationAvailable, isTrue);
    expect(capabilities.activeProvider, AiActiveProvider.groq);
  });

  test('missing Web App Check site key is a non-retryable setup state', () {
    final container = _container(
      policy: _policy(ownerScopeSafe: true),
      appCheckState: const FirebaseAppCheckActivationState.unavailable(
        FirebaseAppCheckUnavailableReason.webSiteKeyMissing,
      ),
    );
    addTearDown(container.dispose);

    final capabilities = container.read(aiAssistantCapabilitiesProvider);

    expect(capabilities.generalConversationAvailable, isFalse);
    expect(
      capabilities.unavailableReason,
      AiUnavailableReason.appCheckUnavailable,
    );
    expect(capabilities.retryable, isFalse);
  });

  test('missing Groq URL falls back to Firebase when Firebase is valid', () {
    final container = _container(
      policy: _policy(ownerScopeSafe: true),
      runtime: AiRuntimeConfig.resolve(providerValue: 'auto'),
      gatewayFlags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
        firebaseTextFallbackValue: 'true',
      ),
      gatewayConfig: AiGatewayRuntimeConfig.resolve(baseUrl: ''),
    );
    addTearDown(container.dispose);

    final capabilities = container.read(aiAssistantCapabilitiesProvider);
    final plan = container.read(aiGeneralConversationRoutePlanProvider);

    expect(capabilities.generalConversationAvailable, isTrue);
    expect(capabilities.activeProvider, AiActiveProvider.firebase);
    expect(capabilities.unavailableReason, isNull);
    expect(plan.primaryProvider, AiActiveProvider.groq);
    expect(plan.primaryAvailable, isFalse);
    expect(plan.preflightProvider, capabilities.activeProvider);
    expect(plan.routeAvailable, capabilities.generalConversationAvailable);
  });

  test('missing Groq URL is specific when no Firebase fallback is enabled', () {
    final container = _container(
      policy: _policy(ownerScopeSafe: true),
      runtime: AiRuntimeConfig.resolve(providerValue: 'groq'),
      gatewayFlags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
      ),
      gatewayConfig: AiGatewayRuntimeConfig.resolve(baseUrl: ''),
    );
    addTearDown(container.dispose);

    final capabilities = container.read(aiAssistantCapabilitiesProvider);

    expect(capabilities.generalConversationAvailable, isFalse);
    expect(
      capabilities.unavailableReason,
      AiUnavailableReason.gatewayUrlMissing,
    );
    expect(
      capabilities.personalFinancialAnalysisAvailable,
      isFalse,
      reason: 'Explicit Groq must not silently select Firebase financial AI.',
    );
  });

  test(
    'explicit Groq chat keeps financial analysis available with configured Groq',
    () {
      final container = _container(
        policy: _policy(ownerScopeSafe: true),
        runtime: AiRuntimeConfig.resolve(providerValue: 'groq'),
        gatewayFlags: AiGatewayFeatureFlags.resolve(
          groqGatewayValue: 'true',
          generalChatValue: 'true',
          financialExplanationValue: 'true',
          toolSelectionValue: 'false',
        ),
        gatewayConfig: AiGatewayRuntimeConfig.resolve(
          baseUrl: 'https://gateway.example.test',
        ),
      );
      addTearDown(container.dispose);

      final capabilities = container.read(aiAssistantCapabilitiesProvider);
      final plan = container.read(aiGeneralConversationRoutePlanProvider);

      expect(capabilities.generalConversationAvailable, isTrue);
      expect(capabilities.activeProvider, AiActiveProvider.groq);
      expect(capabilities.personalFinancialAnalysisAvailable, isTrue);
      expect(plan.preflightProvider, capabilities.activeProvider);
      expect(plan.routeAvailable, capabilities.generalConversationAvailable);
    },
  );

  test('explicit Groq is unavailable when rollout flags are disabled', () {
    final container = _container(
      policy: _policy(ownerScopeSafe: true),
      runtime: AiRuntimeConfig.resolve(providerValue: 'groq'),
      gatewayFlags: AiGatewayFeatureFlags.resolve(),
      gatewayConfig: AiGatewayRuntimeConfig.resolve(
        baseUrl: 'https://gateway.example.test',
      ),
    );
    addTearDown(container.dispose);

    final capabilities = container.read(aiAssistantCapabilitiesProvider);

    expect(capabilities.generalConversationAvailable, isFalse);
    expect(capabilities.personalFinancialAnalysisAvailable, isFalse);
    expect(capabilities.activeProvider, AiActiveProvider.none);
  });
}

ProviderContainer _container({
  required EffectiveAiAppControlPolicy policy,
  AiRuntimeConfig? runtime,
  AiGatewayFeatureFlags? gatewayFlags,
  AiGatewayRuntimeConfig? gatewayConfig,
  AiAgentFeatureFlags agentFlags = _agentFlags,
  bool platformConfigured = true,
  FirebaseAppCheckActivationState appCheckState =
      const FirebaseAppCheckActivationState.available(),
}) {
  return ProviderContainer(
    overrides: [
      aiRuntimeConfigProvider.overrideWithValue(
        runtime ?? AiRuntimeConfig.resolve(providerValue: 'firebase'),
      ),
      aiGatewayFeatureFlagsProvider.overrideWithValue(
        gatewayFlags ?? AiGatewayFeatureFlags.resolve(),
      ),
      aiGatewayRuntimeConfigProvider.overrideWithValue(
        gatewayConfig ?? AiGatewayRuntimeConfig.resolve(baseUrl: ''),
      ),
      aiAgentFeatureFlagsProvider.overrideWithValue(agentFlags),
      effectiveAiAppControlPolicyProvider.overrideWithValue(policy),
      aiFirebasePlatformConfiguredProvider.overrideWithValue(
        platformConfigured,
      ),
      aiFirebaseInitializedProvider.overrideWithValue(true),
      aiAppCheckActivationSnapshotProvider.overrideWithValue(appCheckState),
      aiAppCheckRuntimeAvailableProvider.overrideWithValue(
        appCheckState.isAvailable,
      ),
      aiConversationAuthenticationAvailableProvider.overrideWithValue(true),
    ],
  );
}

const _agentFlags = AiAgentFeatureFlags(
  agentEnabled: true,
  readOnlyToolsEnabled: true,
  draftToolsEnabled: true,
  conversationMemoryEnabled: true,
  complexPlanningEnabled: false,
);

EffectiveAiAppControlPolicy _policy({
  required bool ownerScopeSafe,
  bool confirmedExecutionEnabled = false,
}) {
  return EffectiveAiAppControlPolicy(
    flags: AiAppControlFeatureFlags(
      appControlEnabled: true,
      readToolsEnabled: true,
      navigationToolsEnabled: true,
      createDraftsEnabled: true,
      confirmedExecutionEnabled: confirmedExecutionEnabled,
      updateDraftsEnabled: false,
      archiveDraftsEnabled: false,
      multiStepPlansEnabled: false,
      agentAuditEnabled: true,
      localDatasetScopeVerified: true,
    ),
    settings: const AiAppControlSettings(
      level: AiAppControlLevel.fullGovernedControl,
      allowFinancialAnalysis: true,
      allowNavigation: true,
      allowTransactionDrafts: true,
      allowBudgetAndGoalDrafts: true,
      allowAccountCategoryPayeeDrafts: false,
      allowRecurringDrafts: false,
      allowMultiStepPlans: false,
      requireConfirmationForEveryChange: true,
    ),
    hasAuthenticatedScope: true,
    runtimeOwnerScopeSafe: ownerScopeSafe,
    configurationRevision: 1,
  );
}
