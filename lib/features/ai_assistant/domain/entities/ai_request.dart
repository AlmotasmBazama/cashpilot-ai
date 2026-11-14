import 'ai_message.dart';

class AiRequest {
  AiRequest({
    required this.conversationId,
    required List<AiMessage> messages,
    this.modelId,
    this.systemPrompt,
    Map<String, Object?> context = const <String, Object?>{},
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : messages = List.unmodifiable(messages),
       context = Map.unmodifiable(context),
       metadata = Map.unmodifiable(metadata);

  final String conversationId;
  final String? modelId;
  final String? systemPrompt;
  final List<AiMessage> messages;
  final Map<String, Object?> context;
  final Map<String, Object?> metadata;
}
