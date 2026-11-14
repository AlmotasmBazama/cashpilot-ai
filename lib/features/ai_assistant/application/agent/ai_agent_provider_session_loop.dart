import 'dart:convert';

import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/agent/tool_relevance_policy.dart';
import '../../domain/services/ai_intent_router.dart';
import 'ai_agent_local_plan_executor.dart';

/// Immutable inputs for one provider-backed assistant session.
final class AiAgentProviderSessionContext {
  const AiAgentProviderSessionContext({
    required this.request,
    required this.memory,
    required this.memoryAccess,
    required this.taskClass,
    required this.route,
    required this.systemInstruction,
  });

  final AiAgentRequest request;
  final AiAgentSessionMemory memory;
  final AiAgentMemoryAccess memoryAccess;
  final ModelTask taskClass;
  final AiIntentRoute route;
  final String systemInstruction;
}

/// Owns provider request construction, history minimization, and bounded tool
/// continuation for one model session.
abstract interface class AiAgentProviderSessionLoop {
  Stream<AiAgentModelTurn> streamInitial(AiAgentProviderSessionContext context);

  Future<AiAgentModelTurn> run({
    required AiAgentProviderSessionContext context,
    required List<AiToolResult> successfulResults,
    required AiToolExecutionContext Function() executionContextFactory,
  });
}

final class DefaultAiAgentProviderSessionLoop
    implements AiAgentProviderSessionLoop {
  const DefaultAiAgentProviderSessionLoop({
    required AiToolRegistry toolRegistry,
    required AiAgentModelGateway modelGateway,
    required AiProviderEgressGuardFactory providerEgressGuardFactory,
    required AiAgentContextSanitizer contextSanitizer,
    required ToolRelevancePolicy toolRelevancePolicy,
    required AiAgentLocalPlanExecutor localPlanExecutor,
    required AiAgentLimits limits,
    required bool deterministicFinancialExplanationEnabled,
  }) : _toolRegistry = toolRegistry,
       _modelGateway = modelGateway,
       _providerEgressGuardFactory = providerEgressGuardFactory,
       _contextSanitizer = contextSanitizer,
       _toolRelevancePolicy = toolRelevancePolicy,
       _localPlanExecutor = localPlanExecutor,
       _limits = limits,
       _deterministicFinancialExplanationEnabled =
           deterministicFinancialExplanationEnabled;

  final AiToolRegistry _toolRegistry;
  final AiAgentModelGateway _modelGateway;
  final AiProviderEgressGuardFactory _providerEgressGuardFactory;
  final AiAgentContextSanitizer _contextSanitizer;
  final ToolRelevancePolicy _toolRelevancePolicy;
  final AiAgentLocalPlanExecutor _localPlanExecutor;
  final AiAgentLimits _limits;
  final bool _deterministicFinancialExplanationEnabled;

  @override
  Stream<AiAgentModelTurn> streamInitial(
    AiAgentProviderSessionContext context,
  ) async* {
    final request = context.request;
    final memory = context.memory;
    final memoryAccess = context.memoryAccess;
    final route = context.route;
    final message = request.message.trim();
    final egressGuard = _requireProviderEgressGuard(memoryAccess);
    final relevantTools = _toolRelevancePolicy.relevantDefinitions(
      route: route,
      userMessage: message,
      memory: memory,
      definitions: _toolRegistry.definitions,
    );
    final modelRequest = AiAgentModelRequest(
      userMessage: message,
      systemInstruction: context.systemInstruction,
      memoryContext:
          route.target == AssistantRouteTarget.personalFinancialAnalysis
          ? _contextSanitizer.buildMemoryContext(memory)
          : '',
      taskClass: context.taskClass,
      locale: request.locale,
      baseCurrencyCode: request.baseCurrencyCode,
      conversationHistory: _providerSafeHistory(memory, route),
      compactMemorySummary: null,
    );
    egressGuard.assertActive();
    memoryAccess.assertActive();
    final session = await _modelGateway.startSession(
      request: modelRequest,
      tools: relevantTools,
      egressGuard: egressGuard,
    );
    egressGuard.assertActive();
    memoryAccess.assertActive();
    if (session is StreamingAiAgentModelSession) {
      egressGuard.assertActive();
      memoryAccess.assertActive();
      final initialStream = session.sendInitialStream();
      egressGuard.assertActive();
      memoryAccess.assertActive();
      await for (final turn in initialStream) {
        egressGuard.assertActive();
        memoryAccess.assertActive();
        yield turn;
      }
    } else {
      egressGuard.assertActive();
      memoryAccess.assertActive();
      yield await session.sendInitial();
    }
  }

  @override
  Future<AiAgentModelTurn> run({
    required AiAgentProviderSessionContext context,
    required List<AiToolResult> successfulResults,
    required AiToolExecutionContext Function() executionContextFactory,
  }) async {
    final request = context.request;
    final memory = context.memory;
    final memoryAccess = context.memoryAccess;
    final route = context.route;
    final egressGuard = _requireProviderEgressGuard(memoryAccess);
    final relevantTools = _toolRelevancePolicy.relevantDefinitions(
      route: route,
      userMessage: request.message,
      memory: memory,
      definitions: _toolRegistry.definitions,
    );
    final modelRequest = AiAgentModelRequest(
      userMessage: request.message.trim(),
      systemInstruction: context.systemInstruction,
      memoryContext:
          route.target == AssistantRouteTarget.personalFinancialAnalysis
          ? _contextSanitizer.buildMemoryContext(memory)
          : '',
      taskClass: context.taskClass,
      locale: request.locale,
      baseCurrencyCode: request.baseCurrencyCode,
      conversationHistory: _providerSafeHistory(memory, route),
      compactMemorySummary: null,
    );
    egressGuard.assertActive();
    memoryAccess.assertActive();
    final session = await _modelGateway.startSession(
      request: modelRequest,
      tools: relevantTools,
      egressGuard: egressGuard,
    );
    egressGuard.assertActive();
    memoryAccess.assertActive();
    var totalCallCount = 0;
    final fingerprints = <String>{};
    late AiAgentModelTurn turn;
    if (_deterministicFinancialExplanationEnabled &&
        context.taskClass == ModelTask.personalFinancialAnalysis) {
      final execution = await _localPlanExecutor.execute(
        message: request.message,
        memory: memory,
        route: route,
        context: executionContextFactory(),
      );
      successfulResults.addAll(execution.successfulResults);
      totalCallCount = execution.calls.length;
      if (execution.calls.isEmpty) {
        return const AiAgentModelTurn();
      }
      egressGuard.assertActive();
      memoryAccess.assertActive();
      turn = await session.sendToolResults(execution.calls, execution.payloads);
    } else {
      turn = await session.sendInitial();
    }

    for (var round = 0; turn.toolCalls.isNotEmpty; round++) {
      if (round >= _limits.maxRounds ||
          turn.toolCalls.length > _limits.maxCallsPerRound ||
          totalCallCount + turn.toolCalls.length > _limits.maxCallsPerRequest) {
        throw const AiToolFailure(
          code: 'agent_limit_reached',
          safeMessage: 'The analysis reached its safe tool-use limit.',
        );
      }
      totalCallCount += turn.toolCalls.length;
      final payloads = <Object>[];
      for (final call in turn.toolCalls) {
        final fingerprint = '${call.name}:${jsonEncode(call.arguments)}';
        if (!fingerprints.add(fingerprint)) {
          payloads.add(
            const AiToolFailure(
              code: 'duplicate_tool_call',
              safeMessage: 'A duplicate tool call was blocked.',
            ).toModelPayload(),
          );
          continue;
        }
        try {
          final definition = _toolRegistry.definitionFor(call.name);
          if (definition == null ||
              !_toolRelevancePolicy.allows(
                route: route,
                userMessage: request.message,
                memory: memory,
                definition: definition,
              )) {
            payloads.add(
              const AiToolFailure(
                code: 'tool_not_relevant',
                safeMessage:
                    'That tool is not relevant to the current request.',
              ).toModelPayload(),
            );
            continue;
          }
          final result = await _toolRegistry.execute(
            call,
            executionContextFactory(),
          );
          successfulResults.add(result);
          payloads.add(result.toModelPayload());
        } on AiToolFailure catch (failure) {
          payloads.add(failure.toModelPayload());
        }
      }
      egressGuard.assertActive();
      memoryAccess.assertActive();
      turn = await session.sendToolResults(turn.toolCalls, payloads);
    }
    return turn;
  }

  List<AiAgentMessage> _providerSafeHistory(
    AiAgentSessionMemory memory,
    AiIntentRoute route,
  ) {
    if (route.target != AssistantRouteTarget.generalConversation) {
      return const <AiAgentMessage>[];
    }
    final messages = memory.messages.isEmpty
        ? const <AiAgentMessage>[]
        : memory.messages.sublist(0, memory.messages.length - 1);
    final safeMessages = messages
        .where((message) => !_looksPrivateOrFinancial(message.content))
        .map(
          (message) => AiAgentMessage(
            role: message.role,
            content: message.content.length <= 500
                ? message.content
                : message.content.substring(0, 500),
            createdAt: message.createdAt,
          ),
        )
        .toList(growable: false);
    return safeMessages.length <= 4
        ? safeMessages
        : safeMessages.sublist(safeMessages.length - 4);
  }

  bool _looksPrivateOrFinancial(String value) {
    final normalized = value.toLowerCase();
    if (RegExp(r'\d').hasMatch(normalized)) {
      return true;
    }
    return const <String>[
      'account',
      'balance',
      'transaction',
      'income',
      'expense',
      'budget',
      'goal',
      'salary',
      'token',
      'email',
      'phone',
      'حساب',
      'رصيد',
      'معامل',
      'دخل',
      'مصروف',
      'ميزاني',
      'هدف',
      'راتب',
    ].any(normalized.contains);
  }

  AiProviderEgressGuard _requireProviderEgressGuard(
    AiAgentMemoryAccess memoryAccess,
  ) {
    memoryAccess.assertActive();
    final guard = _providerEgressGuardFactory(memoryAccess);
    if (guard == null) {
      throw const AiProviderEgressRevokedException();
    }
    guard.assertActive();
    return guard;
  }
}
