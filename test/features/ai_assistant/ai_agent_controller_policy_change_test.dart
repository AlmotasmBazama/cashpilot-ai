import 'dart:async';

import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/effective_ai_app_control_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_app_control_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_app_control_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _policyStateProvider = StateProvider<EffectiveAiAppControlPolicy>(
  (_) => _policy(AiAppControlLevel.fullControl, revision: 1),
);

void main() {
  test(
    'policy revision change discards a late Future response and preserves history',
    () async {
      final orchestrator = _ControlledAgentOrchestrator();
      final container = _container(orchestrator);
      addTearDown(container.dispose);
      final subscription = container.listen(
        aiAgentControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final pending = container
          .read(aiAgentControllerProvider.notifier)
          .send(
            content: 'Explain a 7 percent inflation scenario',
            locale: 'en',
            baseCurrencyCode: 'LYD',
          );
      await orchestrator.started.future;
      expect(container.read(aiAgentControllerProvider).isSending, isTrue);
      expect(container.read(aiAgentControllerProvider).messages, hasLength(1));

      container.read(_policyStateProvider.notifier).state = _policy(
        AiAppControlLevel.off,
        revision: 2,
      );
      await pumpEventQueue();

      final cancelled = container.read(aiAgentControllerProvider);
      expect(cancelled.isSending, isFalse);
      expect(cancelled.messages, hasLength(1));
      expect(cancelled.messages.single.role, AiAgentMessageRole.user);

      orchestrator.response.complete(
        const AiAgentResponse(
          kind: AiAgentResponseKind.answer,
          message: 'This response belongs to the stale policy.',
        ),
      );
      expect(await pending, isNull);
      final completed = container.read(aiAgentControllerProvider);
      expect(completed.messages, hasLength(1));
      expect(
        completed.messages.any(
          (message) => message.content.contains('stale policy'),
        ),
        isFalse,
      );
    },
  );

  test(
    'policy capability change detaches an active stream and retains partial text',
    () async {
      final orchestrator = _ControlledStreamingAgentOrchestrator();
      final container = _container(orchestrator);
      addTearDown(() async {
        container.dispose();
        await orchestrator.close();
      });
      final subscription = container.listen(
        aiAgentControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final pending = container
          .read(aiAgentControllerProvider.notifier)
          .send(
            content: 'Explain a changing financial policy',
            locale: 'en',
            baseCurrencyCode: 'LYD',
          );
      await orchestrator.started.future;
      orchestrator.add(
        const AiAgentResponse(
          kind: AiAgentResponseKind.answer,
          message: 'Partial explanation',
          isPartial: true,
        ),
      );
      await pumpEventQueue();
      expect(orchestrator.hasListener, isTrue);
      expect(container.read(aiAgentControllerProvider).messages, hasLength(2));

      container.read(_policyStateProvider.notifier).state = _policy(
        AiAppControlLevel.fullControl,
        revision: 2,
        confirmedExecutionEnabled: false,
      );
      await pumpEventQueue();

      expect(await pending, isNull);
      expect(orchestrator.hasListener, isFalse);
      final cancelled = container.read(aiAgentControllerProvider);
      expect(cancelled.isSending, isFalse);
      expect(cancelled.messages, hasLength(2));
      expect(cancelled.messages.last.content, 'Partial explanation');
    },
  );
}

ProviderContainer _container(AiAgentOrchestrator orchestrator) {
  final container = ProviderContainer(
    overrides: [
      aiAgentAccountScopeProvider.overrideWithValue('policy-test-owner'),
      aiAgentOrchestratorProvider.overrideWith((ref) {
        // Matches the production orchestrator dependency and keeps the weak
        // controller listener from eagerly initializing the policy graph.
        ref.watch(effectiveAiAppControlPolicyProvider);
        return orchestrator;
      }),
      aiAgentFeatureFlagsProvider.overrideWithValue(_agentFlags),
      effectiveAiAppControlPolicyProvider.overrideWith(
        (ref) => ref.watch(_policyStateProvider),
      ),
    ],
  );
  return container;
}

EffectiveAiAppControlPolicy _policy(
  AiAppControlLevel level, {
  required int revision,
  bool confirmedExecutionEnabled = true,
}) {
  final settings = AiAppControlSettings.forLevel(
    level,
    provenance: AiAppControlPolicyProvenance.persistedUserSelection,
  );
  return EffectiveAiAppControlPolicy(
    flags: AiAppControlFeatureFlags(
      appControlEnabled: true,
      readToolsEnabled: true,
      navigationToolsEnabled: true,
      createDraftsEnabled: true,
      confirmedExecutionEnabled: confirmedExecutionEnabled,
      transferExecutionEnabled: false,
      updateDraftsEnabled: false,
      archiveDraftsEnabled: false,
      multiStepPlansEnabled: false,
      agentAuditEnabled: true,
      localDatasetScopeVerified: true,
    ),
    settings: settings,
    hasAuthenticatedScope: true,
    runtimeOwnerScopeSafe: true,
    provenance: settings.provenance,
    configurationRevision: revision,
  );
}

final class _ControlledAgentOrchestrator implements AiAgentOrchestrator {
  final Completer<void> started = Completer<void>();
  final Completer<AiAgentResponse> response = Completer<AiAgentResponse>();

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) {
    started.complete();
    return response.future;
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

final class _ControlledStreamingAgentOrchestrator
    implements StreamingAiAgentOrchestrator {
  final Completer<void> started = Completer<void>();
  final StreamController<AiAgentResponse> _controller =
      StreamController<AiAgentResponse>();

  bool get hasListener => _controller.hasListener;

  void add(AiAgentResponse response) => _controller.add(response);

  Future<void> close() => _controller.close();

  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) {
    started.complete();
    return _controller.stream;
  }

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async =>
      const AiAgentResponse(
        kind: AiAgentResponseKind.answer,
        message: 'Unused non-streaming response',
      );

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
