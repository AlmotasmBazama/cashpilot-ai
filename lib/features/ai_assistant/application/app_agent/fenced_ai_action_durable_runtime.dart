import '../../../../core/sync/application/backup_operation_fence.dart';
import '../../domain/app_agent/app_agent_models.dart';
import '../../domain/app_agent/app_agent_policy.dart';
import '../../domain/entities/ai_action_draft.dart';
import 'durable_ai_action_bridge.dart';

/// Holds an owner-scoped writer lease across every durable AI operation.
///
/// The bound scope is captured from the trusted owner session when this
/// runtime is constructed. A deletion fence therefore cannot be bypassed by a
/// later provider read, and a completion from an old owner/session epoch is
/// never surfaced as successful.
final class FencedAiActionDurableRuntime implements AiActionDurableRuntime {
  const FencedAiActionDurableRuntime({
    required AiActionDurableRuntime delegate,
    required BackupOperationFence operationFence,
    required String? boundOwnerScope,
    required bool Function() isOwnerBindingCurrent,
  }) : _delegate = delegate,
       _operationFence = operationFence,
       _boundOwnerScope = boundOwnerScope,
       _isOwnerBindingCurrent = isOwnerBindingCurrent;

  final AiActionDurableRuntime _delegate;
  final BackupOperationFence _operationFence;
  final String? _boundOwnerScope;
  final bool Function() _isOwnerBindingCurrent;

  @override
  Future<AppAgentCommand> persistDraft(AiActionDraft draft) async {
    final lease = _acquireOrThrow();
    try {
      _assertCurrent(lease);
      final command = await _delegate.persistDraft(draft);
      _assertCurrent(lease);
      return command;
    } on BackupWriterCancelledException {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.cancelled,
        'The action was cancelled because account deletion started.',
      );
    } on _OwnerBindingChangedException {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.accountScopeMismatch,
        'The confirmed account changed before the action completed.',
      );
    } finally {
      lease.release();
    }
  }

  @override
  Future<AppAgentExecutionResult> confirmAndExecute(String commandId) async {
    final lease = _tryAcquire();
    if (lease == null) {
      return _failedResult(commandId, _unavailableFailureCode());
    }
    try {
      _assertCurrent(lease);
      final result = await _delegate.confirmAndExecute(commandId);
      _assertCurrent(lease);
      return result;
    } on BackupWriterCancelledException {
      return _failedResult(commandId, AppAgentFailureCodes.cancelled);
    } on _OwnerBindingChangedException {
      return _failedResult(
        commandId,
        AppAgentFailureCodes.accountScopeMismatch,
      );
    } finally {
      lease.release();
    }
  }

  @override
  Future<void> cancel(String commandId) async {
    final lease = _tryAcquire();
    if (lease == null) return;
    try {
      _assertCurrent(lease);
      await _delegate.cancel(commandId);
      _assertCurrent(lease);
    } on BackupWriterCancelledException {
      return;
    } on _OwnerBindingChangedException {
      return;
    } finally {
      lease.release();
    }
  }

  @override
  Future<AiActionDraft?> restoreLatestPendingDraft() async {
    final lease = _tryAcquire();
    if (lease == null) return null;
    try {
      _assertCurrent(lease);
      final draft = await _delegate.restoreLatestPendingDraft();
      _assertCurrent(lease);
      return draft;
    } on BackupWriterCancelledException {
      return null;
    } on _OwnerBindingChangedException {
      return null;
    } finally {
      lease.release();
    }
  }

  @override
  Future<void> acknowledgeRecoveryResult(String commandId) async {
    final lease = _tryAcquire();
    if (lease == null) return;
    try {
      _assertCurrent(lease);
      await _delegate.acknowledgeRecoveryResult(commandId);
      _assertCurrent(lease);
    } on BackupWriterCancelledException {
      return;
    } on _OwnerBindingChangedException {
      return;
    } finally {
      lease.release();
    }
  }

  BackupWriterLease _acquireOrThrow() {
    final lease = _tryAcquire();
    if (lease != null) return lease;
    final code = _unavailableFailureCode();
    throw AppAgentPolicyViolation(
      code,
      code == AppAgentFailureCodes.cancelled
          ? 'The action is unavailable while account deletion is active.'
          : 'A current confirmed account is required.',
    );
  }

  BackupWriterLease? _tryAcquire() {
    final scope = _boundOwnerScope;
    if (scope == null || scope.trim().isEmpty || !_isOwnerBindingCurrent()) {
      return null;
    }
    final lease = _operationFence.tryAcquireWriter(scope);
    if (lease == null) return null;
    try {
      _assertCurrent(lease);
      return lease;
    } on Object {
      lease.release();
      return null;
    }
  }

  void _assertCurrent(BackupWriterLease lease) {
    lease.assertActive();
    if (!_isOwnerBindingCurrent()) {
      throw const _OwnerBindingChangedException();
    }
  }

  String _unavailableFailureCode() {
    final scope = _boundOwnerScope;
    if (scope != null &&
        scope.trim().isNotEmpty &&
        _operationFence.isFenced(scope)) {
      return AppAgentFailureCodes.cancelled;
    }
    return AppAgentFailureCodes.accountScopeMismatch;
  }

  AppAgentExecutionResult _failedResult(String commandId, String code) {
    return AppAgentExecutionResult(
      commandId: commandId,
      status: AppAgentCommandStatus.failed,
      verified: false,
      entityType: 'financialEntity',
      affectedCount: 0,
      completedAt: DateTime.now().toUtc(),
      safeFailureCode: code,
    );
  }
}

final class _OwnerBindingChangedException implements Exception {
  const _OwnerBindingChangedException();
}
