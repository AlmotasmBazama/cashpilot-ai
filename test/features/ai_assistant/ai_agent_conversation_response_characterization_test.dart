import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/general_assistant_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/assistant_navigation_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

void main() {
  group('agent conversation state characterization', () {
    test(
      'clears stale memory before the provider request and final save',
      () async {
        final events = <String>[];
        final memory = _RecordingMemoryStore(
          events: events,
          memory: AiAgentSessionMemory(
            messages: <AiAgentMessage>[
              AiAgentMessage(
                role: AiAgentMessageRole.user,
                content: 'stale private turn',
                createdAt: DateTime.now().toUtc().subtract(
                  const Duration(hours: 14),
                ),
              ),
            ],
            activeTopic: 'stale-topic',
            updatedAt: DateTime.now().toUtc().subtract(
              const Duration(hours: 13),
            ),
          ),
        );
        final gateway = _RecordingGateway(
          events: events,
          turn: const AiAgentModelTurn(text: 'A fresh answer.'),
        );

        final response = await _orchestrator(memory: memory, gateway: gateway)
            .respond(
              const AiAgentRequest(
                message: 'Discuss epistemology in plain language.',
                locale: 'en',
                baseCurrencyCode: 'LYD',
              ),
            );

        expect(response.message, 'A fresh answer.');
        expect(events, <String>[
          'memory.read',
          'memory.clear',
          'gateway.start',
          'model.initial',
          'memory.save',
        ]);
        expect(memory.saved.messages, hasLength(2));
        expect(
          memory.saved.messages.map((message) => message.role),
          <AiAgentMessageRole>[
            AiAgentMessageRole.user,
            AiAgentMessageRole.assistant,
          ],
        );
        expect(
          memory.saved.messages.map((message) => message.content),
          <String>[
            'Discuss epistemology in plain language.',
            'A fresh answer.',
          ],
        );
        expect(memory.saved.activeTopic, isNull);
        expect(memory.accesses, hasLength(3));
        expect(memory.accesses.every((access) => access != null), isTrue);
        expect(identical(memory.accesses[0], memory.accesses[1]), isTrue);
        expect(identical(memory.accesses[1], memory.accesses[2]), isTrue);
      },
    );

    test(
      'updates goal context and preserves unrelated fresh context',
      () async {
        final events = <String>[];
        final memory = _RecordingMemoryStore(
          events: events,
          memory: AiAgentSessionMemory(
            activeTopic: 'budgets',
            activeCategory: 'Groceries',
            activeAccount: 'Cash',
            activeBudget: 'Dining',
            updatedAt: DateTime.now().toUtc().subtract(
              const Duration(hours: 1),
            ),
          ),
        );
        final registry = _GoalToolRegistry(events);

        final response =
            await _orchestrator(
              memory: memory,
              gateway: null,
              registry: registry,
            ).respond(
              const AiAgentRequest(
                message: 'Show my goal progress and remaining amount',
                locale: 'en',
                baseCurrencyCode: 'LYD',
              ),
            );

        expect(response.executedToolNames, <String>[
          'get_goal_summary',
          'get_goal_progress',
        ]);
        expect(events, <String>[
          'memory.read',
          'tool.get_goal_summary',
          'tool.get_goal_progress',
          'memory.save',
        ]);
        expect(memory.saved.activeTopic, 'goals');
        expect(memory.saved.activeGoal, 'Emergency fund');
        expect(memory.saved.activePeriod, '2026-09');
        expect(memory.saved.activeCategory, 'Groceries');
        expect(memory.saved.activeAccount, 'Cash');
        expect(memory.saved.activeBudget, 'Dining');
        expect(memory.saved.messages.last.role, AiAgentMessageRole.assistant);
      },
    );

    test(
      'clear and start-new clear scoped memory before gateway sessions',
      () async {
        for (final startNew in <bool>[false, true]) {
          final events = <String>[];
          final memory = _RecordingMemoryStore(events: events);
          final gateway = _RecordingGateway(events: events);
          final orchestrator = _orchestrator(
            memory: memory,
            gateway: gateway,
            ownerScope: _ownerScope,
          );

          if (startNew) {
            await orchestrator.startNewConversation();
          } else {
            await orchestrator.clearConversation();
          }

          expect(events, <String>['memory.clear', 'gateway.clear']);
          expect(memory.accesses, hasLength(1));
          expect(memory.accesses.single?.ownerScope, _ownerScope);
        }
      },
    );
  });

  group('agent response policy characterization', () {
    test('capability denials precede memory and provider access', () async {
      final events = <String>[];
      final memory = _RecordingMemoryStore(events: events);
      final gateway = _RecordingGateway(events: events);
      final orchestrator = _orchestrator(
        memory: memory,
        gateway: gateway,
        capabilities: const AiAssistantCapabilities(
          directConversationAvailable: true,
          generalConversationAvailable: false,
          currentKnowledgeAvailable: false,
          personalFinancialAnalysisAvailable: false,
          financialDraftsAvailable: false,
          confirmedExecutionAvailable: false,
          receiptVisionAvailable: false,
          navigationAvailable: false,
          activeProvider: AiActiveProvider.none,
          unavailableReason: AiUnavailableReason.gatewayUrlMissing,
          retryable: true,
          platformSupported: true,
        ),
      );

      final general = await orchestrator.respond(
        const AiAgentRequest(
          message: 'Discuss epistemology in plain language.',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        ),
      );
      final current = await orchestrator.respond(
        const AiAgentRequest(
          message: 'What is the weather today?',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        ),
      );
      final financial = await orchestrator.respond(
        const AiAgentRequest(
          message: 'Analyze my spending',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        ),
      );
      final receipt = await orchestrator.respond(
        const AiAgentRequest(
          message: 'Scan receipt',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        ),
      );
      final navigation = await orchestrator.respond(
        const AiAgentRequest(
          message: 'Open accounts',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        ),
      );

      expect(general.warnings, <String>['gatewayUrlMissing']);
      expect(general.retryable, isTrue);
      expect(current.warnings, <String>['gatewayUrlMissing']);
      expect(current.retryable, isTrue);
      expect(financial.warnings, <String>['financialAccessDisabled']);
      expect(financial.retryable, isFalse);
      expect(receipt.warnings, <String>['receiptVisionUnavailable']);
      expect(receipt.retryable, isFalse);
      expect(navigation.warnings, <String>['financialAccessDisabled']);
      expect(navigation.retryable, isFalse);
      expect(events, isEmpty);
    });

    test(
      'navigation validates the result and saves after tool execution',
      () async {
        for (final valid in <bool>[true, false]) {
          final events = <String>[];
          final memory = _RecordingMemoryStore(events: events);
          final registry = _NavigationToolRegistry(
            events: events,
            valid: valid,
          );

          final response =
              await _orchestrator(
                memory: memory,
                gateway: null,
                registry: registry,
              ).respond(
                const AiAgentRequest(
                  message: 'Open accounts',
                  locale: 'en',
                  baseCurrencyCode: 'LYD',
                ),
              );

          expect(events, <String>[
            'memory.read',
            'tool.navigate_accounts',
            'memory.save',
          ]);
          expect(memory.saved.messages, hasLength(2));
          if (valid) {
            expect(response.kind, AiAgentResponseKind.navigation);
            expect(response.executedToolNames, <String>['navigate_accounts']);
            expect(
              response.navigationPath,
              AssistantNavigationPolicy.approvedToolPaths['navigate_accounts'],
            );
          } else {
            expect(response.kind, AiAgentResponseKind.failure);
            expect(response.turnKind, AssistantTurnKind.failure);
            expect(response.executedToolNames, isEmpty);
            expect(response.navigationPath, isNull);
            expect(
              response.message,
              'The requested screen could not be opened safely.',
            );
          }
        }
      },
    );

    test(
      'unknown provider failure is mapped, composed, and saved safely',
      () async {
        final events = <String>[];
        final memory = _RecordingMemoryStore(events: events);
        final gateway = _RecordingGateway(
          events: events,
          startError: StateError('raw provider detail'),
        );

        final response = await _orchestrator(memory: memory, gateway: gateway)
            .respond(
              const AiAgentRequest(
                message: 'Discuss epistemology in plain language.',
                locale: 'en',
                baseCurrencyCode: 'LYD',
              ),
            );

        expect(events, <String>['memory.read', 'gateway.start', 'memory.save']);
        expect(response.kind, AiAgentResponseKind.failure);
        expect(response.turnKind, AssistantTurnKind.failure);
        expect(response.warnings, <String>[
          'model_unavailable',
          'modelUnavailable',
        ]);
        expect(
          response.message,
          GeneralAssistantPolicy.unavailableForReason(
            AiUnavailableReason.modelUnavailable,
            locale: 'en',
          ),
        );
        expect(response.retryable, isTrue);
        expect(memory.saved.messages.last.content, response.message);
        expect(response.message, isNot(contains('raw provider detail')));
      },
    );
  });
}

AiAgentOrchestratorImpl _orchestrator({
  required _RecordingMemoryStore memory,
  required AiAgentModelGateway? gateway,
  AiToolRegistry registry = const _EmptyToolRegistry(),
  AiAssistantCapabilities capabilities =
      const AiAssistantCapabilities.testDefaults(),
  AiToolOwnerScopeBinding? ownerScope,
}) => AiAgentOrchestratorImpl(
  toolRegistry: registry,
  memoryStore: memory,
  memoryCompactor: const DefaultAiAgentMemoryCompactor(),
  modelRouter: const DefaultAiAgentModelRouter(),
  contextSanitizer: const DefaultAiAgentContextSanitizer(),
  responseComposer: const DefaultAiAgentResponseComposer(),
  capabilities: capabilities,
  modelGateway: gateway,
  providerEgressGuardFactory: (_) => testAiProviderEgressGuard,
  toolOwnerScope: ownerScope,
  currentToolOwnerScope: ownerScope == null ? null : () => ownerScope,
  operationFence: ownerScope == null ? null : BackupOperationFence(),
  financialDataScopeVerified: true,
);

const _ownerScope = AiToolOwnerScopeBinding(
  accountScope:
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
  epoch: 4,
);

final class _RecordingMemoryStore implements AiAgentMemoryStore {
  _RecordingMemoryStore({
    required this.events,
    AiAgentSessionMemory memory = const AiAgentSessionMemory(),
  }) : _memory = memory,
       saved = memory;

  final List<String> events;
  final List<AiAgentMemoryAccess?> accesses = <AiAgentMemoryAccess?>[];
  AiAgentSessionMemory _memory;
  AiAgentSessionMemory saved;

  @override
  Future<AiAgentSessionMemory> read({AiAgentMemoryAccess? access}) async {
    access?.assertActive();
    accesses.add(access);
    events.add('memory.read');
    return _memory;
  }

  @override
  Future<void> save(
    AiAgentSessionMemory memory, {
    AiAgentMemoryAccess? access,
  }) async {
    access?.assertActive();
    accesses.add(access);
    events.add('memory.save');
    _memory = memory;
    saved = memory;
  }

  @override
  Future<void> clear({AiAgentMemoryAccess? access}) async {
    access?.assertActive();
    accesses.add(access);
    events.add('memory.clear');
    _memory = const AiAgentSessionMemory();
    saved = _memory;
  }
}

final class _RecordingGateway implements ResettableAiAgentModelGateway {
  _RecordingGateway({
    required this.events,
    this.turn = const AiAgentModelTurn(text: 'unused'),
    this.startError,
  });

  final List<String> events;
  final AiAgentModelTurn turn;
  final Object? startError;

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async {
    events.add('gateway.start');
    final error = startError;
    if (error != null) throw error;
    return _RecordingSession(events, turn);
  }

  @override
  void clearSessions() => events.add('gateway.clear');
}

final class _RecordingSession implements AiAgentModelSession {
  const _RecordingSession(this.events, this.turn);

  final List<String> events;
  final AiAgentModelTurn turn;

  @override
  Future<AiAgentModelTurn> sendInitial() async {
    events.add('model.initial');
    return turn;
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) => throw StateError('No tool continuation is expected.');
}

final class _GoalToolRegistry implements AiToolRegistry {
  const _GoalToolRegistry(this.events);

  final List<String> events;

  static const summary = AiToolDefinition(
    name: 'get_goal_summary',
    description: 'Returns bounded goal summaries.',
    permission: AiToolPermission.readFinancialData,
  );
  static const progress = AiToolDefinition(
    name: 'get_goal_progress',
    description: 'Returns bounded goal progress.',
    permission: AiToolPermission.readFinancialData,
  );

  @override
  List<AiToolDefinition> get definitions => const <AiToolDefinition>[
    summary,
    progress,
  ];

  @override
  AiToolDefinition? definitionFor(String name) => switch (name) {
    'get_goal_summary' => summary,
    'get_goal_progress' => progress,
    _ => null,
  };

  @override
  Future<AiToolResult> execute(
    AiAgentToolCall call,
    AiToolExecutionContext context,
  ) async {
    events.add('tool.${call.name}');
    return AiToolResult(
      toolName: call.name,
      data: const <String, Object?>{
        'goals': <Map<String, Object?>>[
          <String, Object?>{'title': '  Emergency fund  '},
        ],
      },
      evidenceSummary: 'Emergency fund progress is available.',
      period: call.name == 'get_goal_progress' ? '2026-09' : '2026-08',
    );
  }
}

final class _NavigationToolRegistry implements AiToolRegistry {
  const _NavigationToolRegistry({required this.events, required this.valid});

  final List<String> events;
  final bool valid;

  static const definition = AiToolDefinition(
    name: 'navigate_accounts',
    description: 'Opens the accounts screen.',
    permission: AiToolPermission.navigate,
  );

  @override
  List<AiToolDefinition> get definitions => const <AiToolDefinition>[
    definition,
  ];

  @override
  AiToolDefinition? definitionFor(String name) =>
      name == definition.name ? definition : null;

  @override
  Future<AiToolResult> execute(
    AiAgentToolCall call,
    AiToolExecutionContext context,
  ) async {
    events.add('tool.${call.name}');
    return AiToolResult(
      toolName: call.name,
      data: <String, Object?>{'navigationApproved': valid},
      navigationPath: valid
          ? AssistantNavigationPolicy.approvedToolPaths[call.name]
          : '/forged',
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
