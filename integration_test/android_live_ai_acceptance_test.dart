// ignore_for_file: avoid_print

import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/firebase/firebase_ai_backend.dart';
import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/agent/firebase_ai_agent_model_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/firebase_ai_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_intent_router.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/ai_provider_egress_test_guard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android accepts two local and three live Firebase AI prompts',
    (tester) async {
      if (AiRuntimeConfig.current.providerMode !=
          AiProviderMode.firebaseGemini) {
        fail('The live Firebase provider is not selected.');
      }
      await const DefaultFirebaseInitializer().initialize();
      final appCheckState = await defaultFirebaseAppCheckActivationController
          .activate();
      expect(
        appCheckState.isAvailable,
        isTrue,
        reason: 'App Check activation failed: ${appCheckState.safeCode}',
      );
      final appCheckToken = await FirebaseAppCheck.instance.getToken(true);
      expect(appCheckToken?.trim(), isNotEmpty);
      print('ANDROID_LIVE_APP_CHECK tokenIssued=true');
      final backend = FirebaseAiBackendConfig.current;
      expect(backend.backend, FirebaseAiBackend.vertexAi);
      expect(backend.vertexLocation, 'global');
      print(
        'ANDROID_LIVE_AI_CONFIG provider=firebase '
        'backend=${backend.backend.name} '
        'location=${backend.vertexLocation} '
        'model=${AiModelConfig.current.generalConversationModel}',
      );

      final gateway = _CountingGateway(
        FirebaseAiAgentModelGateway(
          config: FirebaseAiConfig.fromModelConfig(AiModelConfig.current),
        ),
      );
      final orchestrator = AiAgentOrchestratorImpl(
        toolRegistry: const _EmptyToolRegistry(),
        memoryStore: InMemoryAiAgentMemoryStore(),
        memoryCompactor: const DefaultAiAgentMemoryCompactor(),
        modelRouter: const DefaultAiAgentModelRouter(),
        contextSanitizer: const DefaultAiAgentContextSanitizer(),
        responseComposer: const DefaultAiAgentResponseComposer(),
        modelGateway: gateway,
        providerEgressGuardFactory: (_) => testAiProviderEgressGuard,
      );

      var remoteIndex = 0;
      for (final request in const <AiAgentRequest>[
        AiAgentRequest(message: 'مرحبا', locale: 'ar', baseCurrencyCode: 'LYD'),
        AiAgentRequest(
          message: 'شن تقدر تدير؟',
          locale: 'ar',
          baseCurrencyCode: 'LYD',
        ),
      ]) {
        final response = await orchestrator.respond(request);
        expect(response.kind, AiAgentResponseKind.answer);
        expect(response.message.trim(), isNotEmpty);
        expect(response.executedToolNames, isEmpty);
      }
      expect(
        gateway.startSessionCalls,
        0,
        reason: 'Deterministic local prompts must not reach Firebase AI.',
      );

      final firstContentMs = <int>[];
      final completionMs = <int>[];
      var streamedPrompts = 0;
      for (final request in const <AiAgentRequest>[
        AiAgentRequest(
          message: 'اشرح لي الفرق بين الدخل والمصروف في جملتين',
          locale: 'ar',
          baseCurrencyCode: 'LYD',
        ),
        AiAgentRequest(
          message: 'Explain compound interest simply',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        ),
        AiAgentRequest(
          message: 'Give me three simple saving habits',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        ),
      ]) {
        final route = const AiIntentRouter().route(request.message).target;
        expect(route, AssistantRouteTarget.generalConversation);
        final stopwatch = Stopwatch()..start();
        AiAgentResponse? response;
        int? firstContentElapsedMs;
        var partialCount = 0;
        print(
          'ANDROID_LIVE_AI_REQUEST index=$remoteIndex provider=firebase '
          'route=${route.name} requestStarted=true streamSubscribedMs=0',
        );
        await for (final update in orchestrator.respondStream(request)) {
          if (update.message.trim().isNotEmpty) {
            firstContentElapsedMs ??= stopwatch.elapsedMilliseconds;
          }
          if (update.isPartial) {
            partialCount++;
          } else {
            response = update;
          }
        }
        stopwatch.stop();
        expect(response, isNotNull);
        final completed = response!;
        final firstContent = firstContentElapsedMs;
        expect(firstContent, isNotNull);
        firstContentMs.add(firstContent!);
        completionMs.add(stopwatch.elapsedMilliseconds);
        if (partialCount > 0) streamedPrompts++;
        if (completed.kind != AiAgentResponseKind.answer) {
          print(
            'ANDROID_LIVE_AI_FAILURE index=$remoteIndex '
            'kind=${completed.kind.name} turn=${completed.turnKind.name} '
            'warnings=${completed.warnings.join(",")} '
            'retryable=${completed.retryable}',
          );
        }
        expect(completed.kind, AiAgentResponseKind.answer);
        expect(completed.message.trim(), isNotEmpty);
        expect(completed.executedToolNames, isEmpty);
        expect(completed.actionDraft, isNull);
        print(
          'ANDROID_LIVE_AI_RESULT index=$remoteIndex provider=firebase '
          'route=${route.name} partials=$partialCount '
          'firstContentMs=$firstContent completionMs=${stopwatch.elapsedMilliseconds} '
          'completed=true',
        );
        remoteIndex++;
      }

      expect(gateway.startSessionCalls, 3);
      expect(streamedPrompts, greaterThan(0));
      print(
        'ANDROID_LIVE_AI_ACCEPTANCE completed=true localPrompts=2 '
        'remotePrompts=3 firebaseSessions=${gateway.startSessionCalls} '
        'streamedPrompts=$streamedPrompts '
        'firstContentMs=${firstContentMs.join(",")} '
        'completionMs=${completionMs.join(",")}',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

final class _CountingGateway implements AiAgentModelGateway {
  _CountingGateway(this._delegate);

  final AiAgentModelGateway _delegate;
  int startSessionCalls = 0;

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) {
    startSessionCalls++;
    return _delegate.startSession(
      request: request,
      tools: tools,
      egressGuard: egressGuard,
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
  ) {
    throw StateError('No financial tool may run in live general chat.');
  }
}
