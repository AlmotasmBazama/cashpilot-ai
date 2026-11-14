import 'dart:async';

import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_runtime_status_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_runtime_status_builder.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_runtime_status_probe.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_runtime_status.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _testSeedStateProvider = StateProvider<AiRuntimeStatusSnapshot>(
  (_) => _snapshot(),
);

void main() {
  test(
    'fingerprint covers safe runtime dimensions without exposing values',
    () {
      final base = _configuration();
      final baseline = buildAiRuntimeStatusSnapshot(base);
      final variants = <AiRuntimeStatusConfiguration>[
        _configuration(
          appBuild: const AiAppBuildMetadata(version: '2', buildNumber: '1'),
        ),
        _configuration(buildMode: AiRuntimeBuildMode.release),
        _configuration(environmentName: 'qa'),
        _configuration(preference: AiRuntimeProviderPreference.firebase),
        _configuration(gatewayOrigin: 'https://other.example.test'),
        _configuration(modelId: 'another-safe-model'),
        _configuration(firebaseFallback: false),
        _configuration(authGeneration: 8),
        _configuration(
          appCheckPhase: FirebaseAppCheckActivationPhase.unavailable,
          appCheckReason: FirebaseAppCheckUnavailableReason.activationFailed,
        ),
      ];

      for (final variant in variants) {
        expect(
          buildAiRuntimeStatusSnapshot(variant).fingerprint,
          isNot(baseline.fingerprint),
        );
      }
      expect(baseline.fingerprint.value, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(baseline.fingerprint.value, isNot(contains('gateway')));
      expect(baseline.fingerprint.value, isNot(contains('token')));
      expect(baseline.fingerprint.toString(), contains('redacted'));
    },
  );

  test(
    'snapshot exposes flat, typed Settings semantics and safe model catalog',
    () {
      final snapshot = _snapshot();

      expect(snapshot.remoteTextProvider, AiActiveProvider.groq);
      expect(snapshot.remoteTextProviderConfigured, isTrue);
      expect(snapshot.remoteTextProviderAvailable, isTrue);
      expect(
        snapshot.generalConversationModel,
        AiRuntimeModelCatalog.gatewayGeneralConversation,
      );
      expect(
        snapshot.financialExplanationModel,
        AiRuntimeModelCatalog.gatewayFinancialExplanation,
      );
      expect(
        snapshot.localCommandParser,
        AiRuntimeModelCatalog.localCommandParser,
      );
      expect(snapshot.receiptVisionProvider, AiActiveProvider.firebase);
      expect(snapshot.firebaseInitialized, isTrue);
      expect(snapshot.appCheckActivated, isTrue);
      expect(snapshot.authenticationReady, isTrue);

      final missing =
          _snapshot(
            routePlan: _groqPlan(
              available: false,
              reason: AiUnavailableReason.gatewayUrlMissing,
            ),
            gatewayConfigured: false,
          ).completeLiveTest(
            status: AiRuntimeLiveStatus.groqNotConfigured,
            probedProvider: AiActiveProvider.groq,
            respondingProvider: null,
            receivedNonEmptyContent: false,
            failureCode: AiGatewayFailureCode.groqNotConfigured,
            checkedAt: DateTime.utc(2026),
            latency: const Duration(milliseconds: 4),
          );
      expect(missing.generalConversationModel, isNull);
      expect(missing.remoteTextProviderConfigured, isFalse);
      expect(
        missing.lastLiveTestStatus,
        AiRuntimeUiStatus.configurationMissing,
      );
    },
  );

  test(
    'automatic health check publishes bounded gateway availability',
    () async {
      var healthCalls = 0;
      final container = _container(
        health: () async {
          healthCalls++;
          return true;
        },
        probe: _ImmediateProbe(),
      );
      addTearDown(container.dispose);

      final initial = await container.read(
        aiRuntimeStatusControllerProvider.future,
      );
      expect(
        initial.gatewayAvailability,
        AiRuntimeGatewayAvailability.checking,
      );
      await _waitFor(
        () =>
            container
                .read(aiRuntimeStatusControllerProvider)
                .value
                ?.gatewayReachable ==
            true,
      );

      expect(healthCalls, 1);
      expect(
        container
            .read(aiRuntimeStatusControllerProvider)
            .value
            ?.gatewayAvailability,
        AiRuntimeGatewayAvailability.available,
      );
    },
  );

  test('late health result cannot overwrite a new fingerprint', () async {
    final firstHealth = Completer<bool>();
    final secondHealth = Completer<bool>();
    var calls = 0;
    final container = _container(
      health: () {
        calls++;
        return calls == 1 ? firstHealth.future : secondHealth.future;
      },
      probe: _ImmediateProbe(),
    );
    addTearDown(container.dispose);

    await container.read(aiRuntimeStatusControllerProvider.future);
    await _waitFor(() => calls == 1, label: 'first health call');
    final replacement = _snapshot(environmentName: 'qa');
    container.read(_testSeedStateProvider.notifier).state = replacement;
    await _waitFor(
      () =>
          container
              .read(aiRuntimeStatusControllerProvider)
              .value
              ?.fingerprint ==
          replacement.fingerprint,
      label: 'replacement fingerprint',
    );
    await _waitFor(() => calls == 2, label: 'replacement health call');

    firstHealth.complete(true);
    await pumpEventQueue();
    final duringSecond = container
        .read(aiRuntimeStatusControllerProvider)
        .value;
    expect(duringSecond?.fingerprint, replacement.fingerprint);
    expect(
      duringSecond?.gatewayAvailability,
      AiRuntimeGatewayAvailability.checking,
    );

    secondHealth.complete(false);
    await _waitFor(
      () =>
          container
              .read(aiRuntimeStatusControllerProvider)
              .value
              ?.gatewayAvailability ==
          AiRuntimeGatewayAvailability.unavailable,
      label: 'replacement unavailable result',
    );
  });

  test(
    'late live result is discarded after selection fingerprint changes',
    () async {
      final deferred = _DeferredProbe();
      final container = _container(health: () async => true, probe: deferred);
      addTearDown(container.dispose);

      await container.read(aiRuntimeStatusControllerProvider.future);
      await _waitFor(
        () =>
            container
                .read(aiRuntimeStatusControllerProvider)
                .value
                ?.gatewayReachable ==
            true,
      );
      final controller = container.read(
        aiRuntimeStatusControllerProvider.notifier,
      );
      final pending = controller.runLiveTest();
      await _waitFor(() => deferred.fingerprint != null);
      final originalFingerprint = deferred.fingerprint!;

      final replacement = _snapshot(environmentName: 'qa');
      container.read(_testSeedStateProvider.notifier).state = replacement;
      await _waitFor(
        () =>
            container
                .read(aiRuntimeStatusControllerProvider)
                .value
                ?.fingerprint ==
            replacement.fingerprint,
      );
      deferred.complete(
        AiRuntimeLiveProbeResult(
          fingerprint: originalFingerprint,
          status: AiRuntimeLiveStatus.ready,
          probedProvider: AiActiveProvider.groq,
          respondingProvider: AiActiveProvider.groq,
          receivedNonEmptyContent: true,
          failureCode: null,
          checkedAt: DateTime.utc(2026),
          latency: const Duration(milliseconds: 10),
        ),
      );

      expect(await pending, isNull);
      final current = container.read(aiRuntimeStatusControllerProvider).value;
      expect(current?.fingerprint, replacement.fingerprint);
      expect(current?.liveStatus, AiRuntimeLiveStatus.notChecked);
    },
  );

  test(
    'live success publishes checking before ready and retains typed evidence',
    () async {
      final container = _container(
        health: () async => true,
        probe: _ImmediateProbe(),
      );
      addTearDown(container.dispose);
      await container.read(aiRuntimeStatusControllerProvider.future);
      final observedLiveStatuses = <AiRuntimeLiveStatus>[];
      final subscription = container.listen(aiRuntimeStatusControllerProvider, (
        _,
        next,
      ) {
        final liveStatus = next.value?.liveStatus;
        if (liveStatus == null ||
            (liveStatus != AiRuntimeLiveStatus.checking &&
                liveStatus != AiRuntimeLiveStatus.ready)) {
          return;
        }
        if (observedLiveStatuses.isEmpty ||
            observedLiveStatuses.last != liveStatus) {
          observedLiveStatuses.add(liveStatus);
        }
      });
      addTearDown(subscription.close);

      final completed = await container
          .read(aiRuntimeStatusControllerProvider.notifier)
          .runLiveTest();

      expect(observedLiveStatuses, <AiRuntimeLiveStatus>[
        AiRuntimeLiveStatus.checking,
        AiRuntimeLiveStatus.ready,
      ]);
      expect(completed?.liveReady, isTrue);
      expect(completed?.lastLiveTestProvider, AiActiveProvider.groq);
      expect(completed?.lastLiveTestStatus, AiRuntimeUiStatus.available);
      expect(completed?.lastLiveTestFailureCode, isNull);
      expect(completed?.lastLiveTestTimestamp, isNotNull);
      expect(completed?.lastLiveTestLatency, const Duration(milliseconds: 12));
    },
  );

  test(
    'probe provider construction failure cannot leave live status checking',
    () async {
      final container = ProviderContainer(
        overrides: [
          aiRuntimeStatusSeedProvider.overrideWith(
            (ref) async => ref.watch(_testSeedStateProvider),
          ),
          aiRuntimeGatewayHealthCheckProvider.overrideWithValue(
            () async => true,
          ),
          aiRuntimeLiveProbeProvider.overrideWith(
            (_) => throw StateError('synthetic probe construction failure'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(aiRuntimeStatusControllerProvider.future);
      final observedLiveStatuses = <AiRuntimeLiveStatus>[];
      final subscription = container.listen(aiRuntimeStatusControllerProvider, (
        _,
        next,
      ) {
        final liveStatus = next.value?.liveStatus;
        if (liveStatus == null ||
            (liveStatus != AiRuntimeLiveStatus.checking &&
                liveStatus != AiRuntimeLiveStatus.unknownTemporaryFailure)) {
          return;
        }
        if (observedLiveStatuses.isEmpty ||
            observedLiveStatuses.last != liveStatus) {
          observedLiveStatuses.add(liveStatus);
        }
      });
      addTearDown(subscription.close);

      final completed = await container
          .read(aiRuntimeStatusControllerProvider.notifier)
          .runLiveTest();

      expect(observedLiveStatuses, <AiRuntimeLiveStatus>[
        AiRuntimeLiveStatus.checking,
        AiRuntimeLiveStatus.unknownTemporaryFailure,
      ]);
      expect(
        completed?.liveStatus,
        AiRuntimeLiveStatus.unknownTemporaryFailure,
      );
      expect(completed?.lastLiveTestStatus, AiRuntimeUiStatus.unavailable);
      expect(
        completed?.lastLiveTestFailureCode,
        AiGatewayFailureCode.unknownTemporaryFailure,
      );
      expect(completed?.lastLiveTestTimestamp, isNotNull);
      expect(completed?.lastLiveTestLatency, isNotNull);
      expect(completed?.liveReady, isFalse);
    },
  );
}

ProviderContainer _container({
  required AiRuntimeGatewayHealthCheck health,
  required AiRuntimeLiveProbe probe,
}) => ProviderContainer(
  overrides: [
    aiRuntimeStatusSeedProvider.overrideWith(
      (ref) async => ref.watch(_testSeedStateProvider),
    ),
    aiRuntimeGatewayHealthCheckProvider.overrideWithValue(health),
    aiRuntimeLiveProbeProvider.overrideWithValue(probe),
  ],
);

AiRuntimeStatusConfiguration _configuration({
  AiAppBuildMetadata appBuild = const AiAppBuildMetadata(
    version: '1.0.0',
    buildNumber: '1',
  ),
  AiRuntimeBuildMode buildMode = AiRuntimeBuildMode.debug,
  String environmentName = 'staging',
  AiRuntimeProviderPreference preference = AiRuntimeProviderPreference.groq,
  String gatewayOrigin = 'https://gateway.example.test',
  String modelId = AiRuntimeModelCatalog.gatewayGeneralConversation,
  bool firebaseFallback = true,
  int authGeneration = 7,
  FirebaseAppCheckActivationPhase appCheckPhase =
      FirebaseAppCheckActivationPhase.available,
  FirebaseAppCheckUnavailableReason? appCheckReason,
  AiProviderRoutePlan? routePlan,
  bool gatewayConfigured = true,
}) => AiRuntimeStatusConfiguration(
  routePlan: routePlan ?? _groqPlan(),
  appBuild: appBuild,
  buildMode: buildMode,
  environment: aiRuntimeEnvironmentForName(environmentName),
  normalizedEnvironmentName: environmentName,
  preference: preference,
  gatewayConfigured: gatewayConfigured,
  groqGatewayEnabled: true,
  groqGeneralChatEnabled: true,
  normalizedGatewayOrigin: gatewayOrigin,
  gatewayClientVersion: '1.0.0',
  model: gatewayConfigured
      ? AiRuntimeModelIdentity(
          source: AiRuntimeModelSource.gatewayManaged,
          safeModelId: modelId,
        )
      : const AiRuntimeModelIdentity.unavailable(),
  firebaseTextFallbackEnabled: firebaseFallback,
  authenticated: true,
  authSessionGeneration: authGeneration,
  authIsAnonymous: true,
  authTenantConfigured: false,
  firebasePlatformConfigured: true,
  firebaseInitialized: true,
  appCheckPhase: appCheckPhase,
  appCheckUnavailableReason: appCheckReason,
  appCheckProvider: AiRuntimeAppCheckProvider.debug,
  financialExplanationProvider: AiActiveProvider.groq,
  financialExplanationModel: AiRuntimeModelCatalog.gatewayFinancialExplanation,
  receiptVisionProvider: AiActiveProvider.firebase,
  receiptVisionModel: 'gemini-receipt-safe',
);

AiRuntimeStatusSnapshot _snapshot({
  String environmentName = 'staging',
  AiProviderRoutePlan? routePlan,
  bool gatewayConfigured = true,
}) => buildAiRuntimeStatusSnapshot(
  _configuration(
    environmentName: environmentName,
    routePlan: routePlan,
    gatewayConfigured: gatewayConfigured,
  ),
);

AiProviderRoutePlan _groqPlan({
  bool available = true,
  AiUnavailableReason? reason,
}) => AiProviderRoutePlan(
  task: ModelTask.generalConversation,
  primaryProvider: AiActiveProvider.groq,
  primaryAvailable: available,
  preflightProvider: available ? AiActiveProvider.groq : AiActiveProvider.none,
  fallbackProvider: null,
  fallbackAvailable: false,
  fallbackPolicy: AiRuntimeFallbackPolicy.none,
  primaryUnavailableReason: reason,
  routeUnavailableReason: reason,
);

Future<void> _waitFor(
  bool Function() predicate, {
  String label = 'condition',
}) async {
  for (var attempt = 0; attempt < 400; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('$label was not reached before the focused test deadline.');
}

final class _ImmediateProbe implements AiRuntimeLiveProbe {
  @override
  Future<AiRuntimeLiveProbeResult> run({
    required AiRuntimeStatusFingerprint fingerprint,
    required AiProviderRoutePlan routePlan,
  }) async => AiRuntimeLiveProbeResult(
    fingerprint: fingerprint,
    status: AiRuntimeLiveStatus.ready,
    probedProvider: AiActiveProvider.groq,
    respondingProvider: AiActiveProvider.groq,
    receivedNonEmptyContent: true,
    failureCode: null,
    checkedAt: DateTime.utc(2026),
    latency: const Duration(milliseconds: 12),
  );
}

final class _DeferredProbe implements AiRuntimeLiveProbe {
  final Completer<AiRuntimeLiveProbeResult> _completer =
      Completer<AiRuntimeLiveProbeResult>();
  AiRuntimeStatusFingerprint? fingerprint;

  @override
  Future<AiRuntimeLiveProbeResult> run({
    required AiRuntimeStatusFingerprint fingerprint,
    required AiProviderRoutePlan routePlan,
  }) {
    this.fingerprint = fingerprint;
    return _completer.future;
  }

  void complete(AiRuntimeLiveProbeResult result) => _completer.complete(result);
}
