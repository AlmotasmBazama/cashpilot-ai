import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/ai_app_control_permission_resolver.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/effective_ai_app_control_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_app_control_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiAppControlPermissionResolver', () {
    test('Full Control permits transaction drafts and confirmed execution', () {
      final policy = _policy(level: AiAppControlLevel.fullControl);

      expect(_draftDecision(policy).allowed, isTrue);
      expect(_executionDecision(policy).allowed, isTrue);
    });

    test('Review Before Execution permits preview and explicit Confirm', () {
      final policy = _policy(level: AiAppControlLevel.reviewBeforeExecution);

      expect(_draftDecision(policy).allowed, isTrue);
      expect(_executionDecision(policy).allowed, isTrue);
      expect(policy.confirmationAlwaysRequired, isTrue);
    });

    test('Off is a distinct typed denial', () {
      final decision = _draftDecision(_policy(level: AiAppControlLevel.off));

      expect(decision.allowed, isFalse);
      expect(decision.denialReason, AiAppControlDenialReason.controlLevelOff);
      expect(decision.safeFailureCode, AppAgentFailureCodes.appControlOff);
    });

    test('disabled transaction drafts are a distinct typed denial', () {
      final decision = _draftDecision(
        _policy(
          level: AiAppControlLevel.fullControl,
          allowTransactionDrafts: false,
        ),
      );

      expect(
        decision.denialReason,
        AiAppControlDenialReason.transactionDraftsDisabled,
      );
      expect(
        decision.safeFailureCode,
        AppAgentFailureCodes.transactionDraftsDisabled,
      );
    });

    test('disabled confirmed execution remains distinct from draft denial', () {
      final policy = _policy(
        level: AiAppControlLevel.fullControl,
        confirmedExecutionEnabled: false,
      );

      expect(_draftDecision(policy).allowed, isTrue);
      final execution = _executionDecision(policy);
      expect(
        execution.denialReason,
        AiAppControlDenialReason.confirmedExecutionDisabled,
      );
      expect(
        execution.safeFailureCode,
        AppAgentFailureCodes.confirmedExecutionDisabled,
      );
      expect(execution.environmentCapabilityEnabled, isFalse);
    });

    test(
      'disabled transfer execution is reflected in environment capability',
      () {
        final execution = AiAppControlPermissionResolver.resolve(
          policy: _policy(level: AiAppControlLevel.fullControl),
          request: AiAppControlPermissionRequest.confirmedTransactionExecution,
          confirmedToolId: 'createTransferDraft',
          policyProvenance: AiAppControlPolicyProvenance.persistedUserSelection,
        );

        expect(execution.allowed, isFalse);
        expect(
          execution.denialReason,
          AiAppControlDenialReason.confirmedExecutionDisabled,
        );
        expect(execution.environmentCapabilityEnabled, isFalse);
      },
    );

    test('owner-health failure is a distinct typed denial', () {
      final decision = _draftDecision(
        _policy(level: AiAppControlLevel.fullControl, ownerScopeSafe: false),
      );

      expect(
        decision.denialReason,
        AiAppControlDenialReason.ownerScopeNotReady,
      );
      expect(decision.safeFailureCode, AppAgentFailureCodes.ownerScopeNotReady);
    });

    test('missing owner binding forces an owner-scope denial safely', () {
      final decision = AiAppControlPermissionResolver.resolve(
        policy: _policy(level: AiAppControlLevel.fullControl),
        request: AiAppControlPermissionRequest.transactionDraft,
        ownerScopeUnavailable: true,
        policyProvenance: AiAppControlPolicyProvenance.persistedUserSelection,
      );

      expect(
        decision.denialReason,
        AiAppControlDenialReason.ownerScopeNotReady,
      );
      expect(decision.localDataScopeReady, isFalse);
      expect(decision.transactionDraftPermission, isFalse);
    });

    test('unclaimed legacy local data is distinct from owner health', () {
      final decision = AiAppControlPermissionResolver.resolve(
        policy: _policy(
          level: AiAppControlLevel.fullControl,
          ownerScopeSafe: false,
        ),
        request: AiAppControlPermissionRequest.transactionDraft,
        legacyDataUnresolved: true,
        policyProvenance: AiAppControlPolicyProvenance.persistedUserSelection,
      );

      expect(
        decision.denialReason,
        AiAppControlDenialReason.legacyDataUnresolved,
      );
      expect(
        decision.safeFailureCode,
        AppAgentFailureCodes.legacyDataUnresolved,
      );
    });

    test('unresolved legacy policy and stale configuration stay distinct', () {
      final policy = _policy(level: AiAppControlLevel.fullControl);
      final unresolved = AiAppControlPermissionResolver.resolve(
        policy: policy,
        request: AiAppControlPermissionRequest.transactionDraft,
        configurationState: AiAppControlConfigurationState.legacyUnresolved,
        policyProvenance: AiAppControlPolicyProvenance.legacyUnresolved,
      );
      final stale = AiAppControlPermissionResolver.resolve(
        policy: policy,
        request: AiAppControlPermissionRequest.transactionDraft,
        configurationState: AiAppControlConfigurationState.stale,
        policyProvenance: AiAppControlPolicyProvenance.environmentDefault,
      );

      expect(
        unresolved.denialReason,
        AiAppControlDenialReason.legacyPolicyUnresolved,
      );
      expect(
        unresolved.safeFailureCode,
        AppAgentFailureCodes.legacyPolicyUnresolved,
      );
      expect(stale.denialReason, AiAppControlDenialReason.staleConfiguration);
      expect(
        stale.safeFailureCode,
        AppAgentFailureCodes.staleAppControlConfiguration,
      );
    });

    test('diagnostic contains only allowlisted policy facts', () {
      final decision = _draftDecision(_policy(level: AiAppControlLevel.off));

      expect(
        decision.safeDiagnostic,
        'ai_app_control_decision '
        'request=transactionDraft '
        'policy_revision=1 '
        'app_control_flag_enabled=true '
        'create_drafts_flag_enabled=true '
        'confirmed_execution_flag_enabled=true '
        'local_dataset_scope_flag_enabled=true '
        'audit_flag_enabled=true '
        'confirmation_required=true '
        'environment_capability_enabled=true '
        'account_control_level=off '
        'transaction_draft_permission=false '
        'confirmed_execution_permission=false '
        'local_data_scope_ready=true '
        'denial_code=controlLevelOff '
        'policy_source=persistedUserSelection',
      );
      expect(decision.safeDiagnostic, isNot(contains('prompt')));
      expect(decision.safeDiagnostic, isNot(contains('uid')));
      expect(decision.safeDiagnostic, isNot(contains('owner_scope=')));
      expect(decision.safeDiagnostic, isNot(contains('150')));
      expect(decision.safeDiagnostic, isNot(contains('LYD')));
    });
  });
}

AiAppControlPermissionDecision _draftDecision(
  EffectiveAiAppControlPolicy policy,
) => AiAppControlPermissionResolver.resolve(
  policy: policy,
  request: AiAppControlPermissionRequest.transactionDraft,
  policyProvenance: policy.provenance,
);

AiAppControlPermissionDecision _executionDecision(
  EffectiveAiAppControlPolicy policy,
) => AiAppControlPermissionResolver.resolve(
  policy: policy,
  request: AiAppControlPermissionRequest.confirmedTransactionExecution,
  policyProvenance: policy.provenance,
);

EffectiveAiAppControlPolicy _policy({
  required AiAppControlLevel level,
  bool allowTransactionDrafts = true,
  bool confirmedExecutionEnabled = true,
  bool ownerScopeSafe = true,
}) => EffectiveAiAppControlPolicy(
  flags: AiAppControlFeatureFlags(
    appControlEnabled: true,
    readToolsEnabled: true,
    navigationToolsEnabled: true,
    createDraftsEnabled: true,
    confirmedExecutionEnabled: confirmedExecutionEnabled,
    updateDraftsEnabled: false,
    archiveDraftsEnabled: false,
    multiStepPlansEnabled: false,
    agentAuditEnabled: true,
    localDatasetScopeVerified: true,
  ),
  settings: AiAppControlSettings(
    level: level,
    allowFinancialAnalysis: true,
    allowNavigation: level == AiAppControlLevel.fullControl,
    allowTransactionDrafts: allowTransactionDrafts,
    allowBudgetAndGoalDrafts: level == AiAppControlLevel.fullControl,
    allowAccountCategoryPayeeDrafts: level == AiAppControlLevel.fullControl,
    allowRecurringDrafts: false,
    allowMultiStepPlans: false,
    requireConfirmationForEveryChange: true,
    provenance: AiAppControlPolicyProvenance.persistedUserSelection,
  ),
  hasAuthenticatedScope: true,
  runtimeOwnerScopeSafe: ownerScopeSafe,
  provenance: AiAppControlPolicyProvenance.persistedUserSelection,
  configurationRevision: 1,
);
