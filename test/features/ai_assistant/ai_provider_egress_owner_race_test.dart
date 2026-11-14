import 'dart:async';
import 'dart:convert';

import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_provider_egress_guard.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/agent/firebase_ai_agent_model_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_gateway_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/firebase_ai_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/firebase_gateway_token_provider.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/groq_ai_agent_model_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/groq_gateway_client.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/groq_gateway_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_operation_coordinator.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_session_guard.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('AI provider egress owner/session fence', () {
    test(
      'miswired owner scope or epoch cannot pair with Auth identity',
      () async {
        final nativeAuth = _SignedOutFirebaseAuth();
        final nativeGuard = FirebaseAuthSessionEpochGuard(nativeAuth);
        addTearDown(nativeGuard.dispose);
        final ownerForA = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          _sessionA.uid,
        ).id.value;
        final ownerForB = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          _sessionB.uid,
        ).id.value;
        final mismatches = <AiToolOwnerScopeBinding>[
          AiToolOwnerScopeBinding(accountScope: ownerForB, epoch: 4),
          AiToolOwnerScopeBinding(accountScope: ownerForA, epoch: 5),
        ];

        for (final mismatch in mismatches) {
          final memoryAccess = AiAgentMemoryAccess(
            ownerScope: mismatch,
            assertActive: () {},
          );
          expect(
            () => FirebaseAiProviderEgressGuard(
              expectedAuthSession: _sessionA,
              expectedOwnerScope: mismatch,
              currentOwnerScope: () => mismatch,
              memoryAccess: memoryAccess,
              authSessionGuard: nativeGuard,
              authOperationCoordinator: FirebaseAuthOperationCoordinator(),
            ),
            throwsA(isA<AiProviderEgressRevokedException>()),
          );
        }
      },
    );

    for (final transition in <String, AuthSessionIdentity?>{
      'A to B': _sessionB,
      'A to logout': null,
    }.entries) {
      test(
        '${transition.key} after private payload assembly sends zero provider bytes',
        () async {
          final guard = _MutableEgressGuard(currentSession: _sessionA);
          final gateway = _DelayedFirstDispatchGateway();
          final orchestrator = _orchestrator(gateway: gateway, guard: guard);

          final responseFuture = orchestrator.respond(
            const AiAgentRequest(
              message:
                  'Explain why my PRIVATE_FINANCIAL_PAYLOAD spending is 700 LYD',
              locale: 'en',
              baseCurrencyCode: 'LYD',
            ),
          );
          await gateway.sessionAssemblyStarted.future;
          expect(
            gateway.assembledRequest!.userMessage,
            contains('PRIVATE_FINANCIAL_PAYLOAD'),
          );

          guard.currentSession = transition.value;
          gateway.allowSessionAssemblyToFinish.complete();
          await responseFuture;

          expect(gateway.providerBytes, 0);
        },
      );
    }

    test(
      'owner generation change after payload assembly sends zero provider bytes',
      () async {
        final guard = _MutableEgressGuard(currentSession: _sessionA);
        final gateway = _DelayedFirstDispatchGateway();
        AiToolOwnerScopeBinding? currentOwner = _ownerA;
        final orchestrator = _orchestrator(
          gateway: gateway,
          guard: guard,
          currentOwnerScope: () => currentOwner,
        );

        final responseFuture = orchestrator.respond(
          const AiAgentRequest(
            message:
                'Explain why my PRIVATE_FINANCIAL_PAYLOAD spending is 700 LYD',
            locale: 'en',
            baseCurrencyCode: 'LYD',
          ),
        );
        await gateway.sessionAssemblyStarted.future;
        currentOwner = _ownerB;
        gateway.allowSessionAssemblyToFinish.complete();
        await responseFuture;

        expect(gateway.providerBytes, 0);
      },
    );

    test('identity switch after tokens sends zero HTTP bytes', () async {
      final guard = _MutableEgressGuard(currentSession: _sessionA);
      final tokens = _SwitchingTokenProvider(guard);
      final transport = _CountingHttpClient();
      final client = GroqGatewayClient(
        config: AiGatewayRuntimeConfig.resolve(
          baseUrl: 'https://gateway.example',
        ),
        tokenProvider: tokens,
        httpClient: transport,
      );

      await expectLater(
        client
            .streamRequest(
              '/v1/ai/general-chat',
              _generalRequest(),
              egressGuard: guard,
            )
            .toList(),
        throwsA(isA<AiProviderEgressRevokedException>()),
      );

      expect(tokens.calls, 1);
      expect(transport.sendCalls, 0);
    });

    test(
      'identity switch after primary failure sends zero fallback bytes',
      () async {
        final guard = _MutableEgressGuard(currentSession: _sessionA);
        final primary = _FailingFirebaseChat(
          beforeFailure: () => guard.currentSession = _sessionB,
        );
        final fallback = _FailingFirebaseChat();
        final config = FirebaseAiConfig.fromModelConfig(
          AiModelConfig.resolve(
            modelName: 'fallback-model',
            generalConversationModel: 'primary-model',
          ),
        );
        final gateway = FirebaseAiAgentModelGateway(
          config: config,
          chatFactory:
              ({
                required modelId,
                required request,
                required tools,
                required history,
                required maxTurns,
              }) => modelId == 'primary-model' ? primary : fallback,
        );
        final session = await gateway.startSession(
          request: const AiAgentModelRequest(
            userMessage: 'PRIVATE_PROVIDER_PAYLOAD',
            systemInstruction: '',
            memoryContext: '',
            taskClass: ModelTask.generalConversation,
          ),
          tools: const <AiToolDefinition>[],
          egressGuard: guard,
        );

        await expectLater(
          session.sendInitial(),
          throwsA(isA<AiProviderEgressRevokedException>()),
        );

        expect(primary.sendCalls, 1);
        expect(fallback.sendCalls, 0);
      },
    );

    test(
      'primary stream output then failure never resends prompt to fallback',
      () async {
        final guard = _MutableEgressGuard(currentSession: _sessionA);
        final primary = _PartiallyFailingFirebaseChat();
        final fallback = _FailingFirebaseChat();
        final config = FirebaseAiConfig.fromModelConfig(
          AiModelConfig.resolve(
            modelName: 'fallback-model',
            generalConversationModel: 'primary-model',
          ),
        );
        final gateway = FirebaseAiAgentModelGateway(
          config: config,
          chatFactory:
              ({
                required modelId,
                required request,
                required tools,
                required history,
                required maxTurns,
              }) => modelId == 'primary-model' ? primary : fallback,
        );
        final session = await gateway.startSession(
          request: const AiAgentModelRequest(
            userMessage: 'PRIVATE_STREAM_PAYLOAD',
            systemInstruction: '',
            memoryContext: '',
            taskClass: ModelTask.generalConversation,
          ),
          tools: const <AiToolDefinition>[],
          egressGuard: guard,
        );

        final emitted = <AiAgentModelTurn>[];
        final terminal = Completer<void>();
        Object? terminalError;
        var completedSuccessfully = false;
        (session as StreamingAiAgentModelSession).sendInitialStream().listen(
          emitted.add,
          onError: (Object error, StackTrace stackTrace) {
            terminalError ??= error;
          },
          onDone: () {
            completedSuccessfully = terminalError == null;
            if (!terminal.isCompleted) terminal.complete();
          },
        );
        await terminal.future;

        expect(emitted.map((turn) => turn.text), <String?>['partial']);
        expect(
          terminalError,
          isA<AiGatewayException>().having(
            (failure) => failure.code,
            'code',
            AiGatewayFailureCode.providerUnavailable,
          ),
        );
        expect(completedSuccessfully, isFalse);
        expect(primary.sendCalls, 1);
        expect(fallback.sendCalls, 0);
      },
    );

    test(
      'transport failure sends no automatic retry bytes after identity switch',
      () async {
        final guard = _MutableEgressGuard(currentSession: _sessionA);
        final tokens = _CountingTokenProvider();
        final transport = _FailingFirstHttpClient(
          onFirstSend: () => guard.currentSession = _sessionB,
        );
        final source = GroqGatewayDataSource(
          GroqGatewayClient(
            config: AiGatewayRuntimeConfig.resolve(
              baseUrl: 'https://gateway.example',
            ),
            tokenProvider: tokens,
            httpClient: transport,
          ),
        );

        await expectLater(
          source
              .streamGeneralConversation(_generalRequest(), egressGuard: guard)
              .toList(),
          throwsA(
            isA<AiGatewayException>().having(
              (failure) => failure.code,
              'code',
              AiGatewayFailureCode.gatewayUnavailable,
            ),
          ),
        );

        expect(tokens.calls, 1);
        expect(transport.sendCalls, 1);
      },
    );

    test(
      'identity switch before tool continuation sends zero second bytes',
      () async {
        final guard = _MutableEgressGuard(currentSession: _sessionA);
        final conversation = _ToolContinuationGateway();
        final gateway = GroqAiAgentModelGateway(
          gateway: conversation,
          clientVersion: 'test',
          toolSelectionEnabled: true,
          financialExplanationEnabled: true,
        );
        final session = await gateway.startSession(
          request: const AiAgentModelRequest(
            userMessage: 'Explain my spending',
            systemInstruction: '',
            memoryContext: '',
            taskClass: ModelTask.personalFinancialAnalysis,
            locale: 'en',
            baseCurrencyCode: 'LYD',
          ),
          tools: const <AiToolDefinition>[
            AiToolDefinition(
              name: 'get_dashboard_summary',
              description: 'bounded totals',
              permission: AiToolPermission.readFinancialData,
            ),
          ],
          egressGuard: guard,
        );
        final initial = await session.sendInitial();
        expect(conversation.toolSelectionBytes, greaterThan(0));

        guard.currentSession = _sessionB;
        await expectLater(
          session.sendToolResults(initial.toolCalls, const <Object>[
            <String, Object?>{
              'ok': true,
              'data': <String, Object?>{'monthlyExpense': '700.00'},
            },
          ]),
          throwsA(isA<AiProviderEgressRevokedException>()),
        );

        expect(conversation.financialExplanationBytes, 0);
      },
    );
  });
}

AiAgentOrchestrator _orchestrator({
  required AiAgentModelGateway gateway,
  required AiProviderEgressGuard guard,
  AiToolOwnerScopeReader? currentOwnerScope,
}) {
  return AiAgentOrchestratorImpl(
    toolRegistry: const _EmptyToolRegistry(),
    memoryStore: InMemoryAiAgentMemoryStore(),
    memoryCompactor: const DefaultAiAgentMemoryCompactor(),
    modelRouter: const DefaultAiAgentModelRouter(),
    contextSanitizer: const DefaultAiAgentContextSanitizer(),
    responseComposer: const DefaultAiAgentResponseComposer(),
    modelGateway: gateway,
    providerEgressGuardFactory: (_) => guard,
    toolOwnerScope: _ownerA,
    currentToolOwnerScope: currentOwnerScope ?? () => _ownerA,
    operationFence: BackupOperationFence(),
    financialDataScopeVerified: true,
  );
}

AiGatewayRequest _generalRequest() => const AiGatewayRequest(
  requestId: 'request_egress_race',
  mode: AiGatewayMode.generalConversation,
  locale: 'en',
  sanitizedMessages: <AiGatewayMessage>[
    AiGatewayMessage(role: 'user', content: 'PRIVATE_PROVIDER_PAYLOAD'),
  ],
  timeoutClass: AiGatewayTimeoutClass.interactive,
  clientVersion: 'test',
);

const _ownerA = AiToolOwnerScopeBinding(
  accountScope:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  epoch: 4,
);

const _ownerB = AiToolOwnerScopeBinding(
  accountScope:
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  epoch: 5,
);

const _sessionA = AuthSessionIdentity(
  uid: 'user-a',
  isAnonymous: false,
  authSessionGeneration: 4,
  tenantId: null,
);

const _sessionB = AuthSessionIdentity(
  uid: 'user-b',
  isAnonymous: false,
  authSessionGeneration: 5,
  tenantId: null,
);

final class _MutableEgressGuard implements AiProviderEgressGuard {
  _MutableEgressGuard({required this.currentSession});

  AuthSessionIdentity? currentSession;

  @override
  AuthSessionIdentity get expectedAuthSession => _sessionA;

  @override
  void assertActive() {
    if (currentSession != expectedAuthSession) {
      throw const AiProviderEgressRevokedException();
    }
  }

  @override
  Future<T> runSerializedAuthOperation<T>(
    Future<T> Function() operation,
  ) async {
    assertActive();
    final result = await operation();
    assertActive();
    return result;
  }
}

final class _DelayedFirstDispatchGateway implements AiAgentModelGateway {
  final Completer<void> sessionAssemblyStarted = Completer<void>();
  final Completer<void> allowSessionAssemblyToFinish = Completer<void>();
  AiAgentModelRequest? assembledRequest;
  int providerBytes = 0;

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async {
    assembledRequest = request;
    sessionAssemblyStarted.complete();
    await allowSessionAssemblyToFinish.future;
    return _ByteCountingModelSession(this);
  }
}

final class _ByteCountingModelSession implements AiAgentModelSession {
  const _ByteCountingModelSession(this.gateway);

  final _DelayedFirstDispatchGateway gateway;

  @override
  Future<AiAgentModelTurn> sendInitial() async {
    gateway.providerBytes += utf8
        .encode(gateway.assembledRequest!.userMessage)
        .length;
    return const AiAgentModelTurn(text: 'should not dispatch');
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => const AiAgentModelTurn();
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
  ) {
    throw const AiToolFailure(
      code: 'tool_not_allowed',
      safeMessage: 'No tool is available in this test.',
    );
  }
}

final class _SwitchingTokenProvider implements AiGatewayTokenProvider {
  _SwitchingTokenProvider(this.guard);

  final _MutableEgressGuard guard;
  int calls = 0;

  @override
  Future<AiGatewayTokens> freshTokens({
    required AiProviderEgressGuard egressGuard,
  }) async {
    calls += 1;
    guard.currentSession = _sessionB;
    return const AiGatewayTokens(
      firebaseIdToken: 'id-token',
      appCheckToken: 'app-check-token',
    );
  }
}

final class _CountingTokenProvider implements AiGatewayTokenProvider {
  int calls = 0;

  @override
  Future<AiGatewayTokens> freshTokens({
    required AiProviderEgressGuard egressGuard,
  }) async {
    calls += 1;
    return const AiGatewayTokens(
      firebaseIdToken: 'id-token',
      appCheckToken: 'app-check-token',
    );
  }
}

final class _CountingHttpClient extends http.BaseClient {
  int sendCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCalls += 1;
    throw StateError('HTTP must not be reached.');
  }
}

final class _FailingFirstHttpClient extends http.BaseClient {
  _FailingFirstHttpClient({required this.onFirstSend});

  final void Function() onFirstSend;
  int sendCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCalls += 1;
    if (sendCalls == 1) {
      onFirstSend();
      throw StateError('first transport failed');
    }
    throw StateError('retry must not be reached');
  }
}

final class _FailingFirebaseChat implements FirebaseAiAgentChat {
  _FailingFirebaseChat({this.beforeFailure});

  final void Function()? beforeFailure;
  int sendCalls = 0;

  @override
  Future<firebase_ai.GenerateContentResponse> sendMessage(
    firebase_ai.Content content,
  ) async {
    sendCalls += 1;
    beforeFailure?.call();
    throw StateError('provider failure');
  }

  @override
  Stream<firebase_ai.GenerateContentResponse> sendMessageStream(
    firebase_ai.Content content,
  ) async* {
    sendCalls += 1;
    beforeFailure?.call();
    throw StateError('provider failure');
  }
}

final class _PartiallyFailingFirebaseChat implements FirebaseAiAgentChat {
  int sendCalls = 0;

  @override
  Future<firebase_ai.GenerateContentResponse> sendMessage(
    firebase_ai.Content content,
  ) async {
    sendCalls += 1;
    throw StateError('non-stream path is not expected');
  }

  @override
  Stream<firebase_ai.GenerateContentResponse> sendMessageStream(
    firebase_ai.Content content,
  ) async* {
    sendCalls += 1;
    yield firebase_ai.GenerateContentResponse(<firebase_ai.Candidate>[
      firebase_ai.Candidate(
        firebase_ai.Content.model(<firebase_ai.Part>[
          firebase_ai.TextPart('partial'),
        ]),
        null,
        null,
        null,
        null,
      ),
    ], null);
    throw StateError('primary stream failed after output');
  }
}

final class _ToolContinuationGateway implements AiConversationGateway {
  int toolSelectionBytes = 0;
  int financialExplanationBytes = 0;

  @override
  Future<AiGatewayHealth> healthCheck() async =>
      const AiGatewayHealth(reachable: true);

  @override
  Future<AiGatewayToolSelection> selectGovernedTools(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) async {
    toolSelectionBytes += utf8.encode(jsonEncode(request.toJson())).length;
    return const AiGatewayToolSelection(
      calls: <AiGatewayToolCall>[
        AiGatewayToolCall(
          name: 'get_dashboard_summary',
          arguments: <String, Object?>{},
        ),
      ],
    );
  }

  @override
  Stream<AiGatewayEvent> streamFinancialExplanation(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) async* {
    financialExplanationBytes += utf8
        .encode(jsonEncode(request.toJson()))
        .length;
    yield AiGatewayEvent(
      type: AiGatewayEventType.textDelta,
      requestId: request.requestId,
      delta: 'must not dispatch',
    );
  }

  @override
  Stream<AiGatewayEvent> streamGeneralConversation(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) => const Stream<AiGatewayEvent>.empty();
}

final class _SignedOutFirebaseAuth implements firebase_auth.FirebaseAuth {
  @override
  firebase_auth.User? get currentUser => null;

  @override
  Stream<firebase_auth.User?> authStateChanges() =>
      const Stream<firebase_auth.User?>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
