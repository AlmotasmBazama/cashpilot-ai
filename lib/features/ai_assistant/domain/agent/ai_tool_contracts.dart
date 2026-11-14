import 'ai_agent_models.dart';
import '../app_agent/app_agent_models.dart';

typedef AiToolPermission = AgentPermission;

enum AiToolValueType { string, integer, number, boolean }

class AiToolArgument {
  const AiToolArgument({
    required this.description,
    required this.type,
    this.required = false,
    this.allowedValues = const <String>[],
    this.trimWhitespace = false,
    this.minLength,
    this.maxLength,
  }) : assert(minLength == null || minLength >= 0),
       assert(maxLength == null || maxLength >= 0),
       assert(maxLength == null || maxLength <= 256),
       assert(minLength == null || maxLength == null || minLength <= maxLength);

  final String description;
  final AiToolValueType type;
  final bool required;
  final List<String> allowedValues;
  final bool trimWhitespace;
  final int? minLength;
  final int? maxLength;
}

class AiToolDefinition {
  const AiToolDefinition({
    required this.name,
    required this.description,
    required this.permission,
    this.arguments = const <String, AiToolArgument>{},
    this.risk = AgentActionRisk.readOnly,
    this.modelCallable = true,
  });

  final String name;
  final String description;
  final AiToolPermission permission;
  final Map<String, AiToolArgument> arguments;
  final AgentActionRisk risk;
  final bool modelCallable;
}

/// Immutable identity lease captured from the confirmed local owner session.
///
/// The opaque scope is never model authority. The epoch distinguishes a new
/// authenticated session even when the same account signs in again.
class AiToolOwnerScopeBinding {
  const AiToolOwnerScopeBinding({
    required this.accountScope,
    required this.epoch,
  }) : assert(accountScope.length == 64),
       assert(epoch >= 0);

  final String accountScope;
  final int epoch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiToolOwnerScopeBinding &&
          accountScope == other.accountScope &&
          epoch == other.epoch;

  @override
  int get hashCode => Object.hash(accountScope, epoch);

  @override
  String toString() => 'AiToolOwnerScopeBinding(redacted)';
}

typedef AiToolOwnerScopeReader = AiToolOwnerScopeBinding? Function();

class AiToolExecutionContext {
  const AiToolExecutionContext({
    required this.locale,
    required this.baseCurrencyCode,
    required this.now,
    required this.maxSearchResults,
    required this.ownerScope,
    this.financialDataScopeVerified = false,
  });

  final String locale;
  final String baseCurrencyCode;
  final DateTime now;
  final int maxSearchResults;
  final AiToolOwnerScopeBinding? ownerScope;
  final bool financialDataScopeVerified;

  String? get accountScope => ownerScope?.accountScope;
  int? get ownerScopeEpoch => ownerScope?.epoch;
}

class AiToolResult {
  const AiToolResult({
    required this.toolName,
    required this.data,
    this.evidenceSummary,
    this.period,
    this.navigationPath,
    this.actionDraft,
    this.isPartial = false,
  });

  final String toolName;
  final Map<String, Object?> data;
  final String? evidenceSummary;
  final String? period;
  final String? navigationPath;
  final Map<String, Object?>? actionDraft;
  final bool isPartial;

  Map<String, Object?> toModelPayload() => <String, Object?>{
    'ok': true,
    'tool': toolName,
    'data': data,
    if (isPartial) 'partial': true,
  };
}

class AiToolFailure implements Exception {
  const AiToolFailure({
    required this.code,
    required this.safeMessage,
    this.retryable = false,
  });

  final String code;
  final String safeMessage;
  final bool retryable;

  Map<String, Object?> toModelPayload() => <String, Object?>{
    'ok': false,
    'code': code,
    'message': safeMessage,
    'retryable': retryable,
  };

  @override
  String toString() => 'AiToolFailure($code)';
}

typedef AiToolHandler =
    Future<AiToolResult> Function(
      Map<String, Object?> arguments,
      AiToolExecutionContext context,
    );

abstract interface class AiToolRegistry {
  List<AiToolDefinition> get definitions;

  AiToolDefinition? definitionFor(String name);

  Future<AiToolResult> execute(
    AiAgentToolCall call,
    AiToolExecutionContext context,
  );
}

abstract interface class AiToolPermissionPolicy {
  void validate({
    required AiToolDefinition definition,
    required Map<String, Object?> arguments,
    required AiToolExecutionContext context,
  });
}
