import 'package:cashpilot_ai/features/ai_assistant/data/agent/firebase_ai_agent_model_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_gateway_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/firebase_ai_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/routed_ai_agent_model_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart';
import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

void main() {
  test(
    'Firebase primary and fallback seed the same bounded safe history once',
    () async {
      final histories = <String, List<firebase_ai.Content>>{};
      final gateway = FirebaseAiAgentModelGateway(
        config: _config(),
        chatFactory:
            ({
              required modelId,
              required request,
              required tools,
              required history,
              required maxTurns,
            }) {
              histories[modelId] = history;
              return const _UnusedChat();
            },
      );
      final prior =
          List<AiAgentMessage>.generate(
            6,
            (index) => AiAgentMessage(
              role: index.isEven
                  ? AiAgentMessageRole.user
                  : AiAgentMessageRole.assistant,
              content: 'safe turn $index',
              createdAt: DateTime.utc(2026),
            ),
          )..add(
            AiAgentMessage(
              role: AiAgentMessageRole.user,
              content: 'latest question',
              createdAt: DateTime.utc(2026),
            ),
          );

      await gateway.startSession(
        request: AiAgentModelRequest(
          userMessage: 'latest question',
          systemInstruction: 'safe instruction',
          memoryContext: 'PRIVATE_CONTEXT_MUST_NOT_ENTER_GENERAL_HISTORY',
          taskClass: ModelTask.generalConversation,
          conversationHistory: prior,
        ),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );

      expect(
        histories.keys,
        containsAll(<String>['primary-model', 'fallback-model']),
      );
      for (final history in histories.values) {
        expect(history, hasLength(4));
        expect(_texts(history), <String>[
          'safe turn 2',
          'safe turn 3',
          'safe turn 4',
          'safe turn 5',
        ]);
        expect(_texts(history), isNot(contains('latest question')));
        expect(history.map((content) => content.role), <String?>[
          'user',
          'model',
          'user',
          'model',
        ]);
        expect(
          history.toString(),
          isNot(contains('PRIVATE_CONTEXT_MUST_NOT_ENTER_GENERAL_HISTORY')),
        );
        expect(
          () {
            history.add(firebase_ai.Content.text('SDK history append'));
            history.removeLast();
          },
          returnsNormally,
          reason: 'Firebase ChatSession mutates the supplied history list.',
        );
      }
    },
  );

  test(
    'Firebase never seeds general history into a financial request',
    () async {
      late List<firebase_ai.Content> captured;
      final gateway = FirebaseAiAgentModelGateway(
        config: _config(),
        chatFactory:
            ({
              required modelId,
              required request,
              required tools,
              required history,
              required maxTurns,
            }) {
              captured = history;
              return const _UnusedChat();
            },
      );

      await gateway.startSession(
        request: AiAgentModelRequest(
          userMessage: 'Explain my spending',
          systemInstruction: 'financial instruction',
          memoryContext: 'bounded financial facts',
          taskClass: ModelTask.personalFinancialAnalysis,
          conversationHistory: <AiAgentMessage>[
            AiAgentMessage(
              role: AiAgentMessageRole.user,
              content: 'PRIVATE PRIOR TURN',
              createdAt: DateTime.utc(2026),
            ),
          ],
        ),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );

      expect(captured, isEmpty);
    },
  );

  test('Groq startup fallback seeds Firebase with prior safe turns', () async {
    late List<firebase_ai.Content> captured;
    final firebase = FirebaseAiAgentModelGateway(
      config: _config(),
      chatFactory:
          ({
            required modelId,
            required request,
            required tools,
            required history,
            required maxTurns,
          }) {
            captured = history;
            return const _UnusedChat();
          },
    );
    final router = RoutedAiAgentModelGateway(
      flags: AiGatewayFeatureFlags.resolve(
        groqGatewayValue: 'true',
        generalChatValue: 'true',
        firebaseTextFallbackValue: 'true',
      ),
      firebaseGateway: firebase,
      groqGateway: const _ThrowingStartGateway(),
      groqConfigured: true,
    );

    await router.startSession(
      request: AiAgentModelRequest(
        userMessage: 'latest',
        systemInstruction: 'safe',
        memoryContext: '',
        taskClass: ModelTask.generalConversation,
        conversationHistory: <AiAgentMessage>[
          AiAgentMessage(
            role: AiAgentMessageRole.user,
            content: 'prior question',
            createdAt: DateTime.utc(2026),
          ),
          AiAgentMessage(
            role: AiAgentMessageRole.assistant,
            content: 'prior answer',
            createdAt: DateTime.utc(2026),
          ),
        ],
      ),
      tools: const <AiToolDefinition>[],
      egressGuard: testAiProviderEgressGuard,
    );

    expect(_texts(captured), <String>['prior question', 'prior answer']);
  });

  for (final entry in <(String, FirebaseException, AiGatewayFailureCode)>[
    (
      'raw Firebase Auth rejection',
      FirebaseException(plugin: 'firebase_auth', code: 'user-token-expired'),
      AiGatewayFailureCode.unauthenticated,
    ),
    (
      'raw Firebase App Check rejection',
      FirebaseException(plugin: 'firebase_app_check', code: 'invalid-token'),
      AiGatewayFailureCode.appCheckRejected,
    ),
    (
      'raw Firebase network rejection',
      FirebaseException(plugin: 'firebase_ai', code: 'unavailable'),
      AiGatewayFailureCode.networkFailure,
    ),
  ]) {
    test('${entry.$1} is mapped to a typed safe gateway failure', () async {
      final gateway = FirebaseAiAgentModelGateway(
        config: _singleModelConfig(),
        chatFactory:
            ({
              required modelId,
              required request,
              required tools,
              required history,
              required maxTurns,
            }) => _ThrowingChat(entry.$2),
      );
      final session = await gateway.startSession(
        request: const AiAgentModelRequest(
          userMessage: 'harmless request',
          systemInstruction: 'safe',
          memoryContext: '',
          taskClass: ModelTask.generalConversation,
        ),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );

      await expectLater(
        session.sendInitial(),
        throwsA(
          isA<AiGatewayException>()
              .having((failure) => failure.code, 'code', entry.$3)
              .having(
                (failure) => failure.safeMessage,
                'safeMessage',
                isNot(contains(entry.$2.code)),
              ),
        ),
      );
    });
  }

  test(
    'Firebase AI App Check 403 maps to typed rejection without raw diagnostics',
    () async {
      final diagnostics = <String>[];
      final gateway = FirebaseAiAgentModelGateway(
        config: _singleModelConfig(),
        safeDiagnosticLog: diagnostics.add,
        chatFactory:
            ({
              required modelId,
              required request,
              required tools,
              required history,
              required maxTurns,
            }) => _ThrowingChat(
              firebase_ai.FirebaseAIException(
                'Server Error [403]: App Check attestation rejected SECRET',
              ),
            ),
      );
      final session = await gateway.startSession(
        request: const AiAgentModelRequest(
          userMessage: 'harmless request',
          systemInstruction: 'safe',
          memoryContext: '',
          taskClass: ModelTask.generalConversation,
        ),
        tools: const <AiToolDefinition>[],
        egressGuard: testAiProviderEgressGuard,
      );

      await expectLater(
        session.sendInitial(),
        throwsA(
          isA<AiGatewayException>().having(
            (failure) => failure.code,
            'code',
            AiGatewayFailureCode.appCheckRejected,
          ),
        ),
      );
      expect(
        diagnostics,
        contains(
          'AI runtime provider=firebase request=failed code=appCheckRejected',
        ),
      );
      expect(diagnostics.join(' '), isNot(contains('SECRET')));
      expect(diagnostics.join(' '), isNot(contains('403')));
    },
  );

  test('generic Firebase AI 403 remains provider unavailable', () async {
    final gateway = FirebaseAiAgentModelGateway(
      config: _singleModelConfig(),
      chatFactory:
          ({
            required modelId,
            required request,
            required tools,
            required history,
            required maxTurns,
          }) => _ThrowingChat(
            firebase_ai.FirebaseAIException(
              'Server Error [403]: permission denied for model access',
            ),
          ),
    );
    final session = await gateway.startSession(
      request: const AiAgentModelRequest(
        userMessage: 'harmless request',
        systemInstruction: 'safe',
        memoryContext: '',
        taskClass: ModelTask.generalConversation,
      ),
      tools: const <AiToolDefinition>[],
      egressGuard: testAiProviderEgressGuard,
    );

    await expectLater(
      session.sendInitial(),
      throwsA(
        isA<AiGatewayException>().having(
          (failure) => failure.code,
          'code',
          AiGatewayFailureCode.providerUnavailable,
        ),
      ),
    );
  });

  test('depleted Developer API prepayment maps to typed quota', () async {
    final gateway = FirebaseAiAgentModelGateway(
      config: _singleModelConfig(),
      chatFactory:
          ({
            required modelId,
            required request,
            required tools,
            required history,
            required maxTurns,
          }) => _ThrowingChat(
            firebase_ai.ServerException(
              'Your prepayment credits are depleted.',
            ),
          ),
    );
    final session = await gateway.startSession(
      request: const AiAgentModelRequest(
        userMessage: 'harmless request',
        systemInstruction: 'safe',
        memoryContext: '',
        taskClass: ModelTask.generalConversation,
      ),
      tools: const <AiToolDefinition>[],
      egressGuard: testAiProviderEgressGuard,
    );

    await expectLater(
      session.sendInitial(),
      throwsA(
        isA<AiGatewayException>().having(
          (failure) => failure.code,
          'code',
          AiGatewayFailureCode.providerQuotaExceeded,
        ),
      ),
    );
  });
}

FirebaseAiConfig _config() => FirebaseAiConfig.fromModelConfig(
  AiModelConfig.resolve(
    modelName: 'fallback-model',
    generalConversationModel: 'primary-model',
  ),
);

FirebaseAiConfig _singleModelConfig() => FirebaseAiConfig.fromModelConfig(
  AiModelConfig.resolve(
    modelName: 'single-model',
    generalConversationModel: 'single-model',
  ),
);

List<String> _texts(List<firebase_ai.Content> history) => history
    .map((content) => (content.parts.single as firebase_ai.TextPart).text)
    .toList(growable: false);

final class _UnusedChat implements FirebaseAiAgentChat {
  const _UnusedChat();

  @override
  Future<firebase_ai.GenerateContentResponse> sendMessage(
    firebase_ai.Content content,
  ) => throw UnimplementedError();

  @override
  Stream<firebase_ai.GenerateContentResponse> sendMessageStream(
    firebase_ai.Content content,
  ) => throw UnimplementedError();
}

final class _ThrowingChat implements FirebaseAiAgentChat {
  const _ThrowingChat(this.error);

  final Object error;

  @override
  Future<firebase_ai.GenerateContentResponse> sendMessage(
    firebase_ai.Content content,
  ) => Future<firebase_ai.GenerateContentResponse>.error(error);

  @override
  Stream<firebase_ai.GenerateContentResponse> sendMessageStream(
    firebase_ai.Content content,
  ) => Stream<firebase_ai.GenerateContentResponse>.error(error);
}

final class _ThrowingStartGateway implements AiAgentModelGateway {
  const _ThrowingStartGateway();

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async => throw const AiGatewayException(
    code: AiGatewayFailureCode.gatewayUnavailable,
    safeMessage: 'Synthetic transient gateway failure.',
  );
}
