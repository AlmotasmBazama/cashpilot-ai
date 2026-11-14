import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../auth/application/providers/auth_providers.dart';
import '../../data/config/ai_environment_defaults.dart';
import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_runtime_status.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';
import '../agent/ai_provider_egress_guard.dart';
import '../services/ai_runtime_status_builder.dart';
import '../services/ai_runtime_status_probe.dart';
import 'ai_agent_providers.dart';
import 'ai_assistant_providers.dart';

typedef AiRuntimeGatewayHealthCheck = Future<bool> Function();

final aiAppBuildMetadataProvider = FutureProvider<AiAppBuildMetadata>((
  _,
) async {
  try {
    final package = await PackageInfo.fromPlatform();
    return AiAppBuildMetadata(
      version: _nonEmptyOrNull(package.version),
      buildNumber: _nonEmptyOrNull(package.buildNumber),
    );
  } on Object {
    return const AiAppBuildMetadata.unavailable();
  }
}, name: 'aiAppBuildMetadataProvider');

final aiRuntimeBuildModeProvider = Provider<AiRuntimeBuildMode>((_) {
  if (kReleaseMode) return AiRuntimeBuildMode.release;
  if (kProfileMode) return AiRuntimeBuildMode.profile;
  return AiRuntimeBuildMode.debug;
}, name: 'aiRuntimeBuildModeProvider');

final aiRuntimeEnvironmentNameProvider = Provider<String>(
  (_) => normalizeAiRuntimeEnvironmentName(
    AiEnvironmentDefaults.current.environmentName,
  ),
  name: 'aiRuntimeEnvironmentNameProvider',
);

final aiRuntimeAppCheckProviderProvider = Provider<AiRuntimeAppCheckProvider>(
  (_) => _currentAppCheckProvider(),
  name: 'aiRuntimeAppCheckProviderProvider',
);

final aiRuntimeStatusSeedProvider = FutureProvider<AiRuntimeStatusSnapshot>((
  ref,
) async {
  final routePlan = ref.watch(aiGeneralConversationRoutePlanProvider);
  final runtime = ref.watch(aiRuntimeConfigProvider);
  final preference = aiRuntimeProviderPreferenceFor(
    runtime.resolvedConversationProviderPreference,
  );
  final gatewayFlags = ref.watch(aiGatewayFeatureFlagsProvider);
  final gatewayConfig = ref.watch(aiGatewayRuntimeConfigProvider);
  final modelConfig = ref.watch(aiModelConfigProvider);
  final appCheck = ref.watch(aiAppCheckActivationSnapshotProvider);
  final auth = ref.watch(currentAuthUserProvider);
  final platformConfigured = ref.watch(aiFirebasePlatformConfiguredProvider);
  final firebaseInitialized = ref.watch(aiFirebaseInitializedProvider);
  final selectedGeneralProvider =
      routePlan.preflightProvider == AiActiveProvider.none
      ? routePlan.primaryProvider
      : routePlan.preflightProvider;
  final generalModel = switch (selectedGeneralProvider) {
    AiActiveProvider.groq => const AiRuntimeModelIdentity.gatewayManaged(),
    AiActiveProvider.firebase => AiRuntimeModelIdentity(
      source: AiRuntimeModelSource.clientConfigured,
      safeModelId: modelConfig.generalConversationModel,
    ),
    _
        when routePlan.primaryProvider == AiActiveProvider.groq &&
            gatewayConfig.isConfigured &&
            gatewayFlags.aiGroqGatewayEnabled &&
            gatewayFlags.aiGroqGeneralChatEnabled =>
      const AiRuntimeModelIdentity.gatewayManaged(),
    _ => const AiRuntimeModelIdentity.unavailable(),
  };
  final automatic =
      preference == AiRuntimeProviderPreference.auto ||
      preference == AiRuntimeProviderPreference.legacy;
  final groqFinancialSelected =
      (preference == AiRuntimeProviderPreference.groq || automatic) &&
      gatewayFlags.aiGroqGatewayEnabled &&
      (gatewayFlags.aiGroqGeneralChatEnabled ||
          gatewayFlags.aiGroqFinancialExplanationEnabled);
  final groqFinancialConfigured =
      groqFinancialSelected &&
      gatewayConfig.isConfigured &&
      gatewayFlags.financialGatewayEnabledFor('en');
  final firebaseFinancialConfigured =
      (preference == AiRuntimeProviderPreference.firebase ||
      (gatewayFlags.aiFirebaseTextFallbackEnabled && groqFinancialSelected));
  final financialProvider = groqFinancialConfigured
      ? AiActiveProvider.groq
      : firebaseFinancialConfigured
      ? AiActiveProvider.firebase
      : AiActiveProvider.none;
  final financialModel = financialProvider == AiActiveProvider.firebase
      ? modelConfig.financialAnalysisModel
      : AiRuntimeModelCatalog.gatewayFinancialExplanation;
  final receiptProvider = gatewayFlags.aiFirebaseReceiptVisionEnabled
      ? AiActiveProvider.firebase
      : AiActiveProvider.none;
  final environmentName = ref.watch(aiRuntimeEnvironmentNameProvider);
  return buildAiRuntimeStatusSnapshot(
    AiRuntimeStatusConfiguration(
      routePlan: routePlan,
      appBuild: await ref.watch(aiAppBuildMetadataProvider.future),
      buildMode: ref.watch(aiRuntimeBuildModeProvider),
      environment: aiRuntimeEnvironmentForName(environmentName),
      normalizedEnvironmentName: environmentName,
      preference: preference,
      gatewayConfigured: gatewayConfig.isConfigured,
      groqGatewayEnabled: gatewayFlags.aiGroqGatewayEnabled,
      groqGeneralChatEnabled: gatewayFlags.aiGroqGeneralChatEnabled,
      normalizedGatewayOrigin: normalizeAiRuntimeGatewayOrigin(
        gatewayConfig.baseUri,
      ),
      gatewayClientVersion: gatewayConfig.clientVersion,
      model: generalModel,
      firebaseTextFallbackEnabled: gatewayFlags.aiFirebaseTextFallbackEnabled,
      authenticated: auth != null,
      authSessionGeneration: auth?.authSessionGeneration,
      authIsAnonymous: auth?.isAnonymous,
      authTenantConfigured: auth?.tenantId != null,
      firebasePlatformConfigured: platformConfigured,
      firebaseInitialized: firebaseInitialized,
      appCheckPhase: appCheck.phase,
      appCheckUnavailableReason: appCheck.reason,
      appCheckProvider: ref.watch(aiRuntimeAppCheckProviderProvider),
      financialExplanationProvider: financialProvider,
      financialExplanationModel: financialModel,
      receiptVisionProvider: receiptProvider,
      receiptVisionModel: modelConfig.modelFor(ModelTask.receiptAnalysis),
    ),
  );
}, name: 'aiRuntimeStatusSeedProvider');

final aiRuntimeGatewayHealthCheckProvider =
    Provider<AiRuntimeGatewayHealthCheck>(
      (ref) => () async {
        final health = await ref
            .read(groqConversationGatewayProvider)
            .healthCheck()
            .timeout(const Duration(seconds: 6));
        return health.reachable;
      },
      name: 'aiRuntimeGatewayHealthCheckProvider',
    );

final aiRuntimeStatusEgressGuardProvider = Provider<AiProviderEgressGuard?>((
  ref,
) {
  final expectedAuthSession = ref
      .watch(currentAuthUserProvider)
      ?.sessionIdentity;
  if (expectedAuthSession == null) return null;
  final expectedOwnerScope = ref.watch(aiToolOwnerScopeBindingProvider);
  final memoryAccess = AiAgentMemoryAccess(
    ownerScope: expectedOwnerScope,
    assertActive: () {
      if (ref.read(aiToolOwnerScopeBindingProvider) != expectedOwnerScope) {
        throw const AiProviderEgressRevokedException();
      }
    },
  );
  return FirebaseAiProviderEgressGuard(
    expectedAuthSession: expectedAuthSession,
    expectedOwnerScope: expectedOwnerScope,
    currentOwnerScope: () => ref.read(aiToolOwnerScopeBindingProvider),
    memoryAccess: memoryAccess,
    authSessionGuard: ref.watch(firebaseAuthSessionEpochGuardProvider),
    authOperationCoordinator: ref.watch(
      firebaseAuthOperationCoordinatorProvider,
    ),
  );
}, name: 'aiRuntimeStatusEgressGuardProvider');

final aiRuntimeLiveProbeProvider = Provider<AiRuntimeLiveProbe>(
  (ref) => GroqAiRuntimeStatusProbe(
    groqGateway: ref.watch(groqAiAgentModelGatewayProvider),
    egressGuard: ref.watch(aiRuntimeStatusEgressGuardProvider),
  ),
  name: 'aiRuntimeLiveProbeProvider',
);

final aiRuntimeStatusControllerProvider =
    AsyncNotifierProvider<AiRuntimeStatusController, AiRuntimeStatusSnapshot>(
      AiRuntimeStatusController.new,
      name: 'aiRuntimeStatusControllerProvider',
    );

/// Process-memory runtime truth for Settings and Chat diagnostics. Provider
/// overrides may subclass this controller in widget tests; production state is
/// never persisted.
class AiRuntimeStatusController extends AsyncNotifier<AiRuntimeStatusSnapshot> {
  var _configurationGeneration = 0;
  var _liveOperationGeneration = 0;

  @override
  Future<AiRuntimeStatusSnapshot> build() async {
    final configurationGeneration = ++_configurationGeneration;
    _liveOperationGeneration++;
    ref.onDispose(() {
      _configurationGeneration++;
      _liveOperationGeneration++;
    });
    final seed = await ref.watch(aiRuntimeStatusSeedProvider.future);
    if (!seed.gatewayConfigured) {
      return seed.copyWith(
        gatewayAvailability: AiRuntimeGatewayAvailability.notConfigured,
      );
    }
    final checking = seed.copyWith(
      gatewayAvailability: AiRuntimeGatewayAvailability.checking,
    );
    unawaited(
      Future<void>(
        () => _refreshGatewayHealth(
          expected: checking,
          configurationGeneration: configurationGeneration,
        ),
      ),
    );
    return checking;
  }

  Future<void> refreshGatewayHealth() async {
    final current = _currentSnapshot;
    if (current == null) return;
    if (!current.gatewayConfigured) {
      state = AsyncData(
        current.copyWith(
          gatewayAvailability: AiRuntimeGatewayAvailability.notConfigured,
        ),
      );
      return;
    }
    final checking = current.copyWith(
      gatewayAvailability: AiRuntimeGatewayAvailability.checking,
    );
    state = AsyncData(checking);
    await _refreshGatewayHealth(
      expected: checking,
      configurationGeneration: _configurationGeneration,
    );
  }

  Future<AiRuntimeStatusSnapshot?> runLiveTest() async {
    final current = _currentSnapshot;
    if (current == null) return null;
    final configurationGeneration = _configurationGeneration;
    final operationGeneration = ++_liveOperationGeneration;
    final checking = current.beginLiveTest();
    state = AsyncData(checking);
    final fallbackStartedAt = DateTime.now().toUtc();
    final fallbackStopwatch = Stopwatch()..start();
    late AiRuntimeLiveProbeResult result;
    try {
      result = await ref
          .read(aiRuntimeLiveProbeProvider)
          .run(
            fingerprint: checking.fingerprint,
            routePlan: checking.routePlan,
          );
    } on AiProviderEgressRevokedException {
      result = _escapedLiveProbeResult(
        checking: checking,
        status: AiRuntimeLiveStatus.cancelled,
        failureCode: null,
        checkedAt: fallbackStartedAt,
        latency: fallbackStopwatch.elapsed,
      );
    } on TimeoutException {
      result = _escapedLiveProbeResult(
        checking: checking,
        status: AiRuntimeLiveStatus.groqStreamTimedOut,
        failureCode: AiGatewayFailureCode.groqStreamTimedOut,
        checkedAt: fallbackStartedAt,
        latency: fallbackStopwatch.elapsed,
      );
    } on Object {
      result = _escapedLiveProbeResult(
        checking: checking,
        status: AiRuntimeLiveStatus.unknownTemporaryFailure,
        failureCode: AiGatewayFailureCode.unknownTemporaryFailure,
        checkedAt: fallbackStartedAt,
        latency: fallbackStopwatch.elapsed,
      );
    } finally {
      fallbackStopwatch.stop();
    }
    if (!_isCurrent(
          fingerprint: checking.fingerprint,
          configurationGeneration: configurationGeneration,
        ) ||
        operationGeneration != _liveOperationGeneration ||
        result.fingerprint != checking.fingerprint) {
      return null;
    }
    final latest = _currentSnapshot;
    if (latest == null || latest.liveStatus != AiRuntimeLiveStatus.checking) {
      return null;
    }
    final completed = latest.completeLiveTest(
      status: result.status,
      probedProvider: result.probedProvider,
      respondingProvider: result.respondingProvider,
      receivedNonEmptyContent: result.receivedNonEmptyContent,
      failureCode: result.failureCode,
      checkedAt: result.checkedAt,
      latency: result.latency,
    );
    state = AsyncData(completed);
    return completed;
  }

  Future<void> _refreshGatewayHealth({
    required AiRuntimeStatusSnapshot expected,
    required int configurationGeneration,
  }) async {
    bool reachable;
    try {
      reachable = await ref
          .read(aiRuntimeGatewayHealthCheckProvider)()
          .timeout(const Duration(seconds: 7));
    } on Object {
      reachable = false;
    }
    if (!_isCurrent(
      fingerprint: expected.fingerprint,
      configurationGeneration: configurationGeneration,
    )) {
      return;
    }
    final current = _currentSnapshot;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        gatewayAvailability: reachable
            ? AiRuntimeGatewayAvailability.available
            : AiRuntimeGatewayAvailability.unavailable,
      ),
    );
  }

  bool _isCurrent({
    required AiRuntimeStatusFingerprint fingerprint,
    required int configurationGeneration,
  }) {
    return ref.mounted &&
        configurationGeneration == _configurationGeneration &&
        _currentSnapshot?.fingerprint == fingerprint;
  }

  AiRuntimeStatusSnapshot? get _currentSnapshot => switch (state) {
    AsyncData(:final value) => value,
    _ => null,
  };
}

AiRuntimeLiveProbeResult _escapedLiveProbeResult({
  required AiRuntimeStatusSnapshot checking,
  required AiRuntimeLiveStatus status,
  required AiGatewayFailureCode? failureCode,
  required DateTime checkedAt,
  required Duration latency,
}) => AiRuntimeLiveProbeResult(
  fingerprint: checking.fingerprint,
  status: status,
  probedProvider: checking.routePlan.primaryProvider == AiActiveProvider.groq
      ? AiActiveProvider.groq
      : null,
  respondingProvider: null,
  receivedNonEmptyContent: false,
  failureCode: failureCode,
  checkedAt: checkedAt,
  latency: latency,
);

String? _nonEmptyOrNull(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

AiRuntimeAppCheckProvider _currentAppCheckProvider() {
  if (kIsWeb) {
    return kReleaseMode
        ? AiRuntimeAppCheckProvider.recaptchaEnterprise
        : AiRuntimeAppCheckProvider.debug;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android =>
      kReleaseMode
          ? AiRuntimeAppCheckProvider.playIntegrity
          : AiRuntimeAppCheckProvider.debug,
    TargetPlatform.iOS || TargetPlatform.macOS =>
      kReleaseMode
          ? AiRuntimeAppCheckProvider.appAttestWithDeviceCheckFallback
          : AiRuntimeAppCheckProvider.debug,
    TargetPlatform.windows => AiRuntimeAppCheckProvider.windowsDebug,
    TargetPlatform.linux ||
    TargetPlatform.fuchsia => AiRuntimeAppCheckProvider.unknown,
  };
}
