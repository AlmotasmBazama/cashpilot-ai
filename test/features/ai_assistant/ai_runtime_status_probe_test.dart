import 'dart:async';

import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_runtime_status_probe.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_runtime_status.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

void main() {
  test('direct streaming Groq content is required for ready', () async {
    final gateway = _ProbeGateway(
      session: _ProbeSession(
        () => Stream<AiAgentModelTurn>.fromIterable(const [
          AiAgentModelTurn(text: 'A'),
          AiAgentModelTurn(text: 'A safe answer.'),
        ]),
      ),
    );
    final probe = GroqAiRuntimeStatusProbe(
      groqGateway: gateway,
      egressGuard: testAiProviderEgressGuard,
    );

    final result = await probe.run(
      fingerprint: _fingerprint,
      routePlan: _groqPlan(),
    );

    expect(result.status, AiRuntimeLiveStatus.ready);
    expect(result.probedProvider, AiActiveProvider.groq);
    expect(result.respondingProvider, AiActiveProvider.groq);
    expect(result.receivedNonEmptyContent, isTrue);
    expect(result.failureCode, isNull);
    expect(result.latency >= Duration.zero, isTrue);
    expect(gateway.calls, 1);
    expect(gateway.tools, isEmpty);
    expect(gateway.request?.taskClass, ModelTask.generalConversation);
    expect(gateway.request?.memoryContext, isEmpty);
    expect(gateway.request?.conversationHistory, isEmpty);
    expect(gateway.request?.userMessage, isNot(startsWith('Hello')));
    expect(gateway.request?.userMessage, isNot(contains('@')));
    expect(gateway.request?.userMessage, isNot(matches(RegExp(r'\d{7,}'))));
  });

  test('empty or non-stream response cannot claim live availability', () async {
    final empty = GroqAiRuntimeStatusProbe(
      groqGateway: _ProbeGateway(
        session: _ProbeSession(
          () => Stream<AiAgentModelTurn>.value(
            const AiAgentModelTurn(text: '   '),
          ),
        ),
      ),
      egressGuard: testAiProviderEgressGuard,
    );
    final nonStreaming = GroqAiRuntimeStatusProbe(
      groqGateway: _ProbeGateway(session: const _NonStreamingSession()),
      egressGuard: testAiProviderEgressGuard,
    );

    for (final probe in <GroqAiRuntimeStatusProbe>[empty, nonStreaming]) {
      final result = await probe.run(
        fingerprint: _fingerprint,
        routePlan: _groqPlan(),
      );
      expect(result.status, AiRuntimeLiveStatus.groqMalformedResponse);
      expect(result.failureCode, AiGatewayFailureCode.groqMalformedResponse);
      expect(result.respondingProvider, isNull);
    }
  });

  test('typed gateway failures retain granular runtime status', () async {
    const cases = <AiGatewayFailureCode, AiRuntimeLiveStatus>{
      AiGatewayFailureCode.groqAuthenticationFailed:
          AiRuntimeLiveStatus.groqAuthenticationFailed,
      AiGatewayFailureCode.groqModelUnavailable:
          AiRuntimeLiveStatus.groqModelUnavailable,
      AiGatewayFailureCode.groqRateLimited: AiRuntimeLiveStatus.groqRateLimited,
      AiGatewayFailureCode.gatewayAppCheckRequired:
          AiRuntimeLiveStatus.gatewayAppCheckRequired,
      AiGatewayFailureCode.appCheckUnavailable:
          AiRuntimeLiveStatus.gatewayAppCheckRequired,
      AiGatewayFailureCode.appCheckTimedOut:
          AiRuntimeLiveStatus.gatewayAppCheckRequired,
      AiGatewayFailureCode.appCheckRejected:
          AiRuntimeLiveStatus.gatewayAppCheckRequired,
      AiGatewayFailureCode.authenticationNotReady:
          AiRuntimeLiveStatus.gatewayAuthenticationRequired,
      AiGatewayFailureCode.networkFailure: AiRuntimeLiveStatus.offline,
    };
    for (final entry in cases.entries) {
      final probe = GroqAiRuntimeStatusProbe(
        groqGateway: _ProbeGateway(
          session: _ProbeSession(
            () => Stream<AiAgentModelTurn>.error(
              AiGatewayException(code: entry.key, safeMessage: 'safe'),
            ),
          ),
        ),
        egressGuard: testAiProviderEgressGuard,
      );

      final result = await probe.run(
        fingerprint: _fingerprint,
        routePlan: _groqPlan(),
      );

      expect(result.status, entry.value, reason: entry.key.name);
      expect(result.failureCode, entry.key);
      expect(result.respondingProvider, isNull);
    }
  });

  test('request and stream timeouts remain distinguishable', () async {
    final startNeverCompletes = Completer<AiAgentModelSession>();
    final requestProbe = GroqAiRuntimeStatusProbe(
      groqGateway: _ProbeGateway(startFuture: startNeverCompletes.future),
      egressGuard: testAiProviderEgressGuard,
      requestTimeout: const Duration(milliseconds: 2),
    );
    final streamProbe = GroqAiRuntimeStatusProbe(
      groqGateway: _ProbeGateway(
        session: _ProbeSession(() => const Stream<AiAgentModelTurn>.empty()),
      ),
      egressGuard: testAiProviderEgressGuard,
      streamTimeout: const Duration(milliseconds: 2),
    );

    final request = await requestProbe.run(
      fingerprint: _fingerprint,
      routePlan: _groqPlan(),
    );
    final stream = await streamProbe.run(
      fingerprint: _fingerprint,
      routePlan: _groqPlan(),
    );

    expect(request.status, AiRuntimeLiveStatus.groqRequestTimedOut);
    expect(request.failureCode, AiGatewayFailureCode.groqRequestTimedOut);
    // An empty stream completed normally, so it is malformed rather than timed
    // out. A never-completing stream proves the separate timeout below.
    expect(stream.status, AiRuntimeLiveStatus.groqMalformedResponse);

    final neverStreaming = GroqAiRuntimeStatusProbe(
      groqGateway: _ProbeGateway(
        session: _ProbeSession(
          () => StreamController<AiAgentModelTurn>().stream,
        ),
      ),
      egressGuard: testAiProviderEgressGuard,
      streamTimeout: const Duration(milliseconds: 2),
    );
    final timedStream = await neverStreaming.run(
      fingerprint: _fingerprint,
      routePlan: _groqPlan(),
    );
    expect(timedStream.status, AiRuntimeLiveStatus.groqStreamTimedOut);
    expect(timedStream.failureCode, AiGatewayFailureCode.groqStreamTimedOut);
  });

  test(
    'non-Groq route and missing egress fail closed without fallback',
    () async {
      final notSelectedGateway = _ProbeGateway(
        session: _ProbeSession(() => const Stream<AiAgentModelTurn>.empty()),
      );
      final notSelected = GroqAiRuntimeStatusProbe(
        groqGateway: notSelectedGateway,
        egressGuard: testAiProviderEgressGuard,
      );
      final noAuthGateway = _ProbeGateway(
        session: _ProbeSession(() => const Stream<AiAgentModelTurn>.empty()),
      );
      final noAuth = GroqAiRuntimeStatusProbe(
        groqGateway: noAuthGateway,
        egressGuard: null,
      );

      final skipped = await notSelected.run(
        fingerprint: _fingerprint,
        routePlan: _firebasePlan(),
      );
      final blocked = await noAuth.run(
        fingerprint: _fingerprint,
        routePlan: _groqPlan(),
      );

      expect(skipped.status, AiRuntimeLiveStatus.groqNotSelected);
      expect(notSelectedGateway.calls, 0);
      expect(blocked.status, AiRuntimeLiveStatus.gatewayAuthenticationRequired);
      expect(noAuthGateway.calls, 0);
    },
  );

  test(
    'missing Groq configuration is typed without any provider call',
    () async {
      final gateway = _ProbeGateway(
        session: _ProbeSession(() => const Stream<AiAgentModelTurn>.empty()),
      );
      final probe = GroqAiRuntimeStatusProbe(
        groqGateway: gateway,
        egressGuard: testAiProviderEgressGuard,
      );

      final result = await probe.run(
        fingerprint: _fingerprint,
        routePlan: _groqUnavailablePlan(),
      );

      expect(result.status, AiRuntimeLiveStatus.groqNotConfigured);
      expect(gateway.calls, 0);
    },
  );
}

const _fingerprint = AiRuntimeStatusFingerprint(
  '0000000000000000000000000000000000000000000000000000000000000000',
);

AiProviderRoutePlan _groqPlan() => const AiProviderRoutePlan(
  task: ModelTask.generalConversation,
  primaryProvider: AiActiveProvider.groq,
  primaryAvailable: true,
  preflightProvider: AiActiveProvider.groq,
  fallbackProvider: AiActiveProvider.firebase,
  fallbackAvailable: true,
  fallbackPolicy: AiRuntimeFallbackPolicy.firebaseBeforeContent,
  primaryUnavailableReason: null,
  routeUnavailableReason: null,
);

AiProviderRoutePlan _firebasePlan() => const AiProviderRoutePlan(
  task: ModelTask.generalConversation,
  primaryProvider: AiActiveProvider.firebase,
  primaryAvailable: true,
  preflightProvider: AiActiveProvider.firebase,
  fallbackProvider: null,
  fallbackAvailable: false,
  fallbackPolicy: AiRuntimeFallbackPolicy.none,
  primaryUnavailableReason: null,
  routeUnavailableReason: null,
);

AiProviderRoutePlan _groqUnavailablePlan() => const AiProviderRoutePlan(
  task: ModelTask.generalConversation,
  primaryProvider: AiActiveProvider.groq,
  primaryAvailable: false,
  preflightProvider: AiActiveProvider.none,
  fallbackProvider: null,
  fallbackAvailable: false,
  fallbackPolicy: AiRuntimeFallbackPolicy.none,
  primaryUnavailableReason: AiUnavailableReason.gatewayUrlMissing,
  routeUnavailableReason: AiUnavailableReason.gatewayUrlMissing,
);

final class _ProbeGateway implements AiAgentModelGateway {
  _ProbeGateway({this.session, this.startFuture});

  final AiAgentModelSession? session;
  final Future<AiAgentModelSession>? startFuture;
  int calls = 0;
  AiAgentModelRequest? request;
  List<AiToolDefinition> tools = const [];

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) {
    calls++;
    this.request = request;
    this.tools = List<AiToolDefinition>.of(tools);
    return startFuture ?? Future<AiAgentModelSession>.value(session!);
  }
}

final class _ProbeSession implements StreamingAiAgentModelSession {
  const _ProbeSession(this._stream);

  final Stream<AiAgentModelTurn> Function() _stream;

  @override
  Future<AiAgentModelTurn> sendInitial() async {
    var last = const AiAgentModelTurn();
    await for (final turn in _stream()) {
      last = turn;
    }
    return last;
  }

  @override
  Stream<AiAgentModelTurn> sendInitialStream() => _stream();

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => const AiAgentModelTurn();
}

final class _NonStreamingSession implements AiAgentModelSession {
  const _NonStreamingSession();

  @override
  Future<AiAgentModelTurn> sendInitial() async =>
      const AiAgentModelTurn(text: 'not accepted');

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => const AiAgentModelTurn();
}
