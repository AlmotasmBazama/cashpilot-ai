import 'dart:async';

import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

void main() {
  test(
    'buffers streaming provider prose until false mutation claims are rejected',
    () async {
      final orchestrator = AiAgentOrchestratorImpl(
        toolRegistry: const _EmptyToolRegistry(),
        memoryStore: InMemoryAiAgentMemoryStore(),
        memoryCompactor: const DefaultAiAgentMemoryCompactor(),
        modelRouter: const DefaultAiAgentModelRouter(),
        contextSanitizer: const DefaultAiAgentContextSanitizer(),
        responseComposer: const DefaultAiAgentResponseComposer(),
        modelGateway: const _StreamingGateway(),
        providerEgressGuardFactory: (_) => testAiProviderEgressGuard,
        toolOwnerScope: _ownerScope,
        currentToolOwnerScope: () => _ownerScope,
        operationFence: BackupOperationFence(),
        financialDataScopeVerified: true,
      );

      final responses = await orchestrator
          .respondStream(
            const AiAgentRequest(
              message: 'Explain photosynthesis in simple terms.',
              locale: 'en',
              baseCurrencyCode: 'LYD',
            ),
          )
          .toList();

      expect(responses, hasLength(1));
      expect(responses.single.isPartial, isFalse);
      expect(
        responses.single.warnings,
        contains('unverified_mutation_claim_blocked'),
      );
      expect(
        responses.any(
          (response) => response.message.contains('The expense was'),
        ),
        isFalse,
      );
    },
  );

  test('emits sentence-batched safe progress and one final response', () async {
    final orchestrator = _orchestrator(const _SafeStreamingGateway());

    final responses = await orchestrator
        .respondStream(
          const AiAgentRequest(
            message: 'Explain photosynthesis in simple terms.',
            locale: 'en',
            baseCurrencyCode: 'LYD',
          ),
        )
        .toList();

    expect(responses, hasLength(2));
    expect(responses.first.isPartial, isTrue);
    expect(responses.first.message, endsWith('for plants.'));
    expect(responses.last.isPartial, isFalse);
    expect(responses.last.message, endsWith('releases oxygen.'));
  });

  test('outer streaming timeout is typed and retryable', () async {
    final orchestrator = _orchestrator(
      const _NeverCompletingGateway(),
      limits: const AiAgentLimits(requestTimeout: Duration(milliseconds: 20)),
    );

    final responses = await orchestrator
        .respondStream(
          const AiAgentRequest(
            message: 'Explain photosynthesis in simple terms.',
            locale: 'en',
            baseCurrencyCode: 'LYD',
          ),
        )
        .toList();

    expect(responses, hasLength(1));
    expect(responses.single.kind, AiAgentResponseKind.failure);
    expect(
      responses.single.warnings,
      contains(AiUnavailableReason.providerTimedOut.name),
    );
    expect(
      isAiRequestFailureRetryable(AiUnavailableReason.providerTimedOut),
      isTrue,
    );
  });
}

AiAgentOrchestratorImpl _orchestrator(
  AiAgentModelGateway gateway, {
  AiAgentLimits limits = const AiAgentLimits(),
}) {
  return AiAgentOrchestratorImpl(
    toolRegistry: const _EmptyToolRegistry(),
    memoryStore: InMemoryAiAgentMemoryStore(),
    memoryCompactor: const DefaultAiAgentMemoryCompactor(),
    modelRouter: const DefaultAiAgentModelRouter(),
    contextSanitizer: const DefaultAiAgentContextSanitizer(),
    responseComposer: const DefaultAiAgentResponseComposer(),
    modelGateway: gateway,
    providerEgressGuardFactory: (_) => testAiProviderEgressGuard,
    toolOwnerScope: _ownerScope,
    currentToolOwnerScope: () => _ownerScope,
    operationFence: BackupOperationFence(),
    financialDataScopeVerified: true,
    limits: limits,
  );
}

const _ownerScope = AiToolOwnerScopeBinding(
  accountScope:
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  epoch: 1,
);

final class _EmptyToolRegistry implements AiToolRegistry {
  const _EmptyToolRegistry();

  @override
  List<AiToolDefinition> get definitions => const <AiToolDefinition>[];

  @override
  AiToolDefinition? definitionFor(String name) => null;

  @override
  Future<AiToolResult> execute(
    AiAgentToolCall call,
    AiToolExecutionContext context,
  ) => throw StateError('No tool is available in this test.');
}

final class _StreamingGateway implements AiAgentModelGateway {
  const _StreamingGateway();

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async => const _StreamingSession();
}

final class _SafeStreamingGateway implements AiAgentModelGateway {
  const _SafeStreamingGateway();

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async => const _SafeStreamingSession();
}

final class _NeverCompletingGateway implements AiAgentModelGateway {
  const _NeverCompletingGateway();

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async => const _NeverCompletingSession();
}

final class _StreamingSession implements StreamingAiAgentModelSession {
  const _StreamingSession();

  @override
  Future<AiAgentModelTurn> sendInitial() async =>
      const AiAgentModelTurn(text: 'The expense was saved.');

  @override
  Stream<AiAgentModelTurn> sendInitialStream() async* {
    yield const AiAgentModelTurn(text: 'The expense was');
    yield const AiAgentModelTurn(text: 'The expense was saved.');
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) => throw StateError('No tool results are expected in this test.');
}

final class _SafeStreamingSession implements StreamingAiAgentModelSession {
  const _SafeStreamingSession();

  static const first =
      'Photosynthesis converts sunlight into stored chemical energy for plants.';
  static const complete = '$first It also releases oxygen.';

  @override
  Future<AiAgentModelTurn> sendInitial() async =>
      const AiAgentModelTurn(text: complete);

  @override
  Stream<AiAgentModelTurn> sendInitialStream() async* {
    yield const AiAgentModelTurn(text: first);
    yield const AiAgentModelTurn(text: complete);
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) => throw StateError('No tool results are expected in this test.');
}

final class _NeverCompletingSession implements StreamingAiAgentModelSession {
  const _NeverCompletingSession();

  @override
  Future<AiAgentModelTurn> sendInitial() =>
      Completer<AiAgentModelTurn>().future;

  @override
  Stream<AiAgentModelTurn> sendInitialStream() async* {
    await Completer<void>().future;
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) => Completer<AiAgentModelTurn>().future;
}
