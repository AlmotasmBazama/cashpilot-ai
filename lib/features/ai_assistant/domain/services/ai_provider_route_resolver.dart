import '../agent/ai_agent_models.dart';
import '../entities/ai_capability.dart';
import '../entities/ai_runtime_status.dart';

final class AiProviderRouteInputs {
  const AiProviderRouteInputs({
    required this.preference,
    required this.agentEnabled,
    required this.groqGatewayEnabled,
    required this.groqGeneralChatEnabled,
    required this.groqConfigured,
    required this.remotePreflightReady,
    required this.firebaseTextFallbackEnabled,
    required this.firebaseConversationReady,
    required this.platformConfigured,
    required this.firebaseInitialized,
    required this.appCheckAvailable,
    required this.appCheckAttemptable,
    required this.authenticated,
  });

  final AiRuntimeProviderPreference preference;
  final bool agentEnabled;
  final bool groqGatewayEnabled;
  final bool groqGeneralChatEnabled;
  final bool groqConfigured;
  final bool remotePreflightReady;
  final bool firebaseTextFallbackEnabled;
  final bool firebaseConversationReady;
  final bool platformConfigured;
  final bool firebaseInitialized;
  final bool appCheckAvailable;
  final bool appCheckAttemptable;
  final bool authenticated;
}

final class AiProviderRouteResolver {
  const AiProviderRouteResolver();

  AiProviderRoutePlan resolveGeneralConversation(AiProviderRouteInputs inputs) {
    final sharedRemotePreflightReady =
        inputs.remotePreflightReady &&
        inputs.platformConfigured &&
        inputs.firebaseInitialized &&
        inputs.authenticated;
    final groqRemotePreflightReady =
        sharedRemotePreflightReady && inputs.appCheckAttemptable;
    final firebaseRemotePreflightReady =
        sharedRemotePreflightReady && inputs.appCheckAvailable;
    final explicitGroq = inputs.preference == AiRuntimeProviderPreference.groq;
    final automatic =
        inputs.preference == AiRuntimeProviderPreference.auto ||
        inputs.preference == AiRuntimeProviderPreference.legacy;
    final explicitFirebase =
        inputs.preference == AiRuntimeProviderPreference.firebase;
    final groqSelected =
        (explicitGroq || automatic) &&
        inputs.groqGatewayEnabled &&
        inputs.groqGeneralChatEnabled;
    final firebaseFallbackConfigured =
        groqSelected && inputs.firebaseTextFallbackEnabled;

    final primaryProvider = groqSelected || explicitGroq
        ? AiActiveProvider.groq
        : explicitFirebase
        ? AiActiveProvider.firebase
        : AiActiveProvider.none;
    final fallbackProvider = firebaseFallbackConfigured
        ? AiActiveProvider.firebase
        : null;
    final primaryAvailable = switch (primaryProvider) {
      AiActiveProvider.groq =>
        inputs.agentEnabled &&
            groqSelected &&
            inputs.groqConfigured &&
            groqRemotePreflightReady,
      AiActiveProvider.firebase =>
        inputs.agentEnabled &&
            inputs.firebaseConversationReady &&
            firebaseRemotePreflightReady,
      _ => false,
    };
    final fallbackAvailable =
        inputs.agentEnabled &&
        fallbackProvider == AiActiveProvider.firebase &&
        inputs.firebaseConversationReady &&
        firebaseRemotePreflightReady;
    final preflightProvider = primaryAvailable
        ? primaryProvider
        : fallbackAvailable
        ? AiActiveProvider.firebase
        : AiActiveProvider.none;
    final primaryUnavailableReason = primaryAvailable
        ? null
        : _unavailableReason(inputs, primaryProvider, groqSelected);
    final routeUnavailableReason = preflightProvider != AiActiveProvider.none
        ? null
        : primaryUnavailableReason;

    return AiProviderRoutePlan(
      task: ModelTask.generalConversation,
      primaryProvider: primaryProvider,
      primaryAvailable: primaryAvailable,
      preflightProvider: preflightProvider,
      fallbackProvider: fallbackProvider,
      fallbackAvailable: fallbackAvailable,
      fallbackPolicy: fallbackProvider == null
          ? AiRuntimeFallbackPolicy.none
          : AiRuntimeFallbackPolicy.firebaseBeforeContent,
      primaryUnavailableReason: primaryUnavailableReason,
      routeUnavailableReason: routeUnavailableReason,
    );
  }

  AiUnavailableReason _unavailableReason(
    AiProviderRouteInputs inputs,
    AiActiveProvider primaryProvider,
    bool groqSelected,
  ) {
    if (!inputs.agentEnabled) return AiUnavailableReason.gatewayDisabled;
    if (primaryProvider == AiActiveProvider.none) {
      return AiUnavailableReason.gatewayDisabled;
    }
    if (primaryProvider == AiActiveProvider.groq) {
      if (!groqSelected) return AiUnavailableReason.gatewayDisabled;
      if (!inputs.groqConfigured) return AiUnavailableReason.gatewayUrlMissing;
    }
    if (!inputs.platformConfigured) {
      return AiUnavailableReason.platformNotConfigured;
    }
    if (!inputs.firebaseInitialized) {
      return AiUnavailableReason.firebaseNotInitialized;
    }
    if (!inputs.appCheckAvailable) {
      return AiUnavailableReason.appCheckUnavailable;
    }
    if (!inputs.authenticated) {
      return AiUnavailableReason.authenticationRequired;
    }
    return AiUnavailableReason.firebaseAiUnavailable;
  }
}
