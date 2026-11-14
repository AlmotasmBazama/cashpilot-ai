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
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_gateway_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/firebase_gateway_token_provider.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/groq_ai_agent_model_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/groq_conversation_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/groq_gateway_client.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/groq_gateway_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/pages/ai_assistant_screen.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/settings/application/base_currency_provider.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'support/android_live_groq_app_check.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android retries one Groq user turn after a controlled network outage',
    (tester) async {
      expect(
        AiRuntimeConfig.current.resolvedConversationProviderPreference,
        AiConversationProviderPreference.groq,
      );
      final flags = AiGatewayFeatureFlags.current;
      expect(flags.aiGroqGatewayEnabled, isTrue);
      expect(flags.aiGroqGeneralChatEnabled, isTrue);
      expect(flags.aiGroqToolSelectionEnabled, isFalse);
      expect(flags.aiFirebaseTextFallbackEnabled, isFalse);
      expect(AiGatewayRuntimeConfig.current.isConfigured, isTrue);

      await const DefaultFirebaseInitializer().initialize();
      final appCheckState = await defaultFirebaseAppCheckActivationController
          .activate();
      expect(
        appCheckState.isAvailable,
        isTrue,
        reason: 'App Check activation failed: ${appCheckState.safeCode}',
      );

      final auth = FirebaseAuth.instance;
      final appCheck = FirebaseAppCheck.instance;
      final synthetic = await _createSyntheticUser(auth);
      final httpClient = http.Client();
      var deleted = false;
      var signedOut = false;
      try {
        await awaitRegisteredAndroidAppCheckToken(appCheck);
        await _waitForGatewayNetworkState(online: true);
        print(
          'ANDROID_GROQ_LIVE_RECOVERY_AUTH synthetic=true '
          'appCheckAvailable=true tokenIssued=true gatewayReachable=true',
        );

        final egressGuard = _LiveUserEgressGuard(
          auth: auth,
          expectedUser: synthetic.user,
        );
        final gateway = _CountingModelGateway(
          GroqAiAgentModelGateway(
            gateway: GroqConversationGateway(
              GroqGatewayDataSource(
                GroqGatewayClient(
                  config: AiGatewayRuntimeConfig.current,
                  tokenProvider: FirebaseAiGatewayTokenProvider(
                    auth: auth,
                    appCheck: appCheck,
                  ),
                  httpClient: httpClient,
                ),
              ),
            ),
            clientVersion: AiGatewayRuntimeConfig.current.clientVersion,
            toolSelectionEnabled: false,
            financialExplanationEnabled: true,
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
            providerEgressGuardFactory: (_) => egressGuard,
          ),
        );
        final container = await _pumpLiveAgent(tester, orchestrator);
        final controller = container.read(aiAgentControllerProvider.notifier);

        print('ANDROID_GROQ_LIVE_NETWORK_REQUEST state=offline');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 2)),
        );

        await tester.enterText(
          find.byKey(const Key('ai_assistant_composer')),
          'Explain compound interest simply.',
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
          content: 'This duplicate request must be blocked.',
          locale: 'en',
          baseCurrencyCode: 'LYD',
        );
        expect(duplicateResponse, isNull);
        print(
          'ANDROID_GROQ_LIVE_RECOVERY loadingStarted=true '
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
          'ANDROID_GROQ_LIVE_RECOVERY firstRequestFailed=true '
          'reason=${failedState.unavailableReason!.name} '
          'retryable=true loadingEnded=true singleUserTurn=true',
        );

        print('ANDROID_GROQ_LIVE_NETWORK_REQUEST state=online');
        await tester.runAsync(() => _waitForGatewayNetworkState(online: true));
        print(
          'ANDROID_GROQ_LIVE_RECOVERY networkOnlineObserved=true '
          'retryStarted=true',
        );

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

        await tester.tap(
          find.byKey(const Key('ai_assistant_new_conversation')),
        );
        await _pumpUntil(
          tester,
          () => container.read(aiAgentControllerProvider).messages.isEmpty,
          phase: 'new_conversation_cleared',
        );
        final clearedState = container.read(aiAgentControllerProvider);
        expect(clearedState.isSending, isFalse);
        expect(clearedState.lastResponse, isNull);
        print(
          'ANDROID_GROQ_LIVE_RECOVERY completed=true retrySucceeded=true '
          'groqSessions=2 singleUserTurn=true newConversationCleared=true',
        );
      } finally {
        httpClient.close();
        deleted = await _deleteSyntheticUser(auth, synthetic);
        try {
          await auth.signOut();
          signedOut = auth.currentUser == null;
        } on Object {
          signedOut = false;
        }
        print(
          'ANDROID_GROQ_LIVE_RECOVERY_AUTH_CLEANUP attempted=true '
          'deleted=$deleted signedOut=$signedOut',
        );
      }
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
        aiAgentAccountScopeProvider.overrideWithValue('android-groq-recovery'),
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

Future<void> _waitForGatewayNetworkState({required bool online}) async {
  for (var attempt = 0; attempt < 120; attempt += 1) {
    if (await _gatewayEndpointIsReachable() == online) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail('The runner did not apply the requested Android network state.');
}

Future<bool> _gatewayEndpointIsReachable() async {
  final baseUri = AiGatewayRuntimeConfig.current.baseUri;
  if (baseUri == null) {
    return false;
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client
        .getUrl(baseUri.resolve('/health'))
        .timeout(const Duration(seconds: 2));
    final response = await request.close().timeout(const Duration(seconds: 2));
    await response.drain<void>().timeout(const Duration(seconds: 2));
    return response.statusCode == HttpStatus.ok;
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
    print('ANDROID_GROQ_LIVE_RECOVERY_TIMEOUT phase=$phase attempts=$attempts');
  }
  expect(condition(), isTrue);
}

final class _SyntheticUser {
  const _SyntheticUser({
    required this.user,
    required this.email,
    required this.password,
  });

  final User user;
  final String email;
  final String password;
}

Future<_SyntheticUser> _createSyntheticUser(FirebaseAuth auth) async {
  if (auth.currentUser != null) {
    await auth.signOut();
  }
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final email = 'cashpilot-groq-recovery-$stamp@example.com';
  final password = 'Cp!${stamp}Az9';
  final credential = await auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  final user = credential.user;
  if (user == null) {
    throw StateError('Synthetic Firebase Auth user was not created.');
  }
  return _SyntheticUser(user: user, email: email, password: password);
}

Future<bool> _deleteSyntheticUser(
  FirebaseAuth auth,
  _SyntheticUser synthetic,
) async {
  try {
    var cleanupUser = auth.currentUser;
    if (cleanupUser?.uid != synthetic.user.uid) {
      await auth.signInWithEmailAndPassword(
        email: synthetic.email,
        password: synthetic.password,
      );
      cleanupUser = auth.currentUser;
    }
    if (cleanupUser?.uid != synthetic.user.uid) {
      return false;
    }
    await cleanupUser!.delete();
    return true;
  } on Object {
    return false;
  }
}

final class _LiveUserEgressGuard implements AiProviderEgressGuard {
  _LiveUserEgressGuard({required this.auth, required User expectedUser})
    : expectedAuthSession = AuthSessionIdentity(
        uid: expectedUser.uid,
        isAnonymous: expectedUser.isAnonymous,
        authSessionGeneration: 1,
        tenantId: expectedUser.tenantId,
      );

  final FirebaseAuth auth;

  @override
  final AuthSessionIdentity expectedAuthSession;

  @override
  void assertActive() {
    final current = auth.currentUser;
    if (current == null ||
        current.uid != expectedAuthSession.uid ||
        current.isAnonymous != expectedAuthSession.isAnonymous ||
        current.tenantId != expectedAuthSession.tenantId) {
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

final class _GatedNonStreamingOrchestrator implements AiAgentOrchestrator {
  _GatedNonStreamingOrchestrator(this._delegate);

  final AiAgentOrchestrator _delegate;
  final Completer<void> _firstRequestStarted = Completer<void>();
  final Completer<void> _releaseFirstRequest = Completer<void>();
  var _requestCount = 0;

  Future<void> get firstRequestStarted => _firstRequestStarted.future;

  void releaseFirstRequest() {
    if (!_releaseFirstRequest.isCompleted) {
      _releaseFirstRequest.complete();
    }
  }

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    _requestCount += 1;
    if (_requestCount == 1) {
      if (!_firstRequestStarted.isCompleted) {
        _firstRequestStarted.complete();
      }
      await _releaseFirstRequest.future;
    }
    return _delegate.respond(request);
  }

  @override
  Future<void> clearConversation() => _delegate.clearConversation();

  @override
  Future<void> startNewConversation() => _delegate.startNewConversation();
}

final class _CountingModelGateway implements AiAgentModelGateway {
  _CountingModelGateway(this._delegate);

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
