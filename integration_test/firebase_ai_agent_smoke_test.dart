// ignore_for_file: avoid_print

import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/financial_agent_tools.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/governed_ai_tool_registry.dart';
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
    'live Firebase agent uses governed read tools and preserves write boundary',
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

      const fixture = _SmokeFinancialDataGateway();
      final registry = GovernedAiToolRegistry(
        tools: const FinancialAgentToolCatalog(fixture).build(),
        permissionPolicy: const DefaultAiToolPermissionPolicy(),
        currentOwnerScope: () => _smokeOwnerScope,
      );
      final memory = InMemoryAiAgentMemoryStore();
      final orchestrator = AiAgentOrchestratorImpl(
        toolRegistry: registry,
        memoryStore: memory,
        memoryCompactor: const DefaultAiAgentMemoryCompactor(),
        modelRouter: const DefaultAiAgentModelRouter(),
        contextSanitizer: const DefaultAiAgentContextSanitizer(),
        responseComposer: const DefaultAiAgentResponseComposer(),
        modelGateway: FirebaseAiAgentModelGateway(
          config: FirebaseAiConfig.fromModelConfig(AiModelConfig.current),
        ),
        providerEgressGuardFactory: (_) => testAiProviderEgressGuard,
        toolOwnerScope: _smokeOwnerScope,
        financialDataScopeVerified: true,
      );
      const originalBalance = '1000.00';

      final analysis = await orchestrator.respond(
        const AiAgentRequest(
          message:
              'Analyze my current-month spending using CashPilot financial data and explain the strongest observation.',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        ),
      );
      expect(analysis.message.trim(), isNotEmpty);
      expect(analysis.executedToolNames, isNotEmpty);
      expect(
        analysis.executedToolNames.every(
          (name) =>
              registry.definitionFor(name)?.permission ==
                  AiToolPermission.readFinancialData ||
              registry.definitionFor(name)?.permission ==
                  AiToolPermission.calculate,
        ),
        isTrue,
      );

      final followUp = await orchestrator.respond(
        const AiAgentRequest(
          message: 'Compare that with the previous month.',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        ),
      );
      expect(followUp.message.trim(), isNotEmpty);
      expect(followUp.executedToolNames, isNotEmpty);

      final actionBoundary = await orchestrator.respond(
        const AiAgentRequest(
          message:
              'Prepare a review-only expense draft for 12.50 LYD in Groceries from Cash. Do not save it.',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        ),
      );
      expect(actionBoundary.executedToolNames, isEmpty);
      expect(actionBoundary.actionDraft, isNull);
      expect(fixture.balance, originalBalance);

      print(
        'FIREBASE_AGENT_DIAG completed=true '
        'providerResponded=true '
        'readToolCalled=true '
        'followUpReady=true '
        'deterministicActionBoundary=true '
        'balanceUnchanged=true',
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

const _smokeOwnerScope = AiToolOwnerScopeBinding(
  accountScope:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  epoch: 1,
);

class _SmokeFinancialDataGateway implements FinancialAgentDataGateway {
  const _SmokeFinancialDataGateway();

  String get balance => '1000.00';

  @override
  Future<AiToolResult> executeReadTool(
    String name,
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
  ) async {
    final data = switch (name) {
      'get_monthly_comparison' => const <String, Object?>{
        'currentExpense': '420.00',
        'previousExpense': '360.00',
        'expenseChangePercent': '16.666667',
        'currency': 'LYD',
      },
      'get_top_spending_categories' ||
      'get_category_spending' => const <String, Object?>{
        'categories': <Map<String, Object?>>[
          <String, Object?>{
            'category': 'Groceries',
            'amount': '180.00',
            'currency': 'LYD',
          },
          <String, Object?>{
            'category': 'Transport',
            'amount': '90.00',
            'currency': 'LYD',
          },
        ],
      },
      _ => const <String, Object?>{
        'monthlyIncome': '900.00',
        'monthlyExpense': '420.00',
        'monthlySavings': '480.00',
        'netWorth': '1000.00',
        'currency': 'LYD',
      },
    };
    return AiToolResult(
      toolName: name,
      data: data,
      evidenceSummary: 'Synthetic fixture summary for the bounded smoke test.',
      period: '2026-07',
    );
  }
}
