import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/effective_ai_app_control_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/ai_app_control_permission_resolver.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_scope_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_app_control_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/app_agent/hive_ai_app_control_settings_store.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_app_control_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('canonical account app-control modes', () {
    test('update delete and undo require audit and confirmation policy', () {
      for (final auditEnabled in [false, true]) {
        for (final confirmationRequired in [false, true]) {
          final policy = EffectiveAiAppControlPolicy(
            flags: AiAppControlFeatureFlags.resolve(
              environmentValue: 'staging',
              updateDraftsValue: 'true',
              archiveDraftsValue: 'true',
              confirmedExecutionValue: 'true',
              localDatasetScopeVerifiedValue: 'true',
              auditValue: auditEnabled.toString(),
            ),
            // Construct the policy directly: storage normalization must not
            // mask a missing runtime guard for malformed settings.
            settings: AiAppControlSettings(
              level: AiAppControlLevel.fullControl,
              allowFinancialAnalysis: true,
              allowNavigation: true,
              allowTransactionDrafts: true,
              allowBudgetAndGoalDrafts: true,
              allowAccountCategoryPayeeDrafts: false,
              allowRecurringDrafts: false,
              allowMultiStepPlans: false,
              requireConfirmationForEveryChange: confirmationRequired,
            ),
            hasAuthenticatedScope: true,
            runtimeOwnerScopeSafe: true,
            configurationRevision: 1,
          );
          final allowed = auditEnabled && confirmationRequired;
          expect(policy.canUpdateDraft, allowed);
          expect(policy.canArchiveDraft, allowed);
          for (final toolId in [
            'updateTransactionDraft',
            'deleteTransactionDraft',
            'undoAiAction',
          ]) {
            expect(
              policy.canExecuteConfirmedTool(toolId),
              allowed,
              reason:
                  '$toolId audit=$auditEnabled confirmation=$confirmationRequired',
            );
          }
        }
      }
    });

    test('Full Control maps transaction drafts and confirmed execution', () {
      const settings = AiAppControlSettings.forLevel(
        AiAppControlLevel.fullControl,
      );
      const policy = EffectiveAiAppControlPolicy(
        flags: _enabledCreateFlags,
        settings: settings,
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: true,
        configurationRevision: 1,
      );

      expect(settings.allowFinancialAnalysis, isTrue);
      expect(settings.allowNavigation, isTrue);
      expect(settings.allowTransactionDrafts, isTrue);
      expect(settings.allowAccountCategoryPayeeDrafts, isFalse);
      expect(settings.allowRecurringDrafts, isFalse);
      expect(settings.allowMultiStepPlans, isFalse);
      expect(settings.requireConfirmationForEveryChange, isTrue);
      expect(policy.canCreateTransactionDraft, isTrue);
      expect(policy.canExecuteConfirmedFinancialCreate, isTrue);
      expect(policy.canExecuteConfirmedTool('createIncomeDraft'), isTrue);
      expect(policy.confirmationAlwaysRequired, isTrue);
    });

    test('Review Before Execution permits preview and explicit Confirm', () {
      const settings = AiAppControlSettings.forLevel(
        AiAppControlLevel.reviewBeforeExecution,
      );
      const policy = EffectiveAiAppControlPolicy(
        flags: _enabledCreateFlags,
        settings: settings,
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: true,
        configurationRevision: 1,
      );

      expect(settings.allowTransactionDrafts, isTrue);
      expect(settings.requireConfirmationForEveryChange, isTrue);
      expect(policy.canCreateTransactionDraft, isTrue);
      expect(policy.canExecuteConfirmedFinancialCreate, isTrue);
      expect(policy.canExecuteConfirmedTool('createIncomeDraft'), isTrue);
      expect(policy.confirmationAlwaysRequired, isTrue);
    });

    test('Off denies transaction drafts and confirmed execution', () {
      const settings = AiAppControlSettings.forLevel(AiAppControlLevel.off);
      const policy = EffectiveAiAppControlPolicy(
        flags: _enabledCreateFlags,
        settings: settings,
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: true,
        configurationRevision: 1,
      );

      expect(policy.canCreateTransactionDraft, isFalse);
      expect(policy.canExecuteConfirmedFinancialCreate, isFalse);
      expect(policy.canExecuteConfirmedTool('createIncomeDraft'), isFalse);
    });

    test('missing current configuration denies an otherwise Full policy', () {
      const policy = EffectiveAiAppControlPolicy(
        flags: _enabledCreateFlags,
        settings: AiAppControlSettings.forLevel(AiAppControlLevel.fullControl),
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: true,
      );

      expect(policy.configurationRevision, 0);
      expect(policy.hasCurrentConfiguration, isFalse);
      expect(policy.appControlAvailable, isFalse);
      expect(policy.canReadFinancialData, isFalse);
      expect(policy.canCreateTransactionDraft, isFalse);
      expect(policy.canExecuteConfirmedTool('createIncomeDraft'), isFalse);
    });

    test('owner-health remains an independent fail-closed gate', () {
      const settings = AiAppControlSettings.forLevel(
        AiAppControlLevel.fullControl,
      );
      const policy = EffectiveAiAppControlPolicy(
        flags: _enabledCreateFlags,
        settings: settings,
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: false,
        configurationRevision: 1,
      );

      expect(policy.appControlAvailable, isTrue);
      expect(policy.canCreateTransactionDraft, isFalse);
      expect(policy.canExecuteConfirmedFinancialCreate, isFalse);
    });

    test('owner-health denial has its own typed safe reason', () {
      const settings = AiAppControlSettings.forLevel(
        AiAppControlLevel.fullControl,
      );
      const policy = EffectiveAiAppControlPolicy(
        flags: _enabledCreateFlags,
        settings: settings,
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: false,
        provenance: AiAppControlPolicyProvenance.persistedUserSelection,
        configurationRevision: 1,
      );

      final decision = AiAppControlPermissionResolver.resolve(
        policy: policy,
        request: AiAppControlPermissionRequest.transactionDraft,
        policyProvenance: policy.provenance,
      );

      expect(decision.allowed, isFalse);
      expect(
        decision.denialReason,
        AiAppControlDenialReason.ownerScopeNotReady,
      );
      expect(decision.localDataScopeReady, isFalse);
      expect(decision.transactionDraftPermission, isFalse);
      expect(decision.safeFailureCode, AppAgentFailureCodes.ownerScopeNotReady);
    });

    test('draft and confirmed-execution denials remain distinguishable', () {
      const disabledDraftSettings = AiAppControlSettings(
        level: AiAppControlLevel.fullControl,
        allowFinancialAnalysis: true,
        allowNavigation: true,
        allowTransactionDrafts: false,
        allowBudgetAndGoalDrafts: false,
        allowAccountCategoryPayeeDrafts: true,
        allowRecurringDrafts: false,
        allowMultiStepPlans: false,
        requireConfirmationForEveryChange: true,
        provenance: AiAppControlPolicyProvenance.persistedUserSelection,
      );
      const draftDisabled = EffectiveAiAppControlPolicy(
        flags: _enabledCreateFlags,
        settings: disabledDraftSettings,
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: true,
        provenance: AiAppControlPolicyProvenance.persistedUserSelection,
        configurationRevision: 1,
      );
      const executionDisabled = EffectiveAiAppControlPolicy(
        flags: _draftOnlyFlags,
        settings: AiAppControlSettings.forLevel(
          AiAppControlLevel.reviewBeforeExecution,
        ),
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: true,
        provenance: AiAppControlPolicyProvenance.persistedUserSelection,
        configurationRevision: 1,
      );

      final draftDecision = AiAppControlPermissionResolver.resolve(
        policy: draftDisabled,
        request: AiAppControlPermissionRequest.transactionDraft,
        policyProvenance: draftDisabled.provenance,
      );
      final previewDecision = AiAppControlPermissionResolver.resolve(
        policy: executionDisabled,
        request: AiAppControlPermissionRequest.transactionDraft,
        policyProvenance: executionDisabled.provenance,
      );
      final confirmDecision = AiAppControlPermissionResolver.resolve(
        policy: executionDisabled,
        request: AiAppControlPermissionRequest.confirmedTransactionExecution,
        policyProvenance: executionDisabled.provenance,
      );

      expect(
        draftDecision.denialReason,
        AiAppControlDenialReason.transactionDraftsDisabled,
      );
      expect(previewDecision.allowed, isTrue);
      expect(
        confirmDecision.denialReason,
        AiAppControlDenialReason.confirmedExecutionDisabled,
      );
    });
  });

  group('policy provenance and persistence', () {
    test('legacy v1 Full Control repairs stale capability bits', () {
      final restored = AiAppControlSettings.fromJson(<String, Object?>{
        'version': 1,
        'level': 'fullGovernedControl',
        'allowFinancialAnalysis': false,
        'allowNavigation': false,
        'allowTransactionDrafts': false,
        'allowBudgetAndGoalDrafts': false,
        'allowAccountCategoryPayeeDrafts': false,
        'allowRecurringDrafts': false,
        'allowMultiStepPlans': false,
        'requireConfirmationForEveryChange': false,
      });

      expect(restored.level, AiAppControlLevel.fullControl);
      expect(restored.allowFinancialAnalysis, isTrue);
      expect(restored.allowNavigation, isTrue);
      expect(restored.allowTransactionDrafts, isTrue);
      expect(
        restored.provenance,
        AiAppControlPolicyProvenance.persistedUserSelection,
      );
      expect(restored.requireConfirmationForEveryChange, isTrue);
    });

    test('v2 Full Control repairs contradictory persisted false bits', () {
      final restored = AiAppControlSettings.fromJson(<String, Object?>{
        'version': 2,
        'level': 'fullControl',
        'allowFinancialAnalysis': false,
        'allowNavigation': false,
        'allowTransactionDrafts': false,
        'allowBudgetAndGoalDrafts': false,
        'allowAccountCategoryPayeeDrafts': false,
        'allowRecurringDrafts': false,
        'allowMultiStepPlans': false,
        'requireConfirmationForEveryChange': true,
        'provenance': AiAppControlPolicyProvenance.persistedUserSelection.name,
      });

      expect(restored.level, AiAppControlLevel.fullControl);
      expect(restored.allowFinancialAnalysis, isTrue);
      expect(restored.allowNavigation, isTrue);
      expect(restored.allowTransactionDrafts, isTrue);
      expect(restored.allowBudgetAndGoalDrafts, isTrue);
      expect(restored.requireConfirmationForEveryChange, isTrue);
    });

    test('unknown legacy data stays fail-closed and distinguishable', () {
      final restored = AiAppControlSettings.fromJson(<String, Object?>{
        'version': 0,
        'level': 'fullControl',
      });

      expect(restored.level, AiAppControlLevel.off);
      expect(restored.allowTransactionDrafts, isFalse);
      expect(
        restored.provenance,
        AiAppControlPolicyProvenance.legacyUnresolved,
      );
    });

    test('v2 and copy paths normalize unsupported capability bits off', () {
      final restored = AiAppControlSettings.fromJson(<String, Object?>{
        'version': 2,
        'level': 'fullControl',
        'allowFinancialAnalysis': true,
        'allowNavigation': true,
        'allowTransactionDrafts': true,
        'allowBudgetAndGoalDrafts': true,
        'allowAccountCategoryPayeeDrafts': true,
        'allowRecurringDrafts': true,
        'allowMultiStepPlans': true,
        'requireConfirmationForEveryChange': true,
        'provenance': AiAppControlPolicyProvenance.persistedUserSelection.name,
      });
      final copied = restored.copyWith(
        allowAccountCategoryPayeeDrafts: true,
        allowRecurringDrafts: true,
        allowMultiStepPlans: true,
      );
      final policy = EffectiveAiAppControlPolicy(
        flags: _enabledCreateFlags,
        settings: copied,
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: true,
        provenance: copied.provenance,
        configurationRevision: 1,
      );

      for (final settings in <AiAppControlSettings>[restored, copied]) {
        expect(settings.allowAccountCategoryPayeeDrafts, isFalse);
        expect(settings.allowRecurringDrafts, isFalse);
        expect(settings.allowMultiStepPlans, isFalse);
      }
      expect(policy.canCreateTransactionDraft, isTrue);
      expect(policy.canCreateBudgetOrGoalDraft, isTrue);
      expect(policy.canCreateAccountCategoryPayeeDraft, isFalse);
      expect(policy.canUseRecurringDrafts, isFalse);
      expect(policy.canUseMultiStepPlans, isFalse);
    });

    test('explicit persisted Off survives store recreation', () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-ai-control-explicit-off-',
      );
      Hive.init(directory.path);
      const scopeHash =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      try {
        var box = await Hive.openBox<dynamic>('explicit-off-reopen-test');
        var store = HiveAiAppControlSettingsStore(
          box,
          missingPolicyDefault: const AiAppControlSettings.forLevel(
            AiAppControlLevel.fullControl,
            provenance: AiAppControlPolicyProvenance.stagingMigration,
          ),
        );
        await box.put(
          'ai_app_control_policy_v1_$scopeHash',
          jsonEncode(<String, Object?>{
            'version': 1,
            'level': 'off',
            'allowFinancialAnalysis': false,
            'allowNavigation': false,
            'allowTransactionDrafts': false,
            'allowBudgetAndGoalDrafts': false,
            'allowAccountCategoryPayeeDrafts': false,
            'allowRecurringDrafts': false,
            'allowMultiStepPlans': false,
            'requireConfirmationForEveryChange': true,
          }),
        );
        final upgraded = await store.read(scopeHash);
        expect(upgraded.level, AiAppControlLevel.off);
        expect(
          upgraded.provenance,
          AiAppControlPolicyProvenance.persistedUserSelection,
        );
        await box.close();

        box = await Hive.openBox<dynamic>('explicit-off-reopen-test');
        store = HiveAiAppControlSettingsStore(
          box,
          missingPolicyDefault: const AiAppControlSettings.forLevel(
            AiAppControlLevel.fullControl,
            provenance: AiAppControlPolicyProvenance.stagingMigration,
          ),
        );
        final restored = await store.read(scopeHash);

        expect(restored.level, AiAppControlLevel.off);
        expect(restored.allowTransactionDrafts, isFalse);
        expect(
          restored.provenance,
          AiAppControlPolicyProvenance.persistedUserSelection,
        );
        final raw = jsonDecode(box.get('ai_app_control_policy_v1_$scopeHash'));
        expect(raw['version'], 2);
        expect(raw['level'], AiAppControlLevel.off.name);
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    });

    test(
      'staging migrates an uninitialized policy once and persists it',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'cashpilot-ai-control-staging-migration-',
        );
        Hive.init(directory.path);
        const scopeHash =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        const legacyDefaultScopeHash =
            'abababababababababababababababababababababababababababababababab';
        try {
          final box = await Hive.openBox<dynamic>('staging-migration-test');
          final migratingStore = HiveAiAppControlSettingsStore(
            box,
            missingPolicyDefault:
                const AiAppControlSettings.stagingTransactionDrafts(),
            migrateUninitializedPolicy: true,
            admitStagingMigrationPolicy: true,
          );

          final migrated = await migratingStore.read(scopeHash);
          expect(migrated.level, AiAppControlLevel.reviewBeforeExecution);
          expect(migrated.allowTransactionDrafts, isTrue);
          expect(
            migrated.provenance,
            AiAppControlPolicyProvenance.stagingMigration,
          );

          await box.put(
            'ai_app_control_policy_v1_$legacyDefaultScopeHash',
            jsonEncode(<String, Object?>{
              'version': 1,
              'level': 'off',
              'initialized': false,
            }),
          );
          final migratedLegacyDefault = await migratingStore.read(
            legacyDefaultScopeHash,
          );
          expect(
            migratedLegacyDefault.level,
            AiAppControlLevel.reviewBeforeExecution,
          );
          expect(
            migratedLegacyDefault.provenance,
            AiAppControlPolicyProvenance.stagingMigration,
          );

          final reopenedWithinStaging = HiveAiAppControlSettingsStore(
            box,
            missingPolicyDefault: const AiAppControlSettings.conservative(),
            migrateUninitializedPolicy: false,
            admitStagingMigrationPolicy: true,
          );
          final persisted = await reopenedWithinStaging.read(scopeHash);
          expect(persisted.level, AiAppControlLevel.reviewBeforeExecution);
          expect(
            persisted.provenance,
            AiAppControlPolicyProvenance.stagingMigration,
          );
          final persistedLegacyDefault = await reopenedWithinStaging.read(
            legacyDefaultScopeHash,
          );
          expect(
            persistedLegacyDefault.level,
            AiAppControlLevel.reviewBeforeExecution,
          );
          expect(
            persistedLegacyDefault.provenance,
            AiAppControlPolicyProvenance.stagingMigration,
          );
        } finally {
          await Hive.close();
          await directory.delete(recursive: true);
        }
      },
    );

    test(
      'non-staging rejects a persisted staging migration without overwriting it',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'cashpilot-ai-control-release-rejects-staging-',
        );
        Hive.init(directory.path);
        const scopeHash =
            'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';
        try {
          final box = await Hive.openBox<dynamic>(
            'release-rejects-staging-policy-test',
          );
          final key = 'ai_app_control_policy_v1_$scopeHash';
          final rawStagingPolicy = jsonEncode(
            const AiAppControlSettings.stagingTransactionDrafts(
              provenance: AiAppControlPolicyProvenance.stagingMigration,
            ).toJson(),
          );
          await box.put(key, rawStagingPolicy);
          final nonStagingStore = HiveAiAppControlSettingsStore(
            box,
            missingPolicyDefault: const AiAppControlSettings.conservative(),
          );

          final rejected = await nonStagingStore.read(scopeHash);

          expect(rejected.level, AiAppControlLevel.off);
          expect(rejected.allowTransactionDrafts, isFalse);
          expect(
            rejected.provenance,
            AiAppControlPolicyProvenance.legacyUnresolved,
          );
          expect(box.get(key), rawStagingPolicy);

          await nonStagingStore.save(
            scopeHash,
            const AiAppControlSettings.forLevel(
              AiAppControlLevel.fullControl,
              provenance: AiAppControlPolicyProvenance.persistedUserSelection,
            ),
          );
          final explicitlySelected = await nonStagingStore.read(scopeHash);
          expect(explicitlySelected.level, AiAppControlLevel.fullControl);
          expect(
            explicitlySelected.provenance,
            AiAppControlPolicyProvenance.persistedUserSelection,
          );
        } finally {
          await Hive.close();
          await directory.delete(recursive: true);
        }
      },
    );

    test(
      'non-staging missing policy remains unwritten and fail-closed',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'cashpilot-ai-control-no-migration-',
        );
        Hive.init(directory.path);
        const scopeHash =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        try {
          final box = await Hive.openBox<dynamic>('no-migration-test');
          final store = HiveAiAppControlSettingsStore(
            box,
            missingPolicyDefault: const AiAppControlSettings.conservative(),
            migrateUninitializedPolicy: false,
          );

          final settings = await store.read(scopeHash);
          expect(settings.level, AiAppControlLevel.off);
          expect(
            settings.provenance,
            AiAppControlPolicyProvenance.environmentDefault,
          );
          expect(box.keys, isEmpty);
        } finally {
          await Hive.close();
          await directory.delete(recursive: true);
        }
      },
    );
  });

  test(
    'saving Full Control immediately rebuilds effective permissions and reopens',
    () async {
      final store = _MemorySettingsStore(
        const AiAppControlSettings.forLevel(AiAppControlLevel.off),
      );
      final first = _policyContainer(store);
      await first.read(aiAppControlSettingsControllerProvider.future);
      await first.read(ownerScopeHealthProvider.future);

      final before = first.read(effectiveAiAppControlPolicyProvider);
      expect(before.canCreateTransactionDraft, isFalse);
      expect(before.configurationRevision, greaterThan(0));

      await first
          .read(aiAppControlSettingsControllerProvider.notifier)
          .setLevel(AiAppControlLevel.fullControl);

      final after = first.read(effectiveAiAppControlPolicyProvider);
      expect(after.settings.level, AiAppControlLevel.fullControl);
      expect(
        after.provenance,
        AiAppControlPolicyProvenance.persistedUserSelection,
      );
      expect(
        after.configurationRevision,
        greaterThan(before.configurationRevision),
      );
      expect(after.canCreateTransactionDraft, isTrue);
      expect(after.canExecuteConfirmedTool('createIncomeDraft'), isTrue);
      expect(store.saveCount, 1);

      first.dispose();
      final reopened = _policyContainer(store);
      addTearDown(reopened.dispose);
      await reopened.read(aiAppControlSettingsControllerProvider.future);
      await reopened.read(ownerScopeHealthProvider.future);
      final restored = reopened.read(effectiveAiAppControlPolicyProvider);
      expect(restored.settings.level, AiAppControlLevel.fullControl);
      expect(restored.canCreateTransactionDraft, isTrue);
      expect(restored.canExecuteConfirmedTool('createIncomeDraft'), isTrue);
    },
  );

  test('failed Full Control save never publishes elevated consent', () async {
    final store = _BlockingSettingsStore(
      const AiAppControlSettings.forLevel(AiAppControlLevel.off),
    );
    final container = _policyContainer(store);
    addTearDown(() {
      store.release(fail: true);
      container.dispose();
    });
    await container.read(aiAppControlSettingsControllerProvider.future);
    await container.read(ownerScopeHealthProvider.future);

    final save = container
        .read(aiAppControlSettingsControllerProvider.notifier)
        .setLevel(AiAppControlLevel.fullControl);
    await store.saveStarted.future;

    expect(
      container.read(aiAppControlSettingsControllerProvider).isLoading,
      isTrue,
    );
    final whileSaving = container.read(effectiveAiAppControlPolicyProvider);
    expect(whileSaving.configurationRevision, 0);
    expect(whileSaving.canCreateTransactionDraft, isFalse);
    expect(whileSaving.canExecuteConfirmedFinancialCreate, isFalse);

    store.release(fail: true);
    await save;

    expect(
      container.read(aiAppControlSettingsControllerProvider).hasError,
      isTrue,
    );
    final afterFailure = container.read(effectiveAiAppControlPolicyProvider);
    expect(afterFailure.configurationRevision, 0);
    expect(afterFailure.canCreateTransactionDraft, isFalse);
    expect(afterFailure.canExecuteConfirmedFinancialCreate, isFalse);
    expect(store.settings.level, AiAppControlLevel.off);
  });

  test('public setters cannot contradict the selected control level', () async {
    final store = _MemorySettingsStore(
      const AiAppControlSettings.forLevel(AiAppControlLevel.fullControl),
    );
    final container = _policyContainer(store);
    addTearDown(container.dispose);
    await container.read(aiAppControlSettingsControllerProvider.future);
    await container.read(ownerScopeHealthProvider.future);
    final controller = container.read(
      aiAppControlSettingsControllerProvider.notifier,
    );

    await controller.setFinancialAnalysis(false);
    await controller.setNavigation(false);
    await controller.setTransactionDrafts(false);
    await controller.setBudgetAndGoalDrafts(false);
    await controller.setAccountCategoryPayeeDrafts(true);
    await controller.setRecurringDrafts(true);
    await controller.setMultiStepPlans(true);

    final snapshot = container
        .read(aiAppControlSettingsControllerProvider)
        .requireValue!;
    expect(snapshot.settings.allowFinancialAnalysis, isTrue);
    expect(snapshot.settings.allowNavigation, isTrue);
    expect(snapshot.settings.allowTransactionDrafts, isTrue);
    expect(snapshot.settings.allowBudgetAndGoalDrafts, isTrue);
    expect(snapshot.settings.allowAccountCategoryPayeeDrafts, isFalse);
    expect(snapshot.settings.allowRecurringDrafts, isFalse);
    expect(snapshot.settings.allowMultiStepPlans, isFalse);
    expect(store.settings.allowAccountCategoryPayeeDrafts, isFalse);
    expect(store.settings.allowFinancialAnalysis, isTrue);
    expect(store.settings.allowNavigation, isTrue);
    expect(store.settings.allowTransactionDrafts, isTrue);
    expect(store.settings.allowBudgetAndGoalDrafts, isTrue);
    expect(store.settings.allowRecurringDrafts, isFalse);
    expect(store.settings.allowMultiStepPlans, isFalse);
    final effective = container.read(effectiveAiAppControlPolicyProvider);
    expect(effective.canCreateTransactionDraft, isTrue);
    expect(effective.canCreateBudgetOrGoalDraft, isTrue);
    expect(effective.canCreateAccountCategoryPayeeDraft, isFalse);
    expect(effective.canUseRecurringDrafts, isFalse);
    expect(effective.canUseMultiStepPlans, isFalse);
  });
}

const _enabledCreateFlags = AiAppControlFeatureFlags(
  appControlEnabled: true,
  readToolsEnabled: true,
  navigationToolsEnabled: true,
  createDraftsEnabled: true,
  confirmedExecutionEnabled: true,
  transferExecutionEnabled: false,
  updateDraftsEnabled: false,
  archiveDraftsEnabled: false,
  multiStepPlansEnabled: false,
  agentAuditEnabled: true,
  localDatasetScopeVerified: true,
);

const _draftOnlyFlags = AiAppControlFeatureFlags(
  appControlEnabled: true,
  readToolsEnabled: true,
  navigationToolsEnabled: false,
  createDraftsEnabled: true,
  confirmedExecutionEnabled: false,
  transferExecutionEnabled: false,
  updateDraftsEnabled: false,
  archiveDraftsEnabled: false,
  multiStepPlansEnabled: false,
  agentAuditEnabled: true,
  localDatasetScopeVerified: true,
);

const _scopeHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

ProviderContainer _policyContainer(AiAppControlSettingsStore store) {
  return ProviderContainer(
    overrides: [
      aiAppControlScopeHashProvider.overrideWithValue(_scopeHash),
      aiToolOwnerScopeBindingProvider.overrideWithValue(
        const AiToolOwnerScopeBinding(accountScope: _scopeHash, epoch: 1),
      ),
      aiAppControlSettingsStoreProvider.overrideWithValue(store),
      aiAppControlFeatureFlagsProvider.overrideWithValue(_enabledCreateFlags),
      backupOperationFenceProvider.overrideWithValue(BackupOperationFence()),
      ownerScopeHealthProvider.overrideWith(
        (_) async => const OwnerScopeHealth(status: OwnerScopeStatus.safe),
      ),
    ],
  );
}

final class _MemorySettingsStore implements AiAppControlSettingsStore {
  _MemorySettingsStore(this.settings);

  AiAppControlSettings settings;
  int saveCount = 0;

  @override
  Future<void> clear(String accountScopeHash) async {}

  @override
  Future<AiAppControlSettings> read(String accountScopeHash) async => settings;

  @override
  Future<void> save(
    String accountScopeHash,
    AiAppControlSettings settings,
  ) async {
    saveCount += 1;
    this.settings = settings;
  }
}

final class _BlockingSettingsStore implements AiAppControlSettingsStore {
  _BlockingSettingsStore(this.settings);

  AiAppControlSettings settings;
  final Completer<void> saveStarted = Completer<void>();
  final Completer<bool> _release = Completer<bool>();

  void release({required bool fail}) {
    if (!_release.isCompleted) _release.complete(fail);
  }

  @override
  Future<void> clear(String accountScopeHash) async {}

  @override
  Future<AiAppControlSettings> read(String accountScopeHash) async => settings;

  @override
  Future<void> save(
    String accountScopeHash,
    AiAppControlSettings settings,
  ) async {
    if (!saveStarted.isCompleted) saveStarted.complete();
    final fail = await _release.future;
    if (fail) throw StateError('controlled policy save failure');
    this.settings = settings;
  }
}
