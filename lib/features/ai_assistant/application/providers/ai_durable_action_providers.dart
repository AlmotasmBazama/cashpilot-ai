import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../budgets/application/providers/budgets_providers.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../goals/application/providers/goals_providers.dart';
import '../../../payees/application/providers/payees_providers.dart';
import '../../../transactions/application/providers/transactions_providers.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/sync/application/backup_operation_fence.dart';
import '../../data/app_agent/drift_app_agent_stores.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/app_agent/app_agent_contracts.dart';
import '../../domain/app_agent/app_agent_models.dart';
import '../../domain/app_agent/canonical_app_tool_catalog.dart';
import '../app_agent/app_agent_command_runtime.dart';
import '../app_agent/app_agent_reconciliation_service.dart';
import '../app_agent/durable_ai_action_bridge.dart';
import '../app_agent/fenced_ai_action_durable_runtime.dart';
import 'ai_agent_scope_providers.dart';
import 'ai_app_control_providers.dart';
import 'ai_assistant_providers.dart';

const _durableFinancialToolIds = <String>{
  'createExpenseDraft',
  'createIncomeDraft',
  'createTransferDraft',
  'createBudgetDraft',
  'createGoalDraft',
  'createGoalContributionDraft',
  'updateTransactionDraft',
  'deleteTransactionDraft',
  'undoAiAction',
};

final durableAiActionResolverProvider = Provider<DurableAiActionResolver>((
  ref,
) {
  return DurableAiActionResolver(
    accounts: ref.watch(accountsRepositoryProvider),
    categories: ref.watch(categoriesRepositoryProvider),
    payees: ref.watch(payeesRepositoryProvider),
    budgets: ref.watch(budgetRepositoryProvider),
    goals: ref.watch(goalRepositoryProvider),
    transactions: ref.watch(transactionsRepositoryProvider),
    commandStore: ref.watch(appAgentCommandStoreProvider),
    executionStore: ref.watch(appAgentDurableExecutionStoreProvider),
  );
}, name: 'durableAiActionResolverProvider');

final durableFinancialHandlerRegistryProvider =
    Provider<AppAgentCommandHandlerRegistry>((ref) {
      final resolver = ref.watch(durableAiActionResolverProvider);
      final executor = ref.watch(aiActionExecutorProvider);
      return MapAppAgentCommandHandlerRegistry(
        CanonicalAppToolCatalog.safeTools
            .where(
              (descriptor) => _durableFinancialToolIds.contains(descriptor.id),
            )
            .map(
              (descriptor) => ProductionFinancialCommandHandler(
                toolId: descriptor.id,
                risk: descriptor.risk,
                resolver: resolver,
                executor: executor,
                mutationExecutor: ref.watch(
                  aiTransactionMutationExecutorProvider,
                ),
                session: ref.watch(requiredScopedAppDatabaseSessionProvider),
              ),
            ),
      );
    }, name: 'durableFinancialHandlerRegistryProvider');

final appAgentConfirmationControllerProvider =
    Provider<AppAgentConfirmationController>((ref) {
      return AppAgentConfirmationController(
        commandStore: ref.watch(appAgentCommandStoreProvider),
        proofStore: ref.watch(appAgentConfirmationProofStoreProvider),
      );
    }, name: 'appAgentConfirmationControllerProvider');

final appAgentAccountScopeAdapterProvider =
    Provider<AppAgentAccountScopeProvider>((ref) {
      return _BoundAccountScope(ref.watch(aiAgentAccountScopeProvider));
    }, name: 'appAgentAccountScopeAdapterProvider');

final durableAppAgentCommandExecutorProvider =
    Provider<AppAgentCommandExecutor>((ref) {
      return AppAgentCommandExecutor(
        commandStore: ref.watch(appAgentCommandStoreProvider),
        auditStore: ref.watch(appAgentAuditStoreProvider),
        proofStore: ref.watch(appAgentConfirmationProofStoreProvider),
        handlerRegistry: ref.watch(durableFinancialHandlerRegistryProvider),
        accountScopeProvider: ref.watch(appAgentAccountScopeAdapterProvider),
        durableExecutionStore: ref.watch(appAgentDurableExecutionStoreProvider),
        executionAuthorization: (command) => ref
            .read(effectiveAiAppControlPolicyProvider)
            .canExecuteConfirmedTool(command.toolId),
      );
    }, name: 'durableAppAgentCommandExecutorProvider');

final appAgentStartupReconciliationProvider =
    FutureProvider<AppAgentStartupReconciliationSummary>((ref) async {
      final ownerBinding = ref.watch(aiToolOwnerScopeBindingProvider);
      final session = ref.watch(scopedAppDatabaseSessionProvider);
      if (ownerBinding == null ||
          session == null ||
          !session.isActive ||
          session.ownerScopeValue != ownerBinding.accountScope) {
        return AppAgentStartupReconciliationSummary.empty;
      }
      // Reconciliation is owner-scoped financial work. Wait for both the
      // current owner's settings and health to settle; AsyncValue may retain
      // A's previous value while B is loading, so health alone is not a
      // sufficient account-switch boundary.
      final policy = ref.watch(effectiveAiAppControlPolicyProvider);
      if (!policy.hasAuthenticatedScope || !policy.runtimeOwnerScopeSafe) {
        return AppAgentStartupReconciliationSummary.empty;
      }
      final writer = ref
          .watch(backupOperationFenceProvider)
          .tryAcquireWriter(ownerBinding.accountScope);
      if (writer == null) {
        return AppAgentStartupReconciliationSummary.empty;
      }
      try {
        writer.assertActive();
        if (!_isCurrentOwnerBinding(ref, ownerBinding)) {
          return AppAgentStartupReconciliationSummary.empty;
        }
        final summary = await AppAgentStartupReconciler(
          commandStore: ref.watch(appAgentCommandStoreProvider),
          executionStore: ref.watch(appAgentDurableExecutionStoreProvider),
          handlerRegistry: ref.watch(durableFinancialHandlerRegistryProvider),
        ).reconcile();
        writer.assertActive();
        return _isCurrentOwnerBinding(ref, ownerBinding)
            ? summary
            : AppAgentStartupReconciliationSummary.empty;
      } on BackupWriterCancelledException {
        return AppAgentStartupReconciliationSummary.empty;
      } finally {
        writer.release();
      }
    }, name: 'appAgentStartupReconciliationProvider');

final appAgentRecoveryUiCoordinatorProvider =
    Provider<AppAgentRecoveryUiCoordinator>((ref) {
      // Consumption is session-local. A trusted scope/epoch transition must
      // recreate the coordinator even when the same owner signs in again.
      ref.watch(aiToolOwnerScopeBindingProvider);
      return AppAgentRecoveryUiCoordinator();
    }, name: 'appAgentRecoveryUiCoordinatorProvider');

final class AppAgentRecoveryUiCoordinator {
  final Set<String> _consumedCommandIds = <String>{};

  bool tryConsume(AppAgentExecutionResult result) {
    return _consumedCommandIds.add(result.commandId);
  }
}

final durableAiActionBridgeProvider = Provider<AiActionDurableRuntime>((ref) {
  final store = ref.watch(appAgentCommandStoreProvider);
  if (store is! DriftAppAgentCommandStore) {
    throw StateError('The production durable bridge requires the Drift store.');
  }
  final ownerBinding = ref.watch(aiToolOwnerScopeBindingProvider);
  final delegate = DurableAiActionBridge(
    commandStore: store,
    confirmationController: ref.watch(appAgentConfirmationControllerProvider),
    commandExecutor: ref.watch(durableAppAgentCommandExecutorProvider),
    handlerRegistry: ref.watch(durableFinancialHandlerRegistryProvider),
    executionStore: ref.watch(appAgentDurableExecutionStoreProvider),
    resolver: ref.watch(durableAiActionResolverProvider),
    currentScope: () => ref.read(aiAgentAccountScopeProvider),
    canExecuteConfirmedCreate: (toolId) => ref
        .read(effectiveAiAppControlPolicyProvider)
        .canExecuteConfirmedTool(toolId),
  );
  return FencedAiActionDurableRuntime(
    delegate: delegate,
    operationFence: ref.watch(backupOperationFenceProvider),
    boundOwnerScope: ownerBinding?.accountScope,
    isOwnerBindingCurrent: () => _isCurrentOwnerBinding(ref, ownerBinding),
  );
}, name: 'durableAiActionBridgeProvider');

bool _isCurrentOwnerBinding(Ref ref, AiToolOwnerScopeBinding? expectedBinding) {
  if (expectedBinding == null) return false;
  try {
    return ref.read(aiToolOwnerScopeBindingProvider) == expectedBinding;
  } on Object {
    return false;
  }
}

class _BoundAccountScope implements AppAgentAccountScopeProvider {
  const _BoundAccountScope(this.currentAccountScope);

  @override
  final String? currentAccountScope;
}
