enum AiCapability {
  chat,
  financialInsights,
  transactionParsing,
  spendingAnalysis,
  cashFlowExplanation,
}

/// The provider selected for remote conversational work.
///
/// [localParserOnly] is deliberately represented but is never considered a
/// general-conversation model. It can still support deterministic command
/// understanding while remote chat is unavailable.
enum AiActiveProvider { none, groq, firebase, localParserOnly, mock }

/// Safe, typed reasons that a specific assistant capability is unavailable.
///
/// These values are suitable for diagnostics and localization. They must not
/// contain raw provider errors, URLs, tokens, or user data.
enum AiUnavailableReason {
  platformNotConfigured,
  firebaseNotInitialized,
  firebaseAiUnavailable,
  appCheckUnavailable,
  appCheckTimedOut,
  appCheckRejected,
  authenticationNotReady,
  authenticationRequired,
  gatewayDisabled,
  gatewayUrlMissing,
  gatewayUnreachable,
  providerTimedOut,
  providerRejectedRequest,
  rateLimited,
  modelUnavailable,
  offline,
  financialAccessDisabled,
  ownerScopeNotReady,
  legacyDataUnresolved,
  receiptVisionUnavailable,
  unknownTemporaryFailure,
}

/// One immutable configuration/preflight snapshot of independently gated
/// assistant capabilities.
///
/// [unavailableReason] describes remote general conversation. Financial,
/// receipt, current-knowledge, and navigation availability remain explicit
/// booleans so disabling one surface never disables the whole assistant.
/// A `true` remote boolean means the app is eligible to attempt that request;
/// it never claims live provider, network, token, or model health.
final class AiAssistantCapabilities {
  const AiAssistantCapabilities({
    required this.directConversationAvailable,
    required this.generalConversationAvailable,
    required this.currentKnowledgeAvailable,
    required this.personalFinancialAnalysisAvailable,
    required this.financialDraftsAvailable,
    required this.confirmedExecutionAvailable,
    required this.receiptVisionAvailable,
    required this.navigationAvailable,
    required this.activeProvider,
    required this.unavailableReason,
    required this.retryable,
    required this.platformSupported,
  });

  const AiAssistantCapabilities.testDefaults()
    : directConversationAvailable = true,
      generalConversationAvailable = true,
      currentKnowledgeAvailable = true,
      personalFinancialAnalysisAvailable = true,
      financialDraftsAvailable = true,
      confirmedExecutionAvailable = false,
      receiptVisionAvailable = true,
      navigationAvailable = true,
      activeProvider = AiActiveProvider.firebase,
      unavailableReason = null,
      retryable = false,
      platformSupported = true;

  final bool directConversationAvailable;
  final bool generalConversationAvailable;
  final bool currentKnowledgeAvailable;
  final bool personalFinancialAnalysisAvailable;
  final bool financialDraftsAvailable;
  final bool confirmedExecutionAvailable;
  final bool receiptVisionAvailable;
  final bool navigationAvailable;
  final AiActiveProvider activeProvider;
  final AiUnavailableReason? unavailableReason;
  final bool retryable;
  final bool platformSupported;
}

/// Maps only allowlisted, user-safe diagnostic codes to the typed capability
/// failure model. Raw exception messages must never enter this boundary.
AiUnavailableReason? aiUnavailableReasonForSafeCode(String code) {
  for (final reason in AiUnavailableReason.values) {
    if (reason.name == code) return reason;
  }
  return switch (code) {
    'groqNotConfigured' => AiUnavailableReason.gatewayUrlMissing,
    'groqAuthenticationFailed' ||
    'groqModelUnavailable' ||
    'groqMalformedResponse' => AiUnavailableReason.modelUnavailable,
    'groqRateLimited' => AiUnavailableReason.rateLimited,
    'groqRequestTimedOut' ||
    'groqStreamTimedOut' => AiUnavailableReason.providerTimedOut,
    'groqUpstreamUnavailable' ||
    'gatewayUnavailable' => AiUnavailableReason.gatewayUnreachable,
    'gatewayAuthenticationRequired' =>
      AiUnavailableReason.authenticationNotReady,
    'gatewayAppCheckRequired' => AiUnavailableReason.appCheckUnavailable,
    'gatewayRequestInvalid' => AiUnavailableReason.providerRejectedRequest,
    'unknownTemporaryFailure' => AiUnavailableReason.unknownTemporaryFailure,
    'unauthenticated' => AiUnavailableReason.authenticationNotReady,
    'app_check_unavailable' => AiUnavailableReason.appCheckUnavailable,
    'app_check_timed_out' => AiUnavailableReason.appCheckTimedOut,
    'app_check_rejected' ||
    'app_check_blocked' => AiUnavailableReason.appCheckRejected,
    'authentication_not_ready' => AiUnavailableReason.authenticationNotReady,
    'provider_unavailable' => AiUnavailableReason.gatewayUnreachable,
    'model_timeout' => AiUnavailableReason.providerTimedOut,
    'network_failure' => AiUnavailableReason.offline,
    'configuration_failure' => AiUnavailableReason.modelUnavailable,
    'provider_disabled' => AiUnavailableReason.gatewayDisabled,
    'rate_limited' => AiUnavailableReason.rateLimited,
    'quota_exceeded' ||
    'request_too_large' ||
    'tool_selection_invalid' => AiUnavailableReason.providerRejectedRequest,
    'model_unavailable' ||
    'empty_response' ||
    'invalid_response' ||
    'malformed_sse' ||
    'stream_ended_without_completed' => AiUnavailableReason.modelUnavailable,
    _ => null,
  };
}

/// Request failures are retried by starting a fresh provider request. This is
/// intentionally broader than configuration preflight retryability because
/// Auth and App Check tokens may refresh between attempts.
bool isAiRequestFailureRetryable(AiUnavailableReason? reason) {
  return switch (reason) {
    AiUnavailableReason.appCheckUnavailable ||
    AiUnavailableReason.appCheckTimedOut ||
    AiUnavailableReason.appCheckRejected ||
    AiUnavailableReason.authenticationNotReady ||
    AiUnavailableReason.authenticationRequired ||
    AiUnavailableReason.firebaseAiUnavailable ||
    AiUnavailableReason.gatewayUnreachable ||
    AiUnavailableReason.providerTimedOut ||
    AiUnavailableReason.providerRejectedRequest ||
    AiUnavailableReason.rateLimited ||
    AiUnavailableReason.modelUnavailable ||
    AiUnavailableReason.offline ||
    AiUnavailableReason.ownerScopeNotReady ||
    AiUnavailableReason.unknownTemporaryFailure => true,
    _ => false,
  };
}

/// Static/configuration preflight never claims provider health. Only conditions
/// expected to recover without an app configuration change are retryable.
bool isAiPreflightFailureRetryable(AiUnavailableReason? reason) {
  return switch (reason) {
    AiUnavailableReason.appCheckUnavailable ||
    AiUnavailableReason.appCheckTimedOut ||
    AiUnavailableReason.appCheckRejected ||
    AiUnavailableReason.authenticationNotReady ||
    AiUnavailableReason.firebaseAiUnavailable ||
    AiUnavailableReason.gatewayUnreachable ||
    AiUnavailableReason.providerTimedOut ||
    AiUnavailableReason.providerRejectedRequest ||
    AiUnavailableReason.rateLimited ||
    AiUnavailableReason.modelUnavailable ||
    AiUnavailableReason.offline ||
    AiUnavailableReason.unknownTemporaryFailure => true,
    _ => false,
  };
}
