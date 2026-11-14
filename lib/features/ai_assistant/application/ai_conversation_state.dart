import '../../../core/error/failure.dart';
import '../domain/entities/ai_conversation.dart';
import '../domain/entities/ai_provider_type.dart';

class AiConversationState {
  const AiConversationState({
    required this.conversation,
    required this.providerType,
    this.isSending = false,
    this.failure,
  });

  final AiConversation conversation;
  final AiProviderType providerType;
  final bool isSending;
  final Failure? failure;

  AiConversationState copyWith({
    AiConversation? conversation,
    AiProviderType? providerType,
    bool? isSending,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AiConversationState(
      conversation: conversation ?? this.conversation,
      providerType: providerType ?? this.providerType,
      isSending: isSending ?? this.isSending,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
