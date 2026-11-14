import '../entities/ai_conversation.dart';

class StartAiConversation {
  const StartAiConversation();

  AiConversation call({
    String? title,
    String? modelId,
    DateTime? createdAt,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return AiConversation.create(
      title: title,
      modelId: modelId,
      createdAt: createdAt,
      metadata: metadata,
    );
  }
}
