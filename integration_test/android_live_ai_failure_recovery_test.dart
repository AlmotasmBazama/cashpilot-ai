// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/agent/firebase_ai_agent_model_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/firebase_ai_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/pages/ai_assistant_screen.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/settings/application/base_currency_provider.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/ai_provider_egress_test_guard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android controller recovers after a runner-controlled network outage',
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
      print('ANDROID_LIVE_FAILURE_RECOVERY appCheckAvailable=true');

      final gateway = _CountingGateway(
        FirebaseAiAgentModelGateway(
          config: FirebaseAiConfig.fromModelConfig(AiModelConfig.current),
        ),
      );
      final orchestrator = _GatedNonStreamingOrchestrator(
        AiAgentOrchestratorImpl(
          toolRegistry: const _EmptyToolRegistry(),
          memoryStore: InMemoryAiAgentMemoryStore(),
          memoryCompactor: const DefaultAiAgentMemoryCompactor(),
          modelRouter: const DefaultAiAgentModelRouter(),
          contextSanitizer: const DefaultAiAgentContextSanitizer(),
          responseComposer: const DefaultAiAgentResponseComposer(),
          modelGateway: gateway,
          providerEgressGuardFactory: (_) => testAiProviderEgressGuard,
        ),
      );
      final container = await _pumpLiveAgent(tester, orchestrator);
      final controller = container.read(aiAgentControllerProvider.notifier);

      print('ANDROID_LIVE_NETWORK_REQUEST state=offline');
      // The runner applies the Android network controls out-of-process. Let
      // them settle, then let the real Firebase request prove the outage. An
      // in-process HTTP probe can reuse DNS/connection state and incorrectly
      // report reachability after airplane mode is enabled.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );

      await tester.enterText(
        find.byKey(const Key('ai_assistant_composer')),
        'Explain compound interest simply',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('ai_assistant_send_button')),
      );
      await tester.tap(find.byKey(const Key('ai_assistant_send_button')));
      await tester.pump();
      await tester.runAsync(
        () => orchestrator.firstRequestStarted.timeout(
          const Duration(seconds: 5),
        ),
      );

      expect(container.read(aiAgentControllerProvider).isSending, isTrue);
      expect(find.byKey(const Key('ai_agent_loading')), findsOneWidget);
      final duplicateResponse = await controller.send(
        content: 'This request must be rejected while another is active',
        locale: 'en',
        baseCurrencyCode: 'LYD',
      );
      expect(duplicateResponse, isNull);
      print(
        'ANDROID_LIVE_FAILURE_RECOVERY loadingStarted=true '
        'doubleSendBlocked=true',
      );
      orchestrator.releaseFirstRequest();

      await _pumpUntil(
        tester,
        () {
          final state = container.read(aiAgentControllerProvider);
          return !state.isSending && state.lastResponse != null;
        },
        attempts: 900,
        phase: 'offline_request_completed',
      );
      final observedFailure = container.read(aiAgentControllerProvider);
      print(
        'ANDROID_LIVE_FAILURE_RECOVERY firstRequestDone=true '
        'kind=${observedFailure.lastResponse?.kind.name ?? "none"} '
        'reason=${observedFailure.unavailableReason?.name ?? "none"} '
        'retryable=${observedFailure.retryable}',
      );
      await _pumpUntil(
        tester,
        () => find.byKey(const Key('ai_agent_retry')).evaluate().isNotEmpty,
        phase: 'retry_visible',
      );

      final failedState = container.read(aiAgentControllerProvider);
      expect(failedState.lastResponse?.kind, AiAgentResponseKind.failure);
      expect(failedState.retryable, isTrue);
      expect(const <AiUnavailableReason>{
        AiUnavailableReason.offline,
        AiUnavailableReason.gatewayUnreachable,
        AiUnavailableReason.providerTimedOut,
        // A forced outage can prevent App Check refresh before the model
        // request begins. Preserve that exact transient reason instead of
        // relabeling an attestation-stage failure as a transport failure.
        AiUnavailableReason.appCheckUnavailable,
      }, contains(failedState.unavailableReason));
      expect(failedState.isSending, isFalse);
      expect(find.byKey(const Key('ai_agent_loading')), findsNothing);
      expect(
        failedState.messages.where(
          (message) => message.role == AiAgentMessageRole.user,
        ),
        hasLength(1),
      );
      expect(gateway.startSessionCalls, 1);
      print(
        'ANDROID_LIVE_FAILURE_RECOVERY failureReason='
        '${failedState.unavailableReason!.name} loadingEnded=true '
        'retryable=true doubleSendBlocked=true',
      );

      print('ANDROID_LIVE_NETWORK_REQUEST state=online');
      await tester.runAsync(() => _waitForNetworkState(online: true));
      print('ANDROID_LIVE_FAILURE_RECOVERY networkOnlineObserved=true');

      await tester.tap(find.byKey(const Key('ai_agent_retry')));
      await tester.pump();
      expect(container.read(aiAgentControllerProvider).isSending, isTrue);
      await _pumpUntil(
        tester,
        () {
          final state = container.read(aiAgentControllerProvider);
          return !state.isSending &&
              state.lastResponse?.kind == AiAgentResponseKind.answer;
        },
        attempts: 1200,
        phase: 'retry_answered',
      );

      final recoveredState = container.read(aiAgentControllerProvider);
      expect(recoveredState.lastResponse?.message.trim(), isNotEmpty);
      expect(recoveredState.retryable, isFalse);
      expect(recoveredState.unavailableReason, isNull);
      expect(
        recoveredState.messages.where(
          (message) => message.role == AiAgentMessageRole.user,
        ),
        hasLength(1),
      );
      expect(
        recoveredState.messages.where(
          (message) => message.role == AiAgentMessageRole.assistant,
        ),
        hasLength(1),
      );
      expect(find.byKey(const Key('ai_agent_loading')), findsNothing);
      expect(find.byKey(const Key('ai_agent_retry')), findsNothing);
      expect(find.byType(AiAssistantScreen), findsOneWidget);
      expect(gateway.startSessionCalls, 2);

      await tester.tap(find.byKey(const Key('ai_assistant_new_conversation')));
      await _pumpUntil(
        tester,
        () => container.read(aiAgentControllerProvider).messages.isEmpty,
        phase: 'new_conversation_cleared',
      );
      final clearedState = container.read(aiAgentControllerProvider);
      expect(clearedState.isSending, isFalse);
      expect(clearedState.lastResponse, isNull);
      print(
        'ANDROID_LIVE_FAILURE_RECOVERY retrySucceeded=true '
        'firebaseSessions=2 singleUserTurn=true newConversationCleared=true',
      );
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

Future<ProviderContainer> _pumpLiveAgent(
  WidgetTester tester,
  AiAgentOrchestrator orchestrator,
) async {
  await tester.binding.setSurfaceSize(const Size(420, 820));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiAgentAccountScopeProvider.overrideWithValue(
          'android-live-ai-recovery',
        ),
        aiAgentOrchestratorProvider.overrideWithValue(orchestrator),
        aiAgentFeatureFlagsProvider.overrideWithValue(
          const AiAgentFeatureFlags(
            agentEnabled: true,
            readOnlyToolsEnabled: true,
            draftToolsEnabled: true,
            conversationMemoryEnabled: true,
            complexPlanningEnabled: false,
          ),
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
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: CPTheme.dark(),
        home: const AiAssistantScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(AiAssistantScreen));
  return ProviderScope.containerOf(context);
}

Future<void> _waitForNetworkState({required bool online}) async {
  for (var attempt = 0; attempt < 120; attempt += 1) {
    if (await _firebaseEndpointIsReachable() == online) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail('The runner did not apply the requested Android network state.');
}

Future<bool> _firebaseEndpointIsReachable() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client
        .getUrl(Uri.https('firebaseappcheck.googleapis.com', '/'))
        .timeout(const Duration(seconds: 2));
    final response = await request.close().timeout(const Duration(seconds: 2));
    await response.drain<void>().timeout(const Duration(seconds: 2));
    return true;
  } on Object {
    return false;
  } finally {
    client.close(force: true);
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int attempts = 100,
  required String phase,
}) async {
  for (var attempt = 0; attempt < attempts && !condition(); attempt += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  if (!condition()) {
    print(
      'ANDROID_LIVE_FAILURE_RECOVERY_TIMEOUT phase=$phase attempts=$attempts',
    );
  }
  expect(condition(), isTrue);
}

final class _GatedNonStreamingOrchestrator implements AiAgentOrchestrator {
  _GatedNonStreamingOrchestrator(this._delegate);

  final AiAgentOrchestrator _delegate;
  final Completer<void> _firstRequestStarted = Completer<void>();
  final Completer<void> _releaseFirstRequest = Completer<void>();
  var _requestCount = 0;

  Future<void> get firstRequestStarted => _firstRequestStarted.future;

  void releaseFirstRequest() {
    if (!_releaseFirstRequest.isCompleted) _releaseFirstRequest.complete();
  }

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    _requestCount += 1;
    if (_requestCount == 1) {
      if (!_firstRequestStarted.isCompleted) _firstRequestStarted.complete();
      await _releaseFirstRequest.future;
    }
    return _delegate.respond(request);
  }

  @override
  Future<void> clearConversation() => _delegate.clearConversation();

  @override
  Future<void> startNewConversation() => _delegate.startNewConversation();
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
    startSessionCalls += 1;
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
