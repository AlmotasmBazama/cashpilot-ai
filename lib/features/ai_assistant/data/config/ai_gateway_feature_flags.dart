import '../../../../core/config/cash_pilot_app_version.dart';
import 'ai_environment_defaults.dart';

class AiGatewayFeatureFlags {
  const AiGatewayFeatureFlags({
    required this.aiGroqGatewayEnabled,
    required this.aiGroqGeneralChatEnabled,
    required this.aiGroqFinancialExplanationEnabled,
    required this.aiGroqToolSelectionEnabled,
    required this.aiGroqArabicSpecialistEnabled,
    required this.aiCurrentWebEnabled,
    required this.aiFirebaseReceiptVisionEnabled,
    this.aiFirebaseTextFallbackEnabled = false,
  });

  static final AiGatewayFeatureFlags current =
      AiGatewayFeatureFlags.fromEnvironmentDefaults(
        AiEnvironmentDefaults.current,
      );

  final bool aiGroqGatewayEnabled;
  final bool aiGroqGeneralChatEnabled;
  final bool aiGroqFinancialExplanationEnabled;
  final bool aiGroqToolSelectionEnabled;
  final bool aiGroqArabicSpecialistEnabled;
  final bool aiCurrentWebEnabled;
  final bool aiFirebaseReceiptVisionEnabled;
  final bool aiFirebaseTextFallbackEnabled;

  factory AiGatewayFeatureFlags.fromEnvironmentDefaults(
    AiEnvironmentDefaults defaults,
  ) => AiGatewayFeatureFlags(
    aiGroqGatewayEnabled: defaults.groqGatewayEnabled,
    aiGroqGeneralChatEnabled: defaults.groqGeneralChatEnabled,
    aiGroqFinancialExplanationEnabled: defaults.groqFinancialExplanationEnabled,
    aiGroqToolSelectionEnabled: defaults.groqToolSelectionEnabled,
    aiGroqArabicSpecialistEnabled: defaults.groqArabicSpecialistEnabled,
    aiCurrentWebEnabled: defaults.currentWebEnabled,
    aiFirebaseReceiptVisionEnabled: defaults.firebaseReceiptVisionEnabled,
    aiFirebaseTextFallbackEnabled: defaults.firebaseTextFallbackEnabled,
  );

  factory AiGatewayFeatureFlags.resolve({
    String groqGatewayValue = '',
    String generalChatValue = '',
    String financialExplanationValue = '',
    String toolSelectionValue = '',
    String arabicSpecialistValue = '',
    String currentWebValue = '',
    String firebaseReceiptVisionValue = '',
    String firebaseTextFallbackValue = '',
  }) {
    return AiGatewayFeatureFlags(
      aiGroqGatewayEnabled: _flag(groqGatewayValue, fallback: false),
      aiGroqGeneralChatEnabled: _flag(generalChatValue, fallback: false),
      aiGroqFinancialExplanationEnabled: _flag(
        financialExplanationValue,
        fallback: false,
      ),
      aiGroqToolSelectionEnabled: _flag(toolSelectionValue, fallback: false),
      aiGroqArabicSpecialistEnabled: _flag(
        arabicSpecialistValue,
        fallback: false,
      ),
      aiCurrentWebEnabled: _flag(currentWebValue, fallback: false),
      aiFirebaseReceiptVisionEnabled: _flag(
        firebaseReceiptVisionValue,
        fallback: true,
      ),
      aiFirebaseTextFallbackEnabled: _flag(
        firebaseTextFallbackValue,
        fallback: false,
      ),
    );
  }

  bool financialGatewayEnabledFor(String locale) {
    if (!aiGroqGatewayEnabled) {
      return false;
    }
    final isArabic = locale.toLowerCase().startsWith('ar');
    return aiGroqFinancialExplanationEnabled &&
        (!isArabic || aiGroqArabicSpecialistEnabled);
  }

  static bool _flag(String value, {required bool fallback}) {
    return switch (value.trim().toLowerCase()) {
      '1' || 'true' || 'yes' || 'on' => true,
      '0' || 'false' || 'no' || 'off' => false,
      _ => fallback,
    };
  }
}

class AiGatewayRuntimeConfig {
  const AiGatewayRuntimeConfig({
    required this.baseUri,
    required this.clientVersion,
    required this.requestTimeout,
  });

  static final AiGatewayRuntimeConfig current =
      AiGatewayRuntimeConfig.fromEnvironmentDefaults(
        AiEnvironmentDefaults.current,
      );

  final Uri? baseUri;
  final String clientVersion;
  final Duration requestTimeout;

  bool get isConfigured => baseUri != null;

  factory AiGatewayRuntimeConfig.fromEnvironmentDefaults(
    AiEnvironmentDefaults defaults,
  ) => AiGatewayRuntimeConfig.resolve(
    baseUrl: defaults.gatewayBaseUrl,
    clientVersion: defaults.clientVersion,
    isReleaseMode: defaults.isReleaseMode,
    isProfileMode: defaults.isProfileMode,
  );

  factory AiGatewayRuntimeConfig.resolve({
    String baseUrl = '',
    String clientVersion = CashPilotAppVersion.version,
    bool isReleaseMode = false,
    bool isProfileMode = false,
  }) {
    final parsed = Uri.tryParse(baseUrl.trim());
    final valid =
        parsed != null &&
        parsed.hasAuthority &&
        (parsed.scheme == 'https' ||
            (!isReleaseMode &&
                !isProfileMode &&
                parsed.scheme == 'http' &&
                <String>{'localhost', '127.0.0.1'}.contains(parsed.host)));
    return AiGatewayRuntimeConfig(
      baseUri: valid ? parsed : null,
      clientVersion: clientVersion.trim().isEmpty
          ? 'unknown'
          : clientVersion.trim(),
      requestTimeout: const Duration(seconds: 40),
    );
  }
}
