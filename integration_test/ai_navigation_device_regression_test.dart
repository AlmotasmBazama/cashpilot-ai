import 'dart:async';

import 'package:cashpilot_ai/app/app.dart';
import 'package:cashpilot_ai/app/router/app_route_paths.dart';
import 'package:cashpilot_ai/app/router/app_router.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/storage/hive_box_names.dart';
import 'package:cashpilot_ai/features/accounts/application/providers/accounts_providers.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/pages/ai_assistant_screen.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/budgets/application/providers/budgets_providers.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/data_deletion/application/account_deletion_startup_recovery_coordinator.dart';
import 'package:cashpilot_ai/features/data_deletion/application/data_deletion_providers.dart';
import 'package:cashpilot_ai/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:cashpilot_ai/features/goals/application/providers/goals_providers.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/transactions/application/providers/transactions_providers.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'same-user Auth refresh during a device UI stream keeps the AI route',
    (tester) async {
      await Hive.initFlutter();
      if (!Hive.isBoxOpen(HiveBoxNames.settings)) {
        await Hive.openBox<dynamic>(HiveBoxNames.settings);
      }
      addTearDown(Hive.close);

      final authEvents = StreamController<AuthUser?>();
      addTearDown(authEvents.close);
      final orchestrator = _RefreshDuringSendOrchestrator(
        onSend: () => authEvents.add(
          _signedInUser.copyWith(lastLogin: DateTime.now().toUtc()),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((_) => authEvents.stream),
            onboardingCompletedProvider.overrideWith((_) => true),
            aiAgentOrchestratorProvider.overrideWithValue(orchestrator),
            aiAgentFeatureFlagsProvider.overrideWithValue(_agentFlags),
            ..._emptyFinanceOverrides(),
          ],
          child: const CashPilotApp(),
        ),
      );
      authEvents.add(_signedInUser);
      await _pumpUntil(
        tester,
        () => find.byType(DashboardScreen).evaluate().isNotEmpty,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardScreen)),
      );
      final router = container.read(appRouterProvider)
        ..go(AppRoutePaths.aiAssistant);
      await _pumpUntil(
        tester,
        () => find.byType(AiAssistantScreen).evaluate().isNotEmpty,
      );

      await _send(tester, 'ما هو التضخم؟');

      expect(find.byType(AiAssistantScreen), findsOneWidget);
      expect(
        GoRouterState.of(
          tester.element(find.byType(AiAssistantScreen)),
        ).uri.path,
        AppRoutePaths.aiAssistant,
      );
      expect(find.text('ما هو التضخم؟'), findsOneWidget);
      expect(find.text('Device stream completed safely.'), findsOneWidget);
      expect(orchestrator.authRefreshCount, 1);

      router.go(AppRoutePaths.dashboard);
      await tester.pumpAndSettle();
      router.go(AppRoutePaths.aiAssistant);
      await _pumpUntil(
        tester,
        () => find.byType(AiAssistantScreen).evaluate().isNotEmpty,
      );

      expect(find.text('ما هو التضخم؟'), findsOneWidget);
      expect(find.text('Device stream completed safely.'), findsOneWidget);

      final newConversation = tester.widget<IconButton>(
        find.byKey(const Key('ai_assistant_new_conversation')),
      );
      expect(newConversation.onPressed, isNotNull);
      newConversation.onPressed!();
      await _pumpUntil(
        tester,
        () => container.read(aiAgentControllerProvider).messages.isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _send(WidgetTester tester, String prompt) async {
  await tester.enterText(
    find.byKey(const Key('ai_assistant_composer')),
    prompt,
  );
  await tester.pump();
  final send = tester.widget<IconButton>(
    find.byKey(const Key('ai_assistant_send_button')),
  );
  expect(send.onPressed, isNotNull);
  send.onPressed!();
  await _pumpUntil(
    tester,
    () => find.text('Device stream completed safely.').evaluate().isNotEmpty,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int attempts = 150,
}) async {
  for (var attempt = 0; attempt < attempts && !condition(); attempt += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }
  expect(condition(), isTrue);
}

class _RefreshDuringSendOrchestrator implements StreamingAiAgentOrchestrator {
  _RefreshDuringSendOrchestrator({required this.onSend});

  final VoidCallback onSend;
  var authRefreshCount = 0;

  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) async* {
    authRefreshCount += 1;
    onSend();
    yield const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Device stream started.',
      isPartial: true,
    );
    yield const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Device stream completed safely.',
    );
  }

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    return const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Device stream completed safely.',
    );
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

List<Override> _emptyFinanceOverrides() {
  return [
    accountDeletionStartupRecoveryProvider.overrideWith(
      (_) async => const AccountDeletionStartupRecoveryReport(
        completed: 0,
        retained: 0,
        rejected: 0,
      ),
    ),
    accountsProvider.overrideWith(
      (_) async => const AppResult<List<Account>>.success(<Account>[]),
    ),
    categoriesProvider.overrideWith(
      (_) async => const AppResult<List<Category>>.success(<Category>[]),
    ),
    transactionsProvider.overrideWith(
      (_) async => const AppResult<List<Transaction>>.success(<Transaction>[]),
    ),
    budgetSummaryProvider.overrideWith(
      (_) async => const AppResult<BudgetSummary>.success(
        BudgetSummary(
          activeCount: 0,
          warningCount: 0,
          exceededCount: 0,
          topWarning: null,
        ),
      ),
    ),
    goalSummaryProvider.overrideWith(
      (_) async => const AppResult<GoalSummary>.success(
        GoalSummary(
          activeCount: 0,
          savedTotals: <GoalCurrencyTotal>[],
          nearestTargetDate: null,
          completedCount: 0,
        ),
      ),
    ),
    financialInsightsProvider.overrideWith(
      (_) async =>
          const AppResult<List<FinancialInsight>>.success(<FinancialInsight>[]),
    ),
  ];
}

const _agentFlags = AiAgentFeatureFlags(
  agentEnabled: true,
  readOnlyToolsEnabled: true,
  draftToolsEnabled: true,
  conversationMemoryEnabled: true,
  complexPlanningEnabled: false,
);

const _signedInUser = AuthUser(
  uid: 'synthetic-device-account',
  email: 'device@example.invalid',
  displayName: 'Device Test',
  emailVerified: true,
  isAnonymous: false,
  currency: 'LYD',
  language: 'en',
  country: 'LY',
  timezone: 'Africa/Tripoli',
);
