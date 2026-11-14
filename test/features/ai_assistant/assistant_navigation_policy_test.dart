import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/financial_agent_tools.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/governed_ai_tool_registry.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/assistant_navigation_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_intent_router.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

void main() {
  const router = AiIntentRouter();

  test('normal general chat cannot be classified as navigation', () {
    final route = router.route('What is inflation?');

    expect(route.target, AssistantRouteTarget.generalConversation);
    expect(route.navigationToolId, isNull);
  });

  test('explicit known destination selects one approved local tool', () {
    final route = router.route('Open accounts');

    expect(route.target, AssistantRouteTarget.appNavigation);
    expect(route.navigationToolId, 'navigate_accounts');
  });

  test(
    'destination mention without an explicit navigation verb is rejected',
    () {
      final route = router.route('What are accounts?');

      expect(route.target, isNot(AssistantRouteTarget.appNavigation));
    },
  );

  test(
    'approved navigation executes locally without a model gateway',
    () async {
      final orchestrator = AiAgentOrchestratorImpl(
        toolRegistry: GovernedAiToolRegistry(
          tools: FinancialAgentToolCatalog(_NoopFinancialGateway()).build(),
          permissionPolicy: const DefaultAiToolPermissionPolicy(),
        ),
        memoryStore: InMemoryAiAgentMemoryStore(),
        memoryCompactor: const DefaultAiAgentMemoryCompactor(),
        modelRouter: const DefaultAiAgentModelRouter(),
        contextSanitizer: const DefaultAiAgentContextSanitizer(),
        responseComposer: const DefaultAiAgentResponseComposer(),
        modelGateway: null,
        providerEgressGuardFactory: (_) => testAiProviderEgressGuard,
      );

      final response = await orchestrator.respond(
        const AiAgentRequest(
          message: 'Open accounts',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        ),
      );

      expect(response.kind, AiAgentResponseKind.navigation);
      expect(response.turnKind, AssistantTurnKind.appNavigation);
      expect(response.executedToolNames, <String>['navigate_accounts']);
      expect(
        response.navigationPath,
        AssistantNavigationPolicy.approvedToolPaths['navigate_accounts'],
      );
    },
  );
}

class _NoopFinancialGateway implements FinancialAgentDataGateway {
  @override
  Future<Never> executeReadTool(
    String name,
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
  ) {
    throw StateError('A financial read tool must not run in this test.');
  }
}
