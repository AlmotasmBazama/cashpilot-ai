import '../../../../core/error/failure.dart';
import '../app_agent/app_agent_reconciliation_service.dart';
import '../app_agent/durable_ai_action_bridge.dart';
import '../../domain/app_agent/app_agent_models.dart';
import '../../domain/app_agent/app_agent_policy.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_action_draft.dart';
import '../../domain/entities/ai_action_validation_result.dart';
import 'ai_action_executor.dart';

typedef AiAssistantDurableCurrentReader = bool Function();
typedef AiAssistantDurableMountedReader = bool Function();
typedef AiAssistantDurableRuntimeReader = AiActionDurableRuntime Function();
typedef AiAssistantDurablePermissionFailureReader =
    Failure? Function(int? expectedConfigurationRevision);
typedef AiAssistantDurableRecoveryPublisher =
    void Function(AppAgentExecutionResult result);

sealed class AiAssistantDurableDraftOutcome {
  const AiAssistantDurableDraftOutcome();
}

final class AiAssistantDurableDraftReady
    extends AiAssistantDurableDraftOutcome {
  const AiAssistantDurableDraftReady({
    required this.runtime,
    required this.policyRevision,
  });

  final AiActionDurableRuntime? runtime;
  final int? policyRevision;
}

final class AiAssistantDurableDraftPermissionRejected
    extends AiAssistantDurableDraftOutcome {
  const AiAssistantDurableDraftPermissionRejected(this.failure);

  final Failure failure;
}

final class AiAssistantDurableDraftPersistenceFailed
    extends AiAssistantDurableDraftOutcome {
  const AiAssistantDurableDraftPersistenceFailed(this.failure);

  final Failure failure;
}

final class AiAssistantDurableDraftSuperseded
    extends AiAssistantDurableDraftOutcome {
  const AiAssistantDurableDraftSuperseded();
}

enum AiAssistantDurableConfirmationDisposition {
  preflightRejected,
  verifiedSuccess,
  executionFailed,
  superseded,
}

final class AiAssistantDurableConfirmationOutcome {
  const AiAssistantDurableConfirmationOutcome({
    required this.disposition,
    this.failure,
    this.result,
  });

  final AiAssistantDurableConfirmationDisposition disposition;
  final Failure? failure;
  final AppAgentExecutionResult? result;
}

enum AiAssistantDurableRecoveryDisposition { skipped, restored, superseded }

final class AiAssistantDurableRecoveryOutcome {
  const AiAssistantDurableRecoveryOutcome({required this.disposition});

  final AiAssistantDurableRecoveryDisposition disposition;
}

final class AiAssistantDurableDraftCoordinatorFactory {
  const AiAssistantDurableDraftCoordinatorFactory();

  AiAssistantDurableDraftCoordinator create() {
    return AiAssistantDurableDraftCoordinator();
  }
}

/// Owns the durable draft binding plus confirmation and startup-recovery
/// sequencing. Rendering remains a presentation concern supplied through
/// ordered callbacks.
final class AiAssistantDurableDraftCoordinator {
  static const _preparationPersistenceFailure = Failure(
    message: 'The financial draft could not be saved safely.',
    code: AppAgentFailureCodes.validationFailed,
  );
  static const _revisionPersistenceFailure = Failure(
    message: 'The revised financial draft could not be saved safely.',
    code: AppAgentFailureCodes.validationFailed,
  );

  AiActionDurableRuntime? _visibleRuntime;
  int? _visiblePolicyRevision;

  AiActionDurableRuntime? get visibleRuntime => _visibleRuntime;

  int? get visiblePolicyRevision => _visiblePolicyRevision;

  void bindVisibleDraft({
    required AiActionDurableRuntime? runtime,
    required int? policyRevision,
  }) {
    _visibleRuntime = runtime;
    _visiblePolicyRevision = policyRevision;
  }

  void replaceVisibleRuntime(AiActionDurableRuntime? runtime) {
    _visibleRuntime = runtime;
  }

  AiActionDurableRuntime? clearVisibleDraftBinding() {
    final runtime = _visibleRuntime;
    _visibleRuntime = null;
    _visiblePolicyRevision = null;
    return runtime;
  }

  Future<AiAssistantDurableDraftOutcome> prepare({
    required AiActionDraft draft,
    required AiActionValidationResult validation,
    required bool isDurableFinancialCreate,
    required int policyRevision,
    required AiAssistantDurableCurrentReader isCurrent,
    required AiAssistantDurableRuntimeReader readRuntime,
    required AiAssistantDurablePermissionFailureReader readPermissionFailure,
  }) async {
    AiActionDurableRuntime? runtime;
    if (validation.isValid && isDurableFinancialCreate) {
      runtime = readRuntime();
      try {
        await runtime.persistDraft(draft);
      } on Object {
        return const AiAssistantDurableDraftPersistenceFailed(
          _preparationPersistenceFailure,
        );
      }
      if (!isCurrent()) {
        return const AiAssistantDurableDraftSuperseded();
      }
    }

    final permissionFailure = readPermissionFailure(policyRevision);
    if (permissionFailure != null) {
      if (runtime != null) {
        await cancel(
          draft.id,
          runtime: runtime,
          readFallbackRuntime: readRuntime,
        );
        if (!isCurrent()) {
          return const AiAssistantDurableDraftSuperseded();
        }
      }
      return AiAssistantDurableDraftPermissionRejected(permissionFailure);
    }

    bindVisibleDraft(runtime: runtime, policyRevision: policyRevision);
    return AiAssistantDurableDraftReady(
      runtime: runtime,
      policyRevision: policyRevision,
    );
  }

  Future<AiAssistantDurableDraftOutcome> revise({
    required AiActionDraft previousDraft,
    required AiActionDraft updatedDraft,
    required AiActionValidationResult validation,
    required bool isDurableFinancialCreate,
    required AiAssistantDurableCurrentReader isCurrent,
    required AiAssistantDurableRuntimeReader readRuntime,
    required AiAssistantDurablePermissionFailureReader readPermissionFailure,
  }) async {
    final permissionFailure = readPermissionFailure(_visiblePolicyRevision);
    if (permissionFailure != null) {
      final previousRuntime = _visibleRuntime;
      if (previousRuntime != null) {
        await cancel(
          previousDraft.id,
          runtime: previousRuntime,
          readFallbackRuntime: readRuntime,
        );
        if (!isCurrent()) {
          return const AiAssistantDurableDraftSuperseded();
        }
      }
      clearVisibleDraftBinding();
      return AiAssistantDurableDraftPermissionRejected(permissionFailure);
    }

    final previousRuntime = _visibleRuntime;
    if (previousRuntime != null) {
      await cancel(
        previousDraft.id,
        runtime: previousRuntime,
        readFallbackRuntime: readRuntime,
      );
      if (!isCurrent()) {
        return const AiAssistantDurableDraftSuperseded();
      }
    }

    AiActionDurableRuntime? runtime;
    if (validation.isValid && isDurableFinancialCreate) {
      runtime = readRuntime();
      try {
        await runtime.persistDraft(updatedDraft);
      } on Object {
        return const AiAssistantDurableDraftPersistenceFailed(
          _revisionPersistenceFailure,
        );
      }
      if (!isCurrent()) {
        return const AiAssistantDurableDraftSuperseded();
      }
    }
    if (!isCurrent()) {
      return const AiAssistantDurableDraftSuperseded();
    }

    replaceVisibleRuntime(runtime);
    return AiAssistantDurableDraftReady(
      runtime: runtime,
      policyRevision: _visiblePolicyRevision,
    );
  }

  Future<void> cancel(
    String commandId, {
    AiActionDurableRuntime? runtime,
    required AiAssistantDurableRuntimeReader readFallbackRuntime,
  }) async {
    try {
      final target = runtime ?? _visibleRuntime ?? readFallbackRuntime();
      await target.cancel(commandId);
    } on Object {
      // Scope detachment already makes the old command inaccessible.
    }
  }

  Future<AiAssistantDurableConfirmationOutcome> confirm({
    required AiActionDraft draft,
    required AiAssistantDurableCurrentReader isCurrent,
    required AiAssistantDurableMountedReader isMounted,
    required AiAssistantDurableRuntimeReader readFallbackRuntime,
    required AiAssistantDurablePermissionFailureReader
    readDraftPermissionFailure,
    required AiAssistantDurablePermissionFailureReader
    readExecutionPermissionFailure,
    required Failure? Function() readCurrentExecutionPermissionFailure,
    required void Function(Failure failure) preserveLegacyAction,
    required void Function() markExecuting,
    required void Function() invalidateFinancialReads,
    required void Function(AppAgentExecutionResult result)
    publishVerifiedSuccess,
    required void Function(Failure failure) publishPreflightFailure,
    required void Function(Failure failure) publishLegacyFailure,
    required void Function(Failure failure) publishExecutionFailure,
  }) async {
    final draftPermissionFailure = readDraftPermissionFailure(
      _visiblePolicyRevision,
    );
    if (draftPermissionFailure != null) {
      preserveLegacyAction(draftPermissionFailure);
      await cancel(
        draft.id,
        runtime: _visibleRuntime,
        readFallbackRuntime: readFallbackRuntime,
      );
      if (!isCurrent()) {
        return const AiAssistantDurableConfirmationOutcome(
          disposition: AiAssistantDurableConfirmationDisposition.superseded,
        );
      }
      clearVisibleDraftBinding();
      publishPreflightFailure(draftPermissionFailure);
      return AiAssistantDurableConfirmationOutcome(
        disposition:
            AiAssistantDurableConfirmationDisposition.preflightRejected,
        failure: draftPermissionFailure,
      );
    }

    final executionPermissionFailure = readExecutionPermissionFailure(
      _visiblePolicyRevision,
    );
    if (executionPermissionFailure != null) {
      preserveLegacyAction(executionPermissionFailure);
      await cancel(
        draft.id,
        runtime: _visibleRuntime,
        readFallbackRuntime: readFallbackRuntime,
      );
      if (!isCurrent()) {
        return const AiAssistantDurableConfirmationOutcome(
          disposition: AiAssistantDurableConfirmationDisposition.superseded,
        );
      }
      clearVisibleDraftBinding();
      publishPreflightFailure(executionPermissionFailure);
      return AiAssistantDurableConfirmationOutcome(
        disposition:
            AiAssistantDurableConfirmationDisposition.preflightRejected,
        failure: executionPermissionFailure,
      );
    }

    final runtime = _visibleRuntime ?? readFallbackRuntime();
    markExecuting();
    final AppAgentExecutionResult result;
    try {
      result = await runtime.confirmAndExecute(draft.id);
    } on Object {
      const failure = Failure(
        message: 'The financial action failed safely.',
        code: AiActionFailureCodes.executionFailed,
      );
      if (isCurrent() && isMounted()) {
        publishExecutionFailure(failure);
      }
      return const AiAssistantDurableConfirmationOutcome(
        disposition: AiAssistantDurableConfirmationDisposition.executionFailed,
        failure: failure,
      );
    }
    if (!isCurrent() || !isMounted()) {
      return const AiAssistantDurableConfirmationOutcome(
        disposition: AiAssistantDurableConfirmationDisposition.superseded,
      );
    }

    if (result.verified && result.status == AppAgentCommandStatus.succeeded) {
      invalidateFinancialReads();
      clearVisibleDraftBinding();
      publishVerifiedSuccess(result);
      await runtime.acknowledgeRecoveryResult(result.commandId);
      if (!isCurrent()) {
        return AiAssistantDurableConfirmationOutcome(
          disposition: AiAssistantDurableConfirmationDisposition.superseded,
          result: result,
        );
      }
      return AiAssistantDurableConfirmationOutcome(
        disposition: AiAssistantDurableConfirmationDisposition.verifiedSuccess,
        result: result,
      );
    }

    final failure = failureForExecutionResult(
      action: draft.action,
      result: result,
      readCurrentExecutionPermissionFailure:
          readCurrentExecutionPermissionFailure,
    );
    if (failure.code == AppAgentFailureCodes.legacyDataUnresolved) {
      preserveLegacyAction(failure);
      clearVisibleDraftBinding();
      publishLegacyFailure(failure);
    } else {
      publishExecutionFailure(failure);
    }
    return AiAssistantDurableConfirmationOutcome(
      disposition: AiAssistantDurableConfirmationDisposition.executionFailed,
      failure: failure,
      result: result,
    );
  }

  Future<AiAssistantDurableRecoveryOutcome> recover({
    required bool enabled,
    required AiAssistantDurableCurrentReader isCurrent,
    required AiAssistantDurableMountedReader isMounted,
    required Future<AppAgentStartupReconciliationSummary> Function()
    readStartupReconciliation,
    required AiAssistantDurableRuntimeReader readRuntime,
    required bool Function(AppAgentExecutionResult result)
    tryConsumeRecoveryResult,
    required AiAssistantDurableRecoveryPublisher publishRecoveryResult,
    required Future<void> Function() waitForRenderedFrame,
    required bool Function(AiAction action) allowsAction,
    required AiActionValidationResult Function(AiAction action) validateAction,
    required void Function(
      AiActionDraft draft,
      AiActionValidationResult validation,
      Failure? failure,
    )
    publishRestoredDraft,
    required int Function() readPolicyRevision,
  }) async {
    if (!enabled) {
      return const AiAssistantDurableRecoveryOutcome(
        disposition: AiAssistantDurableRecoveryDisposition.skipped,
      );
    }
    try {
      final recovery = await readStartupReconciliation();
      if (!isCurrent() || !isMounted()) {
        return const AiAssistantDurableRecoveryOutcome(
          disposition: AiAssistantDurableRecoveryDisposition.superseded,
        );
      }
      final runtime = readRuntime();
      final recoveredResult = recovery.latestUserVisibleResult;
      if (recoveredResult != null &&
          tryConsumeRecoveryResult(recoveredResult)) {
        publishRecoveryResult(recoveredResult);
        await waitForRenderedFrame();
        if (!isCurrent()) {
          return const AiAssistantDurableRecoveryOutcome(
            disposition: AiAssistantDurableRecoveryDisposition.superseded,
          );
        }
        await runtime.acknowledgeRecoveryResult(recoveredResult.commandId);
        if (!isCurrent()) {
          return const AiAssistantDurableRecoveryOutcome(
            disposition: AiAssistantDurableRecoveryDisposition.superseded,
          );
        }
      }

      final restored = await runtime.restoreLatestPendingDraft();
      if (!isCurrent() || restored == null || !allowsAction(restored.action)) {
        return const AiAssistantDurableRecoveryOutcome(
          disposition: AiAssistantDurableRecoveryDisposition.skipped,
        );
      }
      final validation = validateAction(restored.action);
      final failure = restored.status == AiActionExecutionStatus.failed
          ? const Failure(
              message: 'A previous financial action requires review.',
              code: AppAgentFailureCodes.verificationFailed,
            )
          : null;
      publishRestoredDraft(restored, validation, failure);
      _visibleRuntime = runtime;
      _visiblePolicyRevision = readPolicyRevision();
      return const AiAssistantDurableRecoveryOutcome(
        disposition: AiAssistantDurableRecoveryDisposition.restored,
      );
    } on Object {
      // No authenticated/safe scope means there is deliberately no draft to
      // restore. General conversation remains available.
      return const AiAssistantDurableRecoveryOutcome(
        disposition: AiAssistantDurableRecoveryDisposition.skipped,
      );
    }
  }

  Failure failureForExecutionResult({
    required AiAction action,
    required AppAgentExecutionResult result,
    required Failure? Function() readCurrentExecutionPermissionFailure,
  }) {
    final genericFailure = Failure(
      message: 'The financial action failed safely.',
      code: result.safeFailureCode,
    );
    if (result.safeFailureCode != AppAgentFailureCodes.permissionDenied ||
        (action is! CreateExpenseDraft &&
            action is! CreateIncomeDraft &&
            action is! CreateTransferDraft)) {
      return genericFailure;
    }

    // Re-authorize with the current policy only for a durable transaction
    // denial so the UI can retain its exact privacy-safe reason.
    return readCurrentExecutionPermissionFailure() ?? genericFailure;
  }
}
