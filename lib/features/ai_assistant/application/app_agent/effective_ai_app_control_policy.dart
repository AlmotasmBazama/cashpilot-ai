import '../../data/config/ai_app_control_feature_flags.dart';
import '../../domain/app_agent/ai_app_control_settings.dart';

/// Resolves build-time gates and account-scoped user consent without allowing
/// a setting to elevate a capability disabled by the build.
class EffectiveAiAppControlPolicy {
  const EffectiveAiAppControlPolicy({
    required this.flags,
    required this.settings,
    required this.hasAuthenticatedScope,
    this.runtimeOwnerScopeSafe = false,
    this.provenance = AiAppControlPolicyProvenance.environmentDefault,
    this.configurationRevision = 0,
  });

  final AiAppControlFeatureFlags flags;
  final AiAppControlSettings settings;
  final bool hasAuthenticatedScope;
  final bool runtimeOwnerScopeSafe;
  final AiAppControlPolicyProvenance provenance;

  /// Zero denotes the fail-closed absence of a current account snapshot.
  /// Loaded snapshots and every local policy mutation use a positive revision.
  final int configurationRevision;

  bool get configurationResolved =>
      provenance != AiAppControlPolicyProvenance.legacyUnresolved;

  bool get hasCurrentConfiguration =>
      configurationResolved && configurationRevision > 0;

  bool get appControlAvailable =>
      flags.appControlEnabled &&
      hasAuthenticatedScope &&
      hasCurrentConfiguration;

  bool get scopedFinancialControlAvailable =>
      appControlAvailable &&
      runtimeOwnerScopeSafe &&
      flags.localDatasetScopeVerified;

  bool get canReadFinancialData =>
      scopedFinancialControlAvailable &&
      flags.readToolsEnabled &&
      settings.level.index >= AiAppControlLevel.readOnly.index &&
      settings.allowFinancialAnalysis;

  bool get canNavigate =>
      appControlAvailable &&
      flags.navigationToolsEnabled &&
      settings.level == AiAppControlLevel.fullControl &&
      settings.allowNavigation;

  bool get canCreateTransactionDraft =>
      scopedFinancialControlAvailable &&
      flags.createDraftsEnabled &&
      flags.agentAuditEnabled &&
      settings.requireConfirmationForEveryChange &&
      settings.level.index >= AiAppControlLevel.reviewBeforeExecution.index &&
      settings.allowTransactionDrafts;

  bool get canCreateBudgetOrGoalDraft =>
      scopedFinancialControlAvailable &&
      flags.createDraftsEnabled &&
      flags.agentAuditEnabled &&
      settings.requireConfirmationForEveryChange &&
      settings.level.index >= AiAppControlLevel.reviewBeforeExecution.index &&
      settings.allowBudgetAndGoalDrafts;

  bool get canExecuteConfirmedFinancialCreate =>
      scopedFinancialControlAvailable &&
      flags.createDraftsEnabled &&
      flags.confirmedExecutionEnabled &&
      flags.agentAuditEnabled &&
      settings.requireConfirmationForEveryChange &&
      settings.level.index >= AiAppControlLevel.reviewBeforeExecution.index &&
      (settings.allowTransactionDrafts || settings.allowBudgetAndGoalDrafts);

  bool canExecuteConfirmedTool(String toolId) {
    return switch (toolId) {
      'createExpenseDraft' || 'createIncomeDraft' =>
        canExecuteConfirmedFinancialCreate && settings.allowTransactionDrafts,
      'createTransferDraft' =>
        canExecuteConfirmedFinancialCreate &&
            settings.allowTransactionDrafts &&
            flags.transferExecutionEnabled,
      'createBudgetDraft' ||
      'createGoalDraft' ||
      'createGoalContributionDraft' =>
        canExecuteConfirmedFinancialCreate && settings.allowBudgetAndGoalDrafts,
      'updateTransactionDraft' =>
        canUpdateDraft &&
            flags.confirmedExecutionEnabled &&
            settings.allowTransactionDrafts,
      'deleteTransactionDraft' =>
        canArchiveDraft &&
            flags.confirmedExecutionEnabled &&
            settings.allowTransactionDrafts,
      'undoAiAction' =>
        canUpdateDraft &&
            canArchiveDraft &&
            flags.confirmedExecutionEnabled &&
            settings.allowTransactionDrafts,
      _ => false,
    };
  }

  bool get canCreateAccountCategoryPayeeDraft => false;

  bool get canUpdateDraft =>
      scopedFinancialControlAvailable &&
      flags.updateDraftsEnabled &&
      flags.agentAuditEnabled &&
      settings.requireConfirmationForEveryChange &&
      settings.level == AiAppControlLevel.fullControl;

  bool get canArchiveDraft =>
      scopedFinancialControlAvailable &&
      flags.archiveDraftsEnabled &&
      flags.agentAuditEnabled &&
      settings.requireConfirmationForEveryChange &&
      settings.level == AiAppControlLevel.fullControl;

  bool get canUseRecurringDrafts => false;

  bool get canUseMultiStepPlans => false;

  bool get confirmationAlwaysRequired => true;
}
