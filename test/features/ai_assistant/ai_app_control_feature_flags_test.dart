import 'dart:io';

import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/effective_ai_app_control_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/app_agent/hive_ai_app_control_settings_store.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_app_control_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test(
    'production-neutral defaults are conservative and audit stays enabled',
    () {
      final flags = AiAppControlFeatureFlags.resolve();

      expect(flags.appControlEnabled, isFalse);
      expect(flags.readToolsEnabled, isFalse);
      expect(flags.navigationToolsEnabled, isFalse);
      expect(flags.createDraftsEnabled, isFalse);
      expect(flags.confirmedExecutionEnabled, isFalse);
      expect(flags.transferExecutionEnabled, isFalse);
      expect(flags.updateDraftsEnabled, isFalse);
      expect(flags.archiveDraftsEnabled, isFalse);
      expect(flags.multiStepPlansEnabled, isFalse);
      expect(flags.agentAuditEnabled, isTrue);
      expect(flags.localDatasetScopeVerified, isFalse);

      const settings = AiAppControlSettings.conservative();
      expect(settings.level, AiAppControlLevel.off);
      expect(settings.allowFinancialAnalysis, isFalse);
      expect(settings.allowNavigation, isFalse);
      expect(settings.allowTransactionDrafts, isFalse);
      expect(settings.allowBudgetAndGoalDrafts, isFalse);
      expect(settings.allowAccountCategoryPayeeDrafts, isFalse);
      expect(settings.allowRecurringDrafts, isFalse);
      expect(settings.allowMultiStepPlans, isFalse);
      expect(settings.requireConfirmationForEveryChange, isTrue);
    },
  );

  test('non-release staging enables only the bounded create flow', () {
    final staging = AiAppControlFeatureFlags.resolve(
      environmentValue: 'staging',
    );
    final production = AiAppControlFeatureFlags.resolve(
      environmentValue: 'production',
    );

    expect(staging.readToolsEnabled, isTrue);
    expect(staging.appControlEnabled, isTrue);
    expect(staging.navigationToolsEnabled, isFalse);
    expect(staging.createDraftsEnabled, isTrue);
    expect(staging.confirmedExecutionEnabled, isTrue);
    expect(staging.transferExecutionEnabled, isFalse);
    expect(staging.updateDraftsEnabled, isFalse);
    expect(staging.archiveDraftsEnabled, isFalse);
    expect(staging.multiStepPlansEnabled, isFalse);
    expect(staging.localDatasetScopeVerified, isTrue);
    expect(production.readToolsEnabled, isFalse);
  });

  test('explicit false overrides every non-release staging default', () {
    final flags = AiAppControlFeatureFlags.resolve(
      environmentValue: 'staging',
      appControlValue: 'false',
      readToolsValue: 'false',
      createDraftsValue: 'false',
      confirmedExecutionValue: 'false',
      localDatasetScopeVerifiedValue: 'false',
    );

    expect(flags.appControlEnabled, isFalse);
    expect(flags.readToolsEnabled, isFalse);
    expect(flags.createDraftsEnabled, isFalse);
    expect(flags.confirmedExecutionEnabled, isFalse);
    expect(flags.localDatasetScopeVerified, isFalse);
  });

  test(
    'release requires production environment and explicit feature flags',
    () {
      final mislabeledStaging = AiAppControlFeatureFlags.resolve(
        environmentValue: 'staging',
        isReleaseMode: true,
        appControlValue: 'true',
        readToolsValue: 'true',
        createDraftsValue: 'true',
        confirmedExecutionValue: 'true',
        localDatasetScopeVerifiedValue: 'true',
      );
      final implicitProduction = AiAppControlFeatureFlags.resolve(
        environmentValue: 'production',
        isReleaseMode: true,
        hasExplicitProductionEnvironment: true,
      );
      final explicitProduction = AiAppControlFeatureFlags.resolve(
        environmentValue: 'production',
        isReleaseMode: true,
        hasExplicitProductionEnvironment: true,
        appControlValue: 'true',
        readToolsValue: 'true',
        createDraftsValue: 'true',
        confirmedExecutionValue: 'true',
        localDatasetScopeVerifiedValue: 'true',
      );

      expect(mislabeledStaging.appControlEnabled, isFalse);
      expect(mislabeledStaging.readToolsEnabled, isFalse);
      expect(mislabeledStaging.createDraftsEnabled, isFalse);
      expect(mislabeledStaging.confirmedExecutionEnabled, isFalse);
      expect(mislabeledStaging.localDatasetScopeVerified, isFalse);
      expect(implicitProduction.appControlEnabled, isFalse);
      expect(implicitProduction.readToolsEnabled, isFalse);
      expect(implicitProduction.createDraftsEnabled, isFalse);
      expect(implicitProduction.confirmedExecutionEnabled, isFalse);
      expect(explicitProduction.appControlEnabled, isTrue);
      expect(explicitProduction.readToolsEnabled, isTrue);
      expect(explicitProduction.createDraftsEnabled, isTrue);
      expect(explicitProduction.confirmedExecutionEnabled, isTrue);
      expect(explicitProduction.localDatasetScopeVerified, isTrue);
      expect(explicitProduction.transferExecutionEnabled, isFalse);
      expect(explicitProduction.updateDraftsEnabled, isFalse);
      expect(explicitProduction.archiveDraftsEnabled, isFalse);
      expect(explicitProduction.multiStepPlansEnabled, isFalse);
    },
  );

  test('environment-specific account defaults remain confirmation locked', () {
    final staging = AiAppControlSettings.initialForEnvironment(
      environmentName: 'staging',
      isReleaseMode: false,
    );
    final release = AiAppControlSettings.initialForEnvironment(
      environmentName: 'production',
      isReleaseMode: true,
    );

    expect(staging.level, AiAppControlLevel.draftChanges);
    expect(staging.allowFinancialAnalysis, isTrue);
    expect(staging.allowTransactionDrafts, isTrue);
    expect(staging.allowBudgetAndGoalDrafts, isFalse);
    expect(staging.allowMultiStepPlans, isFalse);
    expect(staging.requireConfirmationForEveryChange, isTrue);
    expect(release.level, AiAppControlLevel.off);
    expect(release.allowTransactionDrafts, isFalse);
    expect(release.requireConfirmationForEveryChange, isTrue);
  });

  test(
    'draft-only staging cannot execute until a separate gate is enabled',
    () {
      const settings = AiAppControlSettings(
        level: AiAppControlLevel.draftChanges,
        allowFinancialAnalysis: true,
        allowNavigation: false,
        allowTransactionDrafts: true,
        allowBudgetAndGoalDrafts: true,
        allowAccountCategoryPayeeDrafts: false,
        allowRecurringDrafts: false,
        allowMultiStepPlans: false,
        requireConfirmationForEveryChange: true,
      );
      const draftOnly = EffectiveAiAppControlPolicy(
        flags: AiAppControlFeatureFlags(
          appControlEnabled: true,
          readToolsEnabled: true,
          navigationToolsEnabled: false,
          createDraftsEnabled: true,
          confirmedExecutionEnabled: false,
          updateDraftsEnabled: false,
          archiveDraftsEnabled: false,
          multiStepPlansEnabled: false,
          agentAuditEnabled: true,
          localDatasetScopeVerified: true,
        ),
        settings: settings,
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: true,
        configurationRevision: 1,
      );
      const confirmed = EffectiveAiAppControlPolicy(
        flags: AiAppControlFeatureFlags(
          appControlEnabled: true,
          readToolsEnabled: true,
          navigationToolsEnabled: false,
          createDraftsEnabled: true,
          confirmedExecutionEnabled: true,
          updateDraftsEnabled: false,
          archiveDraftsEnabled: false,
          multiStepPlansEnabled: false,
          agentAuditEnabled: true,
          localDatasetScopeVerified: true,
        ),
        settings: settings,
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: true,
        configurationRevision: 1,
      );

      expect(draftOnly.canCreateTransactionDraft, isTrue);
      expect(draftOnly.canCreateBudgetOrGoalDraft, isTrue);
      expect(draftOnly.canExecuteConfirmedFinancialCreate, isFalse);
      expect(confirmed.canExecuteConfirmedFinancialCreate, isTrue);
      expect(confirmed.canExecuteConfirmedTool('createExpenseDraft'), isTrue);
      expect(confirmed.canExecuteConfirmedTool('createTransferDraft'), isFalse);
    },
  );

  test('confirmed creates require consent for the exact tool family', () {
    const transactionTools = <String>[
      'createExpenseDraft',
      'createIncomeDraft',
      'createTransferDraft',
    ];
    const budgetAndGoalTools = <String>[
      'createBudgetDraft',
      'createGoalDraft',
      'createGoalContributionDraft',
    ];

    final transactionOnly = _confirmedPolicy(
      allowTransactionDrafts: true,
      allowBudgetAndGoalDrafts: false,
      transferExecutionEnabled: true,
    );
    for (final toolId in transactionTools) {
      expect(
        transactionOnly.canExecuteConfirmedTool(toolId),
        isTrue,
        reason: '$toolId requires transaction consent and its feature gate',
      );
    }
    for (final toolId in budgetAndGoalTools) {
      expect(
        transactionOnly.canExecuteConfirmedTool(toolId),
        isFalse,
        reason: '$toolId must not inherit transaction consent',
      );
    }

    final budgetAndGoalOnly = _confirmedPolicy(
      allowTransactionDrafts: false,
      allowBudgetAndGoalDrafts: true,
      transferExecutionEnabled: true,
    );
    for (final toolId in transactionTools) {
      expect(
        budgetAndGoalOnly.canExecuteConfirmedTool(toolId),
        isFalse,
        reason: '$toolId must not inherit budget and goal consent',
      );
    }
    for (final toolId in budgetAndGoalTools) {
      expect(
        budgetAndGoalOnly.canExecuteConfirmedTool(toolId),
        isTrue,
        reason: '$toolId has the exact relevant consent and feature gates',
      );
    }

    final noCreateConsent = _confirmedPolicy(
      allowTransactionDrafts: false,
      allowBudgetAndGoalDrafts: false,
      transferExecutionEnabled: true,
    );
    for (final toolId in <String>[...transactionTools, ...budgetAndGoalTools]) {
      expect(
        noCreateConsent.canExecuteConfirmedTool(toolId),
        isFalse,
        reason: '$toolId requires explicit consent for its tool family',
      );
    }
  });

  test(
    'confirmed transfer requires its feature flag and transaction consent',
    () {
      final transferDisabled = _confirmedPolicy(
        allowTransactionDrafts: true,
        allowBudgetAndGoalDrafts: true,
        transferExecutionEnabled: false,
      );
      final transferEnabled = _confirmedPolicy(
        allowTransactionDrafts: true,
        allowBudgetAndGoalDrafts: false,
        transferExecutionEnabled: true,
      );

      expect(
        transferDisabled.canExecuteConfirmedTool('createTransferDraft'),
        isFalse,
      );
      expect(
        transferEnabled.canExecuteConfirmedTool('createTransferDraft'),
        isTrue,
      );
    },
  );

  test('user settings cannot widen build-disabled capabilities', () {
    const flags = AiAppControlFeatureFlags(
      appControlEnabled: true,
      readToolsEnabled: false,
      navigationToolsEnabled: false,
      createDraftsEnabled: false,
      updateDraftsEnabled: false,
      archiveDraftsEnabled: false,
      multiStepPlansEnabled: false,
      agentAuditEnabled: true,
      localDatasetScopeVerified: true,
    );
    const settings = AiAppControlSettings(
      level: AiAppControlLevel.fullGovernedControl,
      allowFinancialAnalysis: true,
      allowNavigation: true,
      allowTransactionDrafts: true,
      allowBudgetAndGoalDrafts: true,
      allowAccountCategoryPayeeDrafts: true,
      allowRecurringDrafts: true,
      allowMultiStepPlans: true,
      requireConfirmationForEveryChange: true,
    );
    const policy = EffectiveAiAppControlPolicy(
      flags: flags,
      settings: settings,
      hasAuthenticatedScope: true,
      configurationRevision: 1,
    );

    expect(policy.appControlAvailable, isTrue);
    expect(policy.canReadFinancialData, isFalse);
    expect(policy.canNavigate, isFalse);
    expect(policy.canCreateTransactionDraft, isFalse);
    expect(policy.canCreateBudgetOrGoalDraft, isFalse);
    expect(policy.canCreateAccountCategoryPayeeDraft, isFalse);
    expect(policy.canUpdateDraft, isFalse);
    expect(policy.canArchiveDraft, isFalse);
    expect(policy.canUseRecurringDrafts, isFalse);
    expect(policy.canUseMultiStepPlans, isFalse);
  });

  test('unverified local account scope blocks financial reads and drafts', () {
    const flags = AiAppControlFeatureFlags(
      appControlEnabled: true,
      readToolsEnabled: true,
      navigationToolsEnabled: true,
      createDraftsEnabled: true,
      updateDraftsEnabled: true,
      archiveDraftsEnabled: true,
      multiStepPlansEnabled: true,
      agentAuditEnabled: true,
      localDatasetScopeVerified: false,
    );
    const settings = AiAppControlSettings(
      level: AiAppControlLevel.fullGovernedControl,
      allowFinancialAnalysis: true,
      allowNavigation: true,
      allowTransactionDrafts: true,
      allowBudgetAndGoalDrafts: true,
      allowAccountCategoryPayeeDrafts: true,
      allowRecurringDrafts: true,
      allowMultiStepPlans: true,
      requireConfirmationForEveryChange: true,
    );
    const policy = EffectiveAiAppControlPolicy(
      flags: flags,
      settings: settings,
      hasAuthenticatedScope: true,
      configurationRevision: 1,
    );

    expect(policy.canReadFinancialData, isFalse);
    expect(policy.canCreateTransactionDraft, isFalse);
    expect(policy.canCreateBudgetOrGoalDraft, isFalse);
    expect(policy.canUpdateDraft, isFalse);
    expect(policy.canArchiveDraft, isFalse);
    expect(policy.canUseMultiStepPlans, isFalse);
    expect(policy.canNavigate, isTrue);
  });

  test(
    'confirmation requirement is policy-locked against persisted override',
    () {
      final restored = AiAppControlSettings.fromJson(<String, Object?>{
        'version': 1,
        'level': AiAppControlLevel.fullGovernedControl.name,
        'allowFinancialAnalysis': true,
        'allowNavigation': true,
        'allowTransactionDrafts': true,
        'allowBudgetAndGoalDrafts': true,
        'allowAccountCategoryPayeeDrafts': true,
        'allowRecurringDrafts': true,
        'allowMultiStepPlans': true,
        'requireConfirmationForEveryChange': false,
      });
      final copied = restored.copyWith(level: AiAppControlLevel.off);
      const flags = AiAppControlFeatureFlags(
        appControlEnabled: true,
        readToolsEnabled: true,
        navigationToolsEnabled: true,
        createDraftsEnabled: true,
        updateDraftsEnabled: true,
        archiveDraftsEnabled: true,
        multiStepPlansEnabled: true,
        agentAuditEnabled: true,
        localDatasetScopeVerified: true,
      );
      final policy = EffectiveAiAppControlPolicy(
        flags: flags,
        settings: restored,
        hasAuthenticatedScope: true,
        configurationRevision: 1,
      );

      expect(restored.requireConfirmationForEveryChange, isTrue);
      expect(copied.requireConfirmationForEveryChange, isTrue);
      expect(restored.toJson()['requireConfirmationForEveryChange'], isTrue);
      expect(policy.confirmationAlwaysRequired, isTrue);
    },
  );

  test('persisted app-control settings are isolated by hashed scope', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cashpilot-ai-control-settings-',
    );
    Hive.init(directory.path);
    final box = await Hive.openBox<dynamic>('app-control-settings-test');
    try {
      final store = HiveAiAppControlSettingsStore(box);
      final scopeA = 'a' * 64;
      final scopeB = 'b' * 64;
      const enabled = AiAppControlSettings(
        level: AiAppControlLevel.draftChanges,
        allowFinancialAnalysis: true,
        allowNavigation: true,
        allowTransactionDrafts: true,
        allowBudgetAndGoalDrafts: false,
        allowAccountCategoryPayeeDrafts: false,
        allowRecurringDrafts: false,
        allowMultiStepPlans: false,
        requireConfirmationForEveryChange: true,
      );

      await store.save(scopeA, enabled);

      expect((await store.read(scopeA)).level, AiAppControlLevel.draftChanges);
      expect((await store.read(scopeB)).level, AiAppControlLevel.off);
      expect(box.keys.single, 'ai_app_control_policy_v1_$scopeA');

      await store.clear(scopeA);
      expect((await store.read(scopeA)).level, AiAppControlLevel.off);
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'staging missing policy is permissive but explicit off and malformed data fail closed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-ai-control-staging-default-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>(
        'app-control-staging-default-test',
      );
      const missingScope =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const explicitOffScope =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const malformedScope =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      try {
        final store = HiveAiAppControlSettingsStore(
          box,
          missingPolicyDefault:
              const AiAppControlSettings.stagingTransactionDrafts(),
        );

        final missing = await store.read(missingScope);
        expect(missing.level, AiAppControlLevel.draftChanges);
        expect(missing.allowTransactionDrafts, isTrue);
        expect(missing.requireConfirmationForEveryChange, isTrue);

        await store.save(
          explicitOffScope,
          const AiAppControlSettings.conservative(),
        );
        final explicitOff = await store.read(explicitOffScope);
        expect(explicitOff.level, AiAppControlLevel.off);
        expect(explicitOff.allowTransactionDrafts, isFalse);

        await box.put('ai_app_control_policy_v1_$malformedScope', '{not-json');
        final malformed = await store.read(malformedScope);
        expect(malformed.level, AiAppControlLevel.off);
        expect(malformed.allowTransactionDrafts, isFalse);
        expect(malformed.requireConfirmationForEveryChange, isTrue);
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('raw account identifiers cannot be used as settings keys', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cashpilot-ai-control-key-',
    );
    Hive.init(directory.path);
    final box = await Hive.openBox<dynamic>('app-control-key-test');
    try {
      final store = HiveAiAppControlSettingsStore(box);
      await expectLater(store.read('raw-user-id'), throwsArgumentError);
      expect(box.keys, isEmpty);
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}

EffectiveAiAppControlPolicy _confirmedPolicy({
  required bool allowTransactionDrafts,
  required bool allowBudgetAndGoalDrafts,
  required bool transferExecutionEnabled,
}) {
  return EffectiveAiAppControlPolicy(
    flags: AiAppControlFeatureFlags(
      appControlEnabled: true,
      readToolsEnabled: true,
      navigationToolsEnabled: false,
      createDraftsEnabled: true,
      confirmedExecutionEnabled: true,
      transferExecutionEnabled: transferExecutionEnabled,
      updateDraftsEnabled: false,
      archiveDraftsEnabled: false,
      multiStepPlansEnabled: false,
      agentAuditEnabled: true,
      localDatasetScopeVerified: true,
    ),
    settings: AiAppControlSettings(
      level: AiAppControlLevel.draftChanges,
      allowFinancialAnalysis: false,
      allowNavigation: false,
      allowTransactionDrafts: allowTransactionDrafts,
      allowBudgetAndGoalDrafts: allowBudgetAndGoalDrafts,
      allowAccountCategoryPayeeDrafts: false,
      allowRecurringDrafts: false,
      allowMultiStepPlans: false,
      requireConfirmationForEveryChange: true,
    ),
    hasAuthenticatedScope: true,
    runtimeOwnerScopeSafe: true,
    configurationRevision: 1,
  );
}
