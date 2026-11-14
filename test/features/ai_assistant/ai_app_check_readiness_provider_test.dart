import 'dart:async';
import 'dart:convert';

import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_readiness.dart';
import 'package:cashpilot_ai/core/firebase/firebase_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_runtime_status_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_gateway_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/firebase_gateway_token_provider.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_runtime_status.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

void main() {
  test(
    'Settings live probe and Chat token provider share one coordinator',
    () async {
      final activationGate = Completer<void>();
      var appCheckTokenCalls = 0;
      var httpCalls = 0;
      final activation = FirebaseAppCheckActivationController(
        activator: _CallbackActivator(() => activationGate.future),
        timeout: const Duration(seconds: 1),
      );
      final readiness = FirebaseAppCheckReadinessCoordinator(
        activationController: activation,
        tokenLoader: ({required forceRefresh}) async {
          appCheckTokenCalls += 1;
          return 'shared-app-check-token';
        },
        tokenRetryDelays: const <Duration>[Duration.zero],
        totalTimeout: const Duration(seconds: 1),
        tokenAttemptTimeout: const Duration(seconds: 1),
      );
      final transport = MockClient((request) async {
        httpCalls += 1;
        final requestId = request.headers['X-Request-ID']!;
        final body = <Map<String, Object?>>[
          <String, Object?>{'type': 'started', 'requestId': requestId},
          <String, Object?>{
            'type': 'textDelta',
            'requestId': requestId,
            'delta': 'ready',
          },
          <String, Object?>{'type': 'completed', 'requestId': requestId},
        ].map((event) => 'data: ${jsonEncode(event)}\n\n').join();
        return http.Response(
          body,
          200,
          headers: const <String, String>{'content-type': 'text/event-stream'},
        );
      });
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            _FakeFirebaseAuth(_FakeFirebaseUser()),
          ),
          firebaseAppCheckReadinessCoordinatorProvider.overrideWithValue(
            readiness,
          ),
          aiGatewayRuntimeConfigProvider.overrideWithValue(
            AiGatewayRuntimeConfig.resolve(
              baseUrl: 'https://gateway.example.test',
            ),
          ),
          aiGatewayFeatureFlagsProvider.overrideWithValue(
            AiGatewayFeatureFlags.resolve(
              groqGatewayValue: 'true',
              generalChatValue: 'true',
            ),
          ),
          aiGatewayHttpClientProvider.overrideWithValue(transport),
          aiRuntimeStatusEgressGuardProvider.overrideWithValue(
            testAiProviderEgressGuard,
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(transport.close);
      addTearDown(readiness.dispose);
      addTearDown(activation.dispose);

      final chatTokens = container.read(aiGatewayTokenProvider);
      expect(chatTokens, isA<FirebaseAiGatewayTokenProvider>());
      expect(
        (chatTokens as FirebaseAiGatewayTokenProvider).appCheckReadiness,
        same(readiness),
      );
      expect(appCheckTokenCalls, 0);

      final pendingResult = container
          .read(aiRuntimeLiveProbeProvider)
          .run(
            fingerprint: const AiRuntimeStatusFingerprint(
              '0000000000000000000000000000000000000000000000000000000000000000',
            ),
            routePlan: _groqPlan,
          );
      await Future<void>.delayed(Duration.zero);

      expect(readiness.state.phase, FirebaseAppCheckReadinessPhase.activating);
      expect(appCheckTokenCalls, 0);
      expect(httpCalls, 0);

      activationGate.complete();
      final result = await pendingResult;

      expect(result.status, AiRuntimeLiveStatus.ready);
      expect(result.respondingProvider, AiActiveProvider.groq);
      expect(appCheckTokenCalls, 1);
      expect(httpCalls, 1);
    },
  );
}

const _groqPlan = AiProviderRoutePlan(
  task: ModelTask.generalConversation,
  primaryProvider: AiActiveProvider.groq,
  primaryAvailable: true,
  preflightProvider: AiActiveProvider.groq,
  fallbackProvider: null,
  fallbackAvailable: false,
  fallbackPolicy: AiRuntimeFallbackPolicy.none,
  primaryUnavailableReason: null,
  routeUnavailableReason: null,
);

final class _CallbackActivator implements FirebaseAppCheckActivator {
  const _CallbackActivator(this.callback);

  final Future<void> Function() callback;

  @override
  Future<void> activate() => callback();
}

final class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this.user);

  final User user;

  @override
  User? get currentUser => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeFirebaseUser implements User {
  @override
  String get uid => 'test-user';

  @override
  bool get isAnonymous => false;

  @override
  String? get tenantId => null;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'firebase-id-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
