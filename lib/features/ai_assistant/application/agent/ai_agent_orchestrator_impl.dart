import 'dart:async';

import '../../../../core/sync/application/backup_operation_fence.dart';
import 'ai_agent_conversation_response_coordinator.dart';
import 'ai_agent_local_plan_executor.dart';
import 'ai_agent_memory.dart';
import 'ai_agent_provider_session_loop.dart';
import 'ai_provider_response_safety.dart';
import 'ai_agent_response_stream_deadline.dart';
import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_agent_safety_policy.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/agent/financial_guidance_policy.dart';
import 'general_assistant_policy.dart';
import '../../domain/agent/tool_relevance_policy.dart';
import '../../domain/entities/ai_capability.dart';
import '../../domain/services/ai_intent_router.dart';

class AiAgentOrchestratorImpl implements StreamingAiAgentOrchestrator {
  const AiAgentOrchestratorImpl({
    required AiToolRegistry toolRegistry,
    required AiAgentMemoryStore memoryStore,
    required AiAgentMemoryCompactor memoryCompactor,
    required AiAgentModelRouter modelRouter,
    required AiAgentContextSanitizer contextSanitizer,
    required AiAgentResponseComposer responseComposer,
    AiAssistantCapabilities capabilities =
        const AiAssistantCapabilities.testDefaults(),
    required AiAgentModelGateway? modelGateway,
    required AiProviderEgressGuardFactory providerEgressGuardFactory,
    AiAgentSafetyPolicy safetyPolicy = const AiAgentSafetyPolicy(),
    FinancialGuidancePolicy guidancePolicy = const FinancialGuidancePolicy(),
    AiIntentRouter intentRouter = const AiIntentRouter(),
    ToolRelevancePolicy toolRelevancePolicy = const ToolRelevancePolicy(),
    AiProviderResponseSafetyPolicy responseSafetyPolicy =
        const AiProviderResponseSafetyPolicy(),
    AiAgentLimits limits = const AiAgentLimits(),
    AiToolOwnerScopeBinding? toolOwnerScope,
    AiToolOwnerScopeReader? currentToolOwnerScope,
    BackupOperationFence? operationFence,
    bool financialDataScopeVerified = false,
    bool deterministicFinancialExplanationEnabled = false,
  }) : _toolRegistry = toolRegistry,
       _memoryStore = memoryStore,
       _memoryCompactor = memoryCompactor,
       _modelRouter = modelRouter,
       _contextSanitizer = contextSanitizer,
       _responseComposer = responseComposer,
       _capabilities = capabilities,
       _modelGateway = modelGateway,
       _providerEgressGuardFactory = providerEgressGuardFactory,
       _safetyPolicy = safetyPolicy,
       _guidancePolicy = guidancePolicy,
       _intentRouter = intentRouter,
       _toolRelevancePolicy = toolRelevancePolicy,
       _responseSafetyPolicy = responseSafetyPolicy,
       _limits = limits,
       _toolOwnerScope = toolOwnerScope,
       _currentToolOwnerScope = currentToolOwnerScope,
       _operationFence = operationFence,
       _financialDataScopeVerified = financialDataScopeVerified,
       _deterministicFinancialExplanationEnabled =
           deterministicFinancialExplanationEnabled;

  final AiToolRegistry _toolRegistry;
  final AiAgentMemoryStore _memoryStore;
  final AiAgentMemoryCompactor _memoryCompactor;
  final AiAgentModelRouter _modelRouter;
  final AiAgentContextSanitizer _contextSanitizer;
  final AiAgentResponseComposer _responseComposer;
  final AiAssistantCapabilities _capabilities;
  final AiAgentModelGateway? _modelGateway;
  final AiProviderEgressGuardFactory _providerEgressGuardFactory;
  final AiAgentSafetyPolicy _safetyPolicy;
  final FinancialGuidancePolicy _guidancePolicy;
  final AiIntentRouter _intentRouter;
  final ToolRelevancePolicy _toolRelevancePolicy;
  final AiProviderResponseSafetyPolicy _responseSafetyPolicy;
  final AiAgentLimits _limits;
  final AiToolOwnerScopeBinding? _toolOwnerScope;
  final AiToolOwnerScopeReader? _currentToolOwnerScope;
  final BackupOperationFence? _operationFence;
  final bool _financialDataScopeVerified;
  final bool _deterministicFinancialExplanationEnabled;

  AiAgentLocalPlanExecutor get _localPlanExecutor =>
      DefaultAiAgentLocalPlanExecutor(
        toolRegistry: _toolRegistry,
        toolRelevancePolicy: _toolRelevancePolicy,
        limits: _limits,
      );

  AiAgentProviderSessionLoop get _providerSessionLoop =>
      DefaultAiAgentProviderSessionLoop(
        toolRegistry: _toolRegistry,
        modelGateway: _modelGateway!,
        providerEgressGuardFactory: _providerEgressGuardFactory,
        contextSanitizer: _contextSanitizer,
        toolRelevancePolicy: _toolRelevancePolicy,
        localPlanExecutor: _localPlanExecutor,
        limits: _limits,
        deterministicFinancialExplanationEnabled:
            _deterministicFinancialExplanationEnabled,
      );

  AiAgentResponseStreamDeadline get _responseStreamDeadline =>
      const DefaultAiAgentResponseStreamDeadline();

  AiAgentConversationResponseCoordinator get _conversationResponseCoordinator =>
      DefaultAiAgentConversationResponseCoordinator(
        toolRegistry: _toolRegistry,
        memoryStore: _memoryStore,
        memoryCompactor: _memoryCompactor,
        responseComposer: _responseComposer,
        capabilities: _capabilities,
        safetyPolicy: _safetyPolicy,
        guidancePolicy: _guidancePolicy,
        toolRelevancePolicy: _toolRelevancePolicy,
        responseSafetyPolicy: _responseSafetyPolicy,
      );

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    final directResponse = _directResponseWithoutOwnerState(request);
    if (directResponse != null) return directResponse;
    final lease = _tryAcquireMemoryLease();
    if (lease == null) {
      return _conversationResponseCoordinator.responseForPolicy(
        policy: AiAgentConversationPolicyResponse.ownerScopeUnavailable,
        request: request,
      );
    }
    try {
      return await _respond(request, lease.access).timeout(
        _limits.requestTimeout,
        onTimeout: () => _conversationResponseCoordinator.responseForPolicy(
          policy: AiAgentConversationPolicyResponse.providerTimedOut,
          request: request,
        ),
      );
    } on BackupWriterCancelledException {
      return _conversationResponseCoordinator.responseForPolicy(
        policy: AiAgentConversationPolicyResponse.ownerScopeUnavailable,
        request: request,
      );
    } on AiAgentMemoryOwnerBindingChangedException {
      return _conversationResponseCoordinator.responseForPolicy(
        policy: AiAgentConversationPolicyResponse.ownerScopeUnavailable,
        request: request,
      );
    } finally {
      lease.release();
    }
  }

  @override
  Stream<AiAgentResponse> respondStream(AiAgentRequest request) async* {
    final directResponse = _directResponseWithoutOwnerState(request);
    if (directResponse != null) {
      yield directResponse;
      return;
    }
    final lease = _tryAcquireMemoryLease();
    if (lease == null) {
      yield _conversationResponseCoordinator.responseForPolicy(
        policy: AiAgentConversationPolicyResponse.ownerScopeUnavailable,
        request: request,
      );
      return;
    }
    try {
      yield* _responseStreamDeadline.enforce(
        _respondStream(request, lease.access),
        timeout: _limits.requestTimeout,
        timeoutResponse: _conversationResponseCoordinator.responseForPolicy(
          policy: AiAgentConversationPolicyResponse.providerTimedOut,
          request: request,
        ),
      );
    } on TimeoutException {
      yield _conversationResponseCoordinator.responseForPolicy(
        policy: AiAgentConversationPolicyResponse.providerTimedOut,
        request: request,
      );
    } on BackupWriterCancelledException {
      yield _conversationResponseCoordinator.responseForPolicy(
        policy: AiAgentConversationPolicyResponse.ownerScopeUnavailable,
        request: request,
      );
    } on AiAgentMemoryOwnerBindingChangedException {
      yield _conversationResponseCoordinator.responseForPolicy(
        policy: AiAgentConversationPolicyResponse.ownerScopeUnavailable,
        request: request,
      );
    } finally {
      lease.release();
    }
  }

  Stream<AiAgentResponse> _respondStream(
    AiAgentRequest request,
    AiAgentMemoryAccess memoryAccess,
  ) async* {
    final message = request.message.trim();
    final route = _intentRouter.route(message);
    final unavailable = _conversationResponseCoordinator
        .capabilityUnavailableResponse(route: route, request: request);
    if (unavailable != null) {
      yield unavailable;
      return;
    }
    final canStream =
        message.isNotEmpty &&
        !_safetyPolicy.isBlocked(message) &&
        _modelGateway != null &&
        (route.target == AssistantRouteTarget.generalConversation ||
            route.target == AssistantRouteTarget.groundedCurrentKnowledge);
    if (!canStream) {
      yield await _respond(request, memoryAccess);
      return;
    }

    final memory = await _conversationResponseCoordinator.beginTurn(
      memoryAccess: memoryAccess,
      message: message,
    );
    final taskClass = _modelRouter.classify(
      message,
      allowComplexPlanning: request.allowComplexPlanning,
      route: route,
    );
    AiAgentModelTurn? finalTurn;
    var lastPartialLength = 0;
    try {
      final turns = _providerSessionLoop.streamInitial(
        AiAgentProviderSessionContext(
          request: request,
          memory: memory,
          memoryAccess: memoryAccess,
          taskClass: taskClass,
          route: route,
          systemInstruction: _systemInstructionFor(route),
        ),
      );
      await for (final turn in turns) {
        finalTurn = turn;
        final partial = _conversationResponseCoordinator
            .progressivePartialResponse(
              route: route,
              turn: turn,
              lastPartialLength: lastPartialLength,
            );
        if (partial != null) {
          lastPartialLength = partial.message.length;
          yield partial;
        }
      }
    } on Object catch (error) {
      finalTurn = AiAgentModelTurn(
        warnings: <String>[
          _conversationResponseCoordinator.safeModelErrorCode(error),
        ],
      );
    }

    final response = _conversationResponseCoordinator.composeFinalResponse(
      route: route,
      modelTurn: finalTurn,
      results: const <AiToolResult>[],
      locale: request.locale,
      message: message,
    );
    await _conversationResponseCoordinator.completeTurn(
      memory: memory,
      response: response,
      memoryAccess: memoryAccess,
      message: message,
      results: const <AiToolResult>[],
      completion: AiAgentConversationCompletion.preserveActiveContext,
    );
    yield response;
  }

  Future<AiAgentResponse> _respond(
    AiAgentRequest request,
    AiAgentMemoryAccess memoryAccess,
  ) async {
    final message = request.message.trim();
    if (message.isEmpty) {
      return _conversationResponseCoordinator.responseForPolicy(
        policy: AiAgentConversationPolicyResponse.emptyMessage,
        request: request,
      );
    }
    if (_safetyPolicy.isBlocked(message)) {
      return _conversationResponseCoordinator.responseForPolicy(
        policy: AiAgentConversationPolicyResponse.safetyRefusal,
        request: request,
      );
    }
    final route = _intentRouter.route(message);
    final unavailable = _conversationResponseCoordinator
        .capabilityUnavailableResponse(route: route, request: request);
    if (unavailable != null) return unavailable;
    if (route.target == AssistantRouteTarget.blocked) {
      return _conversationResponseCoordinator.responseForPolicy(
        policy: AiAgentConversationPolicyResponse.blockedFinancialMutation,
        request: request,
      );
    }
    if (route.target == AssistantRouteTarget.personalFinancialAnalysis &&
        _guidancePolicy.isHighRiskAdviceRequest(message)) {
      return _conversationResponseCoordinator.responseForPolicy(
        policy: AiAgentConversationPolicyResponse.highRiskFinancialAdvice,
        request: request,
      );
    }

    final memory = await _conversationResponseCoordinator.beginTurn(
      memoryAccess: memoryAccess,
      message: message,
    );
    if (route.target == AssistantRouteTarget.appNavigation) {
      final response = await _conversationResponseCoordinator
          .executeApprovedNavigation(
            request: request,
            route: route,
            memory: memory,
            executeTool: (call) =>
                _toolRegistry.execute(call, _executionContext(request)),
          );
      await _conversationResponseCoordinator.completeTurn(
        memory: memory,
        response: response,
        memoryAccess: memoryAccess,
        message: message,
        results: const <AiToolResult>[],
        completion: AiAgentConversationCompletion.preserveActiveContext,
      );
      return response;
    }
    final taskClass = _modelRouter.classify(
      message,
      allowComplexPlanning: request.allowComplexPlanning,
      route: route,
    );

    final localResponse = _conversationResponseCoordinator.localResponse(
      route: route,
      request: request,
    );
    if (localResponse != null) {
      await _conversationResponseCoordinator.completeTurn(
        memory: memory,
        response: localResponse,
        memoryAccess: memoryAccess,
        message: message,
        results: const <AiToolResult>[],
        completion: AiAgentConversationCompletion.preserveActiveContext,
      );
      return localResponse;
    }

    final results = <AiToolResult>[];
    AiAgentModelTurn? modelTurn;

    if (_modelGateway == null) {
      if (route.target == AssistantRouteTarget.personalFinancialAnalysis) {
        results.addAll(
          await _executeLocalPlan(message, memory, request, route),
        );
      }
    } else {
      try {
        modelTurn = await _providerSessionLoop.run(
          context: AiAgentProviderSessionContext(
            request: request,
            memory: memory,
            memoryAccess: memoryAccess,
            taskClass: taskClass,
            route: route,
            systemInstruction: _systemInstructionFor(route),
          ),
          successfulResults: results,
          executionContextFactory: () => _executionContext(request),
        );
      } on Object catch (error) {
        if (route.target != AssistantRouteTarget.personalFinancialAnalysis) {
          modelTurn = AiAgentModelTurn(
            warnings: <String>[
              _conversationResponseCoordinator.safeModelErrorCode(error),
            ],
          );
        }
        if (route.target == AssistantRouteTarget.personalFinancialAnalysis) {
          results.addAll(
            await _executeLocalPlan(message, memory, request, route),
          );
        }
      }
    }

    if (taskClass == ModelTask.personalFinancialAnalysis && results.isEmpty) {
      results.addAll(await _executeLocalPlan(message, memory, request, route));
      if (results.isNotEmpty) {
        modelTurn = null;
      }
    }

    final response = _conversationResponseCoordinator.composeFinalResponse(
      route: route,
      modelTurn: modelTurn,
      results: results,
      locale: request.locale,
      message: message,
    );
    await _conversationResponseCoordinator.completeTurn(
      memory: memory,
      response: response,
      memoryAccess: memoryAccess,
      message: message,
      results: results,
      completion: AiAgentConversationCompletion.updateActiveContext,
    );
    return response;
  }

  Future<List<AiToolResult>> _executeLocalPlan(
    String message,
    AiAgentSessionMemory memory,
    AiAgentRequest request,
    AiIntentRoute route,
  ) async {
    final execution = await _localPlanExecutor.execute(
      message: message,
      memory: memory,
      route: route,
      context: _executionContext(request),
    );
    return execution.successfulResults;
  }

  String _systemInstructionFor(AiIntentRoute route) {
    return switch (route.target) {
      AssistantRouteTarget.groundedCurrentKnowledge =>
        GroundedKnowledgePolicy.systemInstruction,
      AssistantRouteTarget.personalFinancialAnalysis =>
        FinancialGuidancePolicy.systemInstruction,
      _ => GeneralAssistantPolicy.systemInstruction,
    };
  }

  AiToolExecutionContext _executionContext(AiAgentRequest request) =>
      AiToolExecutionContext(
        locale: request.locale,
        baseCurrencyCode: request.baseCurrencyCode,
        now: DateTime.now().toUtc(),
        maxSearchResults: _limits.maxSearchResults,
        ownerScope: _toolOwnerScope,
        financialDataScopeVerified: _financialDataScopeVerified,
      );

  AiAgentMemoryOwnerLease? _tryAcquireMemoryLease() {
    return AiAgentMemoryOwnerLease.tryAcquire(
      binding: _toolOwnerScope,
      currentOwnerScope: _currentToolOwnerScope,
      operationFence: _operationFence,
    );
  }

  AiAgentResponse? _directResponseWithoutOwnerState(AiAgentRequest request) {
    final message = request.message.trim();
    if (message.isEmpty) return null;
    final safetyBlocked = _safetyPolicy.isBlocked(message);
    if (safetyBlocked) {
      return _conversationResponseCoordinator.responseWithoutOwnerState(
        request: request,
        route: null,
        safetyBlocked: true,
      );
    }
    final route = _intentRouter.route(message);
    return _conversationResponseCoordinator.responseWithoutOwnerState(
      request: request,
      route: route,
      safetyBlocked: false,
    );
  }

  @override
  Future<void> clearConversation() async {
    final lease = _tryAcquireMemoryLease();
    try {
      if (lease != null) {
        await _conversationResponseCoordinator.clearMemory(lease.access);
      }
    } on BackupWriterCancelledException {
      // Account deletion or a restored quarantine owns this scope.
    } on AiAgentMemoryOwnerBindingChangedException {
      // An old owner/session must not clear the current owner's memory.
    } finally {
      lease?.release();
    }
    final gateway = _modelGateway;
    if (gateway is ResettableAiAgentModelGateway) {
      gateway.clearSessions();
    }
  }

  @override
  Future<void> startNewConversation() => clearConversation();
}
