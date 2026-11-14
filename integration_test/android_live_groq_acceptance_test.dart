// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
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
import 'package:cashpilot_ai/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_intent_router.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'support/android_live_groq_app_check.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android streams live Arabic and English answers through Groq gateway',
    (tester) async {
      expect(
        AiRuntimeConfig.current.resolvedConversationProviderPreference,
        AiConversationProviderPreference.groq,
      );
      final flags = AiGatewayFeatureFlags.current;
      expect(flags.aiGroqGatewayEnabled, isTrue);
      expect(flags.aiGroqGeneralChatEnabled, isTrue);
      expect(flags.aiGroqFinancialExplanationEnabled, isTrue);
      expect(flags.aiGroqToolSelectionEnabled, isFalse);
      expect(flags.aiGroqArabicSpecialistEnabled, isTrue);
      expect(flags.aiCurrentWebEnabled, isFalse);
      expect(flags.aiFirebaseTextFallbackEnabled, isFalse);
      final runtime = AiGatewayRuntimeConfig.current;
      expect(runtime.isConfigured, isTrue);

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
      final synthetic = await _createSyntheticUser(auth, label: 'acceptance');
      var deleted = false;
      var signedOut = false;
      final httpClient = http.Client();
      try {
        await awaitRegisteredAndroidAppCheckToken(appCheck);
        final freshIdToken = await synthetic.user.getIdToken(true);
        expect(freshIdToken?.trim(), isNotEmpty);
        final appCheckPreflight = await _verifyAppCheckNegativePreflight(
          httpClient: httpClient,
          baseUri: runtime.baseUri!,
          clientVersion: runtime.clientVersion,
          firebaseIdToken: freshIdToken!,
        );
        for (final result in appCheckPreflight) {
          print(
            'ANDROID_GROQ_LIVE_APPCHECK_NEGATIVE '
            'variant=${result.variant} status=${result.status} '
            'code=${result.code} rejected=${result.rejected}',
          );
          expect(result.status, 401);
          expect(result.code, 'gatewayAppCheckRequired');
          expect(result.rejected, isTrue);
        }
        print(
          'ANDROID_GROQ_LIVE_AUTH synthetic=true '
          'appCheckAvailable=true tokenIssued=true '
          'negativePreflight=2',
        );

        final egressGuard = _LiveUserEgressGuard(
          auth: auth,
          expectedUser: synthetic.user,
        );
        final streamMetrics = _StreamMetricsConversationGateway(
          GroqConversationGateway(
            GroqGatewayDataSource(
              GroqGatewayClient(
                config: runtime,
                tokenProvider: FirebaseAiGatewayTokenProvider(
                  auth: auth,
                  appCheck: appCheck,
                ),
                httpClient: httpClient,
              ),
            ),
          ),
        );
        final health = await streamMetrics.healthCheck();
        expect(health.reachable, isTrue);
        print(
          'ANDROID_GROQ_LIVE_HEALTH reachable=true provider=groq '
          'gatewayConfigured=true',
        );

        final modelGateway = _CountingModelGateway(
          GroqAiAgentModelGateway(
            gateway: streamMetrics,
            clientVersion: runtime.clientVersion,
            toolSelectionEnabled: false,
            financialExplanationEnabled: true,
          ),
        );
        final orchestrator = AiAgentOrchestratorImpl(
          toolRegistry: const _EmptyToolRegistry(),
          memoryStore: InMemoryAiAgentMemoryStore(),
          memoryCompactor: const DefaultAiAgentMemoryCompactor(),
          modelRouter: const DefaultAiAgentModelRouter(),
          contextSanitizer: const DefaultAiAgentContextSanitizer(),
          responseComposer: const DefaultAiAgentResponseComposer(),
          modelGateway: modelGateway,
          providerEgressGuardFactory: (_) => egressGuard,
        );

        final firstChunkMs = <int>[];
        final completionMs = <int>[];
        final rawChunkCounts = <int>[];
        final responseByteCounts = <int>[];
        var streamedPrompts = 0;
        var index = 0;
        for (final liveCase in const <_LivePrompt>[
          _LivePrompt(
            locale: 'ar',
            message: 'اشرح لي معنى الفائدة المركبة بطريقة بسيطة.',
          ),
          _LivePrompt(
            locale: 'en',
            message: 'Explain compound interest simply in two sentences.',
          ),
        ]) {
          final route = const AiIntentRouter().route(liveCase.message).target;
          expect(route, AssistantRouteTarget.generalConversation);
          final modelSessionsBefore = modelGateway.startSessionCalls;
          final generalStreamsBefore = streamMetrics.generalStreamCalls;
          final chunksBefore = streamMetrics.textDeltaEvents;
          final bytesBefore = streamMetrics.textDeltaBytes;
          final startedBefore = streamMetrics.startedEvents;
          final completedBefore = streamMetrics.completedEvents;
          final failuresBefore = streamMetrics.failureEvents;
          final stopwatch = Stopwatch()..start();
          AiAgentResponse? response;
          int? firstContentElapsedMs;
          var partialCount = 0;
          print(
            'ANDROID_GROQ_LIVE_REQUEST index=$index locale=${liveCase.locale} '
            'provider=groq route=${route.name} streamSubscribed=true',
          );
          await for (final update in orchestrator.respondStream(
            AiAgentRequest(
              message: liveCase.message,
              locale: liveCase.locale,
              baseCurrencyCode: 'LYD',
            ),
          )) {
            if (update.message.trim().isNotEmpty) {
              firstContentElapsedMs ??= stopwatch.elapsedMilliseconds;
            }
            if (update.isPartial) {
              partialCount += 1;
            } else {
              response = update;
            }
          }
          stopwatch.stop();

          final completedResponse = response;
          final rawChunks = streamMetrics.textDeltaEvents - chunksBefore;
          final responseBytes = streamMetrics.textDeltaBytes - bytesBefore;
          final startedDelta = streamMetrics.startedEvents - startedBefore;
          final completedDelta =
              streamMetrics.completedEvents - completedBefore;
          final failureDelta = streamMetrics.failureEvents - failuresBefore;
          final firstWarning = completedResponse?.warnings.isNotEmpty == true
              ? completedResponse!.warnings.first
              : null;
          final safeWarningCode =
              firstWarning != null &&
                  RegExp(r'^[A-Za-z0-9_]+$').hasMatch(firstWarning)
              ? firstWarning
              : 'unknown';
          final retryable = completedResponse?.retryable;
          print(
            'ANDROID_GROQ_LIVE_PROMPT_DIAGNOSTIC index=$index '
            'locale=${liveCase.locale} '
            'kind=${completedResponse?.kind.name ?? "none"} '
            'retryable=${retryable ?? "unknown"} '
            'warningCode=$safeWarningCode '
            'modelSessionsDelta='
            '${modelGateway.startSessionCalls - modelSessionsBefore} '
            'generalStreamsDelta='
            '${streamMetrics.generalStreamCalls - generalStreamsBefore} '
            'startedDelta=$startedDelta textDeltaDelta=$rawChunks '
            'completedDelta=$completedDelta failureDelta=$failureDelta',
          );
          expect(completedResponse, isNotNull);
          expect(completedResponse!.kind, AiAgentResponseKind.answer);
          expect(completedResponse.message.trim(), isNotEmpty);
          expect(completedResponse.executedToolNames, isEmpty);
          expect(completedResponse.actionDraft, isNull);
          final firstContent = firstContentElapsedMs;
          expect(firstContent, isNotNull);
          expect(rawChunks, greaterThan(0));
          expect(responseBytes, greaterThan(0));
          expect(startedDelta, 1);
          expect(completedDelta, 1);
          expect(failureDelta, 0);
          expect(partialCount, greaterThan(0));
          expect(
            firstContent!,
            lessThanOrEqualTo(stopwatch.elapsedMilliseconds),
          );

          firstChunkMs.add(firstContent);
          completionMs.add(stopwatch.elapsedMilliseconds);
          rawChunkCounts.add(rawChunks);
          responseByteCounts.add(responseBytes);
          streamedPrompts += 1;
          print(
            'ANDROID_GROQ_LIVE_RESULT index=$index locale=${liveCase.locale} '
            'provider=groq rawChunks=$rawChunks partials=$partialCount '
            'responseBytes=$responseBytes '
            'firstChunkMs=$firstContent '
            'completionMs=${stopwatch.elapsedMilliseconds} completed=true',
          );
          index += 1;
        }

        final cancellation = await _cancelLiveGatewayStreamAfterFirstContent(
          gateway: streamMetrics,
          egressGuard: egressGuard,
          clientVersion: runtime.clientVersion,
        );
        expect(cancellation.rawChunksBeforeCancel, greaterThan(0));
        expect(cancellation.responseBytesBeforeCancel, greaterThan(0));
        expect(cancellation.completedEvents, 0);
        expect(cancellation.failureEvents, 0);
        expect(cancellation.lateEvents, 0);
        print(
          'ANDROID_GROQ_LIVE_CANCELLATION firstContentReceived=true '
          'subscriptionCancelled=true '
          'firstChunkMs=${cancellation.firstChunkMs} '
          'cancelCompletionMs=${cancellation.cancelCompletionMs} '
          'rawChunksBeforeCancel=${cancellation.rawChunksBeforeCancel} '
          'responseBytesBeforeCancel=${cancellation.responseBytesBeforeCancel} '
          'completedEvents=${cancellation.completedEvents} '
          'failureEvents=${cancellation.failureEvents} '
          'lateEvents=${cancellation.lateEvents}',
        );

        expect(modelGateway.startSessionCalls, 2);
        expect(streamMetrics.generalStreamCalls, 3);
        expect(streamedPrompts, 2);
        print(
          'ANDROID_GROQ_LIVE_ACCEPTANCE completed=true prompts=2 '
          'arabicPrompts=1 englishPrompts=1 groqSessions=2 '
          'gatewayStreams=3 streamedPrompts=$streamedPrompts '
          'liveCancellation=true '
          'rawChunks=${rawChunkCounts.join(",")} '
          'responseBytes=${responseByteCounts.join(",")} '
          'firstChunkMs=${firstChunkMs.join(",")} '
          'completionMs=${completionMs.join(",")}',
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
          'ANDROID_GROQ_LIVE_AUTH_CLEANUP attempted=true '
          'deleted=$deleted signedOut=$signedOut',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<List<_SafeAppCheckNegativeResult>> _verifyAppCheckNegativePreflight({
  required http.Client httpClient,
  required Uri baseUri,
  required String clientVersion,
  required String firebaseIdToken,
}) async {
  final results = <_SafeAppCheckNegativeResult>[];
  for (final variant in const <String>['missing', 'invalid']) {
    final requestId =
        'appcheck_${variant}_${DateTime.now().toUtc().microsecondsSinceEpoch}';
    final headers = <String, String>{
      'Authorization': 'Bearer $firebaseIdToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Request-ID': requestId,
      'X-CashPilot-Platform': 'android',
    };
    if (variant == 'invalid') {
      headers['X-Firebase-AppCheck'] = 'invalid-app-check-token';
    }
    final response = await httpClient
        .post(
          baseUri.resolve('/v1/ai/general-chat'),
          headers: headers,
          body: jsonEncode(<String, Object?>{
            'requestId': requestId,
            'mode': 'generalConversation',
            'locale': 'en',
            'sanitizedMessages': const <Map<String, String>>[
              <String, String>{
                'role': 'user',
                'content': 'Explain one synthetic budgeting concept.',
              },
            ],
            'timeoutClass': 'interactive',
            'clientVersion': clientVersion,
          }),
        )
        .timeout(const Duration(seconds: 10));
    var safeCode = 'unknown';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['failure'] is Map) {
        final failure = decoded['failure'] as Map;
        final candidate = failure['code'];
        if (candidate is String &&
            RegExp(r'^[A-Za-z0-9_]+$').hasMatch(candidate)) {
          safeCode = candidate;
        }
      }
    } on Object {
      safeCode = 'unknown';
    }
    results.add(
      _SafeAppCheckNegativeResult(
        variant: variant,
        status: response.statusCode,
        code: safeCode,
        rejected:
            response.statusCode == 401 && safeCode == 'gatewayAppCheckRequired',
      ),
    );
  }
  return List<_SafeAppCheckNegativeResult>.unmodifiable(results);
}

final class _SafeAppCheckNegativeResult {
  const _SafeAppCheckNegativeResult({
    required this.variant,
    required this.status,
    required this.code,
    required this.rejected,
  });

  final String variant;
  final int status;
  final String code;
  final bool rejected;
}

Future<_LiveCancellationMetrics> _cancelLiveGatewayStreamAfterFirstContent({
  required AiConversationGateway gateway,
  required AiProviderEgressGuard egressGuard,
  required String clientVersion,
}) async {
  final requestId = 'cancel_${DateTime.now().toUtc().microsecondsSinceEpoch}';
  final requestStarted = Stopwatch()..start();
  final cancellationCompleted = Completer<void>();
  late final StreamSubscription<AiGatewayEvent> subscription;
  var cancelRequested = false;
  var firstChunkMs = 0;
  var cancelCompletionMs = 0;
  var rawChunksBeforeCancel = 0;
  var responseBytesBeforeCancel = 0;
  var completedEvents = 0;
  var failureEvents = 0;
  var lateEvents = 0;

  void failBeforeCancellation() {
    if (!cancellationCompleted.isCompleted) {
      cancellationCompleted.completeError(
        StateError('Live cancellation stream ended before first content.'),
      );
    }
  }

  subscription = gateway
      .streamGeneralConversation(
        AiGatewayRequest(
          requestId: requestId,
          mode: AiGatewayMode.generalConversation,
          locale: 'en',
          sanitizedMessages: const <AiGatewayMessage>[
            AiGatewayMessage(
              role: 'user',
              content:
                  'Give a detailed numbered explanation of ten practical '
                  'budgeting habits.',
            ),
          ],
          timeoutClass: AiGatewayTimeoutClass.interactive,
          clientVersion: clientVersion,
        ),
        egressGuard: egressGuard,
      )
      .listen(
        (event) {
          if (cancelRequested) {
            lateEvents += 1;
          }
          switch (event.type) {
            case AiGatewayEventType.textDelta:
              final delta = event.delta;
              if (delta == null || delta.isEmpty) {
                return;
              }
              rawChunksBeforeCancel += 1;
              responseBytesBeforeCancel += utf8.encode(delta).length;
              if (cancelRequested) {
                return;
              }
              cancelRequested = true;
              firstChunkMs = requestStarted.elapsedMilliseconds;
              final cancelStarted = Stopwatch()..start();
              unawaited(
                subscription.cancel().then(
                  (_) {
                    cancelStarted.stop();
                    cancelCompletionMs = cancelStarted.elapsedMilliseconds;
                    if (!cancellationCompleted.isCompleted) {
                      cancellationCompleted.complete();
                    }
                  },
                  onError: (_) {
                    failBeforeCancellation();
                  },
                ),
              );
            case AiGatewayEventType.completed:
              completedEvents += 1;
              if (!cancelRequested) {
                failBeforeCancellation();
              }
            case AiGatewayEventType.failure:
              failureEvents += 1;
              if (!cancelRequested) {
                failBeforeCancellation();
              }
            case AiGatewayEventType.started ||
                AiGatewayEventType.toolSelection ||
                AiGatewayEventType.warning:
              break;
          }
        },
        onError: (Object _, StackTrace _) {
          if (!cancelRequested) {
            failBeforeCancellation();
          }
        },
        onDone: () {
          if (!cancelRequested) {
            failBeforeCancellation();
          }
        },
        cancelOnError: true,
      );

  await cancellationCompleted.future.timeout(const Duration(seconds: 45));
  await Future<void>.delayed(const Duration(milliseconds: 750));
  requestStarted.stop();
  return _LiveCancellationMetrics(
    firstChunkMs: firstChunkMs,
    cancelCompletionMs: cancelCompletionMs,
    rawChunksBeforeCancel: rawChunksBeforeCancel,
    responseBytesBeforeCancel: responseBytesBeforeCancel,
    completedEvents: completedEvents,
    failureEvents: failureEvents,
    lateEvents: lateEvents,
  );
}

final class _LiveCancellationMetrics {
  const _LiveCancellationMetrics({
    required this.firstChunkMs,
    required this.cancelCompletionMs,
    required this.rawChunksBeforeCancel,
    required this.responseBytesBeforeCancel,
    required this.completedEvents,
    required this.failureEvents,
    required this.lateEvents,
  });

  final int firstChunkMs;
  final int cancelCompletionMs;
  final int rawChunksBeforeCancel;
  final int responseBytesBeforeCancel;
  final int completedEvents;
  final int failureEvents;
  final int lateEvents;
}

final class _LivePrompt {
  const _LivePrompt({required this.locale, required this.message});

  final String locale;
  final String message;
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

Future<_SyntheticUser> _createSyntheticUser(
  FirebaseAuth auth, {
  required String label,
}) async {
  if (auth.currentUser != null) {
    await auth.signOut();
  }
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final email = 'cashpilot-groq-$label-$stamp@example.com';
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

final class _StreamMetricsConversationGateway implements AiConversationGateway {
  _StreamMetricsConversationGateway(this._delegate);

  final AiConversationGateway _delegate;
  int generalStreamCalls = 0;
  int startedEvents = 0;
  int textDeltaEvents = 0;
  int textDeltaBytes = 0;
  int completedEvents = 0;
  int failureEvents = 0;

  @override
  Stream<AiGatewayEvent> streamGeneralConversation(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) async* {
    generalStreamCalls += 1;
    await for (final event in _delegate.streamGeneralConversation(
      request,
      egressGuard: egressGuard,
    )) {
      switch (event.type) {
        case AiGatewayEventType.started:
          startedEvents += 1;
        case AiGatewayEventType.textDelta:
          textDeltaEvents += 1;
          final delta = event.delta;
          if (delta != null) {
            textDeltaBytes += utf8.encode(delta).length;
          }
        case AiGatewayEventType.completed:
          completedEvents += 1;
        case AiGatewayEventType.failure:
          failureEvents += 1;
        case AiGatewayEventType.toolSelection || AiGatewayEventType.warning:
          break;
      }
      yield event;
    }
  }

  @override
  Stream<AiGatewayEvent> streamFinancialExplanation(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) => _delegate.streamFinancialExplanation(request, egressGuard: egressGuard);

  @override
  Future<AiGatewayToolSelection> selectGovernedTools(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) => _delegate.selectGovernedTools(request, egressGuard: egressGuard);

  @override
  Future<AiGatewayHealth> healthCheck() => _delegate.healthCheck();
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
