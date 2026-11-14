import 'dart:async';

import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_durable_action_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _ownerLeaseProvider = StateProvider<_TestOwnerLease?>(
  (_) => const _TestOwnerLease(scope: _scopeA, epoch: 1),
);

const _scopeA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _scopeB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  test('A to B to A drops every late chunk from the first A stream', () async {
    final agent = _ControlledStreamingOrchestrator();
    final container = _container(agent);
    addTearDown(() async {
      await agent.close();
      container.dispose();
    });
    final subscription = container.listen(
      aiAgentControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final response = container
        .read(aiAgentControllerProvider.notifier)
        .send(
          content: 'Synthetic A request',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        );
    agent.add(
      const AiAgentResponse(
        kind: AiAgentResponseKind.answer,
        message: 'Synthetic partial A',
        isPartial: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(aiAgentControllerProvider).messages, hasLength(2));

    container.read(_ownerLeaseProvider.notifier).state = const _TestOwnerLease(
      scope: _scopeB,
      epoch: 2,
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(aiAgentControllerProvider).messages, isEmpty);

    container.read(_ownerLeaseProvider.notifier).state = const _TestOwnerLease(
      scope: _scopeA,
      epoch: 3,
    );
    await Future<void>.delayed(Duration.zero);
    agent.add(
      const AiAgentResponse(
        kind: AiAgentResponseKind.answer,
        message: 'Synthetic late A final',
      ),
    );
    await agent.close();

    expect(await response, isNull);
    final state = container.read(aiAgentControllerProvider);
    expect(state.messages, isEmpty);
    expect(state.lastResponse, isNull);
    expect(state.isSending, isFalse);
  });

  test('logout and same-owner login reject the pre-logout result', () async {
    final agent = _ControlledRespondingOrchestrator();
    final container = _container(agent);
    addTearDown(container.dispose);
    final subscription = container.listen(
      aiAgentControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final response = container
        .read(aiAgentControllerProvider.notifier)
        .send(
          content: 'Synthetic pre-logout request',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        );
    container.read(_ownerLeaseProvider.notifier).state = null;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(aiAgentControllerProvider).messages, isEmpty);

    container.read(_ownerLeaseProvider.notifier).state = const _TestOwnerLease(
      scope: _scopeA,
      epoch: 2,
    );
    await Future<void>.delayed(Duration.zero);
    agent.complete(
      const AiAgentResponse(
        kind: AiAgentResponseKind.answer,
        message: 'Synthetic late pre-logout result',
      ),
    );

    expect(await response, isNull);
    final state = container.read(aiAgentControllerProvider);
    expect(state.messages, isEmpty);
    expect(state.lastResponse, isNull);
    expect(state.isSending, isFalse);
  });

  test(
    'logout during AI streaming drops late chunks and clears state',
    () async {
      final agent = _ControlledStreamingOrchestrator();
      final container = _container(agent);
      addTearDown(() async {
        await agent.close();
        container.dispose();
      });
      final subscription = container.listen(
        aiAgentControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final response = container
          .read(aiAgentControllerProvider.notifier)
          .send(
            content: 'Synthetic streaming A request',
            locale: 'en',
            baseCurrencyCode: 'LYD',
          );
      agent.add(
        const AiAgentResponse(
          kind: AiAgentResponseKind.answer,
          message: 'Synthetic private A partial',
          isPartial: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(aiAgentControllerProvider).messages, hasLength(2));

      container.read(_ownerLeaseProvider.notifier).state = null;
      await Future<void>.delayed(Duration.zero);
      expect(container.read(aiAgentControllerProvider).messages, isEmpty);

      agent.add(
        const AiAgentResponse(
          kind: AiAgentResponseKind.answer,
          message: 'Synthetic late final after logout',
        ),
      );
      await agent.close();

      expect(await response, isNull);
      final state = container.read(aiAgentControllerProvider);
      expect(state.messages, isEmpty);
      expect(state.lastResponse, isNull);
      expect(state.isSending, isFalse);
    },
  );

  test('recovery UI result consumption resets for B and a new A session', () {
    final container = _container(_ImmediateOrchestrator());
    addTearDown(container.dispose);
    final result = AppAgentExecutionResult(
      commandId: 'synthetic-command-collision',
      status: AppAgentCommandStatus.succeeded,
      verified: true,
      entityType: 'transaction',
      affectedCount: 1,
      completedAt: DateTime.utc(2026, 8, 10),
    );

    final coordinatorA = container.read(appAgentRecoveryUiCoordinatorProvider);
    expect(coordinatorA.tryConsume(result), isTrue);
    expect(coordinatorA.tryConsume(result), isFalse);

    container.read(_ownerLeaseProvider.notifier).state = const _TestOwnerLease(
      scope: _scopeB,
      epoch: 2,
    );
    final coordinatorB = container.read(appAgentRecoveryUiCoordinatorProvider);
    expect(coordinatorB.tryConsume(result), isTrue);

    container.read(_ownerLeaseProvider.notifier).state = const _TestOwnerLease(
      scope: _scopeA,
      epoch: 3,
    );
    final coordinatorANewSession = container.read(
      appAgentRecoveryUiCoordinatorProvider,
    );
    expect(coordinatorANewSession.tryConsume(result), isTrue);
  });
}

ProviderContainer _container(AiAgentOrchestrator orchestrator) {
  return ProviderContainer(
    overrides: [
      aiAgentAccountScopeProvider.overrideWith(
        (ref) => ref.watch(_ownerLeaseProvider)?.scope,
      ),
      aiToolOwnerScopeBindingProvider.overrideWith((ref) {
        final lease = ref.watch(_ownerLeaseProvider);
        return lease == null
            ? null
            : AiToolOwnerScopeBinding(
                accountScope: lease.scope,
                epoch: lease.epoch,
              );
      }),
      aiAgentOrchestratorProvider.overrideWithValue(orchestrator),
      aiAgentFeatureFlagsProvider.overrideWithValue(_agentFlags),
    ],
  );
}

class _TestOwnerLease {
  const _TestOwnerLease({required this.scope, required this.epoch});

  final String scope;
  final int epoch;
}

class _ControlledStreamingOrchestrator implements StreamingAiAgentOrchestrator {
  final StreamController<AiAgentResponse> _controller =
      StreamController<AiAgentResponse>();

  void add(AiAgentResponse response) => _controller.add(response);

  Future<void> close() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) =>
      _controller.stream;

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) =>
      throw UnimplementedError();

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _ControlledRespondingOrchestrator implements AiAgentOrchestrator {
  final Completer<AiAgentResponse> _response = Completer<AiAgentResponse>();

  void complete(AiAgentResponse response) => _response.complete(response);

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) => _response.future;

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _ImmediateOrchestrator implements AiAgentOrchestrator {
  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    return const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Synthetic response',
    );
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

const _agentFlags = AiAgentFeatureFlags(
  agentEnabled: true,
  readOnlyToolsEnabled: true,
  draftToolsEnabled: true,
  conversationMemoryEnabled: true,
  complexPlanningEnabled: false,
);
