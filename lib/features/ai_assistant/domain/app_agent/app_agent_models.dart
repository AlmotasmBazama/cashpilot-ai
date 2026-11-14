enum AgentPermission {
  readFinancialData,
  readAppConfiguration,
  calculate,
  navigate,
  createDraft,
  updateDraft,
  archiveDraft,
  bulkDraft,
  exportDraft,
  executeConfirmedAction,
}

enum AgentActionRisk { readOnly, low, medium, high, prohibited }

enum AppAgentCommandType {
  read,
  calculate,
  navigate,
  create,
  update,
  archive,
  bulk,
  export,
}

enum AppAgentCommandStatus {
  proposed,
  resolving,
  needsClarification,
  readyForPreview,
  awaitingConfirmation,
  confirmed,
  executing,
  succeeded,
  partiallySucceeded,
  failed,
  cancelled,
  expired,
}

enum AppAgentConfirmationLevel {
  none,
  normal,
  detailed,
  doubleConfirmation,
  protectedNativeWorkflow,
}

enum AppAgentConfirmationMethod {
  primaryButton,
  doubleConfirmation,
  protectedNativeWorkflow,
}

class AppAgentCommand {
  AppAgentCommand({
    required this.commandId,
    required this.conversationId,
    required this.userAccountScope,
    required this.commandType,
    required this.toolId,
    required Map<String, Object?> normalizedArguments,
    required this.permission,
    required this.risk,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.revision = 0,
    this.previewFingerprint,
    this.safeFailureCode,
  }) : normalizedArguments = Map<String, Object?>.unmodifiable(
         normalizedArguments.map(
           (key, value) => MapEntry<String, Object?>(key, _freezeJson(value)),
         ),
       );

  final String commandId;
  final String conversationId;

  /// Local account-scope fingerprint. This value is never sent to a model.
  final String userAccountScope;
  final AppAgentCommandType commandType;
  final String toolId;

  /// Locally normalized arguments. Entity references must be opaque model
  /// references or locally resolved values; provider output is never trusted.
  final Map<String, Object?> normalizedArguments;
  final AgentPermission permission;
  final AgentActionRisk risk;
  final DateTime createdAt;
  final DateTime expiresAt;
  final AppAgentCommandStatus status;
  final int revision;
  final String? previewFingerprint;
  final String? safeFailureCode;

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt.toUtc());

  bool get isTerminal => switch (status) {
    AppAgentCommandStatus.succeeded ||
    AppAgentCommandStatus.partiallySucceeded ||
    AppAgentCommandStatus.failed ||
    AppAgentCommandStatus.cancelled ||
    AppAgentCommandStatus.expired => true,
    _ => false,
  };

  AppAgentCommand copyWith({
    AppAgentCommandStatus? status,
    int? revision,
    String? previewFingerprint,
    String? safeFailureCode,
    bool clearPreviewFingerprint = false,
    bool clearSafeFailureCode = false,
  }) {
    return AppAgentCommand(
      commandId: commandId,
      conversationId: conversationId,
      userAccountScope: userAccountScope,
      commandType: commandType,
      toolId: toolId,
      normalizedArguments: normalizedArguments,
      permission: permission,
      risk: risk,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
      revision: revision ?? this.revision,
      previewFingerprint: clearPreviewFingerprint
          ? null
          : previewFingerprint ?? this.previewFingerprint,
      safeFailureCode: clearSafeFailureCode
          ? null
          : safeFailureCode ?? this.safeFailureCode,
    );
  }

  Map<String, Object?> toStorageJson() => <String, Object?>{
    'commandId': commandId,
    'conversationId': conversationId,
    'userAccountScope': userAccountScope,
    'commandType': commandType.name,
    'toolId': toolId,
    'normalizedArguments': normalizedArguments,
    'permission': permission.name,
    'risk': risk.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'status': status.name,
    'revision': revision,
    if (previewFingerprint != null) 'previewFingerprint': previewFingerprint,
    if (safeFailureCode != null) 'safeFailureCode': safeFailureCode,
  };

  /// Provider-safe metadata intentionally excludes account scope, local
  /// entity values, confirmation state, and execution state.
  Map<String, Object?> toModelMetadata() => <String, Object?>{
    'commandType': commandType.name,
    'toolId': toolId,
    'permission': permission.name,
    'risk': risk.name,
  };

  static AppAgentCommand? fromStorageJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final commandType = _enumByName(
      AppAgentCommandType.values,
      value['commandType'],
    );
    final permission = _enumByName(AgentPermission.values, value['permission']);
    final risk = _enumByName(AgentActionRisk.values, value['risk']);
    final status = _enumByName(AppAgentCommandStatus.values, value['status']);
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(value['expiresAt']?.toString() ?? '');
    final arguments = value['normalizedArguments'];
    if (value['commandId'] is! String ||
        value['conversationId'] is! String ||
        value['userAccountScope'] is! String ||
        value['toolId'] is! String ||
        commandType == null ||
        permission == null ||
        risk == null ||
        status == null ||
        createdAt == null ||
        expiresAt == null ||
        arguments is! Map) {
      return null;
    }
    return AppAgentCommand(
      commandId: value['commandId'] as String,
      conversationId: value['conversationId'] as String,
      userAccountScope: value['userAccountScope'] as String,
      commandType: commandType,
      toolId: value['toolId'] as String,
      normalizedArguments: Map<String, Object?>.from(arguments),
      permission: permission,
      risk: risk,
      createdAt: createdAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
      status: status,
      revision: value['revision'] is int ? value['revision'] as int : 0,
      previewFingerprint: value['previewFingerprint'] as String?,
      safeFailureCode: value['safeFailureCode'] as String?,
    );
  }
}

class AppAgentPreviewField {
  const AppAgentPreviewField({
    required this.label,
    this.previousValue,
    required this.proposedValue,
  });

  final String label;
  final String? previousValue;
  final String proposedValue;

  Map<String, Object?> toJson() => <String, Object?>{
    'label': label,
    if (previousValue != null) 'previousValue': previousValue,
    'proposedValue': proposedValue,
  };

  static AppAgentPreviewField? fromJson(Object? value) {
    if (value is! Map ||
        value['label'] is! String ||
        value['proposedValue'] is! String) {
      return null;
    }
    return AppAgentPreviewField(
      label: value['label'] as String,
      previousValue: value['previousValue'] as String?,
      proposedValue: value['proposedValue'] as String,
    );
  }
}

class AppAgentAffectedItem {
  const AppAgentAffectedItem({
    required this.opaqueReference,
    required this.label,
    required this.summary,
  });

  final String opaqueReference;
  final String label;
  final String summary;

  Map<String, Object?> toJson() => <String, Object?>{
    'opaqueReference': opaqueReference,
    'label': label,
    'summary': summary,
  };

  static AppAgentAffectedItem? fromJson(Object? value) {
    if (value is! Map ||
        value['opaqueReference'] is! String ||
        value['label'] is! String ||
        value['summary'] is! String) {
      return null;
    }
    return AppAgentAffectedItem(
      opaqueReference: value['opaqueReference'] as String,
      label: value['label'] as String,
      summary: value['summary'] as String,
    );
  }
}

class AppAgentPreview {
  AppAgentPreview({
    required this.commandId,
    required this.title,
    required this.entityType,
    required List<AppAgentPreviewField> fields,
    required this.risk,
    required this.confirmationLevel,
    required this.stateFingerprint,
    required this.createdAt,
    List<AppAgentAffectedItem> affectedItems = const <AppAgentAffectedItem>[],
    this.affectedCount = 1,
    this.omittedItemCount = 0,
    this.partialFailurePossible = false,
  }) : fields = List<AppAgentPreviewField>.unmodifiable(fields),
       affectedItems = List<AppAgentAffectedItem>.unmodifiable(affectedItems);

  final String commandId;
  final String title;
  final String entityType;
  final List<AppAgentPreviewField> fields;
  final AgentActionRisk risk;
  final AppAgentConfirmationLevel confirmationLevel;
  final String stateFingerprint;
  final DateTime createdAt;
  final List<AppAgentAffectedItem> affectedItems;
  final int affectedCount;
  final int omittedItemCount;
  final bool partialFailurePossible;

  Map<String, Object?> toStorageJson() => <String, Object?>{
    'commandId': commandId,
    'title': title,
    'entityType': entityType,
    'fields': fields.map((item) => item.toJson()).toList(growable: false),
    'risk': risk.name,
    'confirmationLevel': confirmationLevel.name,
    'stateFingerprint': stateFingerprint,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'affectedItems': affectedItems
        .map((item) => item.toJson())
        .toList(growable: false),
    'affectedCount': affectedCount,
    'omittedItemCount': omittedItemCount,
    'partialFailurePossible': partialFailurePossible,
  };

  static AppAgentPreview? fromStorageJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final risk = _enumByName(AgentActionRisk.values, value['risk']);
    final level = _enumByName(
      AppAgentConfirmationLevel.values,
      value['confirmationLevel'],
    );
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    if (value['commandId'] is! String ||
        value['title'] is! String ||
        value['entityType'] is! String ||
        value['stateFingerprint'] is! String ||
        risk == null ||
        level == null ||
        createdAt == null) {
      return null;
    }
    return AppAgentPreview(
      commandId: value['commandId'] as String,
      title: value['title'] as String,
      entityType: value['entityType'] as String,
      fields: (value['fields'] as List? ?? const <Object?>[])
          .map(AppAgentPreviewField.fromJson)
          .whereType<AppAgentPreviewField>()
          .toList(growable: false),
      risk: risk,
      confirmationLevel: level,
      stateFingerprint: value['stateFingerprint'] as String,
      createdAt: createdAt.toUtc(),
      affectedItems: (value['affectedItems'] as List? ?? const <Object?>[])
          .map(AppAgentAffectedItem.fromJson)
          .whereType<AppAgentAffectedItem>()
          .toList(growable: false),
      affectedCount: value['affectedCount'] as int? ?? 1,
      omittedItemCount: value['omittedItemCount'] as int? ?? 0,
      partialFailurePossible: value['partialFailurePossible'] == true,
    );
  }
}

class AppAgentConfirmation {
  const AppAgentConfirmation({
    required this.commandId,
    required this.userAccountScope,
    required this.confirmedAt,
    required this.method,
    required this.authorityProof,
  });

  final String commandId;
  final String userAccountScope;
  final DateTime confirmedAt;
  final AppAgentConfirmationMethod method;

  /// One-time local proof issued by AppAgentConfirmationController. It is
  /// never included in model context, logs, audit events, or UI messages.
  final String authorityProof;
}

class AppAgentExecutionResult {
  const AppAgentExecutionResult({
    required this.commandId,
    required this.status,
    required this.verified,
    required this.entityType,
    required this.affectedCount,
    required this.completedAt,
    this.safeFailureCode,
    this.undoAvailable = false,
    this.undoToken,
  });

  final String commandId;
  final AppAgentCommandStatus status;
  final bool verified;
  final String entityType;
  final int affectedCount;
  final DateTime completedAt;
  final String? safeFailureCode;
  final bool undoAvailable;
  final String? undoToken;
}

class AppAgentAuditEvent {
  const AppAgentAuditEvent({
    required this.commandId,
    required this.userAccountScope,
    required this.actionType,
    required this.entityType,
    required this.result,
    required this.timestamp,
    required this.confirmationMethod,
    required this.undoAvailable,
    this.safeFailureCode,
  });

  final String commandId;

  /// Local account-scope fingerprint. This field is persisted locally only
  /// and must never be included in provider context or user-visible logs.
  final String userAccountScope;
  final String actionType;
  final String entityType;
  final AppAgentCommandStatus result;
  final DateTime timestamp;
  final AppAgentConfirmationMethod confirmationMethod;
  final String? safeFailureCode;
  final bool undoAvailable;

  Map<String, Object?> toJson() => <String, Object?>{
    'commandId': commandId,
    'userAccountScope': userAccountScope,
    'actionType': actionType,
    'entityType': entityType,
    'result': result.name,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'confirmationMethod': confirmationMethod.name,
    if (safeFailureCode != null) 'safeFailureCode': safeFailureCode,
    'undoAvailable': undoAvailable,
  };

  static AppAgentAuditEvent? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final result = _enumByName(AppAgentCommandStatus.values, value['result']);
    final method = _enumByName(
      AppAgentConfirmationMethod.values,
      value['confirmationMethod'],
    );
    final timestamp = DateTime.tryParse(value['timestamp']?.toString() ?? '');
    if (value['commandId'] is! String ||
        value['userAccountScope'] is! String ||
        value['actionType'] is! String ||
        value['entityType'] is! String ||
        result == null ||
        method == null ||
        timestamp == null) {
      return null;
    }
    return AppAgentAuditEvent(
      commandId: value['commandId'] as String,
      userAccountScope: value['userAccountScope'] as String,
      actionType: value['actionType'] as String,
      entityType: value['entityType'] as String,
      result: result,
      timestamp: timestamp.toUtc(),
      confirmationMethod: method,
      safeFailureCode: value['safeFailureCode'] as String?,
      undoAvailable: value['undoAvailable'] == true,
    );
  }
}

class AgentPlanStep {
  const AgentPlanStep({
    required this.stepId,
    required this.commandId,
    required this.position,
  });

  final String stepId;
  final String commandId;
  final int position;
}

class AgentPlan {
  AgentPlan({
    required this.planId,
    required this.conversationId,
    required this.userAccountScope,
    required List<AgentPlanStep> steps,
    required this.createdAt,
    required this.expiresAt,
    this.cancelled = false,
  }) : steps = List<AgentPlanStep>.unmodifiable(steps);

  final String planId;
  final String conversationId;
  final String userAccountScope;
  final List<AgentPlanStep> steps;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool cancelled;
}

class AgentPlanPreview {
  AgentPlanPreview({
    required this.planId,
    required List<AppAgentPreview> previews,
    required this.atomic,
    required this.partialFailurePossible,
  }) : previews = List<AppAgentPreview>.unmodifiable(previews);

  final String planId;
  final List<AppAgentPreview> previews;
  final bool atomic;
  final bool partialFailurePossible;
}

class AgentPlanExecutionResult {
  AgentPlanExecutionResult({
    required this.planId,
    required List<AppAgentExecutionResult> results,
    required this.status,
  }) : results = List<AppAgentExecutionResult>.unmodifiable(results);

  final String planId;
  final List<AppAgentExecutionResult> results;
  final AppAgentCommandStatus status;
}

T? _enumByName<T extends Enum>(Iterable<T> values, Object? name) {
  if (name is! String) {
    return null;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

Object? _freezeJson(Object? value) {
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeJson));
  }
  if (value is Map) {
    return Map<Object?, Object?>.unmodifiable(
      value.map(
        (key, nestedValue) =>
            MapEntry<Object?, Object?>(key, _freezeJson(nestedValue)),
      ),
    );
  }
  return value;
}
