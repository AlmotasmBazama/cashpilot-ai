import '../../../auth/domain/entities/auth_user.dart';
import 'ai_agent_models.dart';
import 'ai_tool_contracts.dart';
import '../services/ai_intent_router.dart';

abstract interface class AiAgentOrchestrator {
  Future<AiAgentResponse> respond(AiAgentRequest request);

  Future<void> clearConversation();

  Future<void> startNewConversation();
}

abstract interface class StreamingAiAgentOrchestrator
    implements AiAgentOrchestrator {
  Stream<AiAgentResponse> respondStream(AiAgentRequest request);
}

abstract interface class AiAgentMemoryStore {
  Future<AiAgentSessionMemory> read({AiAgentMemoryAccess? access});

  Future<void> save(AiAgentSessionMemory memory, {AiAgentMemoryAccess? access});

  Future<void> clear({AiAgentMemoryAccess? access});
}

/// Captured owner/session authorization that a memory store must check at its
/// actual read or commit boundary, not only before an asynchronous call starts.
final class AiAgentMemoryAccess {
  const AiAgentMemoryAccess({
    required this.ownerScope,
    required void Function() assertActive,
  }) : _assertActive = assertActive;

  final AiToolOwnerScopeBinding? ownerScope;
  final void Function() _assertActive;

  void assertActive() => _assertActive();
}

/// Immutable, request-local authorization for bytes leaving the device.
///
/// Implementations bind a confirmed Firebase Auth session to the same owner
/// lease used for local AI memory. The identity is control metadata only and
/// must never be serialized into a model or gateway payload.
abstract interface class AiProviderEgressGuard {
  AuthSessionIdentity get expectedAuthSession;

  void assertActive();

  Future<T> runSerializedAuthOperation<T>(Future<T> Function() operation);
}

typedef AiProviderEgressGuardFactory =
    AiProviderEgressGuard? Function(AiAgentMemoryAccess memoryAccess);

final class AiProviderEgressRevokedException implements Exception {
  const AiProviderEgressRevokedException();

  @override
  String toString() => 'AI provider egress authorization was revoked.';
}

abstract interface class AiAgentMemoryCompactor {
  AiAgentSessionMemory append(
    AiAgentSessionMemory memory,
    AiAgentMessage message,
  );
}

abstract interface class AiAgentModelRouter {
  ModelTask classify(
    String message, {
    required bool allowComplexPlanning,
    AiIntentRoute? route,
  });
}

abstract interface class AiAgentContextSanitizer {
  String buildMemoryContext(AiAgentSessionMemory memory);
}

abstract interface class AiAgentResponseComposer {
  AiAgentResponse compose({
    required String? modelText,
    required List<AiToolResult> results,
    required String locale,
  });
}

abstract interface class AiAgentModelGateway {
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  });
}

abstract interface class ResettableAiAgentModelGateway
    implements AiAgentModelGateway {
  void clearSessions();
}

abstract interface class AiAgentModelSession {
  Future<AiAgentModelTurn> sendInitial();

  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  );
}

abstract interface class StreamingAiAgentModelSession
    implements AiAgentModelSession {
  Stream<AiAgentModelTurn> sendInitialStream();
}
