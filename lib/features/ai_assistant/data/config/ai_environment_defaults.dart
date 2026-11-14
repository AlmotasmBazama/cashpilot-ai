import 'package:flutter/foundation.dart';

import '../../../../core/config/cash_pilot_app_version.dart';

abstract final class AiEnvironmentKeys {
  static const String environment = 'CASH_PILOT_ENVIRONMENT';
  static const String provider = 'CASH_PILOT_AI_PROVIDER';
  static const String diagnostics = 'CASH_PILOT_AI_DIAGNOSTICS';
  static const String groqGatewayEnabled = 'CASH_PILOT_AI_GROQ_GATEWAY_ENABLED';
  static const String groqGeneralChatEnabled =
      'CASH_PILOT_AI_GROQ_GENERAL_CHAT_ENABLED';
  static const String groqFinancialExplanationEnabled =
      'CASH_PILOT_AI_GROQ_FINANCIAL_EXPLANATION_ENABLED';
  static const String groqToolSelectionEnabled =
      'CASH_PILOT_AI_GROQ_TOOL_SELECTION_ENABLED';
  static const String groqArabicSpecialistEnabled =
      'CASH_PILOT_AI_GROQ_ARABIC_SPECIALIST_ENABLED';
  static const String currentWebEnabled = 'CASH_PILOT_AI_CURRENT_WEB_ENABLED';
  static const String firebaseReceiptVisionEnabled =
      'CASH_PILOT_AI_FIREBASE_RECEIPT_VISION_ENABLED';
  static const String firebaseTextFallbackEnabled =
      'CASH_PILOT_AI_FIREBASE_TEXT_FALLBACK_ENABLED';
  static const String gatewayBaseUrl = 'CASH_PILOT_AI_GATEWAY_BASE_URL';
  static const String clientVersion = 'CASH_PILOT_CLIENT_VERSION';
}

/// A compile-time value that preserves the difference between an absent
/// `--dart-define` and a present value such as `false` or an empty string.
@immutable
final class AiEnvironmentValue<T> {
  const AiEnvironmentValue.absent() : isPresent = false, _value = null;

  const AiEnvironmentValue.present(T value) : isPresent = true, _value = value;

  final bool isPresent;
  final T? _value;

  T orElse(T fallback) => isPresent ? _value as T : fallback;
}

@immutable
final class AiEnvironmentInputs {
  const AiEnvironmentInputs({
    this.environment = const AiEnvironmentValue<String>.absent(),
    this.provider = const AiEnvironmentValue<String>.absent(),
    this.diagnostics = const AiEnvironmentValue<bool>.absent(),
    this.groqGatewayEnabled = const AiEnvironmentValue<bool>.absent(),
    this.groqGeneralChatEnabled = const AiEnvironmentValue<bool>.absent(),
    this.groqFinancialExplanationEnabled =
        const AiEnvironmentValue<bool>.absent(),
    this.groqToolSelectionEnabled = const AiEnvironmentValue<bool>.absent(),
    this.groqArabicSpecialistEnabled = const AiEnvironmentValue<bool>.absent(),
    this.currentWebEnabled = const AiEnvironmentValue<bool>.absent(),
    this.firebaseReceiptVisionEnabled = const AiEnvironmentValue<bool>.absent(),
    this.firebaseTextFallbackEnabled = const AiEnvironmentValue<bool>.absent(),
    this.gatewayBaseUrl = const AiEnvironmentValue<String>.absent(),
    this.clientVersion = const AiEnvironmentValue<String>.absent(),
  });

  static final AiEnvironmentInputs current = AiEnvironmentInputs(
    environment: _stringEnvironmentValue(
      isPresent: const bool.hasEnvironment(AiEnvironmentKeys.environment),
      value: const String.fromEnvironment(AiEnvironmentKeys.environment),
    ),
    provider: _stringEnvironmentValue(
      isPresent: const bool.hasEnvironment(AiEnvironmentKeys.provider),
      value: const String.fromEnvironment(AiEnvironmentKeys.provider),
    ),
    diagnostics: _boolEnvironmentValue(
      isPresent: const bool.hasEnvironment(AiEnvironmentKeys.diagnostics),
      value: const String.fromEnvironment(AiEnvironmentKeys.diagnostics),
    ),
    groqGatewayEnabled: _boolEnvironmentValue(
      isPresent: const bool.hasEnvironment(
        AiEnvironmentKeys.groqGatewayEnabled,
      ),
      value: const String.fromEnvironment(AiEnvironmentKeys.groqGatewayEnabled),
    ),
    groqGeneralChatEnabled: _boolEnvironmentValue(
      isPresent: const bool.hasEnvironment(
        AiEnvironmentKeys.groqGeneralChatEnabled,
      ),
      value: const String.fromEnvironment(
        AiEnvironmentKeys.groqGeneralChatEnabled,
      ),
    ),
    groqFinancialExplanationEnabled: _boolEnvironmentValue(
      isPresent: const bool.hasEnvironment(
        AiEnvironmentKeys.groqFinancialExplanationEnabled,
      ),
      value: const String.fromEnvironment(
        AiEnvironmentKeys.groqFinancialExplanationEnabled,
      ),
    ),
    groqToolSelectionEnabled: _boolEnvironmentValue(
      isPresent: const bool.hasEnvironment(
        AiEnvironmentKeys.groqToolSelectionEnabled,
      ),
      value: const String.fromEnvironment(
        AiEnvironmentKeys.groqToolSelectionEnabled,
      ),
    ),
    groqArabicSpecialistEnabled: _boolEnvironmentValue(
      isPresent: const bool.hasEnvironment(
        AiEnvironmentKeys.groqArabicSpecialistEnabled,
      ),
      value: const String.fromEnvironment(
        AiEnvironmentKeys.groqArabicSpecialistEnabled,
      ),
    ),
    currentWebEnabled: _boolEnvironmentValue(
      isPresent: const bool.hasEnvironment(AiEnvironmentKeys.currentWebEnabled),
      value: const String.fromEnvironment(AiEnvironmentKeys.currentWebEnabled),
    ),
    firebaseReceiptVisionEnabled: _boolEnvironmentValue(
      isPresent: const bool.hasEnvironment(
        AiEnvironmentKeys.firebaseReceiptVisionEnabled,
      ),
      value: const String.fromEnvironment(
        AiEnvironmentKeys.firebaseReceiptVisionEnabled,
      ),
    ),
    firebaseTextFallbackEnabled: _boolEnvironmentValue(
      isPresent: const bool.hasEnvironment(
        AiEnvironmentKeys.firebaseTextFallbackEnabled,
      ),
      value: const String.fromEnvironment(
        AiEnvironmentKeys.firebaseTextFallbackEnabled,
      ),
    ),
    gatewayBaseUrl: _stringEnvironmentValue(
      isPresent: const bool.hasEnvironment(AiEnvironmentKeys.gatewayBaseUrl),
      value: const String.fromEnvironment(AiEnvironmentKeys.gatewayBaseUrl),
    ),
    clientVersion: _stringEnvironmentValue(
      isPresent: const bool.hasEnvironment(AiEnvironmentKeys.clientVersion),
      value: const String.fromEnvironment(AiEnvironmentKeys.clientVersion),
    ),
  );

  final AiEnvironmentValue<String> environment;
  final AiEnvironmentValue<String> provider;
  final AiEnvironmentValue<bool> diagnostics;
  final AiEnvironmentValue<bool> groqGatewayEnabled;
  final AiEnvironmentValue<bool> groqGeneralChatEnabled;
  final AiEnvironmentValue<bool> groqFinancialExplanationEnabled;
  final AiEnvironmentValue<bool> groqToolSelectionEnabled;
  final AiEnvironmentValue<bool> groqArabicSpecialistEnabled;
  final AiEnvironmentValue<bool> currentWebEnabled;
  final AiEnvironmentValue<bool> firebaseReceiptVisionEnabled;
  final AiEnvironmentValue<bool> firebaseTextFallbackEnabled;
  final AiEnvironmentValue<String> gatewayBaseUrl;
  final AiEnvironmentValue<String> clientVersion;
}

/// Canonical non-secret AI configuration defaults for every runtime consumer.
///
/// Debug and profile builds without defines use the checked staging contract.
/// Release builds retain Groq selection intent so diagnostics report a typed
/// missing-configuration result, but no URL is admitted until both the
/// environment and URL are explicitly provided for production.
@immutable
final class AiEnvironmentDefaults {
  const AiEnvironmentDefaults({
    required this.environmentName,
    required this.providerValue,
    required this.diagnosticsEnabled,
    required this.groqGatewayEnabled,
    required this.groqGeneralChatEnabled,
    required this.groqFinancialExplanationEnabled,
    required this.groqToolSelectionEnabled,
    required this.groqArabicSpecialistEnabled,
    required this.currentWebEnabled,
    required this.firebaseReceiptVisionEnabled,
    required this.firebaseTextFallbackEnabled,
    required this.gatewayBaseUrl,
    required this.clientVersion,
    required this.isReleaseMode,
    required this.isProfileMode,
    required this.hasExplicitProductionEnvironment,
    required this.hasValidExplicitProductionGateway,
  });

  static const String stagingGatewayBaseUrl =
      'https://cashpilot-ai-gateway-staging-yfgt2ypuvq-ew.a.run.app';

  static final AiEnvironmentDefaults current = AiEnvironmentDefaults.resolve(
    inputs: AiEnvironmentInputs.current,
    isReleaseMode: kReleaseMode,
    isProfileMode: kProfileMode,
  );

  final String environmentName;
  final String providerValue;
  final bool diagnosticsEnabled;
  final bool groqGatewayEnabled;
  final bool groqGeneralChatEnabled;
  final bool groqFinancialExplanationEnabled;
  final bool groqToolSelectionEnabled;
  final bool groqArabicSpecialistEnabled;
  final bool currentWebEnabled;
  final bool firebaseReceiptVisionEnabled;
  final bool firebaseTextFallbackEnabled;
  final String gatewayBaseUrl;
  final String clientVersion;
  final bool isReleaseMode;
  final bool isProfileMode;
  final bool hasExplicitProductionEnvironment;
  final bool hasValidExplicitProductionGateway;

  factory AiEnvironmentDefaults.resolve({
    AiEnvironmentInputs inputs = const AiEnvironmentInputs(),
    bool isReleaseMode = false,
    bool isProfileMode = false,
  }) {
    final nonRelease = !isReleaseMode;
    final environmentName = _normalizeEnvironmentName(
      inputs.environment.orElse(nonRelease ? 'staging' : ''),
    );
    final hasExplicitProductionEnvironment =
        inputs.environment.isPresent && environmentName == 'production';
    final requestedProviderValue = inputs.provider.orElse('groq').trim();
    final requestedGatewayBaseUrl = inputs.gatewayBaseUrl.orElse(
      nonRelease && environmentName == 'staging' ? stagingGatewayBaseUrl : '',
    );
    final hasValidExplicitProductionGateway =
        isReleaseMode &&
        hasExplicitProductionEnvironment &&
        inputs.gatewayBaseUrl.isPresent &&
        _isValidProductionGatewayUrl(requestedGatewayBaseUrl);
    final admittedGatewayBaseUrl = isReleaseMode
        ? hasValidExplicitProductionGateway
              ? requestedGatewayBaseUrl
              : ''
        : requestedGatewayBaseUrl;
    final releaseRemoteTextApproved =
        !isReleaseMode || hasValidExplicitProductionGateway;
    final providerValue =
        isReleaseMode &&
            !releaseRemoteTextApproved &&
            _isFirebaseRemoteProvider(requestedProviderValue)
        ? 'groq'
        : requestedProviderValue;

    return AiEnvironmentDefaults(
      environmentName: environmentName,
      providerValue: providerValue.isEmpty ? 'disabled' : providerValue,
      diagnosticsEnabled: inputs.diagnostics.orElse(false),
      groqGatewayEnabled: inputs.groqGatewayEnabled.orElse(true),
      groqGeneralChatEnabled: inputs.groqGeneralChatEnabled.orElse(true),
      groqFinancialExplanationEnabled: inputs.groqFinancialExplanationEnabled
          .orElse(true),
      groqToolSelectionEnabled: inputs.groqToolSelectionEnabled.orElse(false),
      groqArabicSpecialistEnabled: inputs.groqArabicSpecialistEnabled.orElse(
        true,
      ),
      currentWebEnabled:
          releaseRemoteTextApproved && inputs.currentWebEnabled.orElse(false),
      firebaseReceiptVisionEnabled: inputs.firebaseReceiptVisionEnabled.orElse(
        true,
      ),
      firebaseTextFallbackEnabled:
          releaseRemoteTextApproved &&
          inputs.firebaseTextFallbackEnabled.orElse(false),
      gatewayBaseUrl: admittedGatewayBaseUrl.trim(),
      clientVersion: inputs.clientVersion.orElse(CashPilotAppVersion.version),
      isReleaseMode: isReleaseMode,
      isProfileMode: isProfileMode,
      hasExplicitProductionEnvironment: hasExplicitProductionEnvironment,
      hasValidExplicitProductionGateway: hasValidExplicitProductionGateway,
    );
  }
}

AiEnvironmentValue<String> _stringEnvironmentValue({
  required bool isPresent,
  required String value,
}) => isPresent
    ? AiEnvironmentValue<String>.present(value)
    : const AiEnvironmentValue<String>.absent();

AiEnvironmentValue<bool> _boolEnvironmentValue({
  required bool isPresent,
  required String value,
}) => isPresent
    ? AiEnvironmentValue<bool>.present(_parseExplicitBool(value))
    : const AiEnvironmentValue<bool>.absent();

bool _parseExplicitBool(String value) => switch (value.trim().toLowerCase()) {
  '1' || 'true' || 'yes' || 'on' => true,
  _ => false,
};

String _normalizeEnvironmentName(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return 'unspecified';
  return RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(normalized)
      ? normalized
      : 'other';
}

bool _isStagingGatewayUrl(String value) {
  final candidate = Uri.tryParse(value.trim());
  final staging = Uri.parse(AiEnvironmentDefaults.stagingGatewayBaseUrl);
  return candidate != null &&
      candidate.scheme.toLowerCase() == staging.scheme &&
      candidate.host.toLowerCase() == staging.host &&
      candidate.port == staging.port;
}

bool _isValidProductionGatewayUrl(String value) {
  final candidate = Uri.tryParse(value.trim());
  return candidate != null &&
      candidate.hasAuthority &&
      candidate.scheme.toLowerCase() == 'https' &&
      !_isStagingGatewayUrl(value);
}

bool _isFirebaseRemoteProvider(String value) {
  return switch (value.trim().toLowerCase()) {
    'auto' ||
    'firebase' ||
    'firebasegemini' ||
    'firebase_gemini' ||
    'firebasegeminidebug' => true,
    _ => false,
  };
}
