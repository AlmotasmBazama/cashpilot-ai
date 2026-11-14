import 'app_agent_models.dart';
import 'app_agent_reconciliation.dart';

abstract interface class AppAgentCommandStore {
  Future<void> saveCommand(AppAgentCommand command);

  Future<AppAgentCommand?> readCommand({
    required String commandId,
    required String accountScope,
  });

  Future<List<AppAgentCommand>> readCommandsForScope(String accountScope);

  Future<void> savePreview({
    required AppAgentPreview preview,
    required String accountScope,
  });

  Future<AppAgentPreview?> readPreview({
    required String commandId,
    required String accountScope,
  });

  Future<AppAgentCommand?> transition({
    required String commandId,
    required String accountScope,
    required AppAgentCommandStatus expectedStatus,
    required AppAgentCommandStatus nextStatus,
    String? safeFailureCode,
  });

  Future<void> clearScope(String accountScope);
}

abstract interface class AppAgentAuditStore {
  Future<void> append(AppAgentAuditEvent event);

  Future<List<AppAgentAuditEvent>> readRecent({
    required String accountScope,
    int limit = 100,
  });

  Future<void> clearScope(String accountScope);
}

abstract interface class AppAgentConfirmationProofStore {
  Future<void> saveProof({
    required String commandId,
    required String accountScope,
    required String proof,
    required AppAgentConfirmationMethod method,
    required DateTime expiresAt,
  });

  Future<bool> consumeProof({
    required String commandId,
    required String accountScope,
    required String proof,
    required AppAgentConfirmationMethod method,
    required DateTime now,
  });

  Future<void> clearScope(String accountScope);
}

class AppAgentRevalidationResult {
  const AppAgentRevalidationResult({
    required this.isValid,
    required this.currentStateFingerprint,
    this.safeFailureCode,
  });

  final bool isValid;
  final String currentStateFingerprint;
  final String? safeFailureCode;
}

class AppAgentHandlerResult {
  const AppAgentHandlerResult({
    required this.verified,
    required this.entityType,
    required this.affectedCount,
    this.partiallySucceeded = false,
    this.completionUncertain = false,
    this.safeFailureCode,
    this.undoAvailable = false,
    this.undoToken,
  });

  final bool verified;
  final String entityType;
  final int affectedCount;
  final bool partiallySucceeded;
  final bool completionUncertain;
  final String? safeFailureCode;
  final bool undoAvailable;
  final String? undoToken;
}

abstract interface class AppAgentCommandHandler {
  String get toolId;

  AgentPermission get permission;

  AgentActionRisk get risk;

  Future<AppAgentRevalidationResult> revalidate(AppAgentCommand command);

  Future<AppAgentHandlerResult> executeConfirmed(AppAgentCommand command);
}

abstract interface class AppAgentReconciliableCommandHandler
    implements AppAgentCommandHandler {
  AppAgentBusinessOperationSpec businessOperationFor(AppAgentCommand command);

  Future<AppAgentReconciliationResult> reconcileBusinessOperation(
    AppAgentCommand command,
    AppAgentExecutionReceipt receipt,
  );
}

abstract interface class AppAgentFaultAwareCommandHandler
    implements AppAgentCommandHandler {
  Future<AppAgentHandlerResult> executeConfirmedWithFaultInjection(
    AppAgentCommand command,
    AppAgentExecutionFaultInjector faultInjector,
  );
}

abstract interface class AppAgentCommandHandlerRegistry {
  AppAgentCommandHandler? handlerFor(String toolId);
}

enum AppAgentExecutionClaimDisposition {
  claimed,
  duplicateInProgress,
  completed,
}

class AppAgentExecutionClaim {
  const AppAgentExecutionClaim({
    required this.disposition,
    this.attemptId,
    this.previousResult,
  });

  final AppAgentExecutionClaimDisposition disposition;
  final String? attemptId;
  final AppAgentExecutionResult? previousResult;
}

abstract interface class AppAgentDurableExecutionStore {
  Future<AppAgentExecutionClaim> claim(
    AppAgentCommand command, {
    required AppAgentConfirmation confirmation,
    required DateTime now,
    AppAgentBusinessOperationSpec? operation,
  });

  Future<void> complete({
    required AppAgentCommand command,
    required String attemptId,
    required AppAgentExecutionResult result,
  });

  Future<AppAgentExecutionResult?> readVerifiedResult(String commandId);

  Future<List<AppAgentCommand>> readRecoverableCommands();

  /// Finalizes an already-claimed execution whose business-operation receipt
  /// is missing. Implementations must never execute or retry the operation.
  Future<AppAgentExecutionResult> persistMissingCorrelationManualReview({
    required AppAgentCommand command,
  });

  Future<void> acknowledgeUiDelivery(String commandId);

  Future<AppAgentExecutionReceipt?> readExecutionReceipt(
    AppAgentCommand command,
  );

  Future<AppAgentExecutionResult> persistReconciliation({
    required AppAgentCommand command,
    required AppAgentExecutionReceipt receipt,
    required AppAgentReconciliationResult reconciliation,
  });
}

abstract interface class AppAgentAccountScopeProvider {
  String? get currentAccountScope;
}
