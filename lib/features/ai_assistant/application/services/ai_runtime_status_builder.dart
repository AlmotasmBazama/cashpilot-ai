import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/security/app_check_activation_status.dart';
import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_runtime_status.dart';

@immutable
final class AiRuntimeStatusConfiguration {
  const AiRuntimeStatusConfiguration({
    required this.routePlan,
    required this.appBuild,
    required this.buildMode,
    required this.environment,
    required this.normalizedEnvironmentName,
    required this.preference,
    required this.gatewayConfigured,
    required this.groqGatewayEnabled,
    required this.groqGeneralChatEnabled,
    required this.normalizedGatewayOrigin,
    required this.gatewayClientVersion,
    required this.model,
    required this.firebaseTextFallbackEnabled,
    required this.authenticated,
    required this.authSessionGeneration,
    required this.authIsAnonymous,
    required this.authTenantConfigured,
    required this.firebasePlatformConfigured,
    required this.firebaseInitialized,
    required this.appCheckPhase,
    required this.appCheckUnavailableReason,
    required this.appCheckProvider,
    required this.financialExplanationProvider,
    required this.financialExplanationModel,
    required this.receiptVisionProvider,
    required this.receiptVisionModel,
  });

  final AiProviderRoutePlan routePlan;
  final AiAppBuildMetadata appBuild;
  final AiRuntimeBuildMode buildMode;
  final AiRuntimeEnvironment environment;

  /// A normalized, safe deployment label. It remains inside the digest so
  /// distinct custom environments (for example, local and qa) cannot collide.
  final String normalizedEnvironmentName;
  final AiRuntimeProviderPreference preference;
  final bool gatewayConfigured;
  final bool groqGatewayEnabled;
  final bool groqGeneralChatEnabled;
  final String normalizedGatewayOrigin;
  final String gatewayClientVersion;
  final AiRuntimeModelIdentity model;
  final bool firebaseTextFallbackEnabled;
  final bool authenticated;
  final int? authSessionGeneration;
  final bool? authIsAnonymous;
  final bool authTenantConfigured;
  final bool firebasePlatformConfigured;
  final bool firebaseInitialized;
  final AppCheckActivationPhase appCheckPhase;
  final AppCheckUnavailableReason? appCheckUnavailableReason;
  final AiRuntimeAppCheckProvider appCheckProvider;
  final AiActiveProvider financialExplanationProvider;
  final String financialExplanationModel;
  final AiActiveProvider receiptVisionProvider;
  final String receiptVisionModel;
}

AiRuntimeStatusSnapshot buildAiRuntimeStatusSnapshot(
  AiRuntimeStatusConfiguration configuration,
) {
  final canonical = <String, Object?>{
    'appVersion': configuration.appBuild.version,
    'buildNumber': configuration.appBuild.buildNumber,
    'buildMode': configuration.buildMode.name,
    'environment': configuration.normalizedEnvironmentName,
    'preference': configuration.preference.name,
    'gatewayConfigured': configuration.gatewayConfigured,
    'groqGatewayEnabled': configuration.groqGatewayEnabled,
    'groqGeneralChatEnabled': configuration.groqGeneralChatEnabled,
    'gatewayOrigin': configuration.normalizedGatewayOrigin,
    'gatewayClientVersion': configuration.gatewayClientVersion,
    'modelSource': configuration.model.source.name,
    'modelId': configuration.model.safeModelId,
    'firebaseTextFallbackEnabled': configuration.firebaseTextFallbackEnabled,
    'authenticated': configuration.authenticated,
    'authSessionGeneration': configuration.authSessionGeneration,
    'authIsAnonymous': configuration.authIsAnonymous,
    'authTenantConfigured': configuration.authTenantConfigured,
    'firebasePlatformConfigured': configuration.firebasePlatformConfigured,
    'firebaseInitialized': configuration.firebaseInitialized,
    'appCheckPhase': configuration.appCheckPhase.name,
    'appCheckReason': configuration.appCheckUnavailableReason?.name,
    'appCheckProvider': configuration.appCheckProvider.name,
    'routePrimary': configuration.routePlan.primaryProvider.name,
    'routePrimaryAvailable': configuration.routePlan.primaryAvailable,
    'routePreflight': configuration.routePlan.preflightProvider.name,
    'routeFallback': configuration.routePlan.fallbackProvider?.name,
    'routeFallbackAvailable': configuration.routePlan.fallbackAvailable,
    'routeFallbackPolicy': configuration.routePlan.fallbackPolicy.name,
    'financialProvider': configuration.financialExplanationProvider.name,
    'financialModel': configuration.financialExplanationModel,
    'receiptProvider': configuration.receiptVisionProvider.name,
    'receiptModel': configuration.receiptVisionModel,
  };
  final fingerprint = AiRuntimeStatusFingerprint(
    sha256.convert(utf8.encode(jsonEncode(canonical))).toString(),
  );
  return AiRuntimeStatusSnapshot(
    fingerprint: fingerprint,
    routePlan: configuration.routePlan,
    appBuild: configuration.appBuild,
    buildMode: configuration.buildMode,
    environment: configuration.environment,
    preference: configuration.preference,
    gatewayConfigured: configuration.gatewayConfigured,
    groqGatewayEnabled: configuration.groqGatewayEnabled,
    groqGeneralChatEnabled: configuration.groqGeneralChatEnabled,
    model: configuration.model,
    firebaseTextFallbackEnabled: configuration.firebaseTextFallbackEnabled,
    authenticated: configuration.authenticated,
    authSessionGeneration: configuration.authSessionGeneration,
    firebasePlatformConfigured: configuration.firebasePlatformConfigured,
    firebaseInitialized: configuration.firebaseInitialized,
    appCheckPhase: configuration.appCheckPhase,
    appCheckUnavailableReason: configuration.appCheckUnavailableReason,
    appCheckProvider: configuration.appCheckProvider,
    financialExplanationProvider: configuration.financialExplanationProvider,
    financialExplanationModel: configuration.financialExplanationModel,
    receiptVisionProvider: configuration.receiptVisionProvider,
    receiptVisionModel: configuration.receiptVisionModel,
    gatewayAvailability: configuration.gatewayConfigured
        ? AiRuntimeGatewayAvailability.notChecked
        : AiRuntimeGatewayAvailability.notConfigured,
    liveStatus: AiRuntimeLiveStatus.notChecked,
    probedProvider: null,
    respondingProvider: null,
    receivedNonEmptyContent: false,
    gatewayFailureCode: null,
    checkedAt: null,
    lastLiveTestLatency: null,
  );
}

String normalizeAiRuntimeEnvironmentName(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return 'unspecified';
  return RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(normalized)
      ? normalized
      : 'other';
}

AiRuntimeEnvironment aiRuntimeEnvironmentForName(String normalized) {
  return switch (normalized) {
    'unspecified' => AiRuntimeEnvironment.unspecified,
    'dev' || 'development' || 'local' => AiRuntimeEnvironment.development,
    'stage' || 'staging' => AiRuntimeEnvironment.staging,
    'prod' || 'production' => AiRuntimeEnvironment.production,
    _ => AiRuntimeEnvironment.other,
  };
}

String normalizeAiRuntimeGatewayOrigin(Uri? uri) {
  if (uri == null || !uri.hasAuthority) return 'unconfigured';
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  final defaultPort =
      (scheme == 'https' && uri.port == 443) ||
      (scheme == 'http' && uri.port == 80);
  final port = uri.hasPort && !defaultPort ? ':${uri.port}' : '';
  return '$scheme://$host$port';
}
