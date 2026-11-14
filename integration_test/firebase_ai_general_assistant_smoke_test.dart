// ignore_for_file: avoid_print

import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/agent/firebase_ai_agent_model_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/firebase_ai_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/ai_provider_egress_test_guard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live general assistant streams and current knowledge is Search-grounded',
    (tester) async {
      if (AiRuntimeConfig.current.providerMode !=
          AiProviderMode.firebaseGemini) {
        fail('The live Firebase Gemini provider is not selected.');
      }
      if (firebaseAppCheckDebugToken.isEmpty) {
        fail('A registered App Check debug token was not supplied.');
      }
      await const DefaultFirebaseInitializer().initialize();
      final appCheckState = await defaultFirebaseAppCheckActivationController
          .activate();
      expect(
        appCheckState.isAvailable,
        isTrue,
        reason: 'App Check activation failed: ${appCheckState.safeCode}',
      );

      final modelGateway = FirebaseAiAgentModelGateway(
        config: FirebaseAiConfig.fromModelConfig(AiModelConfig.current),
      );
      final orchestrator = AiAgentOrchestratorImpl(
        toolRegistry: const _EmptyToolRegistry(),
        memoryStore: InMemoryAiAgentMemoryStore(),
        memoryCompactor: const DefaultAiAgentMemoryCompactor(),
        modelRouter: const DefaultAiAgentModelRouter(),
        contextSanitizer: const DefaultAiAgentContextSanitizer(),
        responseComposer: const DefaultAiAgentResponseComposer(),
        modelGateway: modelGateway,
        providerEgressGuardFactory: (_) => testAiProviderEgressGuard,
      );

      var partialCount = 0;
      AiAgentResponse? general;
      await for (final update in orchestrator.respondStream(
        const AiAgentRequest(
          message: 'ما هو التضخم؟',
          locale: 'ar',
          baseCurrencyCode: 'LYD',
        ),
      )) {
        if (update.isPartial) {
          partialCount++;
        } else {
          general = update;
        }
      }
      expect(general, isNotNull);
      expect(general!.kind, AiAgentResponseKind.answer);
      expect(general.message.trim(), isNotEmpty);
      expect(general.executedToolNames, isEmpty);
      expect(partialCount, greaterThan(0));

      AiAgentResponse? current;
      await for (final update in orchestrator.respondStream(
        const AiAgentRequest(
          message: 'كيف وضع الاقتصاد الليبي حالياً؟',
          locale: 'ar',
          baseCurrencyCode: 'LYD',
        ),
      )) {
        if (!update.isPartial) {
          current = update;
        }
      }
      expect(current, isNotNull);
      if (current!.turnKind != AssistantTurnKind.groundedKnowledge) {
        print(
          'FIREBASE_GROUNDING_METADATA_DIAG '
          'sources=${current.sources.length} '
          'entryPoint=${current.searchEntryPointRenderedContent?.isNotEmpty == true} '
          'warnings=${current.warnings.join(",")}',
        );
      }
      expect(current.turnKind, AssistantTurnKind.groundedKnowledge);
      expect(current.sources, isNotEmpty);
      expect(current.searchEntryPointRenderedContent, isNotEmpty);
      expect(current.responseDate, isNotNull);
      expect(current.executedToolNames, isEmpty);

      print(
        'FIREBASE_GENERAL_ASSISTANT_DIAG completed=true '
        'streamed=true generalAnswered=true grounded=true '
        'sourcesPresent=true financeToolsCalled=false',
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

class _EmptyToolRegistry implements AiToolRegistry {
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
    throw StateError('No financial tools may run in this smoke test.');
  }
}
