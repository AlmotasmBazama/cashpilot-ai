import '../../domain/agent/ai_agent_models.dart';
import 'ai_environment_defaults.dart';

enum AiProviderMode { mock, localParserOnly, firebaseGemini }

enum AiConversationProviderPreference { legacy, auto, groq, firebase, disabled }

class AiRuntimeConfig {
  const AiRuntimeConfig({
    required this.providerMode,
    required this.diagnosticsEnabled,
    this.generalConversationAutoRoutingEnabled = false,
    this.conversationProviderPreference =
        AiConversationProviderPreference.legacy,
  });

  static const String providerDefine = AiEnvironmentKeys.provider;
  static const String diagnosticsDefine = AiEnvironmentKeys.diagnostics;

  static final AiRuntimeConfig current =
      AiRuntimeConfig.fromEnvironmentDefaults(AiEnvironmentDefaults.current);

  final AiProviderMode providerMode;
  final bool diagnosticsEnabled;

  /// When no legacy provider override is supplied, conversational routing may
  /// use Groq first and Firebase as its configured fallback. The legacy
  /// [providerMode] remains local-parser-only for deterministic financial
  /// command understanding.
  final bool generalConversationAutoRoutingEnabled;
  final AiConversationProviderPreference conversationProviderPreference;

  factory AiRuntimeConfig.fromEnvironmentDefaults(
    AiEnvironmentDefaults defaults,
  ) => AiRuntimeConfig.resolve(
    providerValue: defaults.providerValue,
    diagnosticsValue: defaults.diagnosticsEnabled.toString(),
    isReleaseMode: defaults.isReleaseMode,
    isProfileMode: defaults.isProfileMode,
  );

  AiConversationProviderPreference get resolvedConversationProviderPreference {
    final configured = conversationProviderPreference;
    if (configured != AiConversationProviderPreference.legacy) {
      return configured;
    }
    return providerMode == AiProviderMode.firebaseGemini
        ? AiConversationProviderPreference.firebase
        : AiConversationProviderPreference.disabled;
  }

  factory AiRuntimeConfig.resolve({
    String providerValue = '',
    String diagnosticsValue = '',
    bool isReleaseMode = false,
    bool isProfileMode = false,
  }) {
    final normalizedProvider = providerValue.trim().toLowerCase();
    final providerMode = switch (normalizedProvider) {
      'mock' => AiProviderMode.mock,
      'auto' || 'groq' => AiProviderMode.localParserOnly,
      'localparseronly' ||
      'local_parser_only' ||
      'local' => AiProviderMode.localParserOnly,
      'firebase' ||
      'firebasegemini' ||
      'firebase_gemini' ||
      'firebasegeminidebug' => AiProviderMode.firebaseGemini,
      _ when normalizedProvider.isEmpty && (isReleaseMode || isProfileMode) =>
        AiProviderMode.firebaseGemini,
      _ => AiProviderMode.localParserOnly,
    };
    final conversationPreference = switch (normalizedProvider) {
      '' || 'auto' => AiConversationProviderPreference.auto,
      'groq' => AiConversationProviderPreference.groq,
      'firebase' ||
      'firebasegemini' ||
      'firebase_gemini' ||
      'firebasegeminidebug' => AiConversationProviderPreference.firebase,
      _ => AiConversationProviderPreference.disabled,
    };
    final diagnosticsEnabled = switch (diagnosticsValue.trim().toLowerCase()) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => !isReleaseMode,
    };

    return AiRuntimeConfig(
      providerMode: providerMode,
      diagnosticsEnabled: diagnosticsEnabled,
      generalConversationAutoRoutingEnabled:
          conversationPreference == AiConversationProviderPreference.auto,
      conversationProviderPreference: conversationPreference,
    );
  }
}

class AiModelConfig {
  const AiModelConfig({
    required this.modelName,
    required this.temperature,
    required this.maxOutputTokens,
    required this.structuredOutputEnabled,
    required this.streamingEnabled,
    required this.requestTimeout,
    this.generalConversationModel = defaultGeneralModel,
    this.groundedKnowledgeModel = defaultGeneralModel,
    this.financialAnalysisModel = defaultGeneralModel,
    this.complexPlanningModel = defaultGeneralModel,
  });

  static const String defaultEconomicalModel = 'gemini-3.1-flash-lite';
  static const String defaultGeneralModel = 'gemini-3.6-flash';
  static const String modelDefine = 'CASH_PILOT_AI_MODEL';
  static const String generalModelDefine =
      'CASH_PILOT_AI_GENERAL_CONVERSATION_MODEL';
  static const String groundedModelDefine =
      'CASH_PILOT_AI_GROUNDED_KNOWLEDGE_MODEL';
  static const String financialAnalysisModelDefine =
      'CASH_PILOT_AI_FINANCIAL_ANALYSIS_MODEL';
  static const String complexPlanningModelDefine =
      'CASH_PILOT_AI_COMPLEX_PLANNING_MODEL';
  static const String temperatureDefine = 'CASH_PILOT_AI_TEMPERATURE';
  static const String maxOutputTokensDefine = 'CASH_PILOT_AI_MAX_OUTPUT_TOKENS';
  static const String streamingDefine = 'CASH_PILOT_AI_STREAMING';

  static final AiModelConfig current = AiModelConfig.resolve(
    modelName: const String.fromEnvironment(
      modelDefine,
      defaultValue: defaultEconomicalModel,
    ),
    generalConversationModel: const String.fromEnvironment(
      generalModelDefine,
      defaultValue: defaultGeneralModel,
    ),
    groundedKnowledgeModel: const String.fromEnvironment(
      groundedModelDefine,
      defaultValue: defaultGeneralModel,
    ),
    financialAnalysisModel: const String.fromEnvironment(
      financialAnalysisModelDefine,
      defaultValue: defaultGeneralModel,
    ),
    complexPlanningModel: const String.fromEnvironment(
      complexPlanningModelDefine,
      defaultValue: defaultGeneralModel,
    ),
    temperatureValue: const String.fromEnvironment(
      temperatureDefine,
      defaultValue: '0.1',
    ),
    maxOutputTokensValue: const String.fromEnvironment(
      maxOutputTokensDefine,
      defaultValue: '512',
    ),
    streamingValue: const String.fromEnvironment(
      streamingDefine,
      defaultValue: 'false',
    ),
  );

  final String modelName;
  final double temperature;
  final int maxOutputTokens;
  final bool structuredOutputEnabled;
  final bool streamingEnabled;
  final Duration requestTimeout;
  final String generalConversationModel;
  final String groundedKnowledgeModel;
  final String financialAnalysisModel;
  final String complexPlanningModel;

  factory AiModelConfig.resolve({
    String modelName = defaultEconomicalModel,
    String generalConversationModel = defaultGeneralModel,
    String groundedKnowledgeModel = defaultGeneralModel,
    String financialAnalysisModel = defaultGeneralModel,
    String complexPlanningModel = defaultGeneralModel,
    String temperatureValue = '0.1',
    String maxOutputTokensValue = '512',
    String streamingValue = 'false',
  }) {
    final parsedTemperature = double.tryParse(temperatureValue);
    final parsedMaxOutputTokens = int.tryParse(maxOutputTokensValue);
    final normalizedModelName = modelName.trim();

    return AiModelConfig(
      modelName: normalizedModelName.isEmpty
          ? defaultEconomicalModel
          : normalizedModelName,
      temperature:
          parsedTemperature != null &&
              parsedTemperature > 0 &&
              parsedTemperature <= 2
          ? parsedTemperature
          : 0.1,
      maxOutputTokens:
          parsedMaxOutputTokens != null &&
              parsedMaxOutputTokens >= 64 &&
              parsedMaxOutputTokens <= 4096
          ? parsedMaxOutputTokens
          : 512,
      structuredOutputEnabled: true,
      streamingEnabled: streamingValue.trim().toLowerCase() == 'true',
      requestTimeout: const Duration(seconds: 20),
      generalConversationModel: _modelOrFallback(
        generalConversationModel,
        defaultGeneralModel,
      ),
      groundedKnowledgeModel: _modelOrFallback(
        groundedKnowledgeModel,
        defaultGeneralModel,
      ),
      financialAnalysisModel: _modelOrFallback(
        financialAnalysisModel,
        defaultGeneralModel,
      ),
      complexPlanningModel: _modelOrFallback(
        complexPlanningModel,
        defaultGeneralModel,
      ),
    );
  }

  String modelFor(ModelTask task) => switch (task) {
    ModelTask.generalConversation => generalConversationModel,
    ModelTask.groundedCurrentKnowledge => groundedKnowledgeModel,
    ModelTask.personalFinancialAnalysis => financialAnalysisModel,
    ModelTask.complexFinancialPlanning => complexPlanningModel,
    ModelTask.localConversation ||
    ModelTask.financialCommandExtraction ||
    ModelTask.receiptAnalysis ||
    ModelTask.conversation ||
    ModelTask.commandUnderstanding ||
    ModelTask.financialAnalysis ||
    ModelTask.complexPlanning => modelName,
  };

  Set<String> get availableModelNames => <String>{
    modelName,
    generalConversationModel,
    groundedKnowledgeModel,
    financialAnalysisModel,
    complexPlanningModel,
  };

  static String _modelOrFallback(String value, String fallback) {
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}
