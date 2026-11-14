import 'dart:async';

import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/durable_ai_action_bridge.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/fenced_ai_action_durable_runtime.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ownerScope =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('AI success returning during deletion is suppressed', () async {
    final fence = BackupOperationFence();
    final delegate = _ControlledDurableRuntime();
    final runtime = FencedAiActionDurableRuntime(
      delegate: delegate,
      operationFence: fence,
      boundOwnerScope: ownerScope,
      isOwnerBindingCurrent: () => true,
    );

    final operation = runtime.confirmAndExecute('command-1');
    await delegate.confirmStarted.future;

    final deletionFuture = fence.fenceAndDrain(
      ownerScopeValue: ownerScope,
      operationId: 'delete-1',
    );
    delegate.confirmResult.complete(_successfulResult('command-1'));

    final result = await operation;
    expect(result.verified, isFalse);
    expect(result.affectedCount, 0);
    expect(result.safeFailureCode, AppAgentFailureCodes.cancelled);

    final deletionLease = await deletionFuture;
    deletionLease.release();
  });

  test('new AI financial write while fenced never reaches delegate', () async {
    final fence = BackupOperationFence();
    final delegate = _ControlledDurableRuntime();
    final runtime = FencedAiActionDurableRuntime(
      delegate: delegate,
      operationFence: fence,
      boundOwnerScope: ownerScope,
      isOwnerBindingCurrent: () => true,
    );
    final deletionLease = await fence.fenceAndDrain(
      ownerScopeValue: ownerScope,
      operationId: 'delete-2',
    );
    addTearDown(deletionLease.release);

    final result = await runtime.confirmAndExecute('command-2');

    expect(result.verified, isFalse);
    expect(result.affectedCount, 0);
    expect(result.safeFailureCode, AppAgentFailureCodes.cancelled);
    expect(delegate.confirmCalls, 0);
  });
}

AppAgentExecutionResult _successfulResult(String commandId) {
  return AppAgentExecutionResult(
    commandId: commandId,
    status: AppAgentCommandStatus.succeeded,
    verified: true,
    entityType: 'transaction',
    affectedCount: 1,
    completedAt: DateTime.utc(2026),
  );
}

final class _ControlledDurableRuntime implements AiActionDurableRuntime {
  final Completer<void> confirmStarted = Completer<void>();
  final Completer<AppAgentExecutionResult> confirmResult =
      Completer<AppAgentExecutionResult>();
  int confirmCalls = 0;

  @override
  Future<void> acknowledgeRecoveryResult(String commandId) async {}

  @override
  Future<void> cancel(String commandId) async {}

  @override
  Future<AppAgentExecutionResult> confirmAndExecute(String commandId) {
    confirmCalls += 1;
    if (!confirmStarted.isCompleted) {
      confirmStarted.complete();
    }
    return confirmResult.future;
  }

  @override
  Future<AppAgentCommand> persistDraft(AiActionDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<AiActionDraft?> restoreLatestPendingDraft() async => null;
}
