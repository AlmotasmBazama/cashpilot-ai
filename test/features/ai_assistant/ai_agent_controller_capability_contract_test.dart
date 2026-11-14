import 'dart:convert';

import 'package:cashpilot_ai/features/ai_assistant/application/controllers/ai_agent_conversation_controller.dart'
    as capability;
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy controller facade preserves provider and state contracts', () {
    const response = AiAgentResponse(
      kind: AiAgentResponseKind.failure,
      message: 'Safe failure',
    );
    const request = AiAgentRequest(
      message: 'How much did I spend?',
      locale: 'en',
      baseCurrencyCode: 'LYD',
    );
    const populated = AiAgentConversationState(
      isSending: true,
      lastResponse: response,
      errorMessage: 'Safe error',
      retryRequest: request,
      unavailableReason: AiUnavailableReason.unknownTemporaryFailure,
      retryable: true,
    );

    final unchanged = populated.copyWith();
    expect(unchanged.isSending, isTrue);
    expect(identical(unchanged.lastResponse, response), isTrue);
    expect(unchanged.errorMessage, 'Safe error');
    expect(identical(unchanged.retryRequest, request), isTrue);
    expect(
      unchanged.unavailableReason,
      AiUnavailableReason.unknownTemporaryFailure,
    );
    expect(unchanged.retryable, isTrue);

    final cleared = populated.copyWith(
      clearResponse: true,
      clearError: true,
      clearRetry: true,
    );
    expect(cleared.lastResponse, isNull);
    expect(cleared.errorMessage, isNull);
    expect(cleared.retryRequest, isNull);
    expect(cleared.unavailableReason, isNull);
    expect(cleared.retryable, isFalse);
    expect(aiAgentControllerProvider.name, 'aiAgentControllerProvider');
    expect(populated, isA<capability.AiAgentConversationState>());

    final container = ProviderContainer(
      overrides: [
        aiAgentAccountScopeProvider.overrideWithValue('test-account'),
        aiAgentOrchestratorProvider.overrideWithValue(
          _ThrowingAgentOrchestrator(),
        ),
        aiAgentFeatureFlagsProvider.overrideWithValue(_agentFlags),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(aiAgentControllerProvider.notifier);
    expect(notifier, isA<AiAgentController>());
    expect(notifier, isA<capability.AiAgentConversationControllerCapability>());
  });

  test(
    'controller maps typed failures to the exact safe diagnostic contract',
    () async {
      final logs = <String>[];
      final orchestrator = _ThrowingAgentOrchestrator();
      final container = ProviderContainer(
        overrides: [
          aiAgentAccountScopeProvider.overrideWithValue('test-account'),
          aiAgentOrchestratorProvider.overrideWithValue(orchestrator),
          aiAgentFeatureFlagsProvider.overrideWithValue(_agentFlags),
          aiGatewaySafeDiagnosticLogProvider.overrideWithValue(logs.add),
        ],
      );
      addTearDown(container.dispose);

      final response = await container
          .read(aiAgentControllerProvider.notifier)
          .send(
            content: 'How much did I spend this month?',
            locale: 'en',
            baseCurrencyCode: 'LYD',
          );

      expect(response, isNull);
      expect(orchestrator.respondCount, 1);
      final state = container.read(aiAgentControllerProvider);
      expect(state.isSending, isFalse);
      expect(state.lastResponse, isNull);
      expect(state.retryRequest?.message, 'How much did I spend this month?');
      expect(
        state.unavailableReason,
        AiUnavailableReason.unknownTemporaryFailure,
      );
      expect(state.retryable, isTrue);

      expect(logs, hasLength(1));
      final diagnostic = jsonDecode(logs.single) as Map<String, dynamic>;
      expect(diagnostic.keys, <String>[
        'kind',
        'code',
        'source',
        'typedUnavailableReason',
        'retryable',
      ]);
      expect(diagnostic['kind'], 'cashpilot_ai_controller_failure');
      expect(diagnostic['code'], 'gateway_timeout');
      expect(diagnostic['source'], isA<String>());
      expect(diagnostic['typedUnavailableReason'], 'unknownTemporaryFailure');
      expect(diagnostic['retryable'], isTrue);
      expect(logs.single, isNot(contains(_sensitiveFailureText)));
    },
  );
}

const _agentFlags = AiAgentFeatureFlags(
  agentEnabled: true,
  readOnlyToolsEnabled: true,
  draftToolsEnabled: true,
  conversationMemoryEnabled: true,
  complexPlanningEnabled: false,
);

const _sensitiveFailureText = 'sensitive provider detail';

class _ThrowingAgentOrchestrator implements AiAgentOrchestrator {
  int respondCount = 0;

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) {
    respondCount += 1;
    throw const AiGatewayException(
      code: AiGatewayFailureCode.timeout,
      safeMessage: _sensitiveFailureText,
    );
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}
