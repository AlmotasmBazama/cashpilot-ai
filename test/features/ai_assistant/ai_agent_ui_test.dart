import 'dart:async';

import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_readiness.dart';
import 'package:cashpilot_ai/core/firebase/firebase_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/general_assistant_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/pages/ai_assistant_screen.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/base_currency_provider.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/accessibility/acceptance_semantics.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'fresh agent conversation exposes one idle marker then exact turn counts',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final agent = _ControlledAgentOrchestrator();
      await _pumpAgent(tester, agent);

      Finder acceptanceMarkers() => find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.identifier?.startsWith(
                  'cashpilot_ai_acceptance_',
                ) ==
                true,
      );
      void expectAcceptanceState(String identifier) {
        expect(find.bySemanticsIdentifier(identifier), findsOneWidget);
        expect(acceptanceMarkers(), findsOneWidget);
        final markerSize = tester.getSize(acceptanceMarkers());
        expect(markerSize.width, greaterThan(0));
        expect(markerSize.height, greaterThan(0));
      }

      expect(cashPilotForceStopAcceptanceSemanticsEnabled, isTrue);
      expect(find.byKey(const Key('ai_agent_conversation')), findsNothing);
      expectAcceptanceState('cashpilot_ai_acceptance_idle_0');

      await _send(tester, 'Explain inflation');

      expectAcceptanceState('cashpilot_ai_acceptance_sending_1');

      agent.response.complete(
        const AiAgentResponse(
          kind: AiAgentResponseKind.answer,
          message: 'Inflation explained.',
        ),
      );
      await tester.pumpAndSettle();

      expectAcceptanceState('cashpilot_ai_acceptance_answer_complete_2');
      semantics.dispose();
    },
  );

  testWidgets(
    'non-release small-talk hook submits one fixed local turn atomically',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final agent = _FakeAgentOrchestrator();
      await _pumpAgent(tester, agent);

      final hook = find.bySemanticsIdentifier(
        'cashpilot_acceptance_ai_small_talk',
      );
      expect(hook, findsOneWidget);
      expect(
        find.text(cashPilotAppCheckAcceptanceSmallTalkPrompt),
        findsNothing,
      );

      final firstGesture = await tester.startGesture(tester.getCenter(hook));
      await tester.pump(const Duration(milliseconds: 800));
      await firstGesture.up();
      await tester.pumpAndSettle();

      expect(
        find.text(cashPilotAppCheckAcceptanceSmallTalkPrompt),
        findsOneWidget,
      );
      expect(
        find.text('I’m doing well, thanks! What can I help you with today?'),
        findsOneWidget,
      );
      expect(agent.respondCount, 0, reason: 'Small talk must remain local.');
      expect(
        find.bySemanticsIdentifier('cashpilot_ai_acceptance_answer_complete_2'),
        findsOneWidget,
      );

      final secondGesture = await tester.startGesture(tester.getCenter(hook));
      await tester.pump(const Duration(milliseconds: 800));
      await secondGesture.up();
      await tester.pumpAndSettle();
      expect(
        find.text(cashPilotAppCheckAcceptanceSmallTalkPrompt),
        findsOneWidget,
      );
      expect(agent.respondCount, 0);
      semantics.dispose();
    },
  );

  testWidgets('agent analysis, evidence, follow-up, and clear render', (
    tester,
  ) async {
    final agent = _FakeAgentOrchestrator();
    await _pumpAgent(tester, agent);

    await _send(tester, 'How much did I spend this month?');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_agent_conversation')), findsOneWidget);
    expect(find.text('Grounded answer'), findsOneWidget);
    expect(find.byKey(const Key('ai_agent_evidence_panel')), findsOneWidget);
    expect(find.textContaining('Current month evidence'), findsOneWidget);
    expect(find.text('Compare with last month'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai_assistant_clear_conversation')));
    await tester.pumpAndSettle();

    expect(agent.clearCount, 0);
    expect(
      find.byKey(const Key('ai_clear_conversation_confirm')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ai_clear_conversation_confirm')));
    await tester.pumpAndSettle();

    expect(agent.clearCount, 1);
    expect(find.byKey(const Key('ai_agent_conversation')), findsNothing);
  });

  testWidgets('agent UI fits narrow RTL and starts a new conversation', (
    tester,
  ) async {
    final agent = _FakeAgentOrchestrator();
    await _pumpAgent(
      tester,
      agent,
      locale: const Locale('ar'),
      size: const Size(320, 780),
    );

    await _send(tester, 'حلل وضعي المالي');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('ai_assistant_new_conversation')));
    await tester.pumpAndSettle();

    expect(agent.newCount, 1);
    expect(find.byKey(const Key('ai_agent_conversation')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new conversation detaches an active stream and ignores late chunks',
    (tester) async {
      final agent = _NonCooperativeStreamingAgentOrchestrator();
      addTearDown(agent.dispose);
      await _pumpAgent(tester, agent);

      await _send(tester, 'How much did I spend this month?');
      agent.emit('Partial old-conversation answer');
      await tester.pump();

      expect(find.byKey(const Key('ai_agent_loading')), findsOneWidget);
      expect(find.text('Partial old-conversation answer'), findsOneWidget);
      final newConversationButton = tester.widget<IconButton>(
        find.byKey(const Key('ai_assistant_new_conversation')),
      );
      expect(newConversationButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('ai_assistant_new_conversation')));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AiAssistantScreen)),
      );
      expect(agent.newCount, 1);
      expect(agent.cancelStarted, isTrue);
      expect(container.read(aiAgentControllerProvider).isSending, isFalse);
      expect(container.read(aiAgentControllerProvider).messages, isEmpty);
      expect(find.byKey(const Key('ai_agent_loading')), findsNothing);
      expect(find.byKey(const Key('ai_assistant_loading')), findsNothing);
      expect(find.text('Partial old-conversation answer'), findsNothing);

      agent.emit('Late detached answer');
      await tester.pump();

      expect(find.text('Late detached answer'), findsNothing);
      expect(container.read(aiAgentControllerProvider).isSending, isFalse);
      expect(container.read(aiAgentControllerProvider).messages, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('backgrounding cancels the stream and discards late chunks', (
    tester,
  ) async {
    final agent = _NonCooperativeStreamingAgentOrchestrator();
    addTearDown(agent.dispose);
    await _pumpAgent(tester, agent);

    await _send(tester, 'Explain inflation');
    agent.emit('Partial foreground answer');
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantScreen)),
    );
    expect(agent.cancelStarted, isTrue);
    expect(container.read(aiAgentControllerProvider).isSending, isFalse);
    expect(find.byKey(const Key('ai_agent_loading')), findsNothing);

    agent.emit('Late background answer');
    await tester.pump();

    expect(find.text('Late background answer'), findsNothing);
    expect(container.read(aiAgentControllerProvider).isSending, isFalse);
    expect(tester.takeException(), isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('navigating away cancels the stream and discards late chunks', (
    tester,
  ) async {
    final agent = _NonCooperativeStreamingAgentOrchestrator();
    addTearDown(agent.dispose);
    await _pumpAgent(tester, agent);

    await _send(tester, 'Explain inflation');
    agent.emit('Partial answer before navigation');
    await tester.pump();

    expect(find.byKey(const Key('ai_agent_loading')), findsOneWidget);
    final assistantContext = tester.element(find.byType(AiAssistantScreen));
    unawaited(
      Navigator.of(assistantContext).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Destination screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(agent.cancelStarted, isTrue);
    expect(find.byType(AiAssistantScreen), findsNothing);
    expect(find.text('Partial answer before navigation'), findsNothing);

    agent.emit('Late answer after navigation');
    await tester.pump();

    expect(find.text('Late answer after navigation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('previous turns remain visible after the next prompt', (
    tester,
  ) async {
    await _pumpAgent(tester, _FakeAgentOrchestrator());

    await _send(tester, 'First question');
    await tester.pumpAndSettle();
    await _send(tester, 'Second question');
    await tester.pumpAndSettle();

    expect(find.text('First question'), findsOneWidget);
    expect(find.text('Second question'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('streamed chunks replace one bubble and finalize once', () async {
    final agent = _FakeStreamingAgentOrchestrator();
    final container = ProviderContainer(
      overrides: [
        aiAgentAccountScopeProvider.overrideWithValue('test-account'),
        aiAgentOrchestratorProvider.overrideWithValue(agent),
        aiAgentFeatureFlagsProvider.overrideWithValue(
          const AiAgentFeatureFlags(
            agentEnabled: true,
            readOnlyToolsEnabled: true,
            draftToolsEnabled: true,
            conversationMemoryEnabled: true,
            complexPlanningEnabled: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      aiAgentControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final response = await container
        .read(aiAgentControllerProvider.notifier)
        .send(
          content: 'Explain inflation',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        );
    final state = container.read(aiAgentControllerProvider);

    expect(response?.message, 'Inflation is a broad rise in prices.');
    expect(state.messages, hasLength(2));
    expect(state.messages.last.role, AiAgentMessageRole.assistant);
    expect(state.messages.last.content, 'Inflation is a broad rise in prices.');
    expect(state.isSending, isFalse);
    expect(agent.streamCount, 1);
  });

  test('two quick sends start one request and one conversation turn', () async {
    final agent = _CountingControlledAgentOrchestrator();
    final container = ProviderContainer(
      overrides: [
        aiAgentAccountScopeProvider.overrideWithValue('test-account'),
        aiAgentOrchestratorProvider.overrideWithValue(agent),
        aiAgentFeatureFlagsProvider.overrideWithValue(_agentFlags),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      aiAgentControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(aiAgentControllerProvider.notifier);

    final first = controller.send(
      content: 'First remote request',
      locale: 'en',
      baseCurrencyCode: 'LYD',
    );
    final second = await controller.send(
      content: 'Second quick request',
      locale: 'en',
      baseCurrencyCode: 'LYD',
    );

    expect(second, isNull);
    expect(agent.calls, 1);
    expect(container.read(aiAgentControllerProvider).isSending, isTrue);
    expect(
      container
          .read(aiAgentControllerProvider)
          .messages
          .where((message) => message.role == AiAgentMessageRole.user),
      hasLength(1),
    );

    agent.response.complete(
      const AiAgentResponse(
        kind: AiAgentResponseKind.answer,
        message: 'One completed response',
      ),
    );
    expect((await first)?.message, 'One completed response');

    final state = container.read(aiAgentControllerProvider);
    expect(state.isSending, isFalse);
    expect(state.messages, hasLength(2));
    expect(agent.calls, 1);
  });

  testWidgets(
    'App Check token timeout terminates loading with a typed retryable state',
    (tester) async {
      final agent = _TimedOutReadinessStreamingAgentOrchestrator();
      addTearDown(agent.dispose);
      await _pumpAgent(tester, agent);

      await _send(tester, 'Wait for bounded device verification');
      expect(find.byKey(const Key('ai_agent_loading')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AiAssistantScreen)),
      );
      final state = container.read(aiAgentControllerProvider);
      expect(agent.gatewayCalls, 0);
      expect(state.isSending, isFalse);
      expect(state.unavailableReason, AiUnavailableReason.appCheckTimedOut);
      expect(find.byKey(const Key('ai_agent_loading')), findsNothing);
      expect(find.byKey(const Key('ai_agent_retry')), findsOneWidget);
      expect(
        find.text(
          'Device verification took too long. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    },
  );

  test('cancel while readiness waits prevents a gateway invocation', () async {
    final agent = _ReadinessWaitingStreamingAgentOrchestrator();
    addTearDown(agent.releaseReadiness);
    final container = _controllerContainer(agent);
    addTearDown(container.dispose);
    final subscription = container.listen(
      aiAgentControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(aiAgentControllerProvider.notifier);

    final pending = controller.send(
      content: 'Wait for verification',
      locale: 'en',
      baseCurrencyCode: 'LYD',
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(aiAgentControllerProvider).isSending, isTrue);

    controller.cancel();
    agent.releaseReadiness();

    expect(await pending.timeout(const Duration(milliseconds: 250)), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(agent.gatewayCalls, 0);
    expect(container.read(aiAgentControllerProvider).isSending, isFalse);
  });

  test(
    'new conversation while readiness waits discards the old request',
    () async {
      final agent = _ReadinessWaitingStreamingAgentOrchestrator();
      addTearDown(agent.releaseReadiness);
      final container = _controllerContainer(agent);
      addTearDown(container.dispose);
      final subscription = container.listen(
        aiAgentControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final controller = container.read(aiAgentControllerProvider.notifier);

      final pending = controller.send(
        content: 'Old conversation verification wait',
        locale: 'en',
        baseCurrencyCode: 'LYD',
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(aiAgentControllerProvider).isSending, isTrue);

      await controller.startNew();
      agent.releaseReadiness();

      expect(await pending.timeout(const Duration(milliseconds: 250)), isNull);
      await Future<void>.delayed(Duration.zero);
      final state = container.read(aiAgentControllerProvider);
      expect(agent.gatewayCalls, 0);
      expect(agent.newCount, 1);
      expect(state.isSending, isFalse);
      expect(state.messages, isEmpty);
    },
  );

  test('stop detaches a stream that never closes and clears loading', () async {
    final agent = _ControlledStreamingAgentOrchestrator();
    final container = ProviderContainer(
      overrides: [
        aiAgentAccountScopeProvider.overrideWithValue('test-account'),
        aiAgentOrchestratorProvider.overrideWithValue(agent),
        aiAgentFeatureFlagsProvider.overrideWithValue(
          const AiAgentFeatureFlags(
            agentEnabled: true,
            readOnlyToolsEnabled: true,
            draftToolsEnabled: true,
            conversationMemoryEnabled: true,
            complexPlanningEnabled: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      aiAgentControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final future = container
        .read(aiAgentControllerProvider.notifier)
        .send(
          content: 'Explain inflation',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        );
    agent.controller.add(
      const AiAgentResponse(
        kind: AiAgentResponseKind.answer,
        message: 'Partial',
        isPartial: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    container.read(aiAgentControllerProvider.notifier).cancel();

    expect(await future.timeout(const Duration(milliseconds: 250)), isNull);
    final state = container.read(aiAgentControllerProvider);
    expect(state.isSending, isFalse);
    expect(state.messages.last.content, 'Partial');
    expect(agent.controller.hasListener, isFalse);
    await agent.controller.close();
  });

  test(
    'stream failure retains the user message, releases send, and permits retry',
    () async {
      final agent = _FailOnceStreamingAgentOrchestrator();
      final activator = _CountingAppCheckActivator();
      final activationController = FirebaseAppCheckActivationController(
        activator: activator,
      );
      final readinessDiagnostics = <String>[];
      var tokenLoads = 0;
      final readiness = FirebaseAppCheckReadinessCoordinator(
        activationController: activationController,
        tokenLoader: ({required forceRefresh}) async {
          tokenLoads += 1;
          return 'test-token';
        },
        safeDiagnosticLog: readinessDiagnostics.add,
      );
      final container = ProviderContainer(
        overrides: [
          aiAgentAccountScopeProvider.overrideWithValue('test-account'),
          aiAgentOrchestratorProvider.overrideWithValue(agent),
          aiAgentFeatureFlagsProvider.overrideWithValue(_agentFlags),
          aiAppCheckActivationSnapshotProvider.overrideWithValue(
            const FirebaseAppCheckActivationState.unavailable(
              FirebaseAppCheckUnavailableReason.activationFailed,
            ),
          ),
          firebaseAppCheckActivationControllerProvider.overrideWithValue(
            activationController,
          ),
          firebaseAppCheckReadinessCoordinatorProvider.overrideWithValue(
            readiness,
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(readiness.dispose);
      addTearDown(activationController.dispose);

      final first = await container
          .read(aiAgentControllerProvider.notifier)
          .send(
            content: 'First request',
            locale: 'en',
            baseCurrencyCode: 'LYD',
          );
      var state = container.read(aiAgentControllerProvider);

      expect(first?.kind, AiAgentResponseKind.failure);
      expect(state.messages.first.content, 'First request');
      expect(state.isSending, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.unavailableReason, AiUnavailableReason.appCheckUnavailable);
      expect(state.retryable, isTrue);

      final retry = await container
          .read(aiAgentControllerProvider.notifier)
          .retry();
      state = container.read(aiAgentControllerProvider);

      expect(retry?.message, 'Retry succeeded');
      expect(state.isSending, isFalse);
      expect(state.errorMessage, isNull);
      expect(
        state.messages.where(
          (message) => message.role == AiAgentMessageRole.user,
        ),
        hasLength(1),
      );
      expect(state.messages.first.content, 'First request');
      expect(state.unavailableReason, isNull);
      expect(state.retryable, isFalse);
      expect(
        readinessDiagnostics.where(
          (event) =>
              event == 'firebase_app_check_readiness event=retry_requested',
        ),
        hasLength(1),
      );
      expect(tokenLoads, 0, reason: 'Retry must not prefetch a second token.');
      expect(activator.calls, 0);
    },
  );

  testWidgets(
    'confirmed App Check rejection never loops and retries only on a tap',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final agent = _RejectedAppCheckOrchestrator();
      await _pumpAgent(
        tester,
        agent,
        appCheckState: const FirebaseAppCheckActivationState.unavailable(
          FirebaseAppCheckUnavailableReason.webSiteKeyMissing,
        ),
      );

      await _send(tester, 'Explain compound interest');
      await tester.pumpAndSettle();

      expect(find.text('Explain compound interest'), findsOneWidget);
      expect(
        find.text(
          "This development build could not be verified on this device. Check the emulator's App Check registration.",
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ai_agent_retry')), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('cashpilot_acceptance_ai_retry'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(
          'cashpilot_ai_acceptance_failure_appcheck_rejected_2',
        ),
        findsOneWidget,
      );
      expect(agent.calls, 1);

      await tester.pump(const Duration(seconds: 1));
      expect(agent.calls, 1);

      await tester.tap(find.byKey(const Key('ai_agent_retry')));
      await tester.pumpAndSettle();

      expect(agent.calls, 2);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AiAssistantScreen)),
      );
      final state = container.read(aiAgentControllerProvider);
      expect(state.isSending, isFalse);
      expect(
        state.messages.where(
          (message) => message.role == AiAgentMessageRole.user,
        ),
        hasLength(1),
      );
      expect(
        state.messages.where(
          (message) => message.role == AiAgentMessageRole.assistant,
        ),
        hasLength(1),
      );
      semantics.dispose();
    },
  );

  testWidgets('offline failure has localized copy and an allowlisted marker', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpAgent(
      tester,
      const _TypedFailureOrchestrator(AiUnavailableReason.offline),
    );

    await _send(tester, 'Explain compound interest');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'You appear to be offline. Check your internet connection and try again.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('cashpilot_ai_acceptance_failure_offline_2'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('cashpilot_acceptance_ai_retry'),
      findsOneWidget,
    );
    expect(find.textContaining('Provider unavailable'), findsNothing);
    semantics.dispose();
  });

  testWidgets('retry button recovers without duplicating the user message', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final agent = _FailOnceStreamingAgentOrchestrator();
    await _pumpAgent(tester, agent);

    await _send(tester, 'Explain compound interest');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_agent_retry')), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('cashpilot_acceptance_ai_retry'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(
        'cashpilot_ai_acceptance_failure_appcheck_unavailable_2',
      ),
      findsOneWidget,
    );
    expect(find.text('Explain compound interest'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai_agent_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Retry succeeded'), findsOneWidget);
    expect(find.text('Explain compound interest'), findsOneWidget);
    expect(
      find.text('Device verification is getting ready. Try again in a moment.'),
      findsNothing,
    );
    expect(find.byKey(const Key('ai_agent_retry')), findsNothing);
    expect(agent.attempts, 2);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantScreen)),
    );
    final messages = container.read(aiAgentControllerProvider).messages;
    expect(messages, hasLength(2));
    expect(
      messages.where((message) => message.role == AiAgentMessageRole.user),
      hasLength(1),
    );
    expect(
      messages.where((message) => message.role == AiAgentMessageRole.assistant),
      hasLength(1),
    );
    semantics.dispose();
  });

  test(
    'same account refresh retains state and account change resets it',
    () async {
      final container = ProviderContainer(
        overrides: [
          aiAgentAccountScopeProvider.overrideWith(
            (ref) => ref.watch(_testAccountScopeProvider),
          ),
          aiAgentOrchestratorProvider.overrideWithValue(
            _FakeAgentOrchestrator(),
          ),
          aiAgentFeatureFlagsProvider.overrideWithValue(_agentFlags),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(aiAgentControllerProvider.notifier)
          .send(
            content: 'Retain this turn',
            locale: 'en',
            baseCurrencyCode: 'LYD',
          );
      expect(container.read(aiAgentControllerProvider).messages, isNotEmpty);

      container.read(_testAccountScopeProvider.notifier).state = 'account-a';
      expect(container.read(aiAgentControllerProvider).messages, isNotEmpty);

      container.read(_testAccountScopeProvider.notifier).state = 'account-b';
      expect(container.read(aiAgentControllerProvider).messages, isEmpty);
    },
  );

  test(
    'account change discards an in-flight response from the old scope',
    () async {
      final agent = _ControlledAgentOrchestrator();
      final container = ProviderContainer(
        overrides: [
          aiAgentAccountScopeProvider.overrideWith(
            (ref) => ref.watch(_testAccountScopeProvider),
          ),
          aiAgentOrchestratorProvider.overrideWithValue(agent),
          aiAgentFeatureFlagsProvider.overrideWithValue(_agentFlags),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        aiAgentControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final responseFuture = container
          .read(aiAgentControllerProvider.notifier)
          .send(
            content: 'Old account request',
            locale: 'en',
            baseCurrencyCode: 'LYD',
          );
      expect(container.read(aiAgentControllerProvider).isSending, isTrue);

      container.read(_testAccountScopeProvider.notifier).state = 'account-b';
      await Future<void>.delayed(Duration.zero);
      expect(container.read(aiAgentControllerProvider).messages, isEmpty);
      expect(container.read(aiAgentControllerProvider).isSending, isFalse);

      agent.response.complete(
        const AiAgentResponse(
          kind: AiAgentResponseKind.answer,
          message: 'Late old-account answer',
        ),
      );
      expect(await responseFuture, isNull);
      expect(container.read(aiAgentControllerProvider).messages, isEmpty);
      expect(container.read(aiAgentControllerProvider).lastResponse, isNull);
    },
  );
}

ProviderContainer _controllerContainer(AiAgentOrchestrator agent) {
  return ProviderContainer(
    overrides: [
      aiAgentAccountScopeProvider.overrideWithValue('test-account'),
      aiAgentOrchestratorProvider.overrideWithValue(agent),
      aiAgentFeatureFlagsProvider.overrideWithValue(_agentFlags),
    ],
  );
}

Future<void> _pumpAgent(
  WidgetTester tester,
  AiAgentOrchestrator agent, {
  Locale locale = const Locale('en'),
  Size size = const Size(420, 820),
  FirebaseAppCheckActivationState? appCheckState,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiAgentAccountScopeProvider.overrideWithValue('test-account'),
        aiAgentOrchestratorProvider.overrideWithValue(agent),
        aiAgentFeatureFlagsProvider.overrideWithValue(
          const AiAgentFeatureFlags(
            agentEnabled: true,
            readOnlyToolsEnabled: true,
            draftToolsEnabled: true,
            conversationMemoryEnabled: true,
            complexPlanningEnabled: false,
          ),
        ),
        if (appCheckState != null)
          aiAppCheckActivationSnapshotProvider.overrideWithValue(appCheckState),
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
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: CPTheme.dark(),
        home: const AiAssistantScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(const Key('ai_assistant_composer')), value);
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('ai_assistant_send_button')));
  await tester.tap(find.byKey(const Key('ai_assistant_send_button')));
  await tester.pump();
}

class _FakeAgentOrchestrator implements AiAgentOrchestrator {
  int clearCount = 0;
  int newCount = 0;
  int respondCount = 0;

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    respondCount += 1;
    return const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Grounded answer',
      evidence: <AiAgentEvidence>[
        AiAgentEvidence(
          toolName: 'get_dashboard_summary',
          summary: 'Current month evidence',
          period: '2026-07',
        ),
      ],
      executedToolNames: <String>['get_dashboard_summary'],
      followUpPrompts: <String>['Compare with last month'],
    );
  }

  @override
  Future<void> clearConversation() async {
    clearCount++;
  }

  @override
  Future<void> startNewConversation() async {
    newCount++;
  }
}

class _ControlledAgentOrchestrator implements AiAgentOrchestrator {
  final response = Completer<AiAgentResponse>();

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) => response.future;

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _CountingControlledAgentOrchestrator implements AiAgentOrchestrator {
  final response = Completer<AiAgentResponse>();
  var calls = 0;

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) {
    calls += 1;
    return response.future;
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _FakeStreamingAgentOrchestrator implements StreamingAiAgentOrchestrator {
  int streamCount = 0;

  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) async* {
    streamCount++;
    yield const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Inflation',
      isPartial: true,
    );
    yield const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Inflation is a broad rise',
      isPartial: true,
    );
    yield const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Inflation is a broad rise in prices.',
    );
  }

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    return const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Inflation is a broad rise in prices.',
    );
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _ControlledStreamingAgentOrchestrator
    implements StreamingAiAgentOrchestrator {
  final controller = StreamController<AiAgentResponse>();

  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) =>
      controller.stream;

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    return const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Unused',
    );
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _ReadinessWaitingStreamingAgentOrchestrator
    implements StreamingAiAgentOrchestrator {
  final _readiness = Completer<void>();
  var gatewayCalls = 0;
  var newCount = 0;

  void releaseReadiness() {
    if (!_readiness.isCompleted) _readiness.complete();
  }

  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) {
    var cancelled = false;
    return Stream<AiAgentResponse>.multi((events) {
      events.onCancel = () {
        cancelled = true;
      };
      unawaited(() async {
        await _readiness.future;
        if (cancelled) return;
        gatewayCalls += 1;
        events.add(
          const AiAgentResponse(
            kind: AiAgentResponseKind.answer,
            message: 'Late response must never be requested',
          ),
        );
        events.close();
      }());
    });
  }

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) {
    throw StateError('The streaming path must be used.');
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {
    newCount += 1;
  }
}

class _TimedOutReadinessStreamingAgentOrchestrator
    implements StreamingAiAgentOrchestrator {
  _TimedOutReadinessStreamingAgentOrchestrator()
    : _activation = FirebaseAppCheckActivationController(
        activator: _CountingAppCheckActivator(),
      ) {
    _readiness = FirebaseAppCheckReadinessCoordinator(
      activationController: _activation,
      tokenLoader: ({required forceRefresh}) => _token.future,
      tokenRetryDelays: const <Duration>[Duration.zero],
      tokenAttemptTimeout: const Duration(milliseconds: 5),
      totalTimeout: const Duration(milliseconds: 20),
    );
  }

  final Completer<String?> _token = Completer<String?>();
  final FirebaseAppCheckActivationController _activation;
  late final FirebaseAppCheckReadinessCoordinator _readiness;
  var gatewayCalls = 0;

  Future<void> dispose() async {
    _readiness.dispose();
    await _activation.dispose();
  }

  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) async* {
    try {
      await _readiness.getToken();
      gatewayCalls += 1;
      yield const AiAgentResponse(
        kind: AiAgentResponseKind.answer,
        message: 'This response must never be requested.',
      );
    } on FirebaseAppCheckReadinessException catch (failure) {
      final reason =
          failure.reason == FirebaseAppCheckReadinessFailureReason.timedOut
          ? AiUnavailableReason.appCheckTimedOut
          : AiUnavailableReason.appCheckUnavailable;
      yield AiAgentResponse(
        kind: AiAgentResponseKind.failure,
        turnKind: AssistantTurnKind.failure,
        message: GeneralAssistantPolicy.unavailableForReason(
          reason,
          locale: request.locale,
        ),
        warnings: <String>[reason.name],
        retryable: true,
      );
    }
  }

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) {
    throw StateError('The streaming path must be used.');
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _NonCooperativeStreamingAgentOrchestrator
    implements StreamingAiAgentOrchestrator {
  final cancellation = Completer<void>();
  late final StreamController<AiAgentResponse> controller =
      StreamController<AiAgentResponse>(
        sync: true,
        onCancel: () {
          cancelStarted = true;
          return cancellation.future;
        },
      );
  int newCount = 0;
  bool cancelStarted = false;

  void emit(String message) {
    controller.add(
      AiAgentResponse(
        kind: AiAgentResponseKind.answer,
        message: message,
        isPartial: true,
      ),
    );
  }

  Future<void> dispose() async {
    if (!cancellation.isCompleted) {
      cancellation.complete();
    }
    await controller.close();
  }

  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) =>
      controller.stream;

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    return const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Unused',
    );
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {
    newCount += 1;
  }
}

class _FailOnceStreamingAgentOrchestrator
    implements StreamingAiAgentOrchestrator {
  var attempts = 0;

  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) async* {
    attempts += 1;
    if (attempts == 1) {
      yield const AiAgentResponse(
        kind: AiAgentResponseKind.failure,
        turnKind: AssistantTurnKind.failure,
        message: 'Device verification is getting ready. Try again in a moment.',
        warnings: <String>['appCheckUnavailable'],
        retryable: true,
      );
      return;
    }
    yield const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Retry succeeded',
    );
  }

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    return const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'Retry succeeded',
    );
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _RejectedAppCheckOrchestrator implements AiAgentOrchestrator {
  var calls = 0;

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    calls += 1;
    return AiAgentResponse(
      kind: AiAgentResponseKind.failure,
      turnKind: AssistantTurnKind.failure,
      message: GeneralAssistantPolicy.unavailableForReason(
        AiUnavailableReason.appCheckRejected,
        locale: request.locale,
      ),
      warnings: const <String>['appCheckRejected'],
      retryable: true,
    );
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _TypedFailureOrchestrator implements AiAgentOrchestrator {
  const _TypedFailureOrchestrator(this.reason);

  final AiUnavailableReason reason;

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    return AiAgentResponse(
      kind: AiAgentResponseKind.failure,
      turnKind: AssistantTurnKind.failure,
      message: GeneralAssistantPolicy.unavailableForReason(
        reason,
        locale: request.locale,
      ),
      warnings: <String>[reason.name],
      retryable: isAiRequestFailureRetryable(reason),
    );
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _CountingAppCheckActivator implements FirebaseAppCheckActivator {
  int calls = 0;

  @override
  Future<void> activate() async {
    calls += 1;
  }
}

final _testAccountScopeProvider = StateProvider<String?>((_) => 'account-a');

const _agentFlags = AiAgentFeatureFlags(
  agentEnabled: true,
  readOnlyToolsEnabled: true,
  draftToolsEnabled: true,
  conversationMemoryEnabled: true,
  complexPlanningEnabled: false,
);
