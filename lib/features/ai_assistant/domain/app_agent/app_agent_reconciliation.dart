import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'app_agent_models.dart';

final class AppAgentBusinessOperationKey {
  const AppAgentBusinessOperationKey(this.value);

  final String value;

  @override
  String toString() => 'AppAgentBusinessOperationKey(<opaque>)';
}

abstract final class AppAgentBusinessIdentifiers {
  static const _operationDomain = 'cashpilot.agent-business-operation.v1';
  static const _entityDomain = 'cashpilot.agent-business-entity.v1';

  static AppAgentBusinessOperationKey operationKey(AppAgentCommand command) {
    final value = sha256
        .convert(
          utf8.encode(
            '$_operationDomain\u0000${command.userAccountScope}\u0000'
            '${command.commandId}\u0000${command.revision}\u0000${command.toolId}',
          ),
        )
        .toString();
    return AppAgentBusinessOperationKey(value);
  }

  static String transactionId(AppAgentCommand command) =>
      _stableUuid(command, 'transaction');

  static String transferGroupId(AppAgentCommand command) =>
      _stableUuid(command, 'transfer-group');

  static String transferOutgoingId(AppAgentCommand command) =>
      _stableUuid(command, 'transfer-out');

  static String transferIncomingId(AppAgentCommand command) =>
      _stableUuid(command, 'transfer-in');

  static String _stableUuid(AppAgentCommand command, String role) {
    final hex = sha256
        .convert(
          utf8.encode(
            '$_entityDomain\u0000${command.userAccountScope}\u0000'
            '${command.commandId}\u0000${command.revision}\u0000'
            '${command.toolId}\u0000$role',
          ),
        )
        .toString();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '5${hex.substring(13, 16)}-a${hex.substring(17, 20)}-'
        '${hex.substring(20, 32)}';
  }
}

final class AppAgentBusinessOperationSpec {
  const AppAgentBusinessOperationSpec({
    required this.key,
    required this.expectedEntityType,
    required this.expectedPersistedIdentifiers,
    required this.verificationMethod,
    required this.safeAutomaticResume,
    required this.automaticRetryProhibited,
  });

  final AppAgentBusinessOperationKey key;
  final String expectedEntityType;
  final List<String> expectedPersistedIdentifiers;
  final String verificationMethod;
  final bool safeAutomaticResume;
  final bool automaticRetryProhibited;
}

final class AppAgentExecutionReceipt {
  const AppAgentExecutionReceipt({
    required this.attemptId,
    required this.commandId,
    required this.commandRevision,
    required this.operation,
    required this.claimedAt,
  });

  final String attemptId;
  final String commandId;
  final int commandRevision;
  final AppAgentBusinessOperationSpec operation;
  final DateTime claimedAt;
}

enum AppAgentReconciliationStatus {
  verifiedSucceeded,
  verifiedNotExecuted,
  stillInProgress,
  inconsistent,
  requiresManualReview,
}

enum AppAgentExecutionCrashPoint {
  beforeExecutionClaim,
  afterExecutionClaim,
  beforeBusinessUseCase,
  duringBusinessTransaction,
  afterBusinessCommit,
  beforeDurableResultSave,
  afterDurableResultSave,
  beforeUiReceivesResult,
}

abstract interface class AppAgentExecutionFaultInjector {
  void checkpoint(AppAgentExecutionCrashPoint point, AppAgentCommand command);
}

/// Test-only interruption signal that must never be converted into a normal
/// provider or validation failure by the production execution pipeline.
final class AppAgentSimulatedProcessInterruption implements Exception {
  const AppAgentSimulatedProcessInterruption(this.point);

  final AppAgentExecutionCrashPoint point;
}

final class AppAgentReconciliationResult {
  const AppAgentReconciliationResult({
    required this.status,
    required this.entityType,
    required this.affectedCount,
    this.safeFailureCode,
  });

  final AppAgentReconciliationStatus status;
  final String entityType;
  final int affectedCount;
  final String? safeFailureCode;

  bool get verified => status == AppAgentReconciliationStatus.verifiedSucceeded;

  AppAgentExecutionResult toExecutionResult({
    required String commandId,
    required DateTime completedAt,
  }) {
    return AppAgentExecutionResult(
      commandId: commandId,
      status: verified
          ? AppAgentCommandStatus.succeeded
          : AppAgentCommandStatus.failed,
      verified: verified,
      entityType: entityType,
      affectedCount: verified ? affectedCount : 0,
      completedAt: completedAt,
      safeFailureCode: verified ? null : safeFailureCode,
    );
  }
}
