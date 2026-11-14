import 'dart:convert';

import 'package:cashpilot_ai/app/app.dart';
import 'package:cashpilot_ai/app/router/app_route_paths.dart';
import 'package:cashpilot_ai/app/router/app_router.dart';
import 'package:cashpilot_ai/app/router/navigation_transition_diagnostics.dart';
import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/storage/hive_box_names.dart';
import 'package:cashpilot_ai/core/storage/owner_scoped_storage_keys.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/accounts/presentation/pages/accounts_screen.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_app_control_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/effective_ai_app_control_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_app_control_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/pages/ai_assistant_screen.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:cashpilot_ai/features/data_deletion/application/account_deletion_startup_recovery_coordinator.dart';
import 'package:cashpilot_ai/features/data_deletion/application/data_deletion_providers.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live routed chat stays on AI, retains history, and keeps governed navigation',
    (tester) async {
      await Hive.initFlutter();
      if (!Hive.isBoxOpen(HiveBoxNames.settings)) {
        await Hive.openBox<dynamic>(HiveBoxNames.settings);
      }
      addTearDown(Hive.close);
      await const DefaultFirebaseInitializer().initialize();
      final appCheckState = await defaultFirebaseAppCheckActivationController
          .activate();
      expect(
        appCheckState.isAvailable,
        isTrue,
        reason: 'App Check activation failed: ${appCheckState.safeCode}',
      );
      final firebaseAuth = firebase_auth.FirebaseAuth.instance;
      if (firebaseAuth.currentUser != null) {
        // Never reuse an identity that may belong to a deletion test or carry
        // a durable quarantine from an interrupted prior run.
        await firebaseAuth.signOut();
      }
      final stamp = DateTime.now().microsecondsSinceEpoch;
      await firebaseAuth.createUserWithEmailAndPassword(
        email: 'cashpilot-release-$stamp@example.com',
        password: 'Cp!${stamp}Az9',
      );
      final firebaseUser = firebaseAuth.currentUser!;
      final ownerScope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
        firebaseUser.uid,
      );
      final ownerKeys = OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity(
        firebaseUid: firebaseUser.uid,
        ownerScope: ownerScope,
      );
      final settingsBox = Hive.box<dynamic>(HiveBoxNames.settings);
      // This test exercises AI/navigation, not backup startup repair. Establish
      // a completed synthetic backup snapshot so the production repair cannot
      // transiently fence this fresh owner while Dashboard is first built.
      await settingsBox.put(ownerKeys.backupEnabled, true);
      await settingsBox.put(ownerKeys.backupConsentGeneration, 1);
      await settingsBox.put(ownerKeys.backupInitialSnapshotComplete, true);
      addTearDown(() async {
        await settingsBox.deleteAll(ownerKeys.accountDeletionPreferenceKeys);
        try {
          if (firebaseAuth.currentUser?.uid == firebaseUser.uid) {
            await firebaseAuth.currentUser?.delete();
          }
        } on Object {
          // Cleanup is best-effort and must not hide the navigation result.
        }
        try {
          await firebaseAuth.signOut();
        } on Object {
          // The test identity may already have been deleted and signed out.
        }
      });
      final routedTestUser = AuthUser(
        uid: firebaseUser.uid,
        emailVerified: true,
        isAnonymous: false,
        displayName: 'Live Integration',
        currency: 'LYD',
        language: 'en',
        country: 'LY',
        timezone: 'Africa/Tripoli',
      );
      final safeStreamDiagnostics = <Map<String, Object?>>[];
      final safeControllerFailures = <String>[];
      final operationFence = BackupOperationFence();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionStartupRecoveryProvider.overrideWith(
              (_) async => const AccountDeletionStartupRecoveryReport(
                completed: 0,
                retained: 0,
                rejected: 0,
              ),
            ),
            backupOperationFenceProvider.overrideWithValue(operationFence),
            authStateProvider.overrideWith(
              (_) => Stream<AuthUser?>.value(routedTestUser),
            ),
            onboardingCompletedProvider.overrideWith((_) => true),
            effectiveAiAppControlPolicyProvider.overrideWithValue(
              const EffectiveAiAppControlPolicy(
                flags: AiAppControlFeatureFlags(
                  appControlEnabled: true,
                  readToolsEnabled: false,
                  navigationToolsEnabled: true,
                  createDraftsEnabled: false,
                  updateDraftsEnabled: false,
                  archiveDraftsEnabled: false,
                  multiStepPlansEnabled: false,
                  agentAuditEnabled: false,
                  localDatasetScopeVerified: false,
                ),
                settings: AiAppControlSettings(
                  level: AiAppControlLevel.readAndNavigate,
                  allowFinancialAnalysis: false,
                  allowNavigation: true,
                  allowTransactionDrafts: false,
                  allowBudgetAndGoalDrafts: false,
                  allowAccountCategoryPayeeDrafts: false,
                  allowRecurringDrafts: false,
                  allowMultiStepPlans: false,
                  requireConfirmationForEveryChange: true,
                ),
                hasAuthenticatedScope: true,
                runtimeOwnerScopeSafe: true,
              ),
            ),
            aiGatewaySafeDiagnosticLogProvider.overrideWithValue((message) {
              Object? decoded;
              try {
                decoded = jsonDecode(message);
              } on FormatException {
                // Provider-selection diagnostics are safe plain text. The
                // test only needs structured stream/controller markers and
                // must never break the production graph while observing it.
                return;
              }
              if (decoded is Map &&
                  decoded['kind'] == 'cashpilot_ai_flutter_stream') {
                safeStreamDiagnostics.add(Map<String, Object?>.from(decoded));
              } else if (decoded is Map &&
                  decoded['kind'] == 'cashpilot_ai_controller_failure' &&
                  decoded['code'] is String) {
                safeControllerFailures.add(
                  '${decoded['code']}@${decoded['source'] ?? 'unavailable'}',
                );
              }
            }),
          ],
          child: const CashPilotApp(),
        ),
      );
      await _pumpUntil(
        tester,
        () => find.byType(DashboardScreen).evaluate().isNotEmpty,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CashPilotApp)),
      );
      expect(
        container.read(aiAssistantCapabilitiesProvider).activeProvider,
        AiActiveProvider.firebase,
      );
      final router = container.read(appRouterProvider);
      router.go(AppRoutePaths.aiAssistant);
      await _pumpUntil(
        tester,
        () => find.byType(AiAssistantScreen).evaluate().isNotEmpty,
      );

      final prompts = <(String, bool)>[
        ('hello', false),
        ('اشرح لي الفرق بين الدخل والمصروف في جملتين', true),
        ('Explain compound interest simply', true),
        ('Give me three simple saving habits', true),
      ];

      for (final entry in prompts) {
        final diagnosticsBefore = safeStreamDiagnostics.length;
        await _sendAndAwaitResponse(tester, container, entry.$1);
        final state = container.read(aiAgentControllerProvider);
        if (entry.$2) {
          if (state.lastResponse?.kind != AiAgentResponseKind.answer) {
            debugPrint(
              'COMPOSITE_AI_FAILURE index=${prompts.indexOf(entry)} '
              'reason=${state.unavailableReason?.name ?? "none"} '
              'retryable=${state.retryable} '
              'errorPresent=${state.errorMessage != null} '
              'safeDiagnostics=${safeStreamDiagnostics.length - diagnosticsBefore} '
              'controllerCode=${safeControllerFailures.isEmpty ? "none" : safeControllerFailures.last}',
            );
          }
          expect(state.lastResponse?.kind, AiAgentResponseKind.answer);
          expect(state.lastResponse?.message.trim(), isNotEmpty);
          final requestDiagnostics = safeStreamDiagnostics.sublist(
            diagnosticsBefore,
          );
          if (requestDiagnostics.isNotEmpty) {
            expect(
              requestDiagnostics.any((diagnostic) {
                final eventTypes =
                    diagnostic['normalizedSseEventTypes'] as List<Object?>;
                return diagnostic['parserResult'] == 'completed' &&
                    diagnostic['finalCode'] == 'completed' &&
                    eventTypes.contains('textDelta') &&
                    eventTypes.contains('completed');
              }),
              isTrue,
            );
          }
        } else {
          expect(safeStreamDiagnostics.length, diagnosticsBefore);
        }
        expect(find.byType(AiAssistantScreen), findsOneWidget);
        expect(
          GoRouterState.of(
            tester.element(find.byType(AiAssistantScreen)),
          ).uri.path,
          AppRoutePaths.aiAssistant,
        );
      }

      final retainedCount = container
          .read(aiAgentControllerProvider)
          .messages
          .length;
      router.go(AppRoutePaths.dashboard);
      await tester.pumpAndSettle();
      router.go(AppRoutePaths.aiAssistant);
      await _pumpUntil(
        tester,
        () => find.byType(AiAssistantScreen).evaluate().isNotEmpty,
      );
      expect(
        container.read(aiAgentControllerProvider).messages.length,
        retainedCount,
      );

      final diagnostics = container.read(
        navigationTransitionDiagnosticsProvider,
      );
      expect(diagnostics.hasUnexpectedAiSendTransition, isFalse);

      final newConversation = tester.widget<IconButton>(
        find.byKey(const Key('ai_assistant_new_conversation')),
      );
      expect(newConversation.onPressed, isNotNull);
      newConversation.onPressed!();
      await _pumpUntil(
        tester,
        () => container.read(aiAgentControllerProvider).messages.isEmpty,
      );

      await _sendAndAwaitResponse(tester, container, 'Open accounts');
      final navigationResponse = container
          .read(aiAgentControllerProvider)
          .lastResponse;
      debugPrint(
        'COMPOSITE_NAV kind=${navigationResponse?.kind.name ?? "none"} '
        'turn=${navigationResponse?.turnKind.name ?? "none"} '
        'pathPresent=${navigationResponse?.navigationPath != null} '
        'tools=${navigationResponse?.executedToolNames.join(",") ?? "none"} '
        'records=${diagnostics.records.length}',
      );
      await _pumpUntil(
        tester,
        () => find.byType(AccountsScreen).evaluate().isNotEmpty,
      );
      expect(
        diagnostics.records.last.cause,
        NavigationTransitionCause.explicitAssistantNavigationTool,
      );
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

Future<void> _sendAndAwaitResponse(
  WidgetTester tester,
  ProviderContainer container,
  String prompt,
) async {
  final previousCount = container
      .read(aiAgentControllerProvider)
      .messages
      .length;
  final composer = find.descendant(
    of: find.byKey(const Key('ai_assistant_composer')),
    matching: find.byType(EditableText),
  );
  expect(composer, findsOneWidget);
  await tester.tap(composer);
  await tester.enterText(composer, prompt);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pump();

  await _pumpUntil(tester, () {
    final state = container.read(aiAgentControllerProvider);
    return !state.isSending &&
        (state.messages.length >= previousCount + 2 ||
            state.errorMessage != null);
  }, attempts: 450);

  final state = container.read(aiAgentControllerProvider);
  expect(state.messages.length, greaterThan(previousCount));
  expect(state.isSending, isFalse);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int attempts = 100,
}) async {
  for (var attempt = 0; attempt < attempts && !condition(); attempt += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  expect(condition(), isTrue);
}
