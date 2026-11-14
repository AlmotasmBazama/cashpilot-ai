import 'app_agent_models.dart';

abstract final class AppAgentFailureCodes {
  static const permissionDenied = 'app_agent_permission_denied';
  static const appControlOff = 'ai_app_control_off';
  static const transactionDraftsDisabled = 'ai_transaction_drafts_disabled';
  static const confirmedExecutionDisabled = 'ai_confirmed_execution_disabled';
  static const ownerScopeNotReady = 'ai_owner_scope_not_ready';
  static const legacyDataUnresolved = 'ai_legacy_data_unresolved';
  static const legacyPolicyUnresolved = 'ai_legacy_policy_unresolved';
  static const staleAppControlConfiguration =
      'ai_app_control_stale_configuration';
  static const prohibited = 'app_agent_prohibited';
  static const invalidArguments = 'app_agent_invalid_arguments';
  static const invalidStatus = 'app_agent_invalid_status';
  static const confirmationRequired = 'app_agent_confirmation_required';
  static const doubleConfirmationRequired =
      'app_agent_double_confirmation_required';
  static const invalidConfirmation = 'app_agent_invalid_confirmation';
  static const accountScopeMismatch = 'app_agent_account_scope_mismatch';
  static const expired = 'app_agent_expired';
  static const stalePreview = 'app_agent_stale_preview';
  static const duplicateExecutionPrevented =
      'app_agent_duplicate_execution_prevented';
  static const actionUnavailable = 'app_agent_action_unavailable';
  static const validationFailed = 'app_agent_validation_failed';
  static const verificationFailed = 'app_agent_verification_failed';
  static const partialFailure = 'app_agent_partial_failure';
  static const cancelled = 'app_agent_cancelled';
  static const recoveryManualReview = 'app_agent_recovery_manual_review';
  static const recoveryInconsistent = 'app_agent_recovery_inconsistent';
  static const recoveryNotExecuted = 'app_agent_recovery_not_executed';
}

class AppAgentPolicyViolation implements Exception {
  const AppAgentPolicyViolation(this.code, this.safeMessage);

  final String code;
  final String safeMessage;

  @override
  String toString() => 'AppAgentPolicyViolation($code)';
}

/// Minimal canonical metadata injected by the application layer before any
/// model-proposed or trusted deterministic command enters the runtime.
///
/// The policy intentionally does not import the canonical catalog. The
/// catalog already depends on this policy, so importing it here would create
/// a domain import cycle. Callers must resolve a tool against the canonical
/// catalog and pass only this immutable projection.
class AppAgentModelProposalDescriptor {
  const AppAgentModelProposalDescriptor({
    required this.toolId,
    required this.permission,
    required this.risk,
    required this.modelCallable,
  });

  final String toolId;
  final AgentPermission permission;
  final AgentActionRisk risk;
  final bool modelCallable;
}

class AppAgentPolicy {
  const AppAgentPolicy({
    this.maxArguments = 24,
    this.maxArgumentCharacters = 256,
    this.maxAffectedPreviewItems = 20,
    this.maxPlanSteps = 8,
  });

  final int maxArguments;
  final int maxArgumentCharacters;
  final int maxAffectedPreviewItems;
  final int maxPlanSteps;

  static const Set<String> prohibitedToolIds = <String>{
    'setAccountBalance',
    'modifyBalanceDirectly',
    'runRawSql',
    'accessDrift',
    'accessFirestore',
    'accessRepository',
    'readTokens',
    'readSecrets',
    'changeAuthentication',
    'disableAppCheck',
    'deleteAllUserData',
    'unrestrictedDelete',
    'executeWithoutConfirmation',
    'arbitraryRoute',
    'arbitraryHttpRequest',
    'arbitraryFileAccess',
    'unrestrictedExport',
    'anotherUserDataAccess',
  };

  static const Set<String> _forbiddenArgumentNames = <String>{
    'uid',
    'userid',
    'email',
    'phone',
    'token',
    'authorization',
    'apikey',
    'secret',
    'password',
    'databaseid',
    'firestorepath',
    'filesystempath',
    'rawsql',
    'rawdata',
  };

  static const Set<String> _moneyArgumentNames = <String>{
    'amount',
    'sourceamount',
    'targetamount',
    'destinationamount',
    'income',
    'expense',
    'spenttodate',
    'currentspending',
    'proposedbudget',
    'remaining',
    'monthlycontribution',
    'fixedcosts',
    'plannedsavings',
    'incomechange',
    'scenarioa',
    'scenariob',
    'previouslimit',
    'newlimit',
    'contribution',
    'rate',
    'exchangerate',
    'fee',
  };

  void validateModelProposal(
    AppAgentCommand command, {
    required AppAgentModelProposalDescriptor? descriptor,
  }) {
    _validateCommand(command);
    final canonicalDescriptor = _validateCanonicalDescriptor(
      command,
      descriptor,
    );
    if (!canonicalDescriptor.modelCallable) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.prohibited,
        'That capability cannot be proposed by a model.',
      );
    }
  }

  /// Validates a command created by trusted local deterministic code.
  ///
  /// Canonical tools marked `modelCallable: false` remain valid here, while
  /// unknown tools and canonical permission/risk mismatches fail closed.
  void validateTrustedLocalCommand(
    AppAgentCommand command, {
    required AppAgentModelProposalDescriptor? descriptor,
  }) {
    _validateCommand(command);
    _validateCanonicalDescriptor(command, descriptor);
  }

  /// Revalidates the structure of an immutable command already admitted by a
  /// canonical-aware insert-only store.
  void validatePersistedCommand(AppAgentCommand command) {
    _validateCommand(command);
  }

  void _validateCommand(AppAgentCommand command) {
    if (prohibitedToolIds.contains(command.toolId) ||
        command.risk == AgentActionRisk.prohibited ||
        command.permission == AgentPermission.executeConfirmedAction) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.prohibited,
        'That capability is not available to the assistant.',
      );
    }
    final expectedType = commandTypeForPermission(command.permission);
    if (expectedType != command.commandType) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.permissionDenied,
        'The requested capability does not match its permission.',
      );
    }
    validateArguments(command.normalizedArguments);
    if (command.commandType == AppAgentCommandType.create ||
        command.commandType == AppAgentCommandType.update ||
        command.commandType == AppAgentCommandType.archive ||
        command.commandType == AppAgentCommandType.bulk) {
      _rejectDirectBalanceMutation(command.normalizedArguments);
    }
  }

  AppAgentModelProposalDescriptor _validateCanonicalDescriptor(
    AppAgentCommand command,
    AppAgentModelProposalDescriptor? descriptor,
  ) {
    if (descriptor == null || descriptor.toolId != command.toolId) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.actionUnavailable,
        'That capability is not in the canonical tool registry.',
      );
    }
    if (descriptor.permission != command.permission ||
        descriptor.risk != command.risk) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.permissionDenied,
        'The command does not match its canonical permission and risk.',
      );
    }
    return descriptor;
  }

  void validateArguments(Map<String, Object?> arguments) {
    if (arguments.length > maxArguments) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidArguments,
        'The request contains too many arguments.',
      );
    }
    for (final entry in arguments.entries) {
      _validateValue(entry.key, entry.value, depth: 0);
    }
  }

  void validateTransition(
    AppAgentCommandStatus from,
    AppAgentCommandStatus to,
  ) {
    final allowed = switch (from) {
      AppAgentCommandStatus.proposed => <AppAgentCommandStatus>{
        AppAgentCommandStatus.resolving,
        AppAgentCommandStatus.cancelled,
        AppAgentCommandStatus.expired,
      },
      AppAgentCommandStatus.resolving => <AppAgentCommandStatus>{
        AppAgentCommandStatus.needsClarification,
        AppAgentCommandStatus.readyForPreview,
        AppAgentCommandStatus.failed,
        AppAgentCommandStatus.cancelled,
        AppAgentCommandStatus.expired,
      },
      AppAgentCommandStatus.needsClarification => <AppAgentCommandStatus>{
        AppAgentCommandStatus.resolving,
        AppAgentCommandStatus.cancelled,
        AppAgentCommandStatus.expired,
      },
      AppAgentCommandStatus.readyForPreview => <AppAgentCommandStatus>{
        AppAgentCommandStatus.awaitingConfirmation,
        AppAgentCommandStatus.succeeded,
        AppAgentCommandStatus.cancelled,
        AppAgentCommandStatus.expired,
      },
      AppAgentCommandStatus.awaitingConfirmation => <AppAgentCommandStatus>{
        AppAgentCommandStatus.confirmed,
        AppAgentCommandStatus.cancelled,
        AppAgentCommandStatus.expired,
      },
      AppAgentCommandStatus.confirmed => <AppAgentCommandStatus>{
        AppAgentCommandStatus.executing,
        AppAgentCommandStatus.cancelled,
        AppAgentCommandStatus.expired,
        AppAgentCommandStatus.failed,
      },
      AppAgentCommandStatus.executing => <AppAgentCommandStatus>{
        AppAgentCommandStatus.succeeded,
        AppAgentCommandStatus.partiallySucceeded,
        AppAgentCommandStatus.failed,
      },
      AppAgentCommandStatus.succeeded ||
      AppAgentCommandStatus.partiallySucceeded ||
      AppAgentCommandStatus.failed ||
      AppAgentCommandStatus.cancelled ||
      AppAgentCommandStatus.expired => const <AppAgentCommandStatus>{},
    };
    if (!allowed.contains(to)) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidStatus,
        'The command cannot move to the requested state.',
      );
    }
  }

  AppAgentConfirmationLevel confirmationLevelFor(AgentActionRisk risk) {
    return switch (risk) {
      AgentActionRisk.readOnly => AppAgentConfirmationLevel.none,
      AgentActionRisk.low => AppAgentConfirmationLevel.normal,
      AgentActionRisk.medium => AppAgentConfirmationLevel.detailed,
      AgentActionRisk.high => AppAgentConfirmationLevel.doubleConfirmation,
      AgentActionRisk.prohibited =>
        AppAgentConfirmationLevel.protectedNativeWorkflow,
    };
  }

  AppAgentCommandType commandTypeForPermission(AgentPermission permission) {
    return switch (permission) {
      AgentPermission.readFinancialData ||
      AgentPermission.readAppConfiguration => AppAgentCommandType.read,
      AgentPermission.calculate => AppAgentCommandType.calculate,
      AgentPermission.navigate => AppAgentCommandType.navigate,
      AgentPermission.createDraft => AppAgentCommandType.create,
      AgentPermission.updateDraft => AppAgentCommandType.update,
      AgentPermission.archiveDraft => AppAgentCommandType.archive,
      AgentPermission.bulkDraft => AppAgentCommandType.bulk,
      AgentPermission.exportDraft => AppAgentCommandType.export,
      AgentPermission.executeConfirmedAction =>
        throw const AppAgentPolicyViolation(
          AppAgentFailureCodes.permissionDenied,
          'Execution permission is local-only.',
        ),
    };
  }

  void validatePlan(AgentPlan plan, {required DateTime now}) {
    if (plan.steps.isEmpty || plan.steps.length > maxPlanSteps) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidArguments,
        'The plan is outside the supported step limit.',
      );
    }
    if (plan.planId.trim().isEmpty ||
        plan.conversationId.trim().isEmpty ||
        plan.userAccountScope.trim().isEmpty ||
        plan.steps.any(
          (step) => step.stepId.trim().isEmpty || step.commandId.trim().isEmpty,
        )) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidArguments,
        'The plan is missing required local identifiers.',
      );
    }
    final createdAt = plan.createdAt.toUtc();
    final expiresAt = plan.expiresAt.toUtc();
    final checkedAt = now.toUtc();
    if (createdAt.isAfter(checkedAt) || !expiresAt.isAfter(createdAt)) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidArguments,
        'The plan lifecycle is invalid.',
      );
    }
    if (!checkedAt.isBefore(expiresAt)) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.expired,
        'The plan has expired.',
      );
    }
    final positions = plan.steps.map((step) => step.position).toSet();
    final commandIds = plan.steps.map((step) => step.commandId).toSet();
    if (positions.length != plan.steps.length ||
        commandIds.length != plan.steps.length ||
        !positions.containsAll(
          Iterable<int>.generate(plan.steps.length, (index) => index + 1),
        )) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidArguments,
        'Plan steps must be unique and contiguous.',
      );
    }
  }

  void validatePlanCommand(AgentPlan plan, AppAgentCommand command) {
    if (command.userAccountScope != plan.userAccountScope) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.accountScopeMismatch,
        'The plan does not belong to the active account scope.',
      );
    }
    if (command.conversationId != plan.conversationId) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidArguments,
        'All plan commands must belong to the same conversation.',
      );
    }
    if (command.createdAt.toUtc().isAfter(plan.createdAt.toUtc()) ||
        command.expiresAt.toUtc().isBefore(plan.expiresAt.toUtc())) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidArguments,
        'A command lifecycle does not cover the plan lifecycle.',
      );
    }
  }

  void validatePreview(AppAgentCommand command, AppAgentPreview preview) {
    final hasSafeMetadata =
        _isMeaningfulPreviewText(preview.title) &&
        _isMeaningfulPreviewText(preview.entityType) &&
        _isMeaningfulPreviewText(preview.stateFingerprint);
    final fieldsAreMeaningful = preview.fields.every(
      (field) =>
          _isMeaningfulPreviewText(field.label) &&
          _isMeaningfulPreviewText(field.proposedValue) &&
          (field.previousValue == null ||
              field.previousValue!.length <= maxArgumentCharacters),
    );
    final affectedItemsAreMeaningful = preview.affectedItems.every(
      (item) =>
          _isMeaningfulPreviewText(item.opaqueReference) &&
          _isMeaningfulPreviewText(item.label) &&
          _isMeaningfulPreviewText(item.summary),
    );
    final safelyBounded =
        preview.risk == command.risk &&
        preview.confirmationLevel == confirmationLevelFor(command.risk) &&
        preview.affectedItems.length <= maxAffectedPreviewItems &&
        preview.affectedCount >= preview.affectedItems.length &&
        preview.omittedItemCount >= 0;
    final needsDetailedPreview =
        command.risk == AgentActionRisk.medium ||
        command.risk == AgentActionRisk.high;
    final hasDetailedFields =
        !needsDetailedPreview ||
        (preview.fields.isNotEmpty && preview.affectedCount > 0);
    final hasHighRiskAffectedItems =
        command.risk != AgentActionRisk.high ||
        (preview.affectedItems.isNotEmpty &&
            preview.affectedCount ==
                preview.affectedItems.length + preview.omittedItemCount);
    if (!hasSafeMetadata ||
        !fieldsAreMeaningful ||
        !affectedItemsAreMeaningful ||
        !safelyBounded ||
        !hasDetailedFields ||
        !hasHighRiskAffectedItems) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidArguments,
        'The preview does not contain the required safe detail.',
      );
    }
  }

  void _validateValue(String key, Object? value, {required int depth}) {
    final normalizedKey = _normalizeArgumentName(key);
    if (_isForbiddenArgumentName(normalizedKey)) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.permissionDenied,
        'Private or unrestricted values are not accepted.',
      );
    }
    if (_moneyArgumentNames.contains(normalizedKey) &&
        value != null &&
        value is! String &&
        value is! Map) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidArguments,
        'Money and rate values must be decimal strings.',
      );
    }
    if (depth > 3) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidArguments,
        'Nested arguments exceeded the safe depth.',
      );
    }
    if (value == null || value is bool || value is int) {
      return;
    }
    if (value is double) {
      if (!value.isFinite) {
        throw const AppAgentPolicyViolation(
          AppAgentFailureCodes.invalidArguments,
          'A numeric argument is invalid.',
        );
      }
      return;
    }
    if (value is String) {
      if (value.length > maxArgumentCharacters || value.contains('\u0000')) {
        throw const AppAgentPolicyViolation(
          AppAgentFailureCodes.invalidArguments,
          'A text argument exceeded the safe limit.',
        );
      }
      return;
    }
    if (value is List) {
      if (value.length > maxAffectedPreviewItems) {
        throw const AppAgentPolicyViolation(
          AppAgentFailureCodes.invalidArguments,
          'A list argument exceeded the safe limit.',
        );
      }
      for (final item in value) {
        _validateValue(key, item, depth: depth + 1);
      }
      return;
    }
    if (value is Map) {
      if (value.length > maxArguments) {
        throw const AppAgentPolicyViolation(
          AppAgentFailureCodes.invalidArguments,
          'A structured argument exceeded the safe limit.',
        );
      }
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw const AppAgentPolicyViolation(
            AppAgentFailureCodes.permissionDenied,
            'Private or unrestricted values are not accepted.',
          );
        }
        _validateValue(entry.key as String, entry.value, depth: depth + 1);
      }
      return;
    }
    throw const AppAgentPolicyViolation(
      AppAgentFailureCodes.invalidArguments,
      'An argument type is not supported.',
    );
  }

  bool _isForbiddenArgumentName(String normalizedKey) {
    return _forbiddenArgumentNames.contains(normalizedKey) ||
        normalizedKey.contains('token') ||
        normalizedKey.contains('secret') ||
        normalizedKey.contains('password') ||
        normalizedKey.contains('authorization') ||
        normalizedKey.contains('apikey') ||
        normalizedKey.contains('firestorepath') ||
        normalizedKey.contains('filesystempath') ||
        normalizedKey.contains('rawsql');
  }

  void _rejectDirectBalanceMutation(Object? value) {
    if (value is List) {
      for (final item in value) {
        _rejectDirectBalanceMutation(item);
      }
      return;
    }
    if (value is! Map) {
      return;
    }
    for (final entry in value.entries) {
      if (entry.key is String &&
          _normalizeArgumentName(entry.key as String).contains('balance')) {
        throw const AppAgentPolicyViolation(
          AppAgentFailureCodes.prohibited,
          'Account balances cannot be changed directly.',
        );
      }
      _rejectDirectBalanceMutation(entry.value);
    }
  }

  bool _isMeaningfulPreviewText(String value) =>
      value.trim().isNotEmpty && value.length <= maxArgumentCharacters;

  String _normalizeArgumentName(String value) =>
      value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
}
