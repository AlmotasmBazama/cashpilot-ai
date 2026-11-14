import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_gateway_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/routed_ai_agent_model_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_runtime_status.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

void main() {
  test(
    'shared route plan controls Chat without changing financial routing',
    () async {
      final firebase = _CountingGateway();
      final groq = _CountingGateway();
      final router = RoutedAiAgentModelGateway(
        flags: AiGatewayFeatureFlags.resolve(),
        firebaseGateway: firebase,
        groqGateway: groq,
        generalConversationPlan: const AiProviderRoutePlan(
          task: ModelTask.generalConversation,
          primaryProvider: AiActiveProvider.groq,
          primaryAvailable: true,
          preflightProvider: AiActiveProvider.groq,
          fallbackProvider: null,
          fallbackAvailable: false,
          fallbackPolicy: AiRuntimeFallbackPolicy.none,
          primaryUnavailableReason: null,
          routeUnavailableReason: null,
        ),
      );

      await router.startSession(
        request: _request(ModelTask.generalConversation),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );
      final financial = await router.startSession(
        request: _request(ModelTask.personalFinancialAnalysis),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );

      expect(groq.calls, 1);
      expect(firebase.calls, 0);
      expect((await financial.sendInitial()).warnings, isNotEmpty);
      expect(groq.calls, 1, reason: 'Financial selection remains unchanged.');
    },
  );

  test(
    'auto with flags off disables remote general chat and current web',
    () async {
      final firebase = _CountingGateway();
      final groq = _CountingGateway();
      final router = RoutedAiAgentModelGateway(
        flags: AiGatewayFeatureFlags.resolve(),
        firebaseGateway: firebase,
        groqGateway: groq,
      );

      final general = await router.startSession(
        request: _request(ModelTask.generalConversation),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );
      final current = await router.startSession(
        request: _request(ModelTask.groundedCurrentKnowledge),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );

      expect(
        (await general.sendInitial()).warnings,
        contains('provider_disabled'),
      );
      expect(firebase.calls, 0);
      expect(groq.calls, 0);
      expect(
        (await current.sendInitial()).warnings,
        contains('current_information_disabled'),
      );
    },
  );

  test('Groq general rollout and rollback are independent', () async {
    final firebase = _CountingGateway();
    final groq = _CountingGateway();
    final router = RoutedAiAgentModelGateway(
      flags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
      ),
      firebaseGateway: firebase,
      groqGateway: groq,
    );

    await router.startSession(
      request: _request(ModelTask.generalConversation),
      tools: const <AiToolDefinition>[],
      egressGuard: testAiProviderEgressGuard,
    );

    expect(groq.calls, 1);
    expect(firebase.calls, 0);
  });

  test('missing Groq configuration uses the Firebase fallback', () async {
    final firebase = _CountingGateway();
    final groq = _CountingGateway();
    final router = RoutedAiAgentModelGateway(
      flags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
        firebaseTextFallbackValue: 'true',
      ),
      firebaseGateway: firebase,
      groqGateway: groq,
      groqConfigured: false,
    );

    final session = await router.startSession(
      request: _request(ModelTask.generalConversation),
      tools: const <AiToolDefinition>[],
      egressGuard: testAiProviderEgressGuard,
    );

    expect((await session.sendInitial()).text, 'ok');
    expect(firebase.calls, 1);
    expect(groq.calls, 0);
  });

  test('missing Groq configuration does not silently use Firebase', () async {
    final firebase = _CountingGateway();
    final router = RoutedAiAgentModelGateway(
      flags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
      ),
      firebaseGateway: firebase,
      groqGateway: _CountingGateway(),
      groqConfigured: false,
    );

    final session = await router.startSession(
      request: _request(ModelTask.generalConversation),
      tools: const <AiToolDefinition>[],
      egressGuard: testAiProviderEgressGuard,
    );

    expect(
      (await session.sendInitial()).warnings,
      contains('groqNotConfigured'),
    );
    expect(firebase.calls, 0);
  });

  test(
    'explicit Groq chat uses configured Groq for full financial route',
    () async {
      final firebase = _CountingGateway();
      final groq = _CountingGateway();
      final router = RoutedAiAgentModelGateway(
        flags: AiGatewayFeatureFlags.resolve(
          groqGatewayValue: 'true',
          generalChatValue: 'true',
          toolSelectionValue: 'true',
          financialExplanationValue: 'true',
        ),
        firebaseGateway: firebase,
        groqGateway: groq,
        groqConfigured: true,
        conversationPreference: AiConversationProviderPreference.groq,
      );

      await router.startSession(
        request: _request(ModelTask.personalFinancialAnalysis),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );

      expect(firebase.calls, 0);
      expect(groq.calls, 1);
    },
  );

  test(
    'explicit Groq and Firebase preferences select enabled providers',
    () async {
      final explicitGroq = _CountingGateway();
      final groqRouter = RoutedAiAgentModelGateway(
        flags: AiGatewayFeatureFlags.resolve(
          groqGatewayValue: 'true',
          generalChatValue: 'true',
        ),
        firebaseGateway: _CountingGateway(),
        groqGateway: explicitGroq,
        conversationPreference: AiConversationProviderPreference.groq,
      );
      final explicitFirebase = _CountingGateway();
      final firebaseRouter = RoutedAiAgentModelGateway(
        flags: AiGatewayFeatureFlags.resolve(
          groqGatewayValue: 'true',
          generalChatValue: 'true',
        ),
        firebaseGateway: explicitFirebase,
        groqGateway: _CountingGateway(),
        conversationPreference: AiConversationProviderPreference.firebase,
      );

      await groqRouter.startSession(
        request: _request(ModelTask.generalConversation),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );
      await firebaseRouter.startSession(
        request: _request(ModelTask.generalConversation),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );

      expect(explicitGroq.calls, 1);
      expect(explicitFirebase.calls, 1);
    },
  );

  test('explicit Groq still honors global and capability flags', () async {
    final firebase = _CountingGateway();
    final groq = _CountingGateway();
    final router = RoutedAiAgentModelGateway(
      flags: AiGatewayFeatureFlags.resolve(),
      firebaseGateway: firebase,
      groqGateway: groq,
      conversationPreference: AiConversationProviderPreference.groq,
    );

    for (final task in <ModelTask>[
      ModelTask.generalConversation,
      ModelTask.personalFinancialAnalysis,
    ]) {
      final session = await router.startSession(
        request: _request(task),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );
      expect((await session.sendInitial()).warnings, isNotEmpty);
    }

    expect(groq.calls, 0);
    expect(firebase.calls, 0);
  });

  test('Groq failure before content falls back to Firebase once', () async {
    final firebase = _CountingGateway();
    final groq = _CountingGateway(const _TransientThrowingSession());
    final router = RoutedAiAgentModelGateway(
      flags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
        firebaseTextFallbackValue: 'true',
      ),
      firebaseGateway: firebase,
      groqGateway: groq,
    );

    final session = await router.startSession(
      request: _request(ModelTask.generalConversation),
      tools: const <AiToolDefinition>[],
      egressGuard: testAiProviderEgressGuard,
    );

    expect((await session.sendInitial()).text, 'ok');
    expect(groq.calls, 1);
    expect(firebase.calls, 1);
  });

  test('Groq failure stays on Groq when text fallback is disabled', () async {
    final firebase = _CountingGateway();
    final router = RoutedAiAgentModelGateway(
      flags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
      ),
      firebaseGateway: firebase,
      groqGateway: _CountingGateway(const _ThrowingSession()),
    );

    final session = await router.startSession(
      request: _request(ModelTask.generalConversation),
      tools: const <AiToolDefinition>[],
      egressGuard: testAiProviderEgressGuard,
    );

    await expectLater(session.sendInitial(), throwsA(isA<StateError>()));
    expect(firebase.calls, 0);
  });

  test(
    'configured fallback does not hide gateway authentication failures',
    () async {
      final firebase = _CountingGateway();
      final router = RoutedAiAgentModelGateway(
        flags: AiGatewayFeatureFlags.resolve(
          groqGatewayValue: 'true',
          generalChatValue: 'true',
          firebaseTextFallbackValue: 'true',
        ),
        firebaseGateway: firebase,
        groqGateway: _CountingGateway(const _AuthenticationThrowingSession()),
      );

      final session = await router.startSession(
        request: _request(ModelTask.generalConversation),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );

      await expectLater(
        session.sendInitial(),
        throwsA(
          isA<AiGatewayException>().having(
            (failure) => failure.code,
            'code',
            AiGatewayFailureCode.gatewayAuthenticationRequired,
          ),
        ),
      );
      expect(firebase.calls, 0);
    },
  );

  test('warning-only and empty Groq replies never trigger fallback', () async {
    for (final primary in <AiAgentModelSession>[
      const _WarningSession(),
      const _EmptySession(),
    ]) {
      final firebase = _CountingGateway();
      final router = RoutedAiAgentModelGateway(
        flags: AiGatewayFeatureFlags.resolve(
          groqGatewayValue: 'true',
          generalChatValue: 'true',
          firebaseTextFallbackValue: 'true',
        ),
        firebaseGateway: firebase,
        groqGateway: _CountingGateway(primary),
      );

      final session = await router.startSession(
        request: _request(ModelTask.generalConversation),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );
      final turn = await session.sendInitial();

      expect(turn.text, isNull);
      if (primary is _WarningSession) {
        expect(turn.warnings, contains('provider_unavailable'));
      } else {
        expect(turn.warnings, isEmpty);
      }
      expect(firebase.calls, 0);
    }
  });

  test('warning-only Groq stream never triggers fallback', () async {
    final firebase = _CountingGateway();
    final router = RoutedAiAgentModelGateway(
      flags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
        firebaseTextFallbackValue: 'true',
      ),
      firebaseGateway: firebase,
      groqGateway: _CountingGateway(const _WarningStreamingSession()),
    );

    final session = await router.startSession(
      request: _request(ModelTask.generalConversation),
      tools: const <AiToolDefinition>[],
      egressGuard: testAiProviderEgressGuard,
    );
    final turns = await (session as StreamingAiAgentModelSession)
        .sendInitialStream()
        .toList();

    expect(turns, hasLength(1));
    expect(turns.single.text, isNull);
    expect(turns.single.warnings, contains('provider_unavailable'));
    expect(firebase.calls, 0);
  });

  test('Groq stream never splices Firebase after text was emitted', () async {
    final firebase = _CountingGateway();
    final groq = _CountingGateway(const _PartialThenThrowingSession());
    final router = RoutedAiAgentModelGateway(
      flags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
        firebaseTextFallbackValue: 'true',
      ),
      firebaseGateway: firebase,
      groqGateway: groq,
    );

    final session = await router.startSession(
      request: _request(ModelTask.generalConversation),
      tools: const <AiToolDefinition>[],
      egressGuard: testAiProviderEgressGuard,
    );

    expect(session, isA<StreamingAiAgentModelSession>());
    await expectLater(
      (session as StreamingAiAgentModelSession).sendInitialStream(),
      emitsInOrder(<Object>[
        isA<AiAgentModelTurn>().having((turn) => turn.text, 'text', 'partial'),
        emitsError(isA<StateError>()),
      ]),
    );
    expect(firebase.calls, 0);
  });

  test(
    'partial financial rollout uses only an explicit Firebase fallback',
    () async {
      final firebase = _CountingGateway();
      final groq = _CountingGateway();
      final router = RoutedAiAgentModelGateway(
        flags: AiGatewayFeatureFlags.resolve(
          groqGatewayValue: 'true',
          generalChatValue: 'true',
          toolSelectionValue: 'true',
          financialExplanationValue: 'false',
          firebaseTextFallbackValue: 'true',
        ),
        firebaseGateway: firebase,
        groqGateway: groq,
      );

      await router.startSession(
        request: _request(ModelTask.personalFinancialAnalysis),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );

      expect(firebase.calls, 1);
      expect(groq.calls, 0);
    },
  );

  test('Groq-primary financial route does not silently use Firebase', () async {
    final firebase = _CountingGateway();
    final router = RoutedAiAgentModelGateway(
      flags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
        financialExplanationValue: 'false',
      ),
      firebaseGateway: firebase,
      groqGateway: _CountingGateway(),
    );

    final session = await router.startSession(
      request: _request(ModelTask.personalFinancialAnalysis),
      tools: const <AiToolDefinition>[],
      egressGuard: testAiProviderEgressGuard,
    );

    expect(
      (await session.sendInitial()).warnings,
      contains('provider_disabled'),
    );
    expect(firebase.calls, 0);
  });

  test(
    'full financial flags with missing Groq URL use explicit fallback',
    () async {
      final firebase = _CountingGateway();
      final groq = _CountingGateway();
      final router = RoutedAiAgentModelGateway(
        flags: AiGatewayFeatureFlags.resolve(
          groqGatewayValue: 'true',
          generalChatValue: 'true',
          toolSelectionValue: 'true',
          financialExplanationValue: 'true',
          arabicSpecialistValue: 'true',
          firebaseTextFallbackValue: 'true',
        ),
        firebaseGateway: firebase,
        groqGateway: groq,
        groqConfigured: false,
        conversationPreference: AiConversationProviderPreference.groq,
      );

      final session = await router.startSession(
        request: _request(ModelTask.personalFinancialAnalysis),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );

      expect((await session.sendInitial()).text, 'ok');
      expect(firebase.calls, 1);
      expect(groq.calls, 0);
    },
  );

  test(
    'financial actions and receipt capability never route to Groq',
    () async {
      final groq = _CountingGateway();
      final router = RoutedAiAgentModelGateway(
        flags: AiGatewayFeatureFlags.resolve(
          groqGatewayValue: 'true',
          generalChatValue: 'true',
          financialExplanationValue: 'true',
          toolSelectionValue: 'true',
          arabicSpecialistValue: 'true',
        ),
        firebaseGateway: _CountingGateway(),
        groqGateway: groq,
      );

      for (final task in <ModelTask>[
        ModelTask.financialCommandExtraction,
        ModelTask.receiptAnalysis,
      ]) {
        final session = await router.startSession(
          request: _request(task),
          tools: const <AiToolDefinition>[],
          egressGuard: testAiProviderEgressGuard,
        );
        expect((await session.sendInitial()).warnings, isNotEmpty);
      }
      expect(groq.calls, 0);
    },
  );
}

AiAgentModelRequest _request(ModelTask task) => AiAgentModelRequest(
  userMessage: 'test',
  systemInstruction: '',
  memoryContext: '',
  taskClass: task,
  locale: 'en',
  baseCurrencyCode: 'LYD',
);

class _CountingGateway implements AiAgentModelGateway {
  _CountingGateway([this.session = const _Session()]);

  final AiAgentModelSession session;
  int calls = 0;

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async {
    calls += 1;
    return session;
  }
}

class _Session implements AiAgentModelSession {
  const _Session();

  @override
  Future<AiAgentModelTurn> sendInitial() async =>
      const AiAgentModelTurn(text: 'ok');

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => const AiAgentModelTurn(text: 'ok');
}

class _ThrowingSession implements AiAgentModelSession {
  const _ThrowingSession();

  @override
  Future<AiAgentModelTurn> sendInitial() async {
    throw StateError('synthetic primary failure');
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async {
    throw StateError('synthetic primary failure');
  }
}

class _TransientThrowingSession implements AiAgentModelSession {
  const _TransientThrowingSession();

  @override
  Future<AiAgentModelTurn> sendInitial() async {
    throw const AiGatewayException(
      code: AiGatewayFailureCode.gatewayUnavailable,
      safeMessage: 'Synthetic transient gateway failure.',
    );
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async {
    throw const AiGatewayException(
      code: AiGatewayFailureCode.gatewayUnavailable,
      safeMessage: 'Synthetic transient gateway failure.',
    );
  }
}

class _AuthenticationThrowingSession implements AiAgentModelSession {
  const _AuthenticationThrowingSession();

  @override
  Future<AiAgentModelTurn> sendInitial() async {
    throw const AiGatewayException(
      code: AiGatewayFailureCode.gatewayAuthenticationRequired,
      safeMessage: 'Synthetic gateway authentication failure.',
    );
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => sendInitial();
}

class _WarningSession implements AiAgentModelSession {
  const _WarningSession();

  @override
  Future<AiAgentModelTurn> sendInitial() async =>
      const AiAgentModelTurn(warnings: <String>['provider_unavailable']);

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => const AiAgentModelTurn(warnings: <String>['provider_unavailable']);
}

class _EmptySession implements AiAgentModelSession {
  const _EmptySession();

  @override
  Future<AiAgentModelTurn> sendInitial() async => const AiAgentModelTurn();

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => const AiAgentModelTurn();
}

class _WarningStreamingSession implements StreamingAiAgentModelSession {
  const _WarningStreamingSession();

  @override
  Future<AiAgentModelTurn> sendInitial() async =>
      const AiAgentModelTurn(warnings: <String>['provider_unavailable']);

  @override
  Stream<AiAgentModelTurn> sendInitialStream() async* {
    yield const AiAgentModelTurn(warnings: <String>['provider_unavailable']);
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => const AiAgentModelTurn(warnings: <String>['provider_unavailable']);
}

class _PartialThenThrowingSession implements StreamingAiAgentModelSession {
  const _PartialThenThrowingSession();

  @override
  Future<AiAgentModelTurn> sendInitial() async =>
      const AiAgentModelTurn(text: 'partial');

  @override
  Stream<AiAgentModelTurn> sendInitialStream() async* {
    yield const AiAgentModelTurn(text: 'partial');
    throw StateError('synthetic late primary failure');
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => const AiAgentModelTurn(text: 'partial');
}
