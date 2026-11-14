import '../../domain/app_agent/app_agent_contracts.dart';
import '../../domain/app_agent/app_agent_models.dart';
import '../../domain/app_agent/app_agent_policy.dart';
import '../../domain/app_agent/app_agent_reconciliation.dart';

final class AppAgentStartupReconciliationSummary {
  const AppAgentStartupReconciliationSummary({
    required this.inspectedCount,
    required this.confirmedPendingCount,
    required this.verifiedSucceededCount,
    required this.verifiedNotExecutedCount,
    required this.stillInProgressCount,
    required this.inconsistentCount,
    required this.requiresManualReviewCount,
    required this.reconciledResults,
  });

  static const empty = AppAgentStartupReconciliationSummary(
    inspectedCount: 0,
    confirmedPendingCount: 0,
    verifiedSucceededCount: 0,
    verifiedNotExecutedCount: 0,
    stillInProgressCount: 0,
    inconsistentCount: 0,
    requiresManualReviewCount: 0,
    reconciledResults: <AppAgentExecutionResult>[],
  );

  final int inspectedCount;
  final int confirmedPendingCount;
  final int verifiedSucceededCount;
  final int verifiedNotExecutedCount;
  final int stillInProgressCount;
  final int inconsistentCount;
  final int requiresManualReviewCount;
  final List<AppAgentExecutionResult> reconciledResults;

  AppAgentExecutionResult? get latestUserVisibleResult =>
      reconciledResults.firstOrNull;
}

/// Reconciles durable commands against actual owner-scoped business rows.
/// It never calls a business handler's execution method and never reconstructs
/// confirmation authority.
final class AppAgentStartupReconciler {
  const AppAgentStartupReconciler({
    required AppAgentCommandStore commandStore,
    required AppAgentDurableExecutionStore executionStore,
    required AppAgentCommandHandlerRegistry handlerRegistry,
  }) : _commandStore = commandStore,
       _executionStore = executionStore,
       _handlerRegistry = handlerRegistry;

  final AppAgentCommandStore _commandStore;
  final AppAgentDurableExecutionStore _executionStore;
  final AppAgentCommandHandlerRegistry _handlerRegistry;

  Future<AppAgentStartupReconciliationSummary> reconcile() async {
    final commands = await _executionStore.readRecoverableCommands();
    var confirmedPending = 0;
    var verifiedSucceeded = 0;
    var verifiedNotExecuted = 0;
    var stillInProgress = 0;
    var inconsistent = 0;
    var requiresManualReview = 0;
    final results = <AppAgentExecutionResult>[];

    for (final command in commands) {
      if (command.status == AppAgentCommandStatus.confirmed) {
        // Confirmation alone is not authority to execute after restart.
        confirmedPending += 1;
        continue;
      }
      if (command.status == AppAgentCommandStatus.partiallySucceeded) {
        requiresManualReview += 1;
        final result = await _executionStore.readVerifiedResult(
          command.commandId,
        );
        if (result != null) {
          results.add(result);
        }
        continue;
      }
      if (command.status == AppAgentCommandStatus.succeeded) {
        final result = await _executionStore.readVerifiedResult(
          command.commandId,
        );
        if (result?.verified == true) {
          verifiedSucceeded += 1;
          results.add(result!);
        } else {
          requiresManualReview += 1;
        }
        continue;
      }
      if (command.status != AppAgentCommandStatus.executing) continue;

      final receipt = await _executionStore.readExecutionReceipt(command);
      if (receipt == null) {
        requiresManualReview += 1;
        try {
          results.add(
            await _executionStore.persistMissingCorrelationManualReview(
              command: command,
            ),
          );
        } on Object {
          // A concurrent reconciler may already have persisted the same
          // manual-review result. Read it back if so; otherwise leave the
          // attempt executing so a later startup can inspect it again.
          final current = await _commandStore.readCommand(
            commandId: command.commandId,
            accountScope: command.userAccountScope,
          );
          if (current?.status == AppAgentCommandStatus.partiallySucceeded) {
            final persisted = await _executionStore.readVerifiedResult(
              command.commandId,
            );
            if (persisted != null) results.add(persisted);
          }
        }
        continue;
      }
      final handler = _handlerRegistry.handlerFor(command.toolId);
      final reconciliation = handler is AppAgentReconciliableCommandHandler
          ? await _safeReconcile(handler, command, receipt)
          : AppAgentReconciliationResult(
              status: AppAgentReconciliationStatus.requiresManualReview,
              entityType: command.commandType.name,
              affectedCount: 0,
              safeFailureCode: AppAgentFailureCodes.recoveryManualReview,
            );

      switch (reconciliation.status) {
        case AppAgentReconciliationStatus.verifiedSucceeded:
          verifiedSucceeded += 1;
        case AppAgentReconciliationStatus.verifiedNotExecuted:
          verifiedNotExecuted += 1;
        case AppAgentReconciliationStatus.stillInProgress:
          stillInProgress += 1;
          continue;
        case AppAgentReconciliationStatus.inconsistent:
          inconsistent += 1;
        case AppAgentReconciliationStatus.requiresManualReview:
          requiresManualReview += 1;
      }

      try {
        results.add(
          await _executionStore.persistReconciliation(
            command: command,
            receipt: receipt,
            reconciliation: reconciliation,
          ),
        );
      } on Object {
        // Persistence uncertainty deliberately leaves the attempt executing so
        // a later startup can inspect business state again. Execution is never
        // retried from this path.
        requiresManualReview += 1;
      }
    }

    results.sort(
      (left, right) => right.completedAt.compareTo(left.completedAt),
    );
    return AppAgentStartupReconciliationSummary(
      inspectedCount: commands.length,
      confirmedPendingCount: confirmedPending,
      verifiedSucceededCount: verifiedSucceeded,
      verifiedNotExecutedCount: verifiedNotExecuted,
      stillInProgressCount: stillInProgress,
      inconsistentCount: inconsistent,
      requiresManualReviewCount: requiresManualReview,
      reconciledResults: List<AppAgentExecutionResult>.unmodifiable(results),
    );
  }

  Future<AppAgentReconciliationResult> _safeReconcile(
    AppAgentReconciliableCommandHandler handler,
    AppAgentCommand command,
    AppAgentExecutionReceipt receipt,
  ) async {
    try {
      return await handler.reconcileBusinessOperation(command, receipt);
    } on Object {
      return AppAgentReconciliationResult(
        status: AppAgentReconciliationStatus.requiresManualReview,
        entityType: command.commandType.name,
        affectedCount: 0,
        safeFailureCode: AppAgentFailureCodes.recoveryManualReview,
      );
    }
  }
}
