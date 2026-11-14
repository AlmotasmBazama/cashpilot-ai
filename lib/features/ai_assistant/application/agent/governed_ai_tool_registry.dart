import 'dart:async';
import 'dart:convert';

import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/app_agent/app_agent_models.dart';

class DefaultAiToolPermissionPolicy implements AiToolPermissionPolicy {
  const DefaultAiToolPermissionPolicy({this.maxSearchResults = 20});

  final int maxSearchResults;

  static const Set<String> _forbiddenArgumentNames = <String>{
    'token',
    'secret',
    'apiKey',
    'database',
    'rawData',
    'securityRule',
  };

  @override
  void validate({
    required AiToolDefinition definition,
    required Map<String, Object?> arguments,
    required AiToolExecutionContext context,
  }) {
    if (!definition.modelCallable ||
        definition.permission == AiToolPermission.executeConfirmedAction ||
        definition.risk == AgentActionRisk.prohibited) {
      throw const AiToolFailure(
        code: 'permission_denied',
        safeMessage: 'That capability is not available to the model.',
      );
    }
    for (final key in arguments.keys) {
      if (!definition.arguments.containsKey(key)) {
        throw const AiToolFailure(
          code: 'invalid_arguments',
          safeMessage: 'The tool received an unsupported argument.',
        );
      }
      if (_forbiddenArgumentNames.contains(key)) {
        throw const AiToolFailure(
          code: 'permission_denied',
          safeMessage: 'That information is not available to AI tools.',
        );
      }
    }

    for (final entry in definition.arguments.entries) {
      final value = arguments[entry.key];
      final schema = entry.value;
      if (schema.required && value == null) {
        throw const AiToolFailure(
          code: 'invalid_arguments',
          safeMessage: 'A required tool argument is missing.',
        );
      }
      if (value == null) {
        continue;
      }
      final hasValidType = switch (schema.type) {
        AiToolValueType.string => value is String,
        AiToolValueType.integer => value is int,
        AiToolValueType.number => value is num,
        AiToolValueType.boolean => value is bool,
      };
      if (!hasValidType) {
        throw const AiToolFailure(
          code: 'invalid_arguments',
          safeMessage: 'A tool argument has the wrong type.',
        );
      }
      if (value is String) {
        final normalized = schema.trimWhitespace ? value.trim() : value;
        final minLength = schema.minLength ?? 0;
        final maxLength = schema.maxLength ?? 256;
        if (normalized.length < minLength ||
            normalized.length > maxLength ||
            normalized.contains('\u0000')) {
          throw const AiToolFailure(
            code: 'invalid_arguments',
            safeMessage: 'A tool argument is outside the allowed bounds.',
          );
        }
      }
      if (value is num && (!value.isFinite || value.abs() > 1000000000000)) {
        throw const AiToolFailure(
          code: 'invalid_arguments',
          safeMessage: 'A numeric tool argument is outside the allowed bounds.',
        );
      }
      if (schema.allowedValues.isNotEmpty &&
          !schema.allowedValues.contains(value)) {
        throw const AiToolFailure(
          code: 'invalid_arguments',
          safeMessage: 'A tool argument has an unsupported value.',
        );
      }
    }

    final limit = arguments['limit'];
    if (limit is int && (limit < 1 || limit > maxSearchResults)) {
      throw const AiToolFailure(
        code: 'invalid_arguments',
        safeMessage:
            'The requested result count is outside the allowed bounds.',
      );
    }
    if (definition.permission == AiToolPermission.readFinancialData &&
        (!context.financialDataScopeVerified || context.ownerScope == null)) {
      throw const AiToolFailure(
        code: 'financial_scope_unverified',
        safeMessage: 'Financial data is unavailable for the current session.',
      );
    }
  }
}

class RegisteredAiTool {
  const RegisteredAiTool({required this.definition, required this.handler});

  final AiToolDefinition definition;
  final AiToolHandler handler;
}

class GovernedAiToolRegistry implements AiToolRegistry {
  GovernedAiToolRegistry({
    required Iterable<RegisteredAiTool> tools,
    required AiToolPermissionPolicy permissionPolicy,
    AiToolOwnerScopeReader? currentOwnerScope,
    this.toolTimeout = const Duration(seconds: 5),
    this.maxResultBytes = 16384,
  }) : _permissionPolicy = permissionPolicy,
       _currentOwnerScope = currentOwnerScope,
       _tools = <String, RegisteredAiTool>{
         for (final tool in tools) tool.definition.name: tool,
       } {
    if (_tools.length != tools.length) {
      throw StateError('AI tool names must be unique.');
    }
  }

  final Map<String, RegisteredAiTool> _tools;
  final AiToolPermissionPolicy _permissionPolicy;
  final AiToolOwnerScopeReader? _currentOwnerScope;
  final Duration toolTimeout;
  final int maxResultBytes;

  @override
  List<AiToolDefinition> get definitions => _tools.values
      .map((tool) => tool.definition)
      .where((definition) => definition.modelCallable)
      .toList(growable: false);

  @override
  AiToolDefinition? definitionFor(String name) => _tools[name]?.definition;

  @override
  Future<AiToolResult> execute(
    AiAgentToolCall call,
    AiToolExecutionContext context,
  ) async {
    final tool = _tools[call.name];
    if (tool == null) {
      throw const AiToolFailure(
        code: 'tool_not_allowed',
        safeMessage: 'That tool is not available.',
      );
    }
    _permissionPolicy.validate(
      definition: tool.definition,
      arguments: call.arguments,
      context: context,
    );
    _validateCurrentOwnerScope(tool.definition, context);
    try {
      final result = await tool
          .handler(call.arguments, context)
          .timeout(toolTimeout);
      _validateCurrentOwnerScope(tool.definition, context);
      if (utf8.encode(jsonEncode(result.toModelPayload())).length >
          maxResultBytes) {
        throw const AiToolFailure(
          code: 'tool_result_too_large',
          safeMessage: 'The tool result exceeded the safe size limit.',
        );
      }
      return result;
    } on TimeoutException {
      throw const AiToolFailure(
        code: 'tool_timeout',
        safeMessage: 'The financial data tool took too long to respond.',
        retryable: true,
      );
    } on AiToolFailure {
      rethrow;
    } on Object {
      throw const AiToolFailure(
        code: 'tool_failed',
        safeMessage: 'The financial data tool failed safely.',
        retryable: true,
      );
    }
  }

  void _validateCurrentOwnerScope(
    AiToolDefinition definition,
    AiToolExecutionContext context,
  ) {
    if (definition.permission != AiToolPermission.readFinancialData) {
      return;
    }
    AiToolOwnerScopeBinding? current;
    try {
      current = _currentOwnerScope?.call();
    } on Object {
      current = null;
    }
    if (current == null || current != context.ownerScope) {
      throw const AiToolFailure(
        code: 'account_scope_changed',
        safeMessage: 'The active account changed. The tool was stopped safely.',
      );
    }
  }
}
