import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/receipts/application/receipt_capture_state.dart';
import 'package:cashpilot_ai/features/receipts/domain/config/receipt_feature_config.dart';
import 'package:cashpilot_ai/features/receipts/application/receipt_providers.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_privacy_consent_store.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_analysis_draft.dart';
import 'package:cashpilot_ai/features/receipts/presentation/pages/receipt_capture_screen.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('receipt capture remains usable at 320 logical pixels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiptFeatureConfigProvider.overrideWithValue(
            const ReceiptFeatureConfig(enabled: true),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReceiptCaptureScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('receipt_take_photo_button')), findsOneWidget);
    expect(
      find.byKey(const Key('receipt_import_image_button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('receipt preparation shows a stage and user cancellation', (
    tester,
  ) async {
    late _BusyReceiptCaptureController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiptFeatureConfigProvider.overrideWithValue(
            const ReceiptFeatureConfig(enabled: true),
          ),
          receiptCaptureControllerProvider.overrideWith(
            () => controller = _BusyReceiptCaptureController(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReceiptCaptureScreen(),
        ),
      ),
    );
    // The visible LinearProgressIndicator is intentionally indeterminate while
    // preparation is active, so waiting for every animation frame to settle
    // would never complete.
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('receipt_cancel_processing_button')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    // Keep the full 48dp target inside the compact test viewport. A partially
    // visible control is not sufficient for an accessible hit target.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -64));
    await tester.pump();

    expect(find.text('Preparing the receipt image…'), findsOneWidget);
    expect(
      find.byKey(const Key('receipt_cancel_processing_button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('receipt_cancel_processing_button')));
    await tester.pumpAndSettle();

    expect(controller.cancelCount, 1);
    expect(find.text('Preparing the receipt image…'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('receipt_take_photo_button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'auto conversation mode requests receipt consent and authorizes analysis',
    (tester) async {
      final runtime = AiRuntimeConfig.resolve();
      expect(runtime.providerMode, AiProviderMode.localParserOnly);
      expect(
        runtime.resolvedConversationProviderPreference,
        AiConversationProviderPreference.auto,
      );

      final owner = OwnerScopeDerivation.fromConfirmedFirebaseUid(
        'receipt-ui-owner',
        confirmedAt: DateTime.utc(2026),
      );
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final session = ScopedAppDatabaseSession(
        database: database,
        scope: owner,
      );
      final consentStore = _TrackingReceiptConsentStore();
      late _TrackingReceiptCaptureController controller;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            confirmedOwnerScopeProvider.overrideWithValue(owner),
            scopedAppDatabaseSessionProvider.overrideWithValue(session),
            receiptFeatureConfigProvider.overrideWithValue(
              const ReceiptFeatureConfig(enabled: true),
            ),
            aiAssistantCapabilitiesProvider.overrideWithValue(
              _receiptVisionCapabilities,
            ),
            receiptPrivacyConsentStoreProvider.overrideWithValue(consentStore),
            receiptCaptureControllerProvider.overrideWith(
              () => controller = _TrackingReceiptCaptureController(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ReceiptCaptureScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('receipt_import_image_button')));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      final l10n = AppLocalizations.of(tester.element(dialog));

      await tester.tap(find.text(l10n.analyzeReceipt));
      await tester.pumpAndSettle();

      expect(consentStore.acceptCount, 1);
      expect(consentStore.hasAccepted, isTrue);
      expect(controller.startCount, 1);
      expect(controller.lastFromGallery, isTrue);
      expect(controller.lastAnalyzeRemotely, isTrue);
      expect(controller.lastLocale, const Locale('en'));
    },
  );
}

const _receiptVisionCapabilities = AiAssistantCapabilities(
  directConversationAvailable: true,
  generalConversationAvailable: true,
  currentKnowledgeAvailable: false,
  personalFinancialAnalysisAvailable: false,
  financialDraftsAvailable: false,
  confirmedExecutionAvailable: false,
  receiptVisionAvailable: true,
  navigationAvailable: false,
  activeProvider: AiActiveProvider.firebase,
  unavailableReason: null,
  retryable: false,
  platformSupported: true,
);

final class _TrackingReceiptCaptureController extends ReceiptCaptureController {
  int startCount = 0;
  bool? lastFromGallery;
  bool? lastAnalyzeRemotely;
  Locale? lastLocale;

  @override
  ReceiptCaptureState build() => const ReceiptCaptureState();

  @override
  Future<ReceiptAnalysisDraft?> start({
    required bool fromGallery,
    required bool analyzeRemotely,
    required Locale locale,
  }) async {
    startCount += 1;
    lastFromGallery = fromGallery;
    lastAnalyzeRemotely = analyzeRemotely;
    lastLocale = locale;
    return null;
  }
}

final class _BusyReceiptCaptureController extends ReceiptCaptureController {
  int cancelCount = 0;

  @override
  ReceiptCaptureState build() => const ReceiptCaptureState(
    isBusy: true,
    stage: ReceiptCaptureStage.selectingAndPreparing,
  );

  @override
  void cancel() {
    cancelCount += 1;
    state = const ReceiptCaptureState();
  }
}

final class _TrackingReceiptConsentStore implements ReceiptPrivacyConsentStore {
  bool _accepted = false;
  int acceptCount = 0;

  @override
  bool get hasAccepted => _accepted;

  @override
  Future<void> accept() async {
    acceptCount += 1;
    _accepted = true;
  }

  @override
  Future<void> clear() async {
    _accepted = false;
  }
}
