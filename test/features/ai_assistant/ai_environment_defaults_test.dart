import 'dart:convert';
import 'dart:io';

import 'package:cashpilot_ai/core/config/cash_pilot_app_version.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart'
    show aiRuntimeProviderPreferenceFor;
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_runtime_status_providers.dart'
    show aiRuntimeEnvironmentNameProvider;
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_runtime_status_probe.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_app_control_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_environment_defaults.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_gateway_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_runtime_status.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_provider_route_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _fingerprint = AiRuntimeStatusFingerprint(
  '0000000000000000000000000000000000000000000000000000000000000000',
);

void main() {
  group('plain Flutter build defaults', () {
    test('1. debug no-defines selects Groq', () {
      final consumers = _ResolvedConsumers.debug();

      expect(consumers.defaults.providerValue, 'groq');
      expect(
        consumers.runtime.resolvedConversationProviderPreference,
        AiConversationProviderPreference.groq,
      );
      expect(consumers.route.primaryProvider, AiActiveProvider.groq);
      expect(consumers.route.preflightProvider, AiActiveProvider.groq);
    });

    test('2. debug no-defines uses the staging gateway URL', () {
      final consumers = _ResolvedConsumers.debug();

      expect(consumers.defaults.environmentName, 'staging');
      expect(
        consumers.gateway.baseUri,
        Uri.parse(AiEnvironmentDefaults.stagingGatewayBaseUrl),
      );
      expect(consumers.gateway.isConfigured, isTrue);
      expect(consumers.runtime.diagnosticsEnabled, isFalse);
    });

    test('3. Firebase text fallback remains false', () {
      expect(
        _ResolvedConsumers.debug().gatewayFlags.aiFirebaseTextFallbackEnabled,
        isFalse,
      );
    });

    test('4. receipt vision remains on Firebase', () {
      final consumers = _ResolvedConsumers.debug();

      expect(consumers.gatewayFlags.aiFirebaseReceiptVisionEnabled, isTrue);
      expect(
        _snapshotFor(consumers).receiptVisionProvider,
        AiActiveProvider.firebase,
      );
    });

    test('5. financial commands retain the local parser', () {
      final consumers = _ResolvedConsumers.debug();

      expect(consumers.runtime.providerMode, AiProviderMode.localParserOnly);
      expect(
        _snapshotFor(consumers).localCommandParser,
        AiRuntimeModelCatalog.localCommandParser,
      );
    });

    test('6. staging enables bounded confirmed creates only', () {
      final consumers = _ResolvedConsumers.debug();

      expect(consumers.gatewayFlags.aiGroqToolSelectionEnabled, isFalse);
      expect(consumers.appControl.appControlEnabled, isTrue);
      expect(consumers.appControl.readToolsEnabled, isTrue);
      expect(consumers.appControl.createDraftsEnabled, isTrue);
      expect(consumers.appControl.confirmedExecutionEnabled, isTrue);
      expect(consumers.appControl.transferExecutionEnabled, isFalse);
      expect(consumers.appControl.updateDraftsEnabled, isFalse);
      expect(consumers.appControl.archiveDraftsEnabled, isFalse);
      expect(consumers.appControl.multiStepPlansEnabled, isFalse);
      expect(consumers.appControl.localDatasetScopeVerified, isTrue);
    });

    test('7. profile no-defines uses the same staging contract', () {
      final consumers = _ResolvedConsumers.profile();

      expect(consumers.defaults.environmentName, 'staging');
      expect(
        consumers.gateway.baseUri,
        Uri.parse(AiEnvironmentDefaults.stagingGatewayBaseUrl),
      );
      expect(consumers.route.preflightProvider, AiActiveProvider.groq);
      expect(consumers.runtime.diagnosticsEnabled, isFalse);
      expect(consumers.gatewayFlags.aiFirebaseTextFallbackEnabled, isFalse);
      expect(consumers.appControl.appControlEnabled, isTrue);
      expect(consumers.appControl.readToolsEnabled, isTrue);
      expect(consumers.appControl.createDraftsEnabled, isTrue);
      expect(consumers.appControl.confirmedExecutionEnabled, isTrue);
      expect(consumers.appControl.transferExecutionEnabled, isFalse);
      expect(consumers.appControl.updateDraftsEnabled, isFalse);
      expect(consumers.appControl.archiveDraftsEnabled, isFalse);
      expect(consumers.appControl.multiStepPlansEnabled, isFalse);
    });

    test(
      '8. release no production configuration is typed configuration-missing',
      () async {
        final consumers = _ResolvedConsumers.release();

        expect(consumers.defaults.environmentName, 'unspecified');
        expect(consumers.gateway.isConfigured, isFalse);
        expect(consumers.appControl.appControlEnabled, isFalse);
        expect(consumers.appControl.readToolsEnabled, isFalse);
        expect(consumers.appControl.createDraftsEnabled, isFalse);
        expect(consumers.appControl.confirmedExecutionEnabled, isFalse);
        expect(consumers.route.primaryProvider, AiActiveProvider.groq);
        expect(consumers.route.primaryAvailable, isFalse);
        expect(
          consumers.route.routeUnavailableReason,
          AiUnavailableReason.gatewayUrlMissing,
        );

        final result = await GroqAiRuntimeStatusProbe(
          groqGateway: _UnexpectedGateway(),
          egressGuard: null,
        ).run(fingerprint: _fingerprint, routePlan: consumers.route);
        final completed = _snapshotFor(consumers).completeLiveTest(
          status: result.status,
          probedProvider: result.probedProvider,
          respondingProvider: result.respondingProvider,
          receivedNonEmptyContent: result.receivedNonEmptyContent,
          failureCode: result.failureCode,
          checkedAt: result.checkedAt,
          latency: result.latency,
        );

        expect(result.status, AiRuntimeLiveStatus.groqNotConfigured);
        expect(
          completed.lastLiveTestStatus,
          AiRuntimeUiStatus.configurationMissing,
        );
      },
    );

    test('9. release never inherits or admits the staging URL', () {
      final absent = _ResolvedConsumers.release();
      final explicitStaging = _ResolvedConsumers(
        AiEnvironmentDefaults.resolve(
          isReleaseMode: true,
          inputs: const AiEnvironmentInputs(
            environment: AiEnvironmentValue<String>.present('staging'),
            gatewayBaseUrl: AiEnvironmentValue<String>.present(
              AiEnvironmentDefaults.stagingGatewayBaseUrl,
            ),
          ),
        ),
      );
      final mislabeledProduction = _ResolvedConsumers(
        AiEnvironmentDefaults.resolve(
          isReleaseMode: true,
          inputs: const AiEnvironmentInputs(
            environment: AiEnvironmentValue<String>.present('production'),
            gatewayBaseUrl: AiEnvironmentValue<String>.present(
              AiEnvironmentDefaults.stagingGatewayBaseUrl,
            ),
          ),
        ),
      );

      expect(absent.defaults.gatewayBaseUrl, isEmpty);
      expect(explicitStaging.defaults.gatewayBaseUrl, isEmpty);
      expect(explicitStaging.gateway.isConfigured, isFalse);
      expect(mislabeledProduction.defaults.gatewayBaseUrl, isEmpty);
      expect(mislabeledProduction.gateway.isConfigured, isFalse);
      expect(
        explicitStaging.defaults.gatewayBaseUrl,
        isNot(contains('staging')),
      );
    });

    test('10. explicit false overrides the implicit gateway true', () {
      final implicit = AiEnvironmentDefaults.resolve();
      final explicitFalse = AiEnvironmentDefaults.resolve(
        inputs: const AiEnvironmentInputs(
          groqGatewayEnabled: AiEnvironmentValue<bool>.present(false),
        ),
      );

      expect(implicit.groqGatewayEnabled, isTrue);
      expect(explicitFalse.groqGatewayEnabled, isFalse);
      expect(
        AiGatewayFeatureFlags.fromEnvironmentDefaults(
          explicitFalse,
        ).aiGroqGatewayEnabled,
        isFalse,
      );
    });

    test('11. explicit custom gateway URL overrides the staging URL', () {
      final consumers = _ResolvedConsumers(
        AiEnvironmentDefaults.resolve(
          inputs: const AiEnvironmentInputs(
            gatewayBaseUrl: AiEnvironmentValue<String>.present(
              'https://gateway.example.test',
            ),
          ),
        ),
      );

      expect(
        consumers.gateway.baseUri,
        Uri.parse('https://gateway.example.test'),
      );
    });

    test('12. explicit provider preference overrides Groq primary', () {
      final consumers = _ResolvedConsumers(
        AiEnvironmentDefaults.resolve(
          inputs: const AiEnvironmentInputs(
            provider: AiEnvironmentValue<String>.present('firebase'),
          ),
        ),
      );

      expect(
        consumers.runtime.resolvedConversationProviderPreference,
        AiConversationProviderPreference.firebase,
      );
      expect(consumers.route.primaryProvider, AiActiveProvider.firebase);
      expect(consumers.route.preflightProvider, AiActiveProvider.firebase);
    });
  });

  test('release admits only an explicit production HTTPS gateway', () {
    final production = _ResolvedConsumers(
      AiEnvironmentDefaults.resolve(
        isReleaseMode: true,
        inputs: const AiEnvironmentInputs(
          environment: AiEnvironmentValue<String>.present('production'),
          gatewayBaseUrl: AiEnvironmentValue<String>.present(
            'https://gateway.example.test',
          ),
        ),
      ),
    );
    final productionHttp = _ResolvedConsumers(
      AiEnvironmentDefaults.resolve(
        isReleaseMode: true,
        inputs: const AiEnvironmentInputs(
          environment: AiEnvironmentValue<String>.present('production'),
          gatewayBaseUrl: AiEnvironmentValue<String>.present(
            'http://gateway.example.test',
          ),
        ),
      ),
    );

    expect(production.defaults.hasExplicitProductionEnvironment, isTrue);
    expect(production.defaults.hasValidExplicitProductionGateway, isTrue);
    expect(production.gateway.isConfigured, isTrue);
    expect(production.route.preflightProvider, AiActiveProvider.groq);
    expect(productionHttp.defaults.hasValidExplicitProductionGateway, isFalse);
    expect(productionHttp.gateway.isConfigured, isFalse);
  });

  test(
    'release Firebase text routes require an approved production gateway',
    () {
      final fallbackWithoutProduction = _ResolvedConsumers(
        AiEnvironmentDefaults.resolve(
          isReleaseMode: true,
          inputs: const AiEnvironmentInputs(
            firebaseTextFallbackEnabled: AiEnvironmentValue<bool>.present(true),
          ),
        ),
      );
      final firebaseWithoutProduction = _ResolvedConsumers(
        AiEnvironmentDefaults.resolve(
          isReleaseMode: true,
          inputs: const AiEnvironmentInputs(
            provider: AiEnvironmentValue<String>.present('firebase'),
            currentWebEnabled: AiEnvironmentValue<bool>.present(true),
          ),
        ),
      );
      final firebaseWithHttp = _ResolvedConsumers(
        AiEnvironmentDefaults.resolve(
          isReleaseMode: true,
          inputs: const AiEnvironmentInputs(
            environment: AiEnvironmentValue<String>.present('production'),
            provider: AiEnvironmentValue<String>.present('firebase'),
            gatewayBaseUrl: AiEnvironmentValue<String>.present(
              'http://gateway.example.test',
            ),
            firebaseTextFallbackEnabled: AiEnvironmentValue<bool>.present(true),
          ),
        ),
      );
      final firebaseWithStaging = _ResolvedConsumers(
        AiEnvironmentDefaults.resolve(
          isReleaseMode: true,
          inputs: const AiEnvironmentInputs(
            environment: AiEnvironmentValue<String>.present('production'),
            provider: AiEnvironmentValue<String>.present('firebase'),
            gatewayBaseUrl: AiEnvironmentValue<String>.present(
              AiEnvironmentDefaults.stagingGatewayBaseUrl,
            ),
            firebaseTextFallbackEnabled: AiEnvironmentValue<bool>.present(true),
          ),
        ),
      );

      for (final consumers in <_ResolvedConsumers>[
        fallbackWithoutProduction,
        firebaseWithoutProduction,
        firebaseWithHttp,
        firebaseWithStaging,
      ]) {
        expect(consumers.defaults.hasValidExplicitProductionGateway, isFalse);
        expect(consumers.defaults.providerValue, 'groq');
        expect(consumers.defaults.currentWebEnabled, isFalse);
        expect(consumers.gatewayFlags.aiFirebaseTextFallbackEnabled, isFalse);
        expect(consumers.route.primaryProvider, AiActiveProvider.groq);
        expect(consumers.route.preflightProvider, AiActiveProvider.none);
        expect(
          consumers.route.routeUnavailableReason,
          AiUnavailableReason.gatewayUrlMissing,
        );
      }
    },
  );

  test('release Firebase text overrides require valid production approval', () {
    final consumers = _ResolvedConsumers(
      AiEnvironmentDefaults.resolve(
        isReleaseMode: true,
        inputs: const AiEnvironmentInputs(
          environment: AiEnvironmentValue<String>.present('production'),
          provider: AiEnvironmentValue<String>.present('firebase'),
          gatewayBaseUrl: AiEnvironmentValue<String>.present(
            'https://gateway.example.test',
          ),
          currentWebEnabled: AiEnvironmentValue<bool>.present(true),
          firebaseTextFallbackEnabled: AiEnvironmentValue<bool>.present(true),
        ),
      ),
    );

    expect(consumers.defaults.hasValidExplicitProductionGateway, isTrue);
    expect(consumers.defaults.providerValue, 'firebase');
    expect(consumers.defaults.currentWebEnabled, isTrue);
    expect(consumers.gatewayFlags.aiFirebaseTextFallbackEnabled, isTrue);
    expect(consumers.route.primaryProvider, AiActiveProvider.firebase);
    expect(consumers.route.preflightProvider, AiActiveProvider.firebase);
  });

  test('explicit diagnostics overrides the implicit staging false', () {
    final enabled = AiEnvironmentDefaults.resolve(
      inputs: const AiEnvironmentInputs(
        diagnostics: AiEnvironmentValue<bool>.present(true),
      ),
    );

    expect(AiEnvironmentDefaults.resolve().diagnosticsEnabled, isFalse);
    expect(
      AiRuntimeConfig.fromEnvironmentDefaults(enabled).diagnosticsEnabled,
      isTrue,
    );
  });

  test('runtime status and app-control consume the canonical environment', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(AiEnvironmentDefaults.current.environmentName, 'staging');
    expect(
      AiRuntimeConfig.current.resolvedConversationProviderPreference,
      AiConversationProviderPreference.groq,
    );
    expect(AiGatewayFeatureFlags.current.aiGroqGatewayEnabled, isTrue);
    expect(AiGatewayFeatureFlags.current.aiGroqGeneralChatEnabled, isTrue);
    expect(
      AiGatewayFeatureFlags.current.aiFirebaseTextFallbackEnabled,
      isFalse,
    );
    expect(
      AiGatewayRuntimeConfig.current.baseUri,
      Uri.parse(AiEnvironmentDefaults.stagingGatewayBaseUrl),
    );
    expect(container.read(aiRuntimeEnvironmentNameProvider), 'staging');
    expect(AiAppControlFeatureFlags.current.appControlEnabled, isTrue);
    expect(AiAppControlFeatureFlags.current.readToolsEnabled, isTrue);
    expect(AiAppControlFeatureFlags.current.createDraftsEnabled, isTrue);
    expect(AiAppControlFeatureFlags.current.confirmedExecutionEnabled, isTrue);
    expect(AiAppControlFeatureFlags.current.transferExecutionEnabled, isFalse);
    expect(AiAppControlFeatureFlags.current.multiStepPlansEnabled, isFalse);
    expect(AiAppControlFeatureFlags.current.localDatasetScopeVerified, isTrue);
  });

  test('canonical staging JSON matches defaults plus approved mutations', () {
    final defaults = AiEnvironmentDefaults.resolve();
    final decoded = jsonDecode(
      File('config/groq_staging.json').readAsStringSync(),
    );

    expect(decoded, <String, String>{
      AiEnvironmentKeys.environment: defaults.environmentName,
      AiEnvironmentKeys.provider: defaults.providerValue,
      AiEnvironmentKeys.diagnostics: defaults.diagnosticsEnabled.toString(),
      AiEnvironmentKeys.groqGatewayEnabled: defaults.groqGatewayEnabled
          .toString(),
      AiEnvironmentKeys.groqGeneralChatEnabled: defaults.groqGeneralChatEnabled
          .toString(),
      AiEnvironmentKeys.groqFinancialExplanationEnabled: defaults
          .groqFinancialExplanationEnabled
          .toString(),
      AiEnvironmentKeys.groqToolSelectionEnabled: defaults
          .groqToolSelectionEnabled
          .toString(),
      AiEnvironmentKeys.groqArabicSpecialistEnabled: defaults
          .groqArabicSpecialistEnabled
          .toString(),
      AiEnvironmentKeys.currentWebEnabled: defaults.currentWebEnabled
          .toString(),
      AiEnvironmentKeys.firebaseTextFallbackEnabled: defaults
          .firebaseTextFallbackEnabled
          .toString(),
      AiEnvironmentKeys.firebaseReceiptVisionEnabled: defaults
          .firebaseReceiptVisionEnabled
          .toString(),
      'CASH_PILOT_AI_UPDATE_DRAFTS_ENABLED': 'true',
      'CASH_PILOT_AI_ARCHIVE_DRAFTS_ENABLED': 'true',
      AiEnvironmentKeys.gatewayBaseUrl: defaults.gatewayBaseUrl,
      'CASH_PILOT_ACCOUNT_DELETION_GATEWAY_BASE_URL':
          'https://cashpilot-account-deletion-staging-yfgt2ypuvq-ew.a.run.app',
      AiEnvironmentKeys.clientVersion: defaults.clientVersion,
    });
  });

  test('synchronous client version source stays aligned with pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([^\s#]+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull);
    expect(match!.group(1), CashPilotAppVersion.pubspecVersion);
    expect(
      AiEnvironmentDefaults.resolve().clientVersion,
      CashPilotAppVersion.version,
    );
  });
}

final class _ResolvedConsumers {
  _ResolvedConsumers(this.defaults)
    : runtime = AiRuntimeConfig.fromEnvironmentDefaults(defaults),
      gatewayFlags = AiGatewayFeatureFlags.fromEnvironmentDefaults(defaults),
      gateway = AiGatewayRuntimeConfig.fromEnvironmentDefaults(defaults),
      appControl = AiAppControlFeatureFlags.resolve(
        environmentValue: defaults.environmentName,
        isReleaseMode: defaults.isReleaseMode,
        hasExplicitProductionEnvironment:
            defaults.hasExplicitProductionEnvironment,
      ) {
    route = const AiProviderRouteResolver().resolveGeneralConversation(
      AiProviderRouteInputs(
        preference: aiRuntimeProviderPreferenceFor(
          runtime.resolvedConversationProviderPreference,
        ),
        agentEnabled: true,
        groqGatewayEnabled: gatewayFlags.aiGroqGatewayEnabled,
        groqGeneralChatEnabled: gatewayFlags.aiGroqGeneralChatEnabled,
        groqConfigured: gateway.isConfigured,
        remotePreflightReady: true,
        firebaseTextFallbackEnabled: gatewayFlags.aiFirebaseTextFallbackEnabled,
        firebaseConversationReady: true,
        platformConfigured: true,
        firebaseInitialized: true,
        appCheckAvailable: true,
        appCheckAttemptable: true,
        authenticated: true,
      ),
    );
  }

  factory _ResolvedConsumers.debug() =>
      _ResolvedConsumers(AiEnvironmentDefaults.resolve());

  factory _ResolvedConsumers.profile() =>
      _ResolvedConsumers(AiEnvironmentDefaults.resolve(isProfileMode: true));

  factory _ResolvedConsumers.release() =>
      _ResolvedConsumers(AiEnvironmentDefaults.resolve(isReleaseMode: true));

  final AiEnvironmentDefaults defaults;
  final AiRuntimeConfig runtime;
  final AiGatewayFeatureFlags gatewayFlags;
  final AiGatewayRuntimeConfig gateway;
  final AiAppControlFeatureFlags appControl;
  late final AiProviderRoutePlan route;
}

AiRuntimeStatusSnapshot _snapshotFor(_ResolvedConsumers consumers) {
  final gatewayConfigured = consumers.gateway.isConfigured;
  return AiRuntimeStatusSnapshot(
    fingerprint: _fingerprint,
    routePlan: consumers.route,
    appBuild: const AiAppBuildMetadata(
      version: CashPilotAppVersion.version,
      buildNumber: CashPilotAppVersion.buildNumber,
    ),
    buildMode: consumers.defaults.isReleaseMode
        ? AiRuntimeBuildMode.release
        : consumers.defaults.isProfileMode
        ? AiRuntimeBuildMode.profile
        : AiRuntimeBuildMode.debug,
    environment: switch (consumers.defaults.environmentName) {
      'staging' => AiRuntimeEnvironment.staging,
      'production' => AiRuntimeEnvironment.production,
      'unspecified' => AiRuntimeEnvironment.unspecified,
      _ => AiRuntimeEnvironment.other,
    },
    preference: aiRuntimeProviderPreferenceFor(
      consumers.runtime.resolvedConversationProviderPreference,
    ),
    gatewayConfigured: gatewayConfigured,
    groqGatewayEnabled: consumers.gatewayFlags.aiGroqGatewayEnabled,
    groqGeneralChatEnabled: consumers.gatewayFlags.aiGroqGeneralChatEnabled,
    model: gatewayConfigured
        ? const AiRuntimeModelIdentity.gatewayManaged()
        : const AiRuntimeModelIdentity.unavailable(),
    firebaseTextFallbackEnabled:
        consumers.gatewayFlags.aiFirebaseTextFallbackEnabled,
    authenticated: true,
    authSessionGeneration: 1,
    firebasePlatformConfigured: true,
    firebaseInitialized: true,
    appCheckPhase: FirebaseAppCheckActivationPhase.available,
    appCheckUnavailableReason: null,
    appCheckProvider: AiRuntimeAppCheckProvider.debug,
    financialExplanationProvider:
        consumers.gatewayFlags.aiGroqFinancialExplanationEnabled
        ? AiActiveProvider.groq
        : AiActiveProvider.none,
    financialExplanationModel:
        AiRuntimeModelCatalog.gatewayFinancialExplanation,
    receiptVisionProvider: consumers.gatewayFlags.aiFirebaseReceiptVisionEnabled
        ? AiActiveProvider.firebase
        : AiActiveProvider.none,
    receiptVisionModel: 'firebase-receipt-vision',
    gatewayAvailability: gatewayConfigured
        ? AiRuntimeGatewayAvailability.notChecked
        : AiRuntimeGatewayAvailability.notConfigured,
    liveStatus: AiRuntimeLiveStatus.notChecked,
    probedProvider: null,
    respondingProvider: null,
    receivedNonEmptyContent: false,
    gatewayFailureCode: null,
    checkedAt: null,
    lastLiveTestLatency: null,
  );
}

final class _UnexpectedGateway implements AiAgentModelGateway {
  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) => throw StateError('Release without a URL must not start a session.');
}
