import 'dart:async';

import 'dart:ui' show SemanticsAction;

import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_runtime_status_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_runtime_status.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart';
import 'package:cashpilot_ai/features/settings/presentation/widgets/ai_diagnostics_settings_section.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/accessibility/acceptance_semantics.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows each Groq component under its precise role', (
    tester,
  ) async {
    final controller = _FakeRuntimeStatusController(_groqSnapshot());
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('Remote text provider'), findsOneWidget);
    expect(find.text('Groq'), findsOneWidget);
    expect(find.text('General conversation model'), findsOneWidget);
    expect(
      find.text(AiRuntimeModelCatalog.gatewayGeneralConversation),
      findsOneWidget,
    );
    expect(find.text('Financial explanation model'), findsOneWidget);
    expect(
      find.text(AiRuntimeModelCatalog.gatewayFinancialExplanation),
      findsOneWidget,
    );
    expect(find.text('Local command parser'), findsOneWidget);
    expect(find.text(AiRuntimeModelCatalog.localCommandParser), findsOneWidget);
    expect(find.text('Receipt Vision provider'), findsOneWidget);
    expect(find.text('Firebase AI'), findsOneWidget);
    expect(find.text('Groq primary'), findsOneWidget);
    expect(find.text('Firebase text fallback'), findsOneWidget);
    expect(find.text('Disabled'), findsOneWidget);
    expect(find.text('Gateway'), findsOneWidget);
    expect(find.text('Authentication'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('App Check'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Active AI model'), findsNothing);
    expect(find.text('Automatic provider routing'), findsNothing);
    expect(
      find.text(
        'Live Firebase Gemini is inactive. This test will not send a live AI request.',
      ),
      findsNothing,
    );
    if (cashPilotForceStopAcceptanceSemanticsEnabled) {
      for (final identifier in <String>[
        'ai_settings_remote_groq',
        'ai_settings_general_20b',
        'ai_settings_financial_120b',
        'ai_settings_local_parser',
        'ai_settings_receipt_firebase',
        'ai_settings_fallback_disabled',
        'ai_settings_gateway_available',
        'ai_settings_auth_ready',
        'ai_settings_appcheck_verified',
        'ai_settings_test_idle',
        'ai_settings_live_test',
      ]) {
        expect(
          find.bySemanticsIdentifier(identifier),
          findsOneWidget,
          reason: identifier,
        );
      }
      expect(
        tester.widget<CPListTile>(find.byType(CPListTile)).semanticsIdentifier,
        'ai_settings_live_test',
      );
      final liveTestSemantics = tester.getSemantics(
        find.bySemanticsIdentifier('ai_settings_live_test'),
      );
      expect(
        liveTestSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    }
  });

  testWidgets('live action exposes testing then successful Groq availability', (
    tester,
  ) async {
    final gate = Completer<void>();
    final initial = _groqSnapshot();
    final controller = _FakeRuntimeStatusController(
      initial,
      completion: _completed(initial, status: AiRuntimeLiveStatus.ready),
      gate: gate,
    );
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Test AI connection'));
    await tester.tap(find.text('Test AI connection'));
    await tester.pump();

    expect(controller.runCalls, 1);
    expect(find.text('Testing'), findsOneWidget);
    if (cashPilotForceStopAcceptanceSemanticsEnabled) {
      expect(
        find.bySemanticsIdentifier('ai_settings_test_testing'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('ai_settings_test_available'),
        findsNothing,
      );
    }
    gate.complete();
    await tester.pumpAndSettle();

    if (cashPilotForceStopAcceptanceSemanticsEnabled) {
      expect(
        find.bySemanticsIdentifier('ai_settings_test_testing'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('ai_settings_test_available'),
        findsOneWidget,
      );
    }
    expect(find.text('Last test status'), findsOneWidget);
    expect(find.text('Live-test latency'), findsOneWidget);
    expect(find.text('125 ms'), findsOneWidget);
    expect(find.text('Technical code'), findsNothing);
    expect(find.text('Not checked yet'), findsNothing);
    expect(find.textContaining('2026'), findsOneWidget);
    expect(
      find.text(
        'The Groq gateway, authentication, App Check, and streaming response are available.',
      ),
      findsWidgets,
    );
  });

  for (final entry in <(AiRuntimeLiveStatus, AiGatewayFailureCode, String)>[
    (
      AiRuntimeLiveStatus.gatewayAppCheckRequired,
      AiGatewayFailureCode.gatewayAppCheckRequired,
      'App Check unavailable',
    ),
    (
      AiRuntimeLiveStatus.gatewayUnavailable,
      AiGatewayFailureCode.gatewayUnavailable,
      'Gateway unavailable',
    ),
    (
      AiRuntimeLiveStatus.offline,
      AiGatewayFailureCode.networkFailure,
      'Offline',
    ),
    (
      AiRuntimeLiveStatus.groqRateLimited,
      AiGatewayFailureCode.groqRateLimited,
      'Rate limited',
    ),
    (
      AiRuntimeLiveStatus.groqStreamTimedOut,
      AiGatewayFailureCode.groqStreamTimedOut,
      'Timed out',
    ),
  ]) {
    testWidgets('maps ${entry.$2.name} to ${entry.$3}', (tester) async {
      final initial = _groqSnapshot();
      final status = _completed(
        initial,
        status: entry.$1,
        failureCode: entry.$2,
        content: false,
      );
      await tester.pumpWidget(_app(_FakeRuntimeStatusController(status)));
      await tester.pumpAndSettle();

      expect(find.text(entry.$3), findsWidgets);
      expect(find.text('Technical code'), findsOneWidget);
      expect(find.text(entry.$2.name), findsOneWidget);
    });
  }

  testWidgets(
    'missing Groq defines are explicit and never masquerade as local',
    (tester) async {
      final status = _groqSnapshot(configured: false);
      await tester.pumpWidget(_app(_FakeRuntimeStatusController(status)));
      await tester.pumpAndSettle();

      expect(find.text('Remote text provider'), findsOneWidget);
      expect(find.text('Groq'), findsOneWidget);
      expect(find.text('Configuration missing'), findsOneWidget);
      expect(find.text('Groq is not configured in this build.'), findsWidgets);
      expect(
        find.text(AiRuntimeModelCatalog.localCommandParser),
        findsOneWidget,
      );
      expect(
        find.text(AiRuntimeModelCatalog.gatewayGeneralConversation),
        findsNothing,
      );
    },
  );

  testWidgets('renders localized diagnostics at 320px in Arabic RTL', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        _FakeRuntimeStatusController(_groqSnapshot()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AiDiagnosticsSettingsSection), findsOneWidget);
    expect(find.text('مزوّد النص البعيد'), findsOneWidget);
    expect(find.text('نموذج المحادثة العامة'), findsOneWidget);
    expect(find.text('محلل الأوامر المحلي'), findsOneWidget);
    expect(find.text('Firebase AI'), findsOneWidget);
    expect(find.text('معطّل'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  _FakeRuntimeStatusController controller, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      aiRuntimeStatusControllerProvider.overrideWith(() => controller),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: CPTheme.dark(),
      home: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: AiDiagnosticsSettingsSection(),
        ),
      ),
    ),
  );
}

AiRuntimeStatusSnapshot _groqSnapshot({bool configured = true}) {
  final routePlan = AiProviderRoutePlan(
    task: ModelTask.generalConversation,
    primaryProvider: AiActiveProvider.groq,
    primaryAvailable: configured,
    preflightProvider: configured
        ? AiActiveProvider.groq
        : AiActiveProvider.none,
    fallbackProvider: null,
    fallbackAvailable: false,
    fallbackPolicy: AiRuntimeFallbackPolicy.none,
    primaryUnavailableReason: configured
        ? null
        : AiUnavailableReason.gatewayUrlMissing,
    routeUnavailableReason: configured
        ? null
        : AiUnavailableReason.gatewayUrlMissing,
  );
  return AiRuntimeStatusSnapshot(
    fingerprint: const AiRuntimeStatusFingerprint(
      '0000000000000000000000000000000000000000000000000000000000000000',
    ),
    routePlan: routePlan,
    appBuild: const AiAppBuildMetadata(version: '1.0.0', buildNumber: '1'),
    buildMode: AiRuntimeBuildMode.debug,
    environment: AiRuntimeEnvironment.staging,
    preference: AiRuntimeProviderPreference.groq,
    gatewayConfigured: configured,
    groqGatewayEnabled: configured,
    groqGeneralChatEnabled: configured,
    model: configured
        ? const AiRuntimeModelIdentity.gatewayManaged()
        : const AiRuntimeModelIdentity.unavailable(),
    firebaseTextFallbackEnabled: false,
    authenticated: true,
    authSessionGeneration: 7,
    firebasePlatformConfigured: true,
    firebaseInitialized: true,
    appCheckPhase: FirebaseAppCheckActivationPhase.available,
    appCheckUnavailableReason: null,
    appCheckProvider: AiRuntimeAppCheckProvider.debug,
    financialExplanationProvider: configured
        ? AiActiveProvider.groq
        : AiActiveProvider.none,
    financialExplanationModel:
        AiRuntimeModelCatalog.gatewayFinancialExplanation,
    receiptVisionProvider: AiActiveProvider.firebase,
    receiptVisionModel: 'firebase-receipt-vision',
    gatewayAvailability: configured
        ? AiRuntimeGatewayAvailability.available
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

AiRuntimeStatusSnapshot _completed(
  AiRuntimeStatusSnapshot initial, {
  required AiRuntimeLiveStatus status,
  AiGatewayFailureCode? failureCode,
  bool content = true,
}) {
  return initial.completeLiveTest(
    status: status,
    probedProvider: AiActiveProvider.groq,
    respondingProvider: status == AiRuntimeLiveStatus.ready
        ? AiActiveProvider.groq
        : null,
    receivedNonEmptyContent: content,
    failureCode: failureCode,
    checkedAt: DateTime.utc(2026, 8, 14, 12, 34),
    latency: const Duration(milliseconds: 125),
  );
}

class _FakeRuntimeStatusController extends AiRuntimeStatusController {
  _FakeRuntimeStatusController(this.initial, {this.completion, this.gate});

  final AiRuntimeStatusSnapshot initial;
  final AiRuntimeStatusSnapshot? completion;
  final Completer<void>? gate;
  int runCalls = 0;

  @override
  Future<AiRuntimeStatusSnapshot> build() async => initial;

  @override
  Future<AiRuntimeStatusSnapshot?> runLiveTest() async {
    runCalls += 1;
    state = AsyncData(initial.beginLiveTest());
    await gate?.future;
    final completed =
        completion ?? _completed(initial, status: AiRuntimeLiveStatus.ready);
    state = AsyncData(completed);
    return completed;
  }
}
