import 'package:uuid/uuid.dart';

import 'ai_message.dart';

class AiConversation {
  AiConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required List<AiMessage> messages,
    this.modelId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : messages = List.unmodifiable(messages),
       metadata = Map.unmodifiable(metadata);

  factory AiConversation.create({
    String? id,
    String? title,
    String? modelId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AiMessage> messages = const <AiMessage>[],
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    final now = DateTime.now().toUtc();
    final resolvedCreatedAt = createdAt ?? now;

    return AiConversation(
      id: id ?? const Uuid().v7(),
      title: title ?? 'CashPilot AI',
      modelId: modelId,
      messages: messages,
      createdAt: resolvedCreatedAt,
      updatedAt: updatedAt ?? resolvedCreatedAt,
      metadata: metadata,
    );
  }

  final String id;
  final String title;
  final String? modelId;
  final List<AiMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, Object?> metadata;

  AiConversation addMessage(AiMessage message) {
    return copyWith(
      messages: [...messages, message],
      updatedAt: message.createdAt,
    );
  }

  AiConversation copyWith({
    String? id,
    String? title,
    String? modelId,
    List<AiMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, Object?>? metadata,
  }) {
    return AiConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      modelId: modelId ?? this.modelId,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
