import 'package:uuid/uuid.dart';

enum AiMessageRole { system, user, assistant, tool }

class AiMessage {
  AiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = Map.unmodifiable(metadata);

  factory AiMessage.system({
    required String conversationId,
    required String content,
    String? id,
    DateTime? createdAt,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return AiMessage(
      id: id ?? const Uuid().v7(),
      conversationId: conversationId,
      role: AiMessageRole.system,
      content: content,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      metadata: metadata,
    );
  }

  factory AiMessage.user({
    required String conversationId,
    required String content,
    String? id,
    DateTime? createdAt,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return AiMessage(
      id: id ?? const Uuid().v7(),
      conversationId: conversationId,
      role: AiMessageRole.user,
      content: content,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      metadata: metadata,
    );
  }

  factory AiMessage.assistant({
    required String conversationId,
    required String content,
    String? id,
    DateTime? createdAt,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return AiMessage(
      id: id ?? const Uuid().v7(),
      conversationId: conversationId,
      role: AiMessageRole.assistant,
      content: content,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      metadata: metadata,
    );
  }

  final String id;
  final String conversationId;
  final AiMessageRole role;
  final String content;
  final DateTime createdAt;
  final Map<String, Object?> metadata;
}
