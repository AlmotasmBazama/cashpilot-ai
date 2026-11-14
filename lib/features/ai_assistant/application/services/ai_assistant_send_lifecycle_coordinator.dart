import '../../domain/agent/ai_tool_contracts.dart';
import 'ai_prompt_send_guard.dart';

typedef AiAssistantOwnerBindingReader = AiToolOwnerScopeBinding? Function();
typedef AiAssistantMountedReader = bool Function();
typedef AiAssistantRequestCancellation = void Function();

sealed class AiAssistantSendAdmission {
  const AiAssistantSendAdmission();
}

final class AiAssistantSendAdmitted extends AiAssistantSendAdmission {
  const AiAssistantSendAdmitted();
}

final class AiAssistantSendRejected extends AiAssistantSendAdmission {
  const AiAssistantSendRejected(this.code);

  final String code;
}

final class AiAssistantOwnerOperation {
  const AiAssistantOwnerOperation({
    required this.generation,
    required this.ownerBinding,
  });

  final int generation;
  final AiToolOwnerScopeBinding? ownerBinding;
}

enum AiAssistantActiveOperationCleanup { send, retry, operationOnly }

final class AiAssistantOperationFinish {
  const AiAssistantOperationFinish({
    required this.releasedActiveOperation,
    required this.isCurrent,
  });

  final bool releasedActiveOperation;
  final bool isCurrent;
}

final class AiAssistantSendLifecycleCoordinatorFactory {
  const AiAssistantSendLifecycleCoordinatorFactory();

  AiAssistantSendLifecycleCoordinator create({
    required AiToolOwnerScopeBinding? initialOwnerBinding,
    required AiAssistantOwnerBindingReader readOwnerBinding,
    required AiAssistantMountedReader isMounted,
  }) {
    return AiAssistantSendLifecycleCoordinator(
      initialOwnerBinding: initialOwnerBinding,
      readOwnerBinding: readOwnerBinding,
      isMounted: isMounted,
    );
  }
}

final class AiAssistantSendLifecycleCoordinator {
  AiAssistantSendLifecycleCoordinator({
    required AiToolOwnerScopeBinding? initialOwnerBinding,
    required AiAssistantOwnerBindingReader readOwnerBinding,
    required AiAssistantMountedReader isMounted,
    AiPromptSendGuard? promptSendGuard,
  }) : _ownerBinding = initialOwnerBinding,
       _readOwnerBinding = readOwnerBinding,
       _isMounted = isMounted,
       _promptSendGuard = promptSendGuard ?? AiPromptSendGuard();

  final AiAssistantOwnerBindingReader _readOwnerBinding;
  final AiAssistantMountedReader _isMounted;
  final AiPromptSendGuard _promptSendGuard;

  AiToolOwnerScopeBinding? _ownerBinding;
  int _operationGeneration = 0;
  AiAssistantOwnerOperation? _activeOperation;
  AiAssistantRequestCancellation? _cancelActiveRequest;

  bool get hasActiveOperation => _activeOperation != null;

  AiAssistantSendAdmission tryAdmit(String prompt) {
    final rejectionCode = _promptSendGuard.tryStart(prompt);
    return rejectionCode == null
        ? const AiAssistantSendAdmitted()
        : AiAssistantSendRejected(rejectionCode);
  }

  void completeAdmission() => _promptSendGuard.complete();

  void resetAdmission() => _promptSendGuard.reset();

  bool handleOwnerBindingChanged(
    AiToolOwnerScopeBinding? previous,
    AiToolOwnerScopeBinding? next,
  ) {
    if (previous == next) return false;
    _ownerBinding = next;
    invalidateAndCancelActiveOperation();
    return true;
  }

  void invalidateAndCancelActiveOperation() {
    _operationGeneration += 1;
    _activeOperation = null;
    _promptSendGuard.reset();
    _cancelActiveRequest?.call();
    _cancelActiveRequest = null;
  }

  AiAssistantOwnerOperation? beginOwnerOperation({
    required bool requireConfirmedOwner,
    bool supersedeExisting = true,
  }) {
    final binding = _safeReadOwnerBinding();
    _ownerBinding = binding;
    if (requireConfirmedOwner && binding == null) {
      return null;
    }
    if (supersedeExisting) {
      _operationGeneration += 1;
    }
    return AiAssistantOwnerOperation(
      generation: _operationGeneration,
      ownerBinding: binding,
    );
  }

  bool isCurrent(AiAssistantOwnerOperation operation) {
    if (!_isMounted() || operation.generation != _operationGeneration) {
      return false;
    }
    if (_ownerBinding != operation.ownerBinding) return false;
    try {
      return _readOwnerBinding() == operation.ownerBinding;
    } on Object {
      return false;
    }
  }

  void activateOperation(AiAssistantOwnerOperation operation) {
    _activeOperation = operation;
  }

  void setActiveRequestCancellation(
    AiAssistantRequestCancellation cancellation,
  ) {
    _cancelActiveRequest = cancellation;
  }

  AiAssistantOperationFinish finishOperation(
    AiAssistantOwnerOperation operation, {
    required AiAssistantActiveOperationCleanup cleanup,
  }) {
    final releasedActiveOperation = identical(_activeOperation, operation);
    if (releasedActiveOperation) {
      _activeOperation = null;
      switch (cleanup) {
        case AiAssistantActiveOperationCleanup.send:
          _cancelActiveRequest = null;
          _promptSendGuard.complete();
        case AiAssistantActiveOperationCleanup.retry:
          _cancelActiveRequest = null;
        case AiAssistantActiveOperationCleanup.operationOnly:
          break;
      }
    }
    return AiAssistantOperationFinish(
      releasedActiveOperation: releasedActiveOperation,
      isCurrent: isCurrent(operation),
    );
  }

  AiAssistantRequestCancellation? detachCancellationForDispose() {
    final cancellation = _cancelActiveRequest;
    _cancelActiveRequest = null;
    return cancellation;
  }

  AiToolOwnerScopeBinding? _safeReadOwnerBinding() {
    try {
      return _readOwnerBinding();
    } on Object {
      return null;
    }
  }
}
