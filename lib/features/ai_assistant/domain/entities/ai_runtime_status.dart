import '../../../../core/security/app_check_activation_status.dart';
import '../agent/ai_agent_models.dart';
import '../gateway/ai_conversation_gateway.dart';
import 'ai_capability.dart';

enum AiRuntimeProviderPreference { legacy, auto, groq, firebase, disabled }

enum AiRuntimeFallbackPolicy { none, firebaseBeforeContent }

enum AiRuntimeGatewayAvailability {
  notChecked,
  checking,
  available,
  unavailable,
  notConfigured,
}

enum AiRuntimeLiveStatus {
  notChecked,
  checking,
  ready,
  groqNotSelected,
  groqNotConfigured,
  groqAuthenticationFailed,
  groqModelUnavailable,
  groqRateLimited,
  groqRequestTimedOut,
  groqStreamTimedOut,
  groqMalformedResponse,
  groqUpstreamUnavailable,
  gatewayAuthenticationRequired,
  gatewayAppCheckRequired,
  gatewayRequestInvalid,
  gatewayUnavailable,
  offline,
  providerUnavailable,
  cancelled,
  stale,
  unknownTemporaryFailure,
}

enum AiRuntimeUiStatus {
  notTested,
  testing,
  available,
  unavailable,
  configurationMissing,
  authenticationRequired,
  appCheckUnavailable,
  gatewayUnavailable,
  modelUnavailable,
  rateLimited,
  offline,
  timedOut,
}

enum AiRuntimeBuildMode { debug, profile, release }

enum AiRuntimeEnvironment {
  unspecified,
  development,
  staging,
  production,
  other,
}

enum AiRuntimeModelSource { gatewayManaged, clientConfigured, unavailable }

enum AiRuntimeAppCheckProvider {
  debug,
  playIntegrity,
  appAttestWithDeviceCheckFallback,
  recaptchaEnterprise,
  windowsDebug,
  unknown,
}

abstract final class AiRuntimeModelCatalog {
  static const String gatewayGeneralConversation =
      'gateway-managed/general-conversation';
  static const String gatewayFinancialExplanation =
      'gateway-managed/financial-explanation';
  static const String localCommandParser = 'cashpilot-local-parser-v1';
}

final class AiAppBuildMetadata {
  const AiAppBuildMetadata({required this.version, required this.buildNumber});

  const AiAppBuildMetadata.unavailable() : version = null, buildNumber = null;

  final String? version;
  final String? buildNumber;

  bool get isComplete => version != null && buildNumber != null;

  @override
  bool operator ==(Object other) =>
      other is AiAppBuildMetadata &&
      other.version == version &&
      other.buildNumber == buildNumber;

  @override
  int get hashCode => Object.hash(version, buildNumber);
}

final class AiRuntimeModelIdentity {
  const AiRuntimeModelIdentity({required this.source, this.safeModelId});

  const AiRuntimeModelIdentity.gatewayManaged({
    this.safeModelId = AiRuntimeModelCatalog.gatewayGeneralConversation,
  }) : source = AiRuntimeModelSource.gatewayManaged,
       assert(safeModelId != null);

  const AiRuntimeModelIdentity.unavailable()
    : source = AiRuntimeModelSource.unavailable,
      safeModelId = null;

  final AiRuntimeModelSource source;
  final String? safeModelId;

  @override
  bool operator ==(Object other) =>
      other is AiRuntimeModelIdentity &&
      other.source == source &&
      other.safeModelId == safeModelId;

  @override
  int get hashCode => Object.hash(source, safeModelId);
}

final class AiProviderRoutePlan {
  const AiProviderRoutePlan({
    required this.task,
    required this.primaryProvider,
    required this.primaryAvailable,
    required this.preflightProvider,
    required this.fallbackProvider,
    required this.fallbackAvailable,
    required this.fallbackPolicy,
    required this.primaryUnavailableReason,
    required this.routeUnavailableReason,
  });

  final ModelTask task;
  final AiActiveProvider primaryProvider;
  final bool primaryAvailable;
  final AiActiveProvider preflightProvider;
  final AiActiveProvider? fallbackProvider;
  final bool fallbackAvailable;
  final AiRuntimeFallbackPolicy fallbackPolicy;
  final AiUnavailableReason? primaryUnavailableReason;
  final AiUnavailableReason? routeUnavailableReason;

  bool get routeAvailable => preflightProvider != AiActiveProvider.none;

  @override
  bool operator ==(Object other) =>
      other is AiProviderRoutePlan &&
      other.task == task &&
      other.primaryProvider == primaryProvider &&
      other.primaryAvailable == primaryAvailable &&
      other.preflightProvider == preflightProvider &&
      other.fallbackProvider == fallbackProvider &&
      other.fallbackAvailable == fallbackAvailable &&
      other.fallbackPolicy == fallbackPolicy &&
      other.primaryUnavailableReason == primaryUnavailableReason &&
      other.routeUnavailableReason == routeUnavailableReason;

  @override
  int get hashCode => Object.hash(
    task,
    primaryProvider,
    primaryAvailable,
    preflightProvider,
    fallbackProvider,
    fallbackAvailable,
    fallbackPolicy,
    primaryUnavailableReason,
    routeUnavailableReason,
  );
}

final class AiRuntimeStatusFingerprint {
  const AiRuntimeStatusFingerprint(this.value)
    : assert(value.length == 64, 'Runtime fingerprints must be SHA-256 hex.');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is AiRuntimeStatusFingerprint && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AiRuntimeStatusFingerprint(redacted)';
}

final class AiRuntimeStatusSnapshot {
  const AiRuntimeStatusSnapshot({
    required this.fingerprint,
    required this.routePlan,
    required this.appBuild,
    required this.buildMode,
    required this.environment,
    required this.preference,
    required this.gatewayConfigured,
    required this.groqGatewayEnabled,
    required this.groqGeneralChatEnabled,
    required this.model,
    required this.firebaseTextFallbackEnabled,
    required this.authenticated,
    required this.authSessionGeneration,
    required this.firebasePlatformConfigured,
    required this.firebaseInitialized,
    required this.appCheckPhase,
    required this.appCheckUnavailableReason,
    required this.appCheckProvider,
    required this.financialExplanationProvider,
    required this.financialExplanationModel,
    required this.receiptVisionProvider,
    required this.receiptVisionModel,
    required this.gatewayAvailability,
    required this.liveStatus,
    required this.probedProvider,
    required this.respondingProvider,
    required this.receivedNonEmptyContent,
    required this.gatewayFailureCode,
    required this.checkedAt,
    required this.lastLiveTestLatency,
  });

  final AiRuntimeStatusFingerprint fingerprint;
  final AiProviderRoutePlan routePlan;
  final AiAppBuildMetadata appBuild;
  final AiRuntimeBuildMode buildMode;
  final AiRuntimeEnvironment environment;
  final AiRuntimeProviderPreference preference;
  final bool gatewayConfigured;
  final bool groqGatewayEnabled;
  final bool groqGeneralChatEnabled;
  final AiRuntimeModelIdentity model;
  final bool firebaseTextFallbackEnabled;
  final bool authenticated;
  final int? authSessionGeneration;
  final bool firebasePlatformConfigured;
  final bool firebaseInitialized;
  final AppCheckActivationPhase appCheckPhase;
  final AppCheckUnavailableReason? appCheckUnavailableReason;
  final AiRuntimeAppCheckProvider appCheckProvider;
  final AiActiveProvider financialExplanationProvider;
  final String financialExplanationModel;
  final AiActiveProvider receiptVisionProvider;
  final String receiptVisionModel;
  final AiRuntimeGatewayAvailability gatewayAvailability;
  final AiRuntimeLiveStatus liveStatus;
  final AiActiveProvider? probedProvider;
  final AiActiveProvider? respondingProvider;
  final bool receivedNonEmptyContent;
  final AiGatewayFailureCode? gatewayFailureCode;
  final DateTime? checkedAt;
  final Duration? lastLiveTestLatency;

  AiActiveProvider get remoteTextProvider =>
      routePlan.preflightProvider == AiActiveProvider.none
      ? routePlan.primaryProvider
      : routePlan.preflightProvider;

  bool get remoteTextProviderConfigured => switch (remoteTextProvider) {
    AiActiveProvider.groq =>
      gatewayConfigured && groqGatewayEnabled && groqGeneralChatEnabled,
    AiActiveProvider.firebase =>
      firebasePlatformConfigured && firebaseInitialized,
    _ => false,
  };

  bool get remoteTextProviderAvailable => routePlan.routeAvailable;

  String? get generalConversationModel => model.safeModelId;

  String get localCommandParser => AiRuntimeModelCatalog.localCommandParser;

  bool get appCheckActivated =>
      appCheckPhase == AppCheckActivationPhase.available;

  bool get gatewayReachable =>
      gatewayAvailability == AiRuntimeGatewayAvailability.available;

  bool get authenticationReady => authenticated;

  AiActiveProvider? get lastLiveTestProvider =>
      respondingProvider ?? probedProvider;

  String? get lastLiveTestModel => probedProvider == null
      ? null
      : probedProvider == AiActiveProvider.groq
      ? AiRuntimeModelCatalog.gatewayGeneralConversation
      : model.safeModelId;

  AiRuntimeUiStatus get lastLiveTestStatus => switch (liveStatus) {
    AiRuntimeLiveStatus.notChecked ||
    AiRuntimeLiveStatus.groqNotSelected => AiRuntimeUiStatus.notTested,
    AiRuntimeLiveStatus.checking => AiRuntimeUiStatus.testing,
    AiRuntimeLiveStatus.ready => AiRuntimeUiStatus.available,
    AiRuntimeLiveStatus.groqNotConfigured =>
      AiRuntimeUiStatus.configurationMissing,
    AiRuntimeLiveStatus.groqAuthenticationFailed ||
    AiRuntimeLiveStatus.gatewayAuthenticationRequired =>
      AiRuntimeUiStatus.authenticationRequired,
    AiRuntimeLiveStatus.gatewayAppCheckRequired =>
      AiRuntimeUiStatus.appCheckUnavailable,
    AiRuntimeLiveStatus.gatewayUnavailable ||
    AiRuntimeLiveStatus.groqUpstreamUnavailable =>
      AiRuntimeUiStatus.gatewayUnavailable,
    AiRuntimeLiveStatus.groqModelUnavailable ||
    AiRuntimeLiveStatus.groqMalformedResponse ||
    AiRuntimeLiveStatus.gatewayRequestInvalid =>
      AiRuntimeUiStatus.modelUnavailable,
    AiRuntimeLiveStatus.groqRateLimited => AiRuntimeUiStatus.rateLimited,
    AiRuntimeLiveStatus.offline => AiRuntimeUiStatus.offline,
    AiRuntimeLiveStatus.groqRequestTimedOut ||
    AiRuntimeLiveStatus.groqStreamTimedOut => AiRuntimeUiStatus.timedOut,
    AiRuntimeLiveStatus.providerUnavailable ||
    AiRuntimeLiveStatus.cancelled ||
    AiRuntimeLiveStatus.stale ||
    AiRuntimeLiveStatus.unknownTemporaryFailure =>
      AiRuntimeUiStatus.unavailable,
  };

  AiGatewayFailureCode? get lastLiveTestFailureCode => gatewayFailureCode;

  DateTime? get lastLiveTestTimestamp => checkedAt;

  bool get retryable => switch (lastLiveTestStatus) {
    AiRuntimeUiStatus.gatewayUnavailable ||
    AiRuntimeUiStatus.offline ||
    AiRuntimeUiStatus.timedOut ||
    AiRuntimeUiStatus.rateLimited ||
    AiRuntimeUiStatus.unavailable => true,
    _ => false,
  };

  AiRuntimeStatusFingerprint get configurationFingerprint => fingerprint;

  bool get liveReady =>
      liveStatus == AiRuntimeLiveStatus.ready &&
      probedProvider == AiActiveProvider.groq &&
      respondingProvider == AiActiveProvider.groq &&
      receivedNonEmptyContent;

  AiRuntimeStatusSnapshot copyWith({
    AiRuntimeGatewayAvailability? gatewayAvailability,
    AiRuntimeLiveStatus? liveStatus,
    AiActiveProvider? probedProvider,
    AiActiveProvider? respondingProvider,
    bool? receivedNonEmptyContent,
    AiGatewayFailureCode? gatewayFailureCode,
    DateTime? checkedAt,
    Duration? liveTestLatency,
    bool clearProbe = false,
  }) {
    return AiRuntimeStatusSnapshot(
      fingerprint: fingerprint,
      routePlan: routePlan,
      appBuild: appBuild,
      buildMode: buildMode,
      environment: environment,
      preference: preference,
      gatewayConfigured: gatewayConfigured,
      groqGatewayEnabled: groqGatewayEnabled,
      groqGeneralChatEnabled: groqGeneralChatEnabled,
      model: model,
      firebaseTextFallbackEnabled: firebaseTextFallbackEnabled,
      authenticated: authenticated,
      authSessionGeneration: authSessionGeneration,
      firebasePlatformConfigured: firebasePlatformConfigured,
      firebaseInitialized: firebaseInitialized,
      appCheckPhase: appCheckPhase,
      appCheckUnavailableReason: appCheckUnavailableReason,
      appCheckProvider: appCheckProvider,
      financialExplanationProvider: financialExplanationProvider,
      financialExplanationModel: financialExplanationModel,
      receiptVisionProvider: receiptVisionProvider,
      receiptVisionModel: receiptVisionModel,
      gatewayAvailability: gatewayAvailability ?? this.gatewayAvailability,
      liveStatus: clearProbe
          ? AiRuntimeLiveStatus.notChecked
          : liveStatus ?? this.liveStatus,
      probedProvider: clearProbe ? null : probedProvider ?? this.probedProvider,
      respondingProvider: clearProbe
          ? null
          : respondingProvider ?? this.respondingProvider,
      receivedNonEmptyContent: clearProbe
          ? false
          : receivedNonEmptyContent ?? this.receivedNonEmptyContent,
      gatewayFailureCode: clearProbe
          ? null
          : gatewayFailureCode ?? this.gatewayFailureCode,
      checkedAt: clearProbe ? null : checkedAt ?? this.checkedAt,
      lastLiveTestLatency: clearProbe
          ? null
          : liveTestLatency ?? lastLiveTestLatency,
    );
  }

  AiRuntimeStatusSnapshot beginLiveTest() => AiRuntimeStatusSnapshot(
    fingerprint: fingerprint,
    routePlan: routePlan,
    appBuild: appBuild,
    buildMode: buildMode,
    environment: environment,
    preference: preference,
    gatewayConfigured: gatewayConfigured,
    groqGatewayEnabled: groqGatewayEnabled,
    groqGeneralChatEnabled: groqGeneralChatEnabled,
    model: model,
    firebaseTextFallbackEnabled: firebaseTextFallbackEnabled,
    authenticated: authenticated,
    authSessionGeneration: authSessionGeneration,
    firebasePlatformConfigured: firebasePlatformConfigured,
    firebaseInitialized: firebaseInitialized,
    appCheckPhase: appCheckPhase,
    appCheckUnavailableReason: appCheckUnavailableReason,
    appCheckProvider: appCheckProvider,
    financialExplanationProvider: financialExplanationProvider,
    financialExplanationModel: financialExplanationModel,
    receiptVisionProvider: receiptVisionProvider,
    receiptVisionModel: receiptVisionModel,
    gatewayAvailability: gatewayAvailability,
    liveStatus: AiRuntimeLiveStatus.checking,
    probedProvider: AiActiveProvider.groq,
    respondingProvider: null,
    receivedNonEmptyContent: false,
    gatewayFailureCode: null,
    checkedAt: null,
    lastLiveTestLatency: null,
  );

  AiRuntimeStatusSnapshot completeLiveTest({
    required AiRuntimeLiveStatus status,
    required AiActiveProvider? probedProvider,
    required AiActiveProvider? respondingProvider,
    required bool receivedNonEmptyContent,
    required AiGatewayFailureCode? failureCode,
    required DateTime checkedAt,
    required Duration latency,
  }) => AiRuntimeStatusSnapshot(
    fingerprint: fingerprint,
    routePlan: routePlan,
    appBuild: appBuild,
    buildMode: buildMode,
    environment: environment,
    preference: preference,
    gatewayConfigured: gatewayConfigured,
    groqGatewayEnabled: groqGatewayEnabled,
    groqGeneralChatEnabled: groqGeneralChatEnabled,
    model: model,
    firebaseTextFallbackEnabled: firebaseTextFallbackEnabled,
    authenticated: authenticated,
    authSessionGeneration: authSessionGeneration,
    firebasePlatformConfigured: firebasePlatformConfigured,
    firebaseInitialized: firebaseInitialized,
    appCheckPhase: appCheckPhase,
    appCheckUnavailableReason: appCheckUnavailableReason,
    appCheckProvider: appCheckProvider,
    financialExplanationProvider: financialExplanationProvider,
    financialExplanationModel: financialExplanationModel,
    receiptVisionProvider: receiptVisionProvider,
    receiptVisionModel: receiptVisionModel,
    gatewayAvailability: gatewayAvailability,
    liveStatus: status,
    probedProvider: probedProvider,
    respondingProvider: respondingProvider,
    receivedNonEmptyContent: receivedNonEmptyContent,
    gatewayFailureCode: failureCode,
    checkedAt: checkedAt,
    lastLiveTestLatency: latency,
  );

  @override
  bool operator ==(Object other) =>
      other is AiRuntimeStatusSnapshot &&
      other.fingerprint == fingerprint &&
      other.routePlan == routePlan &&
      other.appBuild == appBuild &&
      other.buildMode == buildMode &&
      other.environment == environment &&
      other.preference == preference &&
      other.gatewayConfigured == gatewayConfigured &&
      other.groqGatewayEnabled == groqGatewayEnabled &&
      other.groqGeneralChatEnabled == groqGeneralChatEnabled &&
      other.model == model &&
      other.firebaseTextFallbackEnabled == firebaseTextFallbackEnabled &&
      other.authenticated == authenticated &&
      other.authSessionGeneration == authSessionGeneration &&
      other.firebasePlatformConfigured == firebasePlatformConfigured &&
      other.firebaseInitialized == firebaseInitialized &&
      other.appCheckPhase == appCheckPhase &&
      other.appCheckUnavailableReason == appCheckUnavailableReason &&
      other.appCheckProvider == appCheckProvider &&
      other.financialExplanationProvider == financialExplanationProvider &&
      other.financialExplanationModel == financialExplanationModel &&
      other.receiptVisionProvider == receiptVisionProvider &&
      other.receiptVisionModel == receiptVisionModel &&
      other.gatewayAvailability == gatewayAvailability &&
      other.liveStatus == liveStatus &&
      other.probedProvider == probedProvider &&
      other.respondingProvider == respondingProvider &&
      other.receivedNonEmptyContent == receivedNonEmptyContent &&
      other.gatewayFailureCode == gatewayFailureCode &&
      other.checkedAt == checkedAt &&
      other.lastLiveTestLatency == lastLiveTestLatency;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    fingerprint,
    routePlan,
    appBuild,
    buildMode,
    environment,
    preference,
    gatewayConfigured,
    groqGatewayEnabled,
    groqGeneralChatEnabled,
    model,
    firebaseTextFallbackEnabled,
    authenticated,
    authSessionGeneration,
    firebasePlatformConfigured,
    firebaseInitialized,
    appCheckPhase,
    appCheckUnavailableReason,
    appCheckProvider,
    financialExplanationProvider,
    financialExplanationModel,
    receiptVisionProvider,
    receiptVisionModel,
    gatewayAvailability,
    liveStatus,
    probedProvider,
    respondingProvider,
    receivedNonEmptyContent,
    gatewayFailureCode,
    checkedAt,
    lastLiveTestLatency,
  ]);
}

AiRuntimeLiveStatus aiRuntimeLiveStatusForGatewayFailure(
  AiGatewayFailureCode code,
) {
  return switch (code) {
    AiGatewayFailureCode.groqNotConfigured =>
      AiRuntimeLiveStatus.groqNotConfigured,
    AiGatewayFailureCode.groqAuthenticationFailed =>
      AiRuntimeLiveStatus.groqAuthenticationFailed,
    AiGatewayFailureCode.groqModelUnavailable =>
      AiRuntimeLiveStatus.groqModelUnavailable,
    AiGatewayFailureCode.groqRateLimited ||
    AiGatewayFailureCode.rateLimited ||
    AiGatewayFailureCode.providerQuotaExceeded =>
      AiRuntimeLiveStatus.groqRateLimited,
    AiGatewayFailureCode.groqRequestTimedOut =>
      AiRuntimeLiveStatus.groqRequestTimedOut,
    AiGatewayFailureCode.groqStreamTimedOut ||
    AiGatewayFailureCode.timeout => AiRuntimeLiveStatus.groqStreamTimedOut,
    AiGatewayFailureCode.groqMalformedResponse ||
    AiGatewayFailureCode.invalidResponse ||
    AiGatewayFailureCode.emptyResponse ||
    AiGatewayFailureCode.malformedSse ||
    AiGatewayFailureCode.streamEndedWithoutCompleted =>
      AiRuntimeLiveStatus.groqMalformedResponse,
    AiGatewayFailureCode.groqUpstreamUnavailable =>
      AiRuntimeLiveStatus.groqUpstreamUnavailable,
    AiGatewayFailureCode.authenticationNotReady ||
    AiGatewayFailureCode.gatewayAuthenticationRequired ||
    AiGatewayFailureCode.unauthenticated =>
      AiRuntimeLiveStatus.gatewayAuthenticationRequired,
    AiGatewayFailureCode.appCheckUnavailable ||
    AiGatewayFailureCode.appCheckTimedOut ||
    AiGatewayFailureCode.gatewayAppCheckRequired ||
    AiGatewayFailureCode.appCheckRejected =>
      AiRuntimeLiveStatus.gatewayAppCheckRequired,
    AiGatewayFailureCode.gatewayRequestInvalid ||
    AiGatewayFailureCode.requestTooLarge ||
    AiGatewayFailureCode.toolSelectionInvalid =>
      AiRuntimeLiveStatus.gatewayRequestInvalid,
    AiGatewayFailureCode.gatewayUnavailable ||
    AiGatewayFailureCode.providerUnavailable =>
      AiRuntimeLiveStatus.gatewayUnavailable,
    AiGatewayFailureCode.networkFailure => AiRuntimeLiveStatus.offline,
    AiGatewayFailureCode.configurationFailure =>
      AiRuntimeLiveStatus.providerUnavailable,
    AiGatewayFailureCode.unknownTemporaryFailure =>
      AiRuntimeLiveStatus.unknownTemporaryFailure,
  };
}
