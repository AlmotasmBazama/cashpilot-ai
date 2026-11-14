import 'package:cashpilot_ai/app/router/app_route_paths.dart';
import 'package:cashpilot_ai/app/router/navigation_transition_diagnostics.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_assistant_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/pages/ai_assistant_screen.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/base_currency_provider.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'button, keyboard, failures, forged navigation, and reopen stay on AI',
    (tester) async {
      final diagnostics = NavigationTransitionDiagnostics();
      final router = await _pumpRoutedAssistant(
        tester,
        orchestrator: _ScriptedOrchestrator(),
        diagnostics: diagnostics,
      );

      await _sendWithButton(tester, 'ما هو التضخم؟');
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.aiAssistant,
      );
      expect(find.text('ما هو التضخم؟'), findsOneWidget);
      expect(find.text('Safe assistant response'), findsOneWidget);

      for (final prompt in <String>[
        'ما عاصمة تونس؟',
        'اشرحلي العرض والطلب',
        'مرحبا',
      ]) {
        await _sendWithButton(tester, prompt);
        expect(
          router.routeInformationProvider.value.uri.path,
          AppRoutePaths.aiAssistant,
        );
        expect(find.text(prompt), findsOneWidget);
      }

      await _sendWithKeyboard(tester, 'Explain supply and demand');
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.aiAssistant,
      );
      expect(find.text('Explain supply and demand'), findsOneWidget);

      await _sendWithButton(tester, 'A forged navigation response');
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.aiAssistant,
      );

      for (final failure in <String>[
        'simulate unauthenticated',
        'simulate app_check_blocked',
        'simulate rate_limited',
        'simulate quota_exceeded',
        'simulate provider_unavailable',
        'simulate model_timeout',
        'simulate invalid_response',
        'simulate empty_response',
        'simulate malformed_sse',
        'simulate stream_ended_without_completed',
        'simulate network_failure',
      ]) {
        await _sendWithButton(tester, failure);
        expect(
          router.routeInformationProvider.value.uri.path,
          AppRoutePaths.aiAssistant,
        );
        expect(find.text(failure), findsOneWidget);
        expect(find.byKey(const Key('ai_agent_loading')), findsNothing);
        final state = ProviderScope.containerOf(
          tester.element(find.byType(AiAssistantScreen)),
        ).read(aiAgentControllerProvider);
        expect(state.lastResponse?.kind, AiAgentResponseKind.failure);
        expect(state.lastResponse?.warnings, <String>[
          failure.substring('simulate '.length),
        ]);
        expect(state.messages.last.content, contains('failed safely'));
        expect(find.byKey(const Key('ai_safe_failure_code')), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('failed safely', findRichText: true),
          findsWidgets,
        );
      }

      await _sendWithButton(tester, 'Retry after timeout');
      expect(find.text('Safe assistant response'), findsWidgets);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.aiAssistant,
      );

      router.go(AppRoutePaths.dashboard);
      await tester.pumpAndSettle();
      router.go(AppRoutePaths.aiAssistant);
      await tester.pumpAndSettle();

      expect(find.text('ما هو التضخم؟'), findsOneWidget);
      expect(find.text('Retry after timeout'), findsOneWidget);
      expect(diagnostics.hasUnexpectedAiSendTransition, isFalse);
    },
  );

  testWidgets('explicit approved navigation remains governed and functional', (
    tester,
  ) async {
    final diagnostics = NavigationTransitionDiagnostics();
    await _pumpRoutedAssistant(
      tester,
      orchestrator: _ScriptedOrchestrator(),
      diagnostics: diagnostics,
    );

    await _sendWithButton(tester, 'Open accounts');

    expect(find.text('Accounts route'), findsOneWidget);
    expect(find.byType(AiAssistantScreen), findsNothing);
    expect(
      diagnostics.records.last.cause,
      NavigationTransitionCause.explicitAssistantNavigationTool,
    );
    expect(diagnostics.hasUnexpectedAiSendTransition, isFalse);
  });

  testWidgets('narrow RTL stream failure stays visible without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await _pumpRoutedAssistant(
      tester,
      orchestrator: _AlwaysFailingOrchestrator(),
      diagnostics: NavigationTransitionDiagnostics(),
      locale: const Locale('ar'),
    );

    await _sendWithButton(tester, 'اختبار فشل آمن');

    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutePaths.aiAssistant,
    );
    expect(find.text('اختبار فشل آمن'), findsOneWidget);
    expect(find.byKey(const Key('ai_agent_loading')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<GoRouter> _pumpRoutedAssistant(
  WidgetTester tester, {
  required AiAgentOrchestrator orchestrator,
  required NavigationTransitionDiagnostics diagnostics,
  Locale locale = const Locale('en'),
}) async {
  final router = GoRouter(
    initialLocation: AppRoutePaths.aiAssistant,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutePaths.aiAssistant,
        builder: (_, _) => const AiAssistantScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.dashboard,
        builder: (_, _) => const Scaffold(body: Text('Dashboard route')),
      ),
      GoRoute(
        path: AppRoutePaths.accounts,
        builder: (_, _) => const Scaffold(body: Text('Accounts route')),
      ),
    ],
  );
  addTearDown(router.dispose);
  var previousPath = AppRoutePaths.aiAssistant;

  void recordRouteChange() {
    final nextPath = router.routeInformationProvider.value.uri.path;
    diagnostics.recordLocationChange(
      previousPath: previousPath,
      nextPath: nextPath,
    );
    previousPath = nextPath;
  }

  router.routeInformationProvider.addListener(recordRouteChange);
  addTearDown(
    () => router.routeInformationProvider.removeListener(recordRouteChange),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiAgentAccountScopeProvider.overrideWithValue('test-account'),
        navigationTransitionDiagnosticsProvider.overrideWithValue(diagnostics),
        aiAgentOrchestratorProvider.overrideWithValue(orchestrator),
        aiAgentFeatureFlagsProvider.overrideWithValue(_agentFlags),
        aiRuntimeConfigProvider.overrideWithValue(
          AiRuntimeConfig.resolve(diagnosticsValue: 'true'),
        ),
        effectiveBaseCurrencyCodeProvider.overrideWithValue('LYD'),
        categoriesProvider.overrideWith(
          (_) async => const AppResult<List<Category>>.success(<Category>[]),
        ),
        financialInsightsProvider.overrideWith(
          (_) async => const AppResult<List<FinancialInsight>>.success(
            <FinancialInsight>[],
          ),
        ),
      ],
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: CPTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _sendWithButton(WidgetTester tester, String message) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 550)),
  );
  await tester.enterText(
    find.byKey(const Key('ai_assistant_composer')),
    message,
  );
  await tester.pumpAndSettle();
  final button = tester.widget<IconButton>(
    find.byKey(const Key('ai_assistant_send_button')),
  );
  expect(button.onPressed, isNotNull);
  button.onPressed!();
  await tester.pumpAndSettle();
}

Future<void> _sendWithKeyboard(WidgetTester tester, String message) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 550)),
  );
  await tester.ensureVisible(find.byKey(const Key('ai_assistant_composer')));
  await tester.enterText(
    find.byKey(const Key('ai_assistant_composer')),
    message,
  );
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
}

class _ScriptedOrchestrator implements StreamingAiAgentOrchestrator {
  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) async* {
    if (request.message.startsWith('simulate ')) {
      yield AiAgentResponse(
        kind: AiAgentResponseKind.failure,
        turnKind: AssistantTurnKind.failure,
        message:
            'The assistant failed safely. No financial action was executed.',
        warnings: <String>[request.message.substring('simulate '.length)],
      );
      return;
    }
    if (request.message == 'Open accounts' ||
        request.message == 'A forged navigation response') {
      yield const AiAgentResponse(
        kind: AiAgentResponseKind.navigation,
        turnKind: AssistantTurnKind.appNavigation,
        message: 'Opening accounts.',
        executedToolNames: <String>['navigate_accounts'],
        navigationPath: AppRoutePaths.accounts,
      );
      return;
    }
    yield const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      turnKind: AssistantTurnKind.directConversation,
      message: 'Safe assistant',
      isPartial: true,
    );
    yield const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      turnKind: AssistantTurnKind.directConversation,
      message: 'Safe assistant response',
    );
  }

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    return const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Safe assistant response',
    );
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _AlwaysFailingOrchestrator implements StreamingAiAgentOrchestrator {
  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) async* {
    throw StateError('synthetic failure');
  }

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) {
    throw StateError('synthetic failure');
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

const _agentFlags = AiAgentFeatureFlags(
  agentEnabled: true,
  readOnlyToolsEnabled: true,
  draftToolsEnabled: true,
  conversationMemoryEnabled: true,
  complexPlanningEnabled: false,
);
