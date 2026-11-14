import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_app_check_activation.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../firebase_options.dart';
import '../../../auth/application/providers/auth_providers.dart';
import '../../data/config/ai_agent_feature_flags.dart';
import '../../data/config/ai_gateway_feature_flags.dart';
import '../../data/config/ai_runtime_config.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_runtime_status.dart';
import '../../domain/services/ai_provider_route_resolver.dart';
import 'ai_app_control_providers.dart';
import 'ai_assistant_providers.dart';

final aiAgentLimitsProvider = Provider<AiAgentLimits>(
  (_) => const AiAgentLimits(),
  name: 'aiAgentLimitsProvider',
);

final aiAgentFeatureFlagsProvider = Provider<AiAgentFeatureFlags>(
  (_) => AiAgentFeatureFlags.current,
  name: 'aiAgentFeatureFlagsProvider',
);

final aiGatewayFeatureFlagsProvider = Provider<AiGatewayFeatureFlags>(
  (_) => AiGatewayFeatureFlags.current,
  name: 'aiGatewayFeatureFlagsProvider',
);

final aiGatewayRuntimeConfigProvider = Provider<AiGatewayRuntimeConfig>(
  (_) => AiGatewayRuntimeConfig.current,
  name: 'aiGatewayRuntimeConfigProvider',
);

/// Reads the generated FlutterFire options as the platform source of truth.
/// Unsupported platforms fail closed without copying platform identifiers into
/// assistant configuration.
final aiFirebasePlatformConfiguredProvider = Provider<bool>((_) {
  try {
    DefaultFirebaseOptions.currentPlatform;
    return true;
  } on Object {
    return false;
  }
}, name: 'aiFirebasePlatformConfiguredProvider');

/// Firebase Core readiness only. App Check has its own asynchronous state and
/// must never be inferred from [Firebase.apps].
final aiFirebaseInitializedProvider = Provider<bool>((_) {
  try {
    return Firebase.apps.isNotEmpty;
  } on Object {
    return false;
  }
}, name: 'aiFirebaseInitializedProvider');

final aiAppCheckActivationSnapshotProvider =
    Provider<FirebaseAppCheckActivationState>((ref) {
      final controller = ref.watch(
        firebaseAppCheckActivationControllerProvider,
      );
      return switch (ref.watch(firebaseAppCheckActivationStateProvider)) {
        AsyncData(:final value) => value,
        _ => controller.state,
      };
    }, name: 'aiAppCheckActivationSnapshotProvider');

/// This is real SDK activation state, not a claim that any future attestation
/// token or provider request will succeed. Each request still performs token
/// acquisition and maps a rejection to a typed retryable failure.
final aiAppCheckRuntimeAvailableProvider = Provider<bool>(
  (ref) => ref.watch(aiAppCheckActivationSnapshotProvider).isAvailable,
  name: 'aiAppCheckRuntimeAvailableProvider',
);

final aiConversationAuthenticationAvailableProvider = Provider<bool>(
  (ref) => ref.watch(currentAuthUserProvider) != null,
  name: 'aiConversationAuthenticationAvailableProvider',
);

final aiGeneralConversationRoutePlanProvider = Provider<AiProviderRoutePlan>((
  ref,
) {
  final runtime = ref.watch(aiRuntimeConfigProvider);
  final gatewayFlags = ref.watch(aiGatewayFeatureFlagsProvider);
  final gatewayConfig = ref.watch(aiGatewayRuntimeConfigProvider);
  final appCheckState = ref.watch(aiAppCheckActivationSnapshotProvider);
  final preference = aiRuntimeProviderPreferenceFor(
    runtime.resolvedConversationProviderPreference,
  );
  final remotePreflightReady =
      ref.watch(aiFirebasePlatformConfiguredProvider) &&
      ref.watch(aiFirebaseInitializedProvider) &&
      ref.watch(aiConversationAuthenticationAvailableProvider);
  return const AiProviderRouteResolver().resolveGeneralConversation(
    AiProviderRouteInputs(
      preference: preference,
      agentEnabled: ref.watch(aiAgentFeatureFlagsProvider).agentEnabled,
      groqGatewayEnabled: gatewayFlags.aiGroqGatewayEnabled,
      groqGeneralChatEnabled: gatewayFlags.aiGroqGeneralChatEnabled,
      groqConfigured: gatewayConfig.isConfigured,
      remotePreflightReady: remotePreflightReady,
      firebaseTextFallbackEnabled: gatewayFlags.aiFirebaseTextFallbackEnabled,
      firebaseConversationReady: remotePreflightReady,
      platformConfigured: ref.watch(aiFirebasePlatformConfiguredProvider),
      firebaseInitialized: ref.watch(aiFirebaseInitializedProvider),
      appCheckAvailable: ref.watch(aiAppCheckRuntimeAvailableProvider),
      appCheckAttemptable: _appCheckCanBecomeReady(appCheckState),
      authenticated: ref.watch(aiConversationAuthenticationAvailableProvider),
    ),
  );
}, name: 'aiGeneralConversationRoutePlanProvider');

AiRuntimeProviderPreference aiRuntimeProviderPreferenceFor(
  AiConversationProviderPreference preference,
) => switch (preference) {
  AiConversationProviderPreference.legacy => AiRuntimeProviderPreference.legacy,
  AiConversationProviderPreference.auto => AiRuntimeProviderPreference.auto,
  AiConversationProviderPreference.groq => AiRuntimeProviderPreference.groq,
  AiConversationProviderPreference.firebase =>
    AiRuntimeProviderPreference.firebase,
  AiConversationProviderPreference.disabled =>
    AiRuntimeProviderPreference.disabled,
};

bool _appCheckCanBecomeReady(FirebaseAppCheckActivationState state) {
  return state.isAvailable ||
      state.phase == FirebaseAppCheckActivationPhase.idle ||
      state.phase == FirebaseAppCheckActivationPhase.initializing ||
      state.retryable;
}

final aiAssistantCapabilitiesProvider = Provider<AiAssistantCapabilities>((
  ref,
) {
  final runtime = ref.watch(aiRuntimeConfigProvider);
  final gatewayFlags = ref.watch(aiGatewayFeatureFlagsProvider);
  final gatewayConfig = ref.watch(aiGatewayRuntimeConfigProvider);
  final agentFlags = ref.watch(aiAgentFeatureFlagsProvider);
  final appControl = ref.watch(effectiveAiAppControlPolicyProvider);
  final platformConfigured = ref.watch(aiFirebasePlatformConfiguredProvider);
  final firebaseInitialized = ref.watch(aiFirebaseInitializedProvider);
  final appCheckAvailable = ref.watch(aiAppCheckRuntimeAvailableProvider);
  final appCheckState = ref.watch(aiAppCheckActivationSnapshotProvider);
  final authenticated = ref.watch(
    aiConversationAuthenticationAvailableProvider,
  );
  final generalRoutePlan = ref.watch(aiGeneralConversationRoutePlanProvider);

  final preference = runtime.resolvedConversationProviderPreference;
  final automatic = preference == AiConversationProviderPreference.auto;
  final sharedRemotePreflightReady =
      platformConfigured && firebaseInitialized && authenticated;
  final groqRemotePreflightReady =
      sharedRemotePreflightReady && _appCheckCanBecomeReady(appCheckState);
  final firebaseRemotePreflightReady =
      sharedRemotePreflightReady && appCheckAvailable;
  final activeProvider = generalRoutePlan.routeAvailable
      ? generalRoutePlan.preflightProvider
      : preference == AiConversationProviderPreference.disabled &&
            runtime.providerMode == AiProviderMode.localParserOnly
      ? AiActiveProvider.localParserOnly
      : runtime.providerMode == AiProviderMode.mock
      ? AiActiveProvider.mock
      : AiActiveProvider.none;
  final generalAvailable = generalRoutePlan.routeAvailable;
  final reason = generalAvailable
      ? null
      : generalRoutePlan.routeUnavailableReason;
  final remoteFirebaseReady =
      preference != AiConversationProviderPreference.disabled &&
      firebaseRemotePreflightReady;
  final groqFinancialReady =
      (preference == AiConversationProviderPreference.groq || automatic) &&
      gatewayConfig.isConfigured &&
      groqRemotePreflightReady &&
      gatewayFlags.financialGatewayEnabledFor('en');
  final groqFinancialRequestSelected =
      (preference == AiConversationProviderPreference.groq || automatic) &&
      gatewayFlags.aiGroqGatewayEnabled &&
      (gatewayFlags.aiGroqGeneralChatEnabled ||
          gatewayFlags.aiGroqFinancialExplanationEnabled);
  final firebaseFinancialReady =
      (preference == AiConversationProviderPreference.firebase ||
          (gatewayFlags.aiFirebaseTextFallbackEnabled &&
              groqFinancialRequestSelected)) &&
      firebaseRemotePreflightReady;
  final financialProviderReady = firebaseFinancialReady || groqFinancialReady;

  return AiAssistantCapabilities(
    directConversationAvailable: true,
    generalConversationAvailable: generalAvailable,
    currentKnowledgeAvailable:
        agentFlags.agentEnabled &&
        gatewayFlags.aiCurrentWebEnabled &&
        remoteFirebaseReady,
    personalFinancialAnalysisAvailable:
        financialProviderReady && appControl.canReadFinancialData,
    financialDraftsAvailable:
        appControl.canCreateTransactionDraft ||
        appControl.canCreateBudgetOrGoalDraft,
    confirmedExecutionAvailable: appControl.canExecuteConfirmedFinancialCreate,
    receiptVisionAvailable:
        gatewayFlags.aiFirebaseReceiptVisionEnabled &&
        firebaseRemotePreflightReady,
    navigationAvailable: appControl.canNavigate,
    activeProvider: activeProvider,
    unavailableReason: reason,
    retryable: reason == AiUnavailableReason.appCheckUnavailable
        ? appCheckState.retryable ||
              appCheckState.phase == FirebaseAppCheckActivationPhase.idle ||
              appCheckState.phase ==
                  FirebaseAppCheckActivationPhase.initializing
        : isAiPreflightFailureRetryable(reason),
    platformSupported: platformConfigured,
  );
}, name: 'aiAssistantCapabilitiesProvider');
