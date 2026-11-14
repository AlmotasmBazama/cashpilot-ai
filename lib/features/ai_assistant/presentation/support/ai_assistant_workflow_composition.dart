import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../budgets/application/providers/budgets_providers.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../exchange_rates/application/base_currency_provider.dart';
import '../../../goals/application/providers/goals_providers.dart';
import '../../../insights/application/providers/insights_providers.dart';
import '../../../transactions/application/providers/transactions_providers.dart';
import '../../application/app_agent/ai_app_control_permission_resolver.dart';
import '../../application/app_agent/app_agent_reconciliation_service.dart';
import '../../application/app_agent/durable_ai_action_bridge.dart';
import '../../application/providers/ai_agent_providers.dart';
import '../../application/providers/ai_app_control_providers.dart';
import '../../application/providers/ai_assistant_conversation_workflow_providers.dart';
import '../../application/providers/ai_assistant_durable_draft_providers.dart';
import '../../application/providers/ai_assistant_providers.dart';
import '../../application/providers/ai_assistant_send_lifecycle_providers.dart';
import '../../application/providers/ai_durable_action_providers.dart';
import '../../application/providers/ai_financial_understanding_providers.dart';
import '../../application/services/ai_assistant_conversation_workflow_controller.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/app_agent/app_agent_models.dart';
import '../../domain/app_agent/app_agent_policy.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_action_validation_result.dart';
import '../../domain/entities/ai_intent.dart';

AiAssistantConversationWorkflowController
composeAiAssistantConversationWorkflowController({
  required WidgetRef ref,
  required AiToolOwnerScopeBinding? initialOwnerBinding,
  required bool Function() isMounted,
  required AiAssistantWorkflowEmissionSink publish,
  required AiAssistantWorkflowFrameBarrier waitForRenderedFrame,
}) {
  return ref
      .read(aiAssistantConversationWorkflowControllerFactoryProvider)
      .create(
        initialOwnerBinding: initialOwnerBinding,
        readOwnerBinding: () => ref.read(aiToolOwnerScopeBindingProvider),
        isMounted: isMounted,
        sendLifecycleFactory: ref.read(
          aiAssistantSendLifecycleCoordinatorFactoryProvider,
        ),
        durableDraftFactory: ref.read(
          aiAssistantDurableDraftCoordinatorFactoryProvider,
        ),
        intentRouter: ref.read(aiIntentRouterProvider),
        readUnderstandingUseCase: () =>
            ref.read(understandAiMessageUseCaseProvider),
        readFinancialCoordinator: () =>
            ref.read(aiFinancialUnderstandingCoordinatorProvider),
        agentSession: _RiverpodAiAssistantAgentSessionPort(ref),
        actionPolicy: _RiverpodAiAssistantActionPolicyPort(ref),
        draftValidator: _RiverpodAiAssistantDraftValidatorPort(ref),
        recovery: _RiverpodAiAssistantRecoveryPort(ref),
        financialReadInvalidator: _RiverpodAiAssistantFinancialReadInvalidator(
          ref,
        ),
        publish: publish,
        waitForRenderedFrame: waitForRenderedFrame,
      );
}

final class _RiverpodAiAssistantAgentSessionPort
    implements AiAssistantAgentSessionPort {
  const _RiverpodAiAssistantAgentSessionPort(this._ref);

  final WidgetRef _ref;

  @override
  bool get agentEnabled => _ref.read(aiAgentFeatureFlagsProvider).agentEnabled;

  @override
  String get baseCurrencyCode => _ref.read(effectiveBaseCurrencyCodeProvider);

  @override
  Future<AiAgentResponse?> send({
    required String content,
    required String locale,
    required String baseCurrencyCode,
  }) => _ref
      .read(aiAgentControllerProvider.notifier)
      .send(
        content: content,
        locale: locale,
        baseCurrencyCode: baseCurrencyCode,
      );

  @override
  Future<AiAgentResponse?> retry() =>
      _ref.read(aiAgentControllerProvider.notifier).retry();

  @override
  Future<void> clear() => _ref.read(aiAgentControllerProvider.notifier).clear();

  @override
  Future<void> startNew() =>
      _ref.read(aiAgentControllerProvider.notifier).startNew();

  @override
  void cancel() => _ref.read(aiAgentControllerProvider.notifier).cancel();

  @override
  void Function() captureCancellation() =>
      _ref.read(aiAgentControllerProvider.notifier).cancel;

  @override
  void recordLocalUserMessage(String content) => _ref
      .read(aiAgentControllerProvider.notifier)
      .recordLocalUserMessage(content);

  @override
  void recordLocalAssistantMessage(String content) => _ref
      .read(aiAgentControllerProvider.notifier)
      .recordLocalAssistantMessage(content);
}

final class _RiverpodAiAssistantActionPolicyPort
    implements AiAssistantActionPolicyPort {
  const _RiverpodAiAssistantActionPolicyPort(this._ref);

  final WidgetRef _ref;

  @override
  bool get appControlEnabled =>
      _ref.read(aiAppControlFeatureFlagsProvider).appControlEnabled;

  @override
  int get configurationRevision =>
      _ref.read(effectiveAiAppControlPolicyProvider).configurationRevision;

  @override
  AiAssistantOwnerScopeReadiness get ownerScopeReadiness =>
      switch (_ref.read(ownerScopeHealthProvider)) {
        AsyncData<OwnerScopeHealth>(value: final health) when health.isSafe =>
          AiAssistantOwnerScopeReadiness.safe,
        AsyncData<OwnerScopeHealth>(value: final health)
            when health.status == OwnerScopeStatus.legacyDataUnclaimed =>
          AiAssistantOwnerScopeReadiness.legacyUnclaimed,
        _ => AiAssistantOwnerScopeReadiness.unavailable,
      };

  @override
  Future<bool> readOwnerScopeSafe() async {
    try {
      return (await _ref.read(ownerScopeHealthProvider.future)).isSafe;
    } on Object {
      return false;
    }
  }

  @override
  Failure ownerUnavailableDraftFailure() => _failureForDecision(
    _resolve(
      request: AiAppControlPermissionRequest.transactionDraft,
      ownerScopeUnavailable: true,
    ),
  )!;

  @override
  Failure ownerUnavailableExecutionFailure(AiAction action) =>
      _failureForDecision(
        _resolve(
          request: AiAppControlPermissionRequest.confirmedTransactionExecution,
          confirmedToolId: _toolIdForAction(action),
          ownerScopeUnavailable: true,
        ),
      )!;

  @override
  Failure? failureForIntent(AiIntent intent) {
    if (intent == AiIntent.createExpense ||
        intent == AiIntent.createIncome ||
        intent == AiIntent.createTransfer) {
      return _failureForDecision(
        _resolve(request: AiAppControlPermissionRequest.transactionDraft),
      );
    }
    return _allowsIntent(intent) ? null : _appControlPermissionFailure;
  }

  @override
  Failure? failureForAction(
    AiAction action, {
    int? expectedConfigurationRevision,
  }) {
    if (action is CreateExpenseDraft ||
        action is CreateIncomeDraft ||
        action is CreateTransferDraft) {
      return _failureForDecision(
        _resolve(
          request: AiAppControlPermissionRequest.transactionDraft,
          expectedConfigurationRevision: expectedConfigurationRevision,
          confirmedToolId: _toolIdForAction(action),
        ),
      );
    }
    return allowsAction(action) ? null : _appControlPermissionFailure;
  }

  @override
  Failure? executionFailureForAction(
    AiAction action, {
    int? expectedConfigurationRevision,
  }) {
    if (action is CreateExpenseDraft ||
        action is CreateIncomeDraft ||
        action is CreateTransferDraft) {
      return _failureForDecision(
        _resolve(
          request: AiAppControlPermissionRequest.confirmedTransactionExecution,
          expectedConfigurationRevision: expectedConfigurationRevision,
          confirmedToolId: _toolIdForAction(action),
        ),
      );
    }
    final toolId = _toolIdForAction(action);
    return toolId.isNotEmpty &&
            _ref
                .read(effectiveAiAppControlPolicyProvider)
                .canExecuteConfirmedTool(toolId)
        ? null
        : _appControlPermissionFailure;
  }

  @override
  bool allowsAction(AiAction action) {
    final policy = _ref.read(effectiveAiAppControlPolicyProvider);
    return switch (action) {
      CreateExpenseDraft() ||
      CreateIncomeDraft() ||
      CreateTransferDraft() => policy.canCreateTransactionDraft,
      UpdateTransactionDraft() => policy.canUpdateDraft,
      DeleteTransactionDraft() => policy.canArchiveDraft,
      UndoAiActionDraft() => policy.canUpdateDraft && policy.canArchiveDraft,
      CreateBudgetDraft() ||
      CreateGoalDraft() ||
      AddGoalContributionDraft() => policy.canCreateBudgetOrGoalDraft,
      CreateCategoryDraft() => policy.canCreateAccountCategoryPayeeDraft,
      _ => true,
    };
  }

  bool _allowsIntent(AiIntent intent) {
    final policy = _ref.read(effectiveAiAppControlPolicyProvider);
    return switch (intent) {
      AiIntent.createExpense ||
      AiIntent.createIncome ||
      AiIntent.createTransfer => policy.canCreateTransactionDraft,
      AiIntent.updateTransaction => policy.canUpdateDraft,
      AiIntent.deleteTransaction => policy.canArchiveDraft,
      AiIntent.undoAction => policy.canUpdateDraft && policy.canArchiveDraft,
      // A clarification response cannot execute by itself. The resolved
      // action is still checked against the current owner-scoped policy.
      AiIntent.clarificationResponse => true,
      AiIntent.createBudget ||
      AiIntent.createGoal ||
      AiIntent.addGoalContribution => policy.canCreateBudgetOrGoalDraft,
      AiIntent.createCategory => policy.canCreateAccountCategoryPayeeDraft,
      _ => false,
    };
  }

  AiAppControlPermissionDecision _resolve({
    required AiAppControlPermissionRequest request,
    int? expectedConfigurationRevision,
    String confirmedToolId = 'createIncomeDraft',
    bool ownerScopeUnavailable = false,
  }) {
    final policy = _ref.read(effectiveAiAppControlPolicyProvider);
    final legacyDataUnresolved =
        !ownerScopeUnavailable &&
        switch (_ref.read(ownerScopeHealthProvider)) {
          AsyncData<OwnerScopeHealth>(value: final health) =>
            health.status == OwnerScopeStatus.legacyDataUnclaimed,
          _ => false,
        };
    final configurationState = switch (policy) {
      _ when !policy.configurationResolved =>
        AiAppControlConfigurationState.legacyUnresolved,
      _ when !policy.hasCurrentConfiguration =>
        AiAppControlConfigurationState.stale,
      _
          when expectedConfigurationRevision != null &&
              expectedConfigurationRevision != policy.configurationRevision =>
        AiAppControlConfigurationState.stale,
      _ => AiAppControlConfigurationState.current,
    };
    return AiAppControlPermissionResolver.resolve(
      policy: policy,
      request: request,
      confirmedToolId: confirmedToolId,
      ownerScopeUnavailable: ownerScopeUnavailable,
      legacyDataUnresolved: legacyDataUnresolved,
      configurationState: configurationState,
      policyProvenance: policy.provenance,
    );
  }

  Failure? _failureForDecision(AiAppControlPermissionDecision decision) {
    if (decision.allowed) return null;
    _ref.read(appLoggerProvider).warning(decision.safeDiagnostic);
    return Failure(
      message: _safePermissionMessage(decision.denialReason!),
      code: decision.safeFailureCode,
    );
  }

  String _safePermissionMessage(AiAppControlDenialReason reason) =>
      switch (reason) {
        AiAppControlDenialReason.controlLevelOff =>
          'AI Control is Off for this account.',
        AiAppControlDenialReason.transactionDraftsDisabled =>
          'Transaction draft creation is disabled for this account.',
        AiAppControlDenialReason.confirmedExecutionDisabled =>
          'Confirmed financial execution is disabled.',
        AiAppControlDenialReason.ownerScopeNotReady =>
          'The account local-data scope is not ready for financial actions.',
        AiAppControlDenialReason.legacyDataUnresolved =>
          'Legacy local data must be resolved for this account first.',
        AiAppControlDenialReason.legacyPolicyUnresolved =>
          'The legacy AI Control policy must be resolved first.',
        AiAppControlDenialReason.staleConfiguration =>
          'AI Control configuration changed or is still refreshing.',
      };

  String _toolIdForAction(AiAction action) => switch (action) {
    CreateExpenseDraft() => 'createExpenseDraft',
    CreateIncomeDraft() => 'createIncomeDraft',
    CreateTransferDraft() => 'createTransferDraft',
    UpdateTransactionDraft() => 'updateTransactionDraft',
    DeleteTransactionDraft() => 'deleteTransactionDraft',
    UndoAiActionDraft() => 'undoAiAction',
    CreateBudgetDraft() => 'createBudgetDraft',
    CreateGoalDraft() => 'createGoalDraft',
    AddGoalContributionDraft() => 'createGoalContributionDraft',
    _ => '',
  };

  static const _appControlPermissionFailure = Failure(
    message: 'Financial draft permission is not enabled.',
    code: AppAgentFailureCodes.permissionDenied,
  );
}

final class _RiverpodAiAssistantDraftValidatorPort
    implements AiAssistantDraftValidatorPort {
  const _RiverpodAiAssistantDraftValidatorPort(this._ref);

  final WidgetRef _ref;

  @override
  AiActionValidationResult validate(AiAction action) =>
      _ref.read(aiActionValidatorProvider).validate(action);
}

final class _RiverpodAiAssistantRecoveryPort
    implements AiAssistantRecoveryPort {
  const _RiverpodAiAssistantRecoveryPort(this._ref);

  final WidgetRef _ref;

  @override
  Future<AppAgentStartupReconciliationSummary> readStartupReconciliation() =>
      _ref.read(appAgentStartupReconciliationProvider.future);

  @override
  AiActionDurableRuntime readRuntime() =>
      _ref.read(durableAiActionBridgeProvider);

  @override
  bool tryConsume(AppAgentExecutionResult result) =>
      _ref.read(appAgentRecoveryUiCoordinatorProvider).tryConsume(result);
}

final class _RiverpodAiAssistantFinancialReadInvalidator
    implements AiAssistantFinancialReadInvalidator {
  const _RiverpodAiAssistantFinancialReadInvalidator(this._ref);

  final WidgetRef _ref;

  @override
  void invalidateAfterVerifiedExecution() {
    _ref
      ..invalidate(accountsProvider)
      ..invalidate(transactionsProvider)
      ..invalidate(categoriesProvider)
      ..invalidate(budgetProgressProvider)
      ..invalidate(budgetSummaryProvider)
      ..invalidate(goalsProvider)
      ..invalidate(allGoalsProvider)
      ..invalidate(goalProgressProvider)
      ..invalidate(allGoalProgressProvider)
      ..invalidate(goalSummaryProvider);
    _ref.invalidate(financialInsightsProvider);
  }
}
