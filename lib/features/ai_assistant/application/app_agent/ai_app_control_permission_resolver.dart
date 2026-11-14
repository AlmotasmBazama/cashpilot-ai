import '../../domain/app_agent/ai_app_control_settings.dart';
import '../../domain/app_agent/app_agent_policy.dart';
import 'effective_ai_app_control_policy.dart';

/// Safe lifecycle state for the account-scoped policy used by an app-control
/// decision. It deliberately carries no account identifier or policy payload.
enum AiAppControlConfigurationState { current, legacyUnresolved, stale }

enum AiAppControlDenialReason {
  controlLevelOff,
  transactionDraftsDisabled,
  confirmedExecutionDisabled,
  ownerScopeNotReady,
  legacyDataUnresolved,
  legacyPolicyUnresolved,
  staleConfiguration,
}

enum AiAppControlPermissionRequest {
  transactionDraft,
  confirmedTransactionExecution,
}

/// A typed, privacy-safe permission result. No user-originated data can enter
/// this object, so it is also safe to render or record as a diagnostic.
final class AiAppControlPermissionDecision {
  const AiAppControlPermissionDecision._({
    required this.request,
    required this.allowed,
    required this.policyRevision,
    required this.appControlFlagEnabled,
    required this.createDraftsFlagEnabled,
    required this.confirmedExecutionFlagEnabled,
    required this.localDatasetScopeFlagEnabled,
    required this.auditFlagEnabled,
    required this.confirmationRequired,
    required this.environmentCapabilityEnabled,
    required this.controlLevel,
    required this.transactionDraftPermission,
    required this.confirmedExecutionPermission,
    required this.localDataScopeReady,
    required this.policyProvenance,
    this.denialReason,
  });

  final AiAppControlPermissionRequest request;
  final bool allowed;
  final int policyRevision;
  final bool appControlFlagEnabled;
  final bool createDraftsFlagEnabled;
  final bool confirmedExecutionFlagEnabled;
  final bool localDatasetScopeFlagEnabled;
  final bool auditFlagEnabled;
  final bool confirmationRequired;
  final bool environmentCapabilityEnabled;
  final AiAppControlLevel controlLevel;
  final bool transactionDraftPermission;
  final bool confirmedExecutionPermission;
  final bool localDataScopeReady;
  final AiAppControlPolicyProvenance policyProvenance;
  final AiAppControlDenialReason? denialReason;

  String? get safeFailureCode => switch (denialReason) {
    AiAppControlDenialReason.controlLevelOff =>
      AppAgentFailureCodes.appControlOff,
    AiAppControlDenialReason.transactionDraftsDisabled =>
      AppAgentFailureCodes.transactionDraftsDisabled,
    AiAppControlDenialReason.confirmedExecutionDisabled =>
      AppAgentFailureCodes.confirmedExecutionDisabled,
    AiAppControlDenialReason.ownerScopeNotReady =>
      AppAgentFailureCodes.ownerScopeNotReady,
    AiAppControlDenialReason.legacyDataUnresolved =>
      AppAgentFailureCodes.legacyDataUnresolved,
    AiAppControlDenialReason.legacyPolicyUnresolved =>
      AppAgentFailureCodes.legacyPolicyUnresolved,
    AiAppControlDenialReason.staleConfiguration =>
      AppAgentFailureCodes.staleAppControlConfiguration,
    null => null,
  };

  String get safeDiagnostic {
    final denial = denialReason?.name ?? 'none';
    return 'ai_app_control_decision '
        'request=${request.name} '
        'policy_revision=$policyRevision '
        'app_control_flag_enabled=$appControlFlagEnabled '
        'create_drafts_flag_enabled=$createDraftsFlagEnabled '
        'confirmed_execution_flag_enabled=$confirmedExecutionFlagEnabled '
        'local_dataset_scope_flag_enabled=$localDatasetScopeFlagEnabled '
        'audit_flag_enabled=$auditFlagEnabled '
        'confirmation_required=$confirmationRequired '
        'environment_capability_enabled=$environmentCapabilityEnabled '
        'account_control_level=${controlLevel.name} '
        'transaction_draft_permission=$transactionDraftPermission '
        'confirmed_execution_permission=$confirmedExecutionPermission '
        'local_data_scope_ready=$localDataScopeReady '
        'denial_code=$denial '
        'policy_source=${policyProvenance.name}';
  }
}

/// Resolves transaction app-control gates in a stable, auditable order.
///
/// Configuration lifecycle errors take precedence because their apparent
/// account level may only be a temporary fail-closed fallback. A deliberate
/// Off selection is then reported distinctly from an unavailable scope or a
/// disabled draft/execution capability.
abstract final class AiAppControlPermissionResolver {
  static AiAppControlPermissionDecision resolve({
    required EffectiveAiAppControlPolicy policy,
    required AiAppControlPermissionRequest request,
    String confirmedToolId = 'createIncomeDraft',
    bool ownerScopeUnavailable = false,
    bool legacyDataUnresolved = false,
    AiAppControlConfigurationState configurationState =
        AiAppControlConfigurationState.current,
    required AiAppControlPolicyProvenance policyProvenance,
  }) {
    final draftEnvironmentCapabilityEnabled =
        policy.flags.appControlEnabled &&
        policy.flags.createDraftsEnabled &&
        policy.flags.agentAuditEnabled;
    final executionEnvironmentCapabilityEnabled =
        draftEnvironmentCapabilityEnabled &&
        policy.flags.confirmedExecutionEnabled &&
        (confirmedToolId != 'createTransferDraft' ||
            policy.flags.transferExecutionEnabled);
    final environmentCapabilityEnabled =
        request == AiAppControlPermissionRequest.transactionDraft
        ? draftEnvironmentCapabilityEnabled
        : executionEnvironmentCapabilityEnabled;
    final localDataScopeReady =
        !ownerScopeUnavailable &&
        policy.hasAuthenticatedScope &&
        policy.runtimeOwnerScopeSafe &&
        policy.flags.localDatasetScopeVerified;
    final transactionDraftPermission =
        !ownerScopeUnavailable && policy.canCreateTransactionDraft;
    final confirmedExecutionPermission =
        transactionDraftPermission &&
        policy.canExecuteConfirmedTool(confirmedToolId);

    AiAppControlDenialReason? denialReason;
    if (ownerScopeUnavailable) {
      denialReason = AiAppControlDenialReason.ownerScopeNotReady;
    } else if (legacyDataUnresolved) {
      denialReason = AiAppControlDenialReason.legacyDataUnresolved;
    } else if (configurationState ==
        AiAppControlConfigurationState.legacyUnresolved) {
      denialReason = AiAppControlDenialReason.legacyPolicyUnresolved;
    } else if (configurationState == AiAppControlConfigurationState.stale) {
      denialReason = AiAppControlDenialReason.staleConfiguration;
    } else if (policy.settings.level == AiAppControlLevel.off) {
      denialReason = AiAppControlDenialReason.controlLevelOff;
    } else if (!localDataScopeReady) {
      denialReason = AiAppControlDenialReason.ownerScopeNotReady;
    } else if (!transactionDraftPermission) {
      denialReason = AiAppControlDenialReason.transactionDraftsDisabled;
    } else if (request ==
            AiAppControlPermissionRequest.confirmedTransactionExecution &&
        !confirmedExecutionPermission) {
      denialReason = AiAppControlDenialReason.confirmedExecutionDisabled;
    }

    return AiAppControlPermissionDecision._(
      request: request,
      allowed: denialReason == null,
      policyRevision: policy.configurationRevision,
      appControlFlagEnabled: policy.flags.appControlEnabled,
      createDraftsFlagEnabled: policy.flags.createDraftsEnabled,
      confirmedExecutionFlagEnabled: policy.flags.confirmedExecutionEnabled,
      localDatasetScopeFlagEnabled: policy.flags.localDatasetScopeVerified,
      auditFlagEnabled: policy.flags.agentAuditEnabled,
      confirmationRequired: policy.settings.requireConfirmationForEveryChange,
      environmentCapabilityEnabled: environmentCapabilityEnabled,
      controlLevel: policy.settings.level,
      transactionDraftPermission: transactionDraftPermission,
      confirmedExecutionPermission: confirmedExecutionPermission,
      localDataScopeReady: localDataScopeReady,
      policyProvenance: policyProvenance,
      denialReason: denialReason,
    );
  }
}
