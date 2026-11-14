import 'dart:math';

import '../../domain/app_agent/app_agent_contracts.dart';
import '../../domain/app_agent/app_agent_models.dart';
import '../../domain/app_agent/app_agent_policy.dart';
import '../../domain/app_agent/app_agent_reconciliation.dart';

typedef AppAgentExecutionAuthorization = bool Function(AppAgentCommand command);

class InMemoryAppAgentCommandStore implements AppAgentCommandStore {
  InMemoryAppAgentCommandStore({
    AppAgentPolicy policy = const AppAgentPolicy(),
    Iterable<AppAgentModelProposalDescriptor> canonicalDescriptors =
        const <AppAgentModelProposalDescriptor>[],
  }) : _policy = policy {
    for (final descriptor in canonicalDescriptors) {
      if (_canonicalDescriptors.containsKey(descriptor.toolId)) {
        throw StateError('Canonical descriptor IDs must be unique.');
      }
      _canonicalDescriptors[descriptor.toolId] = descriptor;
    }
  }

  final AppAgentPolicy _policy;
  final Map<String, AppAgentModelProposalDescriptor> _canonicalDescriptors =
      <String, AppAgentModelProposalDescriptor>{};
  final Map<String, AppAgentCommand> _commands = <String, AppAgentCommand>{};
  final Map<String, AppAgentPreview> _previews = <String, AppAgentPreview>{};

  @override
  Future<void> saveCommand(AppAgentCommand command) async {
    _policy.validateModelProposal(
      command,
      descriptor: _canonicalDescriptors[command.toolId],
    );
    await _insertCommand(command);
  }

  /// Insert-only path for commands produced by trusted deterministic local
  /// code rather than a model. It cannot bypass policy or prohibited tools.
  Future<void> saveTrustedLocalCommand(AppAgentCommand command) async {
    _policy.validateTrustedLocalCommand(
      command,
      descriptor: _canonicalDescriptors[command.toolId],
    );
    await _insertCommand(command);
  }

  Future<void> _insertCommand(AppAgentCommand command) async {
    if (command.status != AppAgentCommandStatus.proposed &&
        command.status != AppAgentCommandStatus.resolving &&
        command.status != AppAgentCommandStatus.needsClarification &&
        command.status != AppAgentCommandStatus.readyForPreview) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidStatus,
        'Only a locally controlled pre-confirmation command may be saved.',
      );
    }
    final existing = _commands[command.commandId];
    if (existing != null) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.duplicateExecutionPrevented,
        'The command identifier has already been used.',
      );
    }
    _commands[command.commandId] = command;
  }

  @override
  Future<AppAgentCommand?> readCommand({
    required String commandId,
    required String accountScope,
  }) async {
    final command = _commands[commandId];
    return command?.userAccountScope == accountScope ? command : null;
  }

  @override
  Future<List<AppAgentCommand>> readCommandsForScope(
    String accountScope,
  ) async {
    return _commands.values
        .where((command) => command.userAccountScope == accountScope)
        .toList(growable: false);
  }

  @override
  Future<void> savePreview({
    required AppAgentPreview preview,
    required String accountScope,
  }) async {
    final command = _commands[preview.commandId];
    if (command == null ||
        command.userAccountScope != accountScope ||
        command.status != AppAgentCommandStatus.readyForPreview) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidStatus,
        'A preview can only be attached to a ready command.',
      );
    }
    _policy.validatePreview(command, preview);
    _previews[preview.commandId] = preview;
    _commands[preview.commandId] = command.copyWith(
      status: preview.confirmationLevel == AppAgentConfirmationLevel.none
          ? AppAgentCommandStatus.readyForPreview
          : AppAgentCommandStatus.awaitingConfirmation,
      previewFingerprint: preview.stateFingerprint,
    );
  }

  @override
  Future<AppAgentPreview?> readPreview({
    required String commandId,
    required String accountScope,
  }) async {
    final command = _commands[commandId];
    return command?.userAccountScope == accountScope
        ? _previews[commandId]
        : null;
  }

  @override
  Future<AppAgentCommand?> transition({
    required String commandId,
    required String accountScope,
    required AppAgentCommandStatus expectedStatus,
    required AppAgentCommandStatus nextStatus,
    String? safeFailureCode,
  }) async {
    final current = _commands[commandId];
    if (current == null ||
        current.userAccountScope != accountScope ||
        current.status != expectedStatus) {
      return null;
    }
    _policy.validateTransition(expectedStatus, nextStatus);
    final updated = current.copyWith(
      status: nextStatus,
      safeFailureCode: safeFailureCode,
      clearSafeFailureCode: safeFailureCode == null,
    );
    _commands[commandId] = updated;
    return updated;
  }

  @override
  Future<void> clearScope(String accountScope) async {
    final commandIds = _commands.values
        .where((command) => command.userAccountScope == accountScope)
        .map((command) => command.commandId)
        .toList(growable: false);
    for (final commandId in commandIds) {
      _commands.remove(commandId);
      _previews.remove(commandId);
    }
  }
}

class InMemoryAppAgentAuditStore implements AppAgentAuditStore {
  InMemoryAppAgentAuditStore({this.maxEvents = 200});

  final int maxEvents;
  final List<AppAgentAuditEvent> _events = <AppAgentAuditEvent>[];

  @override
  Future<void> append(AppAgentAuditEvent event) async {
    _events.add(event);
    if (_events.length > maxEvents) {
      _events.removeRange(0, _events.length - maxEvents);
    }
  }

  @override
  Future<List<AppAgentAuditEvent>> readRecent({
    required String accountScope,
    int limit = 100,
  }) async {
    final safeLimit = limit.clamp(1, maxEvents);
    final scoped = _events
        .where((event) => event.userAccountScope == accountScope)
        .toList(growable: false);
    final start = max(0, scoped.length - safeLimit);
    return scoped.sublist(start).reversed.toList(growable: false);
  }

  @override
  Future<void> clearScope(String accountScope) async {
    _events.removeWhere((event) => event.userAccountScope == accountScope);
  }
}

class InMemoryAppAgentConfirmationProofStore
    implements AppAgentConfirmationProofStore {
  final Map<(String, String), _ConfirmationProofRecord> _proofs =
      <(String, String), _ConfirmationProofRecord>{};

  @override
  Future<void> saveProof({
    required String commandId,
    required String accountScope,
    required String proof,
    required AppAgentConfirmationMethod method,
    required DateTime expiresAt,
  }) async {
    _proofs[(accountScope, commandId)] = _ConfirmationProofRecord(
      accountScope: accountScope,
      proof: proof,
      method: method,
      expiresAt: expiresAt.toUtc(),
    );
  }

  @override
  Future<bool> consumeProof({
    required String commandId,
    required String accountScope,
    required String proof,
    required AppAgentConfirmationMethod method,
    required DateTime now,
  }) async {
    final record = _proofs.remove((accountScope, commandId));
    return record != null &&
        record.accountScope == accountScope &&
        record.proof == proof &&
        record.method == method &&
        now.toUtc().isBefore(record.expiresAt);
  }

  @override
  Future<void> clearScope(String accountScope) async {
    _proofs.removeWhere((key, _) => key.$1 == accountScope);
  }
}

class _ConfirmationProofRecord {
  const _ConfirmationProofRecord({
    required this.accountScope,
    required this.proof,
    required this.method,
    required this.expiresAt,
  });

  final String accountScope;
  final String proof;
  final AppAgentConfirmationMethod method;
  final DateTime expiresAt;
}

class MapAppAgentCommandHandlerRegistry
    implements AppAgentCommandHandlerRegistry {
  MapAppAgentCommandHandlerRegistry(Iterable<AppAgentCommandHandler> handlers)
    : _handlers = <String, AppAgentCommandHandler>{
        for (final handler in handlers) handler.toolId: handler,
      } {
    if (_handlers.length != handlers.length) {
      throw StateError('App agent command handler IDs must be unique.');
    }
  }

  final Map<String, AppAgentCommandHandler> _handlers;

  @override
  AppAgentCommandHandler? handlerFor(String toolId) => _handlers[toolId];
}

class AppAgentConfirmationDecision {
  const AppAgentConfirmationDecision({
    this.confirmation,
    this.requiresSecondConfirmation = false,
    this.safeFailureCode,
  });

  final AppAgentConfirmation? confirmation;
  final bool requiresSecondConfirmation;
  final String? safeFailureCode;
}

class AppAgentConfirmationController {
  AppAgentConfirmationController({
    required AppAgentCommandStore commandStore,
    required AppAgentConfirmationProofStore proofStore,
    AppAgentPolicy policy = const AppAgentPolicy(),
    DateTime Function()? clock,
    AppAgentExecutionFaultInjector? faultInjector,
    Random? secureRandom,
    this.highRiskApprovalWindow = const Duration(seconds: 30),
  }) : _commandStore = commandStore,
       _proofStore = proofStore,
       _policy = policy,
       _clock = clock ?? DateTime.now,
       _random = secureRandom ?? Random.secure(),
       assert(highRiskApprovalWindow > Duration.zero);

  final AppAgentCommandStore _commandStore;
  final AppAgentConfirmationProofStore _proofStore;
  final AppAgentPolicy _policy;
  final DateTime Function() _clock;
  final Random _random;
  final Duration highRiskApprovalWindow;
  final Map<(String, String), DateTime> _firstHighRiskApprovals =
      <(String, String), DateTime>{};

  Future<AppAgentConfirmationDecision> confirm({
    required String commandId,
    required String accountScope,
    required AppAgentConfirmationMethod method,
  }) async {
    final command = await _commandStore.readCommand(
      commandId: commandId,
      accountScope: accountScope,
    );
    if (command == null) {
      return const AppAgentConfirmationDecision(
        safeFailureCode: AppAgentFailureCodes.actionUnavailable,
      );
    }
    if (command.userAccountScope != accountScope) {
      return const AppAgentConfirmationDecision(
        safeFailureCode: AppAgentFailureCodes.accountScopeMismatch,
      );
    }
    final now = _clock().toUtc();
    if (command.isExpiredAt(now)) {
      _firstHighRiskApprovals.remove((accountScope, commandId));
      await _commandStore.transition(
        commandId: commandId,
        accountScope: accountScope,
        expectedStatus: command.status,
        nextStatus: AppAgentCommandStatus.expired,
        safeFailureCode: AppAgentFailureCodes.expired,
      );
      return const AppAgentConfirmationDecision(
        safeFailureCode: AppAgentFailureCodes.expired,
      );
    }
    if (command.status != AppAgentCommandStatus.awaitingConfirmation) {
      return const AppAgentConfirmationDecision(
        safeFailureCode: AppAgentFailureCodes.invalidStatus,
      );
    }
    final level = _policy.confirmationLevelFor(command.risk);
    if (level == AppAgentConfirmationLevel.protectedNativeWorkflow ||
        level == AppAgentConfirmationLevel.none) {
      return const AppAgentConfirmationDecision(
        safeFailureCode: AppAgentFailureCodes.prohibited,
      );
    }
    if (level == AppAgentConfirmationLevel.doubleConfirmation) {
      if (method != AppAgentConfirmationMethod.doubleConfirmation) {
        return const AppAgentConfirmationDecision(
          safeFailureCode: AppAgentFailureCodes.doubleConfirmationRequired,
        );
      }
      _firstHighRiskApprovals.removeWhere(
        (_, expiresAt) => !now.isBefore(expiresAt),
      );
      final approvalKey = (accountScope, commandId);
      final firstApprovalExpiry = _firstHighRiskApprovals.remove(approvalKey);
      if (firstApprovalExpiry == null || !now.isBefore(firstApprovalExpiry)) {
        final approvalExpiry = now.add(highRiskApprovalWindow);
        _firstHighRiskApprovals[approvalKey] =
            approvalExpiry.isBefore(command.expiresAt)
            ? approvalExpiry
            : command.expiresAt.toUtc();
        return const AppAgentConfirmationDecision(
          requiresSecondConfirmation: true,
          safeFailureCode: AppAgentFailureCodes.doubleConfirmationRequired,
        );
      }
    } else if (method != AppAgentConfirmationMethod.primaryButton) {
      return const AppAgentConfirmationDecision(
        safeFailureCode: AppAgentFailureCodes.invalidConfirmation,
      );
    }

    final confirmed = await _commandStore.transition(
      commandId: commandId,
      accountScope: accountScope,
      expectedStatus: AppAgentCommandStatus.awaitingConfirmation,
      nextStatus: AppAgentCommandStatus.confirmed,
    );
    if (confirmed == null) {
      return const AppAgentConfirmationDecision(
        safeFailureCode: AppAgentFailureCodes.duplicateExecutionPrevented,
      );
    }
    final proof = List<int>.generate(
      32,
      (_) => _random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final proofExpiry = now.add(const Duration(minutes: 2));
    await _proofStore.saveProof(
      commandId: commandId,
      accountScope: accountScope,
      proof: proof,
      method: method,
      expiresAt: proofExpiry.isBefore(command.expiresAt)
          ? proofExpiry
          : command.expiresAt,
    );
    return AppAgentConfirmationDecision(
      confirmation: AppAgentConfirmation(
        commandId: commandId,
        userAccountScope: accountScope,
        confirmedAt: now,
        method: method,
        authorityProof: proof,
      ),
    );
  }

  Future<void> clearScope(String accountScope) async {
    _firstHighRiskApprovals.removeWhere((key, _) => key.$1 == accountScope);
    await _proofStore.clearScope(accountScope);
  }
}

class AppAgentCommandExecutor {
  AppAgentCommandExecutor({
    required AppAgentCommandStore commandStore,
    required AppAgentAuditStore auditStore,
    required AppAgentConfirmationProofStore proofStore,
    required AppAgentCommandHandlerRegistry handlerRegistry,
    required AppAgentAccountScopeProvider accountScopeProvider,
    AppAgentDurableExecutionStore? durableExecutionStore,
    AppAgentPolicy policy = const AppAgentPolicy(),
    DateTime Function()? clock,
    AppAgentExecutionFaultInjector? faultInjector,
    AppAgentExecutionAuthorization? executionAuthorization,
    this.auditEnabled = true,
  }) : _commandStore = commandStore,
       _auditStore = auditStore,
       _proofStore = proofStore,
       _handlerRegistry = handlerRegistry,
       _accountScopeProvider = accountScopeProvider,
       _durableExecutionStore = durableExecutionStore,
       _faultInjector = faultInjector,
       _executionAuthorization = executionAuthorization ?? _allowExecution,
       _policy = policy,
       _clock = clock ?? DateTime.now;

  final AppAgentCommandStore _commandStore;
  final AppAgentAuditStore _auditStore;
  final AppAgentConfirmationProofStore _proofStore;
  final AppAgentCommandHandlerRegistry _handlerRegistry;
  final AppAgentAccountScopeProvider _accountScopeProvider;
  final AppAgentDurableExecutionStore? _durableExecutionStore;
  final AppAgentExecutionFaultInjector? _faultInjector;
  final AppAgentExecutionAuthorization _executionAuthorization;
  final AppAgentPolicy _policy;
  final DateTime Function() _clock;
  final bool auditEnabled;

  Future<AppAgentExecutionResult> execute(
    AppAgentConfirmation confirmation,
  ) async {
    final now = _clock().toUtc();
    final currentScope = _accountScopeProvider.currentAccountScope;
    if (currentScope == null || currentScope != confirmation.userAccountScope) {
      return _failure(
        confirmation.commandId,
        AppAgentFailureCodes.accountScopeMismatch,
        now,
      );
    }
    final command = await _commandStore.readCommand(
      commandId: confirmation.commandId,
      accountScope: currentScope,
    );
    if (command == null) {
      return _failure(
        confirmation.commandId,
        AppAgentFailureCodes.actionUnavailable,
        now,
      );
    }
    if (command.status == AppAgentCommandStatus.executing ||
        command.status == AppAgentCommandStatus.succeeded ||
        command.status == AppAgentCommandStatus.partiallySucceeded) {
      final previous = await _durableExecutionStore?.readVerifiedResult(
        command.commandId,
      );
      if (previous != null) {
        return previous;
      }
      return _failure(
        command.commandId,
        AppAgentFailureCodes.duplicateExecutionPrevented,
        now,
        entityType: command.commandType.name,
      );
    }
    if (currentScope != command.userAccountScope) {
      return _failure(
        command.commandId,
        AppAgentFailureCodes.accountScopeMismatch,
        now,
        entityType: command.commandType.name,
      );
    }
    if (command.isExpiredAt(now)) {
      await _commandStore.transition(
        commandId: command.commandId,
        accountScope: command.userAccountScope,
        expectedStatus: command.status,
        nextStatus: AppAgentCommandStatus.expired,
        safeFailureCode: AppAgentFailureCodes.expired,
      );
      return _failure(
        command.commandId,
        AppAgentFailureCodes.expired,
        now,
        entityType: command.commandType.name,
        status: AppAgentCommandStatus.expired,
      );
    }
    if (command.status != AppAgentCommandStatus.confirmed) {
      return _failure(
        command.commandId,
        AppAgentFailureCodes.confirmationRequired,
        now,
        entityType: command.commandType.name,
      );
    }
    final durableStore = _durableExecutionStore;
    if (durableStore == null) {
      final proofValid = await _proofStore.consumeProof(
        commandId: command.commandId,
        accountScope: command.userAccountScope,
        proof: confirmation.authorityProof,
        method: confirmation.method,
        now: now,
      );
      if (!proofValid) {
        return _failure(
          command.commandId,
          AppAgentFailureCodes.invalidConfirmation,
          now,
          entityType: command.commandType.name,
        );
      }
    }

    final handler = _handlerRegistry.handlerFor(command.toolId);
    if (handler == null ||
        handler.permission != command.permission ||
        handler.risk != command.risk ||
        command.risk == AgentActionRisk.prohibited) {
      return _rejectBeforeClaim(
        command,
        confirmation,
        AppAgentFailureCodes.permissionDenied,
        now,
      );
    }
    try {
      _policy.validatePersistedCommand(command);
      final preview = await _commandStore.readPreview(
        commandId: command.commandId,
        accountScope: command.userAccountScope,
      );
      if (preview == null ||
          command.previewFingerprint == null ||
          preview.stateFingerprint != command.previewFingerprint) {
        throw const AppAgentPolicyViolation(
          AppAgentFailureCodes.stalePreview,
          'The command preview is no longer valid.',
        );
      }
      final validation = await handler.revalidate(command);
      if (!validation.isValid) {
        throw AppAgentPolicyViolation(
          validation.safeFailureCode ?? AppAgentFailureCodes.validationFailed,
          'The command failed local validation.',
        );
      }
      if (validation.currentStateFingerprint != preview.stateFingerprint) {
        throw const AppAgentPolicyViolation(
          AppAgentFailureCodes.stalePreview,
          'The underlying data changed after the preview was created.',
        );
      }
    } on AppAgentPolicyViolation catch (violation) {
      return _rejectBeforeClaim(command, confirmation, violation.code, now);
    } on Object {
      return _rejectBeforeClaim(
        command,
        confirmation,
        AppAgentFailureCodes.validationFailed,
        now,
      );
    }

    AppAgentCommand? claimed;
    String? durableAttemptId;
    if (!_isExecutionAuthorized(command)) {
      return _rejectBeforeClaim(
        command,
        confirmation,
        AppAgentFailureCodes.permissionDenied,
        _clock().toUtc(),
      );
    }
    _checkpoint(AppAgentExecutionCrashPoint.beforeExecutionClaim, command);
    if (durableStore == null) {
      claimed = await _commandStore.transition(
        commandId: command.commandId,
        accountScope: command.userAccountScope,
        expectedStatus: AppAgentCommandStatus.confirmed,
        nextStatus: AppAgentCommandStatus.executing,
      );
    } else {
      final operation = handler is AppAgentReconciliableCommandHandler
          ? handler.businessOperationFor(command)
          : null;
      final AppAgentExecutionClaim durableClaim;
      try {
        durableClaim = await durableStore.claim(
          command,
          confirmation: confirmation,
          now: _clock().toUtc(),
          operation: operation,
        );
      } on AppAgentPolicyViolation catch (violation) {
        return _failure(
          command.commandId,
          violation.code,
          _clock().toUtc(),
          entityType: command.commandType.name,
        );
      }
      if (durableClaim.disposition ==
          AppAgentExecutionClaimDisposition.completed) {
        return durableClaim.previousResult ??
            _failure(
              command.commandId,
              AppAgentFailureCodes.verificationFailed,
              now,
              entityType: command.commandType.name,
            );
      }
      if (durableClaim.disposition ==
          AppAgentExecutionClaimDisposition.claimed) {
        durableAttemptId = durableClaim.attemptId;
        claimed = command.copyWith(status: AppAgentCommandStatus.executing);
      }
    }
    if (claimed == null || (durableStore != null && durableAttemptId == null)) {
      return _failure(
        command.commandId,
        AppAgentFailureCodes.duplicateExecutionPrevented,
        now,
        entityType: command.commandType.name,
      );
    }
    _checkpoint(AppAgentExecutionCrashPoint.afterExecutionClaim, command);
    _checkpoint(AppAgentExecutionCrashPoint.beforeBusinessUseCase, command);

    AppAgentHandlerResult handlerResult;
    if (!_isExecutionAuthorized(claimed)) {
      handlerResult = AppAgentHandlerResult(
        verified: false,
        entityType: command.commandType.name,
        affectedCount: 0,
        safeFailureCode: AppAgentFailureCodes.permissionDenied,
      );
    } else {
      try {
        final faultInjector = _faultInjector;
        handlerResult =
            handler is AppAgentFaultAwareCommandHandler && faultInjector != null
            ? await handler.executeConfirmedWithFaultInjection(
                claimed,
                faultInjector,
              )
            : await handler.executeConfirmed(claimed);
      } on AppAgentSimulatedProcessInterruption {
        rethrow;
      } on Object {
        handlerResult = AppAgentHandlerResult(
          verified: false,
          entityType: command.commandType.name,
          affectedCount: 0,
          completionUncertain: true,
          safeFailureCode: AppAgentFailureCodes.verificationFailed,
        );
      }
    }
    _checkpoint(AppAgentExecutionCrashPoint.afterBusinessCommit, command);
    if (handlerResult.completionUncertain &&
        durableStore != null &&
        handler is AppAgentReconciliableCommandHandler) {
      // An exception may have happened after the use case committed. Keep the
      // durable claim executing so startup recovery can inspect the correlated
      // owner-scoped business state. Finalizing this as not-executed would make
      // a committed mutation invisible and would destroy reconciliation.
      return _failure(
        command.commandId,
        handlerResult.safeFailureCode ??
            AppAgentFailureCodes.verificationFailed,
        _clock().toUtc(),
        entityType: handlerResult.entityType,
      );
    }
    final finalStatus = handlerResult.partiallySucceeded
        ? AppAgentCommandStatus.partiallySucceeded
        : handlerResult.verified
        ? AppAgentCommandStatus.succeeded
        : AppAgentCommandStatus.failed;
    final failureCode = handlerResult.partiallySucceeded
        ? handlerResult.safeFailureCode ?? AppAgentFailureCodes.partialFailure
        : handlerResult.verified
        ? handlerResult.safeFailureCode
        : handlerResult.safeFailureCode ??
              AppAgentFailureCodes.verificationFailed;
    final result = AppAgentExecutionResult(
      commandId: command.commandId,
      status: finalStatus,
      verified: handlerResult.verified,
      entityType: handlerResult.entityType,
      affectedCount: handlerResult.affectedCount,
      completedAt: _clock().toUtc(),
      safeFailureCode: failureCode,
      undoAvailable: handlerResult.undoAvailable,
      undoToken: handlerResult.undoToken,
    );
    if (durableStore == null) {
      await _commandStore.transition(
        commandId: command.commandId,
        accountScope: command.userAccountScope,
        expectedStatus: AppAgentCommandStatus.executing,
        nextStatus: finalStatus,
        safeFailureCode: failureCode,
      );
    } else {
      try {
        _checkpoint(
          AppAgentExecutionCrashPoint.beforeDurableResultSave,
          command,
        );
        await durableStore.complete(
          command: command,
          attemptId: durableAttemptId!,
          result: result,
        );
        _checkpoint(
          AppAgentExecutionCrashPoint.afterDurableResultSave,
          command,
        );
      } on AppAgentSimulatedProcessInterruption {
        rethrow;
      } on Object {
        // The durable attempt intentionally remains executing. Startup
        // recovery must verify business state before deciding whether a retry
        // is safe; blindly repeating the use case is forbidden.
        return _failure(
          command.commandId,
          AppAgentFailureCodes.verificationFailed,
          _clock().toUtc(),
          entityType: handlerResult.entityType,
        );
      }
    }
    if (durableStore == null) {
      await _audit(command, confirmation.method, result);
    }
    _checkpoint(AppAgentExecutionCrashPoint.beforeUiReceivesResult, command);
    return result;
  }

  void _checkpoint(AppAgentExecutionCrashPoint point, AppAgentCommand command) {
    _faultInjector?.checkpoint(point, command);
  }

  bool _isExecutionAuthorized(AppAgentCommand command) {
    try {
      return _executionAuthorization(command);
    } on Object {
      return false;
    }
  }

  static bool _allowExecution(AppAgentCommand _) => true;

  Future<AppAgentExecutionResult> _rejectBeforeClaim(
    AppAgentCommand command,
    AppAgentConfirmation confirmation,
    String safeFailureCode,
    DateTime at,
  ) async {
    if (_durableExecutionStore != null) {
      final authentic = await _proofStore.consumeProof(
        commandId: command.commandId,
        accountScope: command.userAccountScope,
        proof: confirmation.authorityProof,
        method: confirmation.method,
        now: at,
      );
      if (!authentic) {
        return _failure(
          command.commandId,
          AppAgentFailureCodes.invalidConfirmation,
          at,
          entityType: command.commandType.name,
        );
      }
    }
    return _failConfirmedAndAudit(
      command,
      confirmation.method,
      safeFailureCode,
      at,
    );
  }

  Future<AppAgentExecutionResult> _failConfirmedAndAudit(
    AppAgentCommand command,
    AppAgentConfirmationMethod confirmationMethod,
    String safeFailureCode,
    DateTime at,
  ) async {
    final failed = await _commandStore.transition(
      commandId: command.commandId,
      accountScope: command.userAccountScope,
      expectedStatus: AppAgentCommandStatus.confirmed,
      nextStatus: AppAgentCommandStatus.failed,
      safeFailureCode: safeFailureCode,
    );
    final result = _failure(
      command.commandId,
      failed == null
          ? AppAgentFailureCodes.duplicateExecutionPrevented
          : safeFailureCode,
      at,
      entityType: command.commandType.name,
    );
    if (failed != null) {
      await _audit(command, confirmationMethod, result);
    }
    return result;
  }

  Future<void> _audit(
    AppAgentCommand command,
    AppAgentConfirmationMethod confirmationMethod,
    AppAgentExecutionResult result,
  ) async {
    if (!auditEnabled) {
      return;
    }
    try {
      await _auditStore.append(
        AppAgentAuditEvent(
          commandId: command.commandId,
          userAccountScope: command.userAccountScope,
          actionType: command.toolId,
          entityType: result.entityType,
          result: result.status,
          timestamp: result.completedAt,
          confirmationMethod: confirmationMethod,
          safeFailureCode: result.safeFailureCode,
          undoAvailable: result.undoAvailable,
        ),
      );
    } on Object {
      // A safe audit failure must not turn a verified committed mutation into
      // a false failure or cause the command to execute again.
    }
  }

  AppAgentExecutionResult _failure(
    String commandId,
    String safeFailureCode,
    DateTime at, {
    String entityType = 'unknown',
    AppAgentCommandStatus status = AppAgentCommandStatus.failed,
  }) {
    return AppAgentExecutionResult(
      commandId: commandId,
      status: status,
      verified: false,
      entityType: entityType,
      affectedCount: 0,
      completedAt: at,
      safeFailureCode: safeFailureCode,
    );
  }
}

class AppAgentPlanExecutor {
  AppAgentPlanExecutor({
    required AppAgentCommandExecutor commandExecutor,
    AppAgentPolicy policy = const AppAgentPolicy(),
  }) : _commandExecutor = commandExecutor,
       _policy = policy;

  final AppAgentCommandExecutor _commandExecutor;
  final AppAgentPolicy _policy;

  Future<AgentPlanExecutionResult> executeSequential({
    required AgentPlan plan,
    required Map<String, AppAgentConfirmation> confirmations,
  }) async {
    final now = _commandExecutor._clock().toUtc();
    _policy.validatePlan(plan, now: now);
    final currentScope =
        _commandExecutor._accountScopeProvider.currentAccountScope;
    if (currentScope == null || currentScope != plan.userAccountScope) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.accountScopeMismatch,
        'The plan does not belong to the active account scope.',
      );
    }
    if (plan.cancelled) {
      return AgentPlanExecutionResult(
        planId: plan.planId,
        results: const <AppAgentExecutionResult>[],
        status: AppAgentCommandStatus.cancelled,
      );
    }
    final ordered = [...plan.steps]
      ..sort((a, b) => a.position.compareTo(b.position));
    for (final step in ordered) {
      final command = await _commandExecutor._commandStore.readCommand(
        commandId: step.commandId,
        accountScope: plan.userAccountScope,
      );
      if (command == null) {
        throw const AppAgentPolicyViolation(
          AppAgentFailureCodes.actionUnavailable,
          'A plan command is not available in the active account scope.',
        );
      }
      _policy.validatePlanCommand(plan, command);
      final confirmation = confirmations[step.commandId];
      if (confirmation != null &&
          (confirmation.commandId != step.commandId ||
              confirmation.userAccountScope != plan.userAccountScope ||
              confirmation.confirmedAt.toUtc().isBefore(
                plan.createdAt.toUtc(),
              ) ||
              !confirmation.confirmedAt.toUtc().isBefore(
                plan.expiresAt.toUtc(),
              ))) {
        throw const AppAgentPolicyViolation(
          AppAgentFailureCodes.invalidConfirmation,
          'A plan confirmation is outside the plan scope or lifecycle.',
        );
      }
    }
    final results = <AppAgentExecutionResult>[];
    for (final step in ordered) {
      final confirmation = confirmations[step.commandId];
      if (confirmation == null) {
        results.add(
          AppAgentExecutionResult(
            commandId: step.commandId,
            status: AppAgentCommandStatus.failed,
            verified: false,
            entityType: 'unknown',
            affectedCount: 0,
            completedAt: now,
            safeFailureCode: AppAgentFailureCodes.confirmationRequired,
          ),
        );
        break;
      }
      final result = await _commandExecutor.execute(confirmation);
      results.add(result);
      if (!result.verified ||
          result.status != AppAgentCommandStatus.succeeded) {
        break;
      }
    }
    final allSucceeded =
        results.length == ordered.length &&
        results.every(
          (item) =>
              item.verified && item.status == AppAgentCommandStatus.succeeded,
        );
    final anySucceeded = results.any(
      (item) =>
          item.status == AppAgentCommandStatus.succeeded ||
          item.status == AppAgentCommandStatus.partiallySucceeded,
    );
    return AgentPlanExecutionResult(
      planId: plan.planId,
      results: results,
      status: allSucceeded
          ? AppAgentCommandStatus.succeeded
          : anySucceeded
          ? AppAgentCommandStatus.partiallySucceeded
          : AppAgentCommandStatus.failed,
    );
  }
}
