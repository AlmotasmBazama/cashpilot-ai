import 'package:uuid/uuid.dart';

import 'ai_action.dart';

enum AiActionExecutionStatus {
  draft,
  awaitingConfirmation,
  executing,
  executed,
  cancelled,
  failed,
}

class AiActionDraft {
  const AiActionDraft({
    required this.id,
    required this.action,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiActionDraft.create({
    required AiAction action,
    String? id,
    DateTime? createdAt,
  }) {
    final timestamp = (createdAt ?? DateTime.now()).toUtc();
    return AiActionDraft(
      id: id ?? const Uuid().v7(),
      action: action,
      status: action.requiresConfirmation
          ? AiActionExecutionStatus.awaitingConfirmation
          : AiActionExecutionStatus.draft,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  final String id;
  final AiAction action;
  final AiActionExecutionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiActionDraft copyWith({
    AiAction? action,
    AiActionExecutionStatus? status,
    DateTime? updatedAt,
  }) {
    return AiActionDraft(
      id: id,
      action: action ?? this.action,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: (updatedAt ?? this.updatedAt).toUtc(),
    );
  }

  AiActionDraft withStatus(AiActionExecutionStatus status, {DateTime? at}) {
    return copyWith(status: status, updatedAt: (at ?? DateTime.now()).toUtc());
  }
}
