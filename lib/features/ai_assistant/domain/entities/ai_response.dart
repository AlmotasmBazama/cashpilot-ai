import 'ai_message.dart';
import 'ai_provider_type.dart';

enum AiFinishReason { complete, length, contentFiltered, error }

class AiTokenUsage {
  const AiTokenUsage({required this.inputTokens, required this.outputTokens});

  final int inputTokens;
  final int outputTokens;

  int get totalTokens => inputTokens + outputTokens;
}

class AiResponse {
  AiResponse({
    required this.message,
    required this.providerType,
    required this.modelId,
    required this.finishReason,
    required this.tokenUsage,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = Map.unmodifiable(metadata);

  final AiMessage message;
  final AiProviderType providerType;
  final String modelId;
  final AiFinishReason finishReason;
  final AiTokenUsage tokenUsage;
  final Map<String, Object?> metadata;
}
