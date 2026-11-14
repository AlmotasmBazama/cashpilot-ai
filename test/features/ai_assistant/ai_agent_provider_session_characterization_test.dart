import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/general_assistant_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

void main() {
  group('provider session loop characterization', () {
    test(
      'builds the exact bounded provider-safe conversation history',
      () async {
        final longSafeMessage = List<String>.filled(520, 'x').join();
        final memory = InMemoryAiAgentMemoryStore();
        await memory.save(
          AiAgentSessionMemory(
            messages: <AiAgentMessage>[
              _message('oldest safe', 1),
              _message('My balance is private', 2),
              _message('first retained safe turn', 3),
              _message('reference 123', 4),
              _message(longSafeMessage, 5),
              _message('third retained safe turn', 6),
              _message('fourth retained safe turn', 7),
            ],
          ),
        );
        final session = _ScriptedSession(
          initial: const AiAgentModelTurn(text: 'A concise explanation.'),
        );
        final gateway = _RecordingGateway(session);

        await _orchestrator(memory: memory, gateway: gateway).respond(
          const AiAgentRequest(
            message: '  Discuss epistemology in plain language.  ',
            locale: 'en-GB',
            baseCurrencyCode: 'LYD',
          ),
        );

        final request = gateway.request!;
        expect(request.userMessage, 'Discuss epistemology in plain language.');
        expect(
          request.systemInstruction,
          GeneralAssistantPolicy.systemInstruction,
        );
        expect(request.memoryContext, isEmpty);
        expect(request.taskClass, ModelTask.generalConversation);
        expect(request.locale, 'en-GB');
        expect(request.baseCurrencyCode, 'LYD');
        expect(request.compactMemorySummary, isNull);
        expect(gateway.tools, isEmpty);
        expect(
          request.conversationHistory.map((message) => message.content),
          <String>[
            'first retained safe turn',
            longSafeMessage.substring(0, 500),
            'third retained safe turn',
            'fourth retained safe turn',
          ],
        );
        expect(
          request.conversationHistory.map((message) => message.role),
          <AiAgentMessageRole>[
            AiAgentMessageRole.user,
            AiAgentMessageRole.user,
            AiAgentMessageRole.user,
            AiAgentMessageRole.user,
          ],
        );
        expect(
          request.conversationHistory.map((message) => message.createdAt),
          <DateTime>[
            DateTime.utc(2026, 8, 17, 0, 3),
            DateTime.utc(2026, 8, 17, 0, 5),
            DateTime.utc(2026, 8, 17, 0, 6),
            DateTime.utc(2026, 8, 17, 0, 7),
          ],
        );
        expect(
          request.conversationHistory.any(
            (message) => message.content.contains('epistemology'),
          ),
          isFalse,
        );
      },
    );

    test(
      'preserves tool payload order while blocking duplicate and irrelevant calls',
      () async {
        final registry = _RecordingToolRegistry();
        final session = _ScriptedSession(
          initial: const AiAgentModelTurn(
            toolCalls: <AiAgentToolCall>[
              AiAgentToolCall(
                id: 'first',
                name: 'get_dashboard_summary',
                arguments: <String, Object?>{'period': 'month'},
              ),
              AiAgentToolCall(
                id: 'duplicate',
                name: 'get_dashboard_summary',
                arguments: <String, Object?>{'period': 'month'},
              ),
              AiAgentToolCall(
                id: 'irrelevant',
                name: 'get_goal_progress',
                arguments: <String, Object?>{},
              ),
            ],
          ),
          afterToolResults: const AiAgentModelTurn(text: 'Grounded summary.'),
        );
        final gateway = _RecordingGateway(session);

        final response =
            await _orchestrator(gateway: gateway, registry: registry).respond(
              const AiAgentRequest(
                message: 'Analyze my spending',
                locale: 'en',
                baseCurrencyCode: 'LYD',
              ),
            );

        expect(registry.executedCalls, hasLength(1));
        expect(registry.executedCalls.single.id, 'first');
        expect(session.toolResultCalls, hasLength(1));
        expect(session.toolResultCalls.single.map((call) => call.id), <String>[
          'first',
          'duplicate',
          'irrelevant',
        ]);
        final payloads = session.toolResultPayloads.single;
        expect(payloads, hasLength(3));
        expect((payloads[0] as Map<String, Object?>)['ok'], isTrue);
        expect(
          (payloads[1] as Map<String, Object?>)['code'],
          'duplicate_tool_call',
        );
        expect(
          (payloads[2] as Map<String, Object?>)['code'],
          'tool_not_relevant',
        );
        expect(response.executedToolNames, <String>['get_dashboard_summary']);
      },
    );

    test(
      'retains a successful result when provider continuation fails',
      () async {
        final registry = _RecordingToolRegistry(failAfterFirstExecution: true);
        final session = _ScriptedSession(
          initial: const AiAgentModelTurn(
            toolCalls: <AiAgentToolCall>[
              AiAgentToolCall(
                id: 'provider-read',
                name: 'get_dashboard_summary',
                arguments: <String, Object?>{},
              ),
            ],
          ),
          toolResultError: StateError('provider continuation failed'),
        );

        final response =
            await _orchestrator(
              gateway: _RecordingGateway(session),
              registry: registry,
            ).respond(
              const AiAgentRequest(
                message: 'Analyze my spending',
                locale: 'en',
                baseCurrencyCode: 'LYD',
              ),
            );

        expect(registry.executedCalls, hasLength(2));
        expect(session.toolResultPayloads, hasLength(1));
        expect(response.kind, AiAgentResponseKind.answer);
        expect(response.executedToolNames, <String>['get_dashboard_summary']);
        expect(response.evidence, hasLength(1));
      },
    );

    test(
      'enforces the per-round cap before executing any provider call',
      () async {
        final registry = _RecordingToolRegistry();
        final session = _ScriptedSession(
          initial: const AiAgentModelTurn(
            toolCalls: <AiAgentToolCall>[
              AiAgentToolCall(
                id: 'one',
                name: 'get_dashboard_summary',
                arguments: <String, Object?>{},
              ),
              AiAgentToolCall(
                id: 'two',
                name: 'get_dashboard_summary',
                arguments: <String, Object?>{'period': 'month'},
              ),
            ],
          ),
        );

        final response =
            await _orchestrator(
              gateway: _RecordingGateway(session),
              registry: registry,
              limits: const AiAgentLimits(maxCallsPerRound: 1),
            ).respond(
              const AiAgentRequest(
                message: 'Discuss epistemology in plain language.',
                locale: 'en',
                baseCurrencyCode: 'LYD',
              ),
            );

        expect(registry.executedCalls, isEmpty);
        expect(session.toolResultCalls, isEmpty);
        expect(response.kind, AiAgentResponseKind.failure);
        expect(response.warnings, contains('model_unavailable'));
      },
    );

    test(
      'stream entry point falls back to one non-stream initial turn',
      () async {
        final session = _ScriptedSession(
          initial: const AiAgentModelTurn(text: 'One final answer.'),
        );
        final gateway = _RecordingGateway(session);

        final responses = await _orchestrator(gateway: gateway)
            .respondStream(
              const AiAgentRequest(
                message: 'Discuss epistemology in plain language.',
                locale: 'en',
                baseCurrencyCode: 'LYD',
              ),
            )
            .toList();

        expect(gateway.startCount, 1);
        expect(session.initialCount, 1);
        expect(session.toolResultCalls, isEmpty);
        expect(responses, hasLength(1));
        expect(responses.single.isPartial, isFalse);
        expect(responses.single.message, 'One final answer.');
      },
    );
  });
}

AiAgentMessage _message(String content, int minute) => AiAgentMessage(
  role: AiAgentMessageRole.user,
  content: content,
  createdAt: DateTime.utc(2026, 8, 17, 0, minute),
);

AiAgentOrchestratorImpl _orchestrator({
  required AiAgentModelGateway gateway,
  AiToolRegistry registry = const _EmptyToolRegistry(),
  AiAgentMemoryStore? memory,
  AiAgentLimits limits = const AiAgentLimits(),
}) => AiAgentOrchestratorImpl(
  toolRegistry: registry,
  memoryStore: memory ?? InMemoryAiAgentMemoryStore(),
  memoryCompactor: const DefaultAiAgentMemoryCompactor(),
  modelRouter: const DefaultAiAgentModelRouter(),
  contextSanitizer: const DefaultAiAgentContextSanitizer(),
  responseComposer: const DefaultAiAgentResponseComposer(),
  modelGateway: gateway,
  providerEgressGuardFactory: (_) => testAiProviderEgressGuard,
  financialDataScopeVerified: true,
  limits: limits,
);

final class _RecordingGateway implements AiAgentModelGateway {
  _RecordingGateway(this.session);

  final AiAgentModelSession session;
  int startCount = 0;
  AiAgentModelRequest? request;
  List<AiToolDefinition> tools = const <AiToolDefinition>[];

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async {
    startCount += 1;
    this.request = request;
    this.tools = tools;
    return session;
  }
}

final class _ScriptedSession implements AiAgentModelSession {
  _ScriptedSession({
    required this.initial,
    this.afterToolResults = const AiAgentModelTurn(),
    this.toolResultError,
  });

  final AiAgentModelTurn initial;
  final AiAgentModelTurn afterToolResults;
  final Object? toolResultError;
  int initialCount = 0;
  final List<List<AiAgentToolCall>> toolResultCalls = <List<AiAgentToolCall>>[];
  final List<List<Object>> toolResultPayloads = <List<Object>>[];

  @override
  Future<AiAgentModelTurn> sendInitial() async {
    initialCount += 1;
    return initial;
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async {
    toolResultCalls.add(List<AiAgentToolCall>.of(calls));
    toolResultPayloads.add(List<Object>.of(results));
    final error = toolResultError;
    if (error != null) throw error;
    return afterToolResults;
  }
}

final class _RecordingToolRegistry implements AiToolRegistry {
  _RecordingToolRegistry({this.failAfterFirstExecution = false});

  final bool failAfterFirstExecution;
  final List<AiAgentToolCall> executedCalls = <AiAgentToolCall>[];

  static const dashboard = AiToolDefinition(
    name: 'get_dashboard_summary',
    description: 'Returns a bounded dashboard summary.',
    permission: AiToolPermission.readFinancialData,
  );
  static const goal = AiToolDefinition(
    name: 'get_goal_progress',
    description: 'Returns bounded goal progress.',
    permission: AiToolPermission.readFinancialData,
  );

  @override
  List<AiToolDefinition> get definitions => const <AiToolDefinition>[
    dashboard,
    goal,
  ];

  @override
  AiToolDefinition? definitionFor(String name) => switch (name) {
    'get_dashboard_summary' => dashboard,
    'get_goal_progress' => goal,
    _ => null,
  };

  @override
  Future<AiToolResult> execute(
    AiAgentToolCall call,
    AiToolExecutionContext context,
  ) async {
    executedCalls.add(call);
    if (failAfterFirstExecution && executedCalls.length > 1) {
      throw const AiToolFailure(
        code: 'fallback_read_failed',
        safeMessage: 'The fallback read failed safely.',
      );
    }
    return const AiToolResult(
      toolName: 'get_dashboard_summary',
      data: <String, Object?>{
        'monthlyIncome': '200',
        'monthlyExpense': '80',
        'monthlySavings': '120',
        'currency': 'LYD',
      },
      evidenceSummary: 'Income 200, expenses 80, savings 120 LYD.',
      period: '2026-08',
    );
  }
}

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
  ) => throw StateError('No tool is available.');
}
