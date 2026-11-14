import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/entities/ai_provider_type.dart';
import '../../domain/agent/ai_agent_models.dart';
import 'ai_runtime_config.dart';

class FirebaseAiConfig {
  const FirebaseAiConfig({
    required this.modelConfig,
    required this.availableModels,
  });

  static final FirebaseAiConfig current = FirebaseAiConfig.fromModelConfig(
    AiModelConfig.current,
  );

  factory FirebaseAiConfig.fromModelConfig(AiModelConfig modelConfig) {
    return FirebaseAiConfig(
      modelConfig: modelConfig,
      availableModels: modelConfig.availableModelNames
          .map(
            (modelName) => AiModel(
              id: modelName,
              providerType: AiProviderType.gemini,
              displayName: modelName,
              capabilities: const <AiCapability>[
                AiCapability.chat,
                AiCapability.financialInsights,
                AiCapability.transactionParsing,
                AiCapability.spendingAnalysis,
                AiCapability.cashFlowExplanation,
              ],
              isDefault: modelName == modelConfig.modelName,
              maxInputTokens: 1048576,
            ),
          )
          .toList(growable: false),
    );
  }

  final AiModelConfig modelConfig;
  final List<AiModel> availableModels;

  String get defaultModelId => modelConfig.modelName;

  String modelFor(ModelTask task) => modelConfig.modelFor(task);

  String get fallbackModelId => modelConfig.modelName;
}
