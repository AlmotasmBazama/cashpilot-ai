import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_agent_safety_policy.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/agent/assistant_navigation_policy.dart';
import '../../domain/agent/financial_guidance_policy.dart';
import '../../domain/agent/tool_relevance_policy.dart';
import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_intent.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';
import '../../domain/services/ai_intent_router.dart';
import 'ai_provider_response_safety.dart';
import 'general_assistant_policy.dart';

enum AiAgentConversationPolicyResponse {
  emptyMessage,
  safetyRefusal,
  blockedFinancialMutation,
  highRiskFinancialAdvice,
  ownerScopeUnavailable,
  providerTimedOut,
}

enum AiAgentConversationCompletion {
  preserveActiveContext,
  updateActiveContext,
}

typedef AiAgentNavigationToolExecutor =
    Future<AiToolResult> Function(AiAgentToolCall call);

/// Owns owner-scoped conversation state and the policy that turns routed
/// outcomes into user-visible assistant responses.
///
/// Intent/model routing and every actual tool invocation remain with the
/// orchestrator. The navigation callback is deliberately execution-only so
/// this coordinator cannot widen the caller's owner-scoped tool context.
abstract interface class AiAgentConversationResponseCoordinator {
  Future<AiAgentSessionMemory> beginTurn({
    required AiAgentMemoryAccess memoryAccess,
    required String message,
  });

  Future<void> completeTurn({
    required AiAgentSessionMemory memory,
    required AiAgentResponse response,
    required AiAgentMemoryAccess memoryAccess,
    required String message,
    required List<AiToolResult> results,
    required AiAgentConversationCompletion completion,
  });

  Future<void> clearMemory(AiAgentMemoryAccess memoryAccess);

  AiAgentResponse responseForPolicy({
    required AiAgentConversationPolicyResponse policy,
    required AiAgentRequest request,
  });

  AiAgentResponse? responseWithoutOwnerState({
    required AiAgentRequest request,
    required AiIntentRoute? route,
    required bool safetyBlocked,
  });

  AiAgentResponse? capabilityUnavailableResponse({
    required AiIntentRoute route,
    required AiAgentRequest request,
  });

  AiAgentResponse? localResponse({
    required AiIntentRoute route,
    required AiAgentRequest request,
  });

  AiAgentResponse? progressivePartialResponse({
    required AiIntentRoute route,
    required AiAgentModelTurn turn,
    required int lastPartialLength,
  });

  AiAgentResponse composeFinalResponse({
    required AiIntentRoute route,
    required AiAgentModelTurn? modelTurn,
    required List<AiToolResult> results,
    required String locale,
    required String message,
  });

  Future<AiAgentResponse> executeApprovedNavigation({
    required AiAgentRequest request,
    required AiIntentRoute route,
    required AiAgentSessionMemory memory,
    required AiAgentNavigationToolExecutor executeTool,
  });

  String safeModelErrorCode(Object error);
}

final class DefaultAiAgentConversationResponseCoordinator
    implements AiAgentConversationResponseCoordinator {
  const DefaultAiAgentConversationResponseCoordinator({
    required AiToolRegistry toolRegistry,
    required AiAgentMemoryStore memoryStore,
    required AiAgentMemoryCompactor memoryCompactor,
    required AiAgentResponseComposer responseComposer,
    required AiAssistantCapabilities capabilities,
    required AiAgentSafetyPolicy safetyPolicy,
    required FinancialGuidancePolicy guidancePolicy,
    required ToolRelevancePolicy toolRelevancePolicy,
    required AiProviderResponseSafetyPolicy responseSafetyPolicy,
  }) : _toolRegistry = toolRegistry,
       _memoryStore = memoryStore,
       _memoryCompactor = memoryCompactor,
       _responseComposer = responseComposer,
       _capabilities = capabilities,
       _safetyPolicy = safetyPolicy,
       _guidancePolicy = guidancePolicy,
       _toolRelevancePolicy = toolRelevancePolicy,
       _responseSafetyPolicy = responseSafetyPolicy;

  final AiToolRegistry _toolRegistry;
  final AiAgentMemoryStore _memoryStore;
  final AiAgentMemoryCompactor _memoryCompactor;
  final AiAgentResponseComposer _responseComposer;
  final AiAssistantCapabilities _capabilities;
  final AiAgentSafetyPolicy _safetyPolicy;
  final FinancialGuidancePolicy _guidancePolicy;
  final ToolRelevancePolicy _toolRelevancePolicy;
  final AiProviderResponseSafetyPolicy _responseSafetyPolicy;

  @override
  Future<AiAgentSessionMemory> beginTurn({
    required AiAgentMemoryAccess memoryAccess,
    required String message,
  }) async {
    final memory = await _freshMemory(memoryAccess);
    return _memoryCompactor.append(
      memory,
      AiAgentMessage(
        role: AiAgentMessageRole.user,
        content: message,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> completeTurn({
    required AiAgentSessionMemory memory,
    required AiAgentResponse response,
    required AiAgentMemoryAccess memoryAccess,
    required String message,
    required List<AiToolResult> results,
    required AiAgentConversationCompletion completion,
  }) async {
    final contextualMemory = switch (completion) {
      AiAgentConversationCompletion.preserveActiveContext => memory,
      AiAgentConversationCompletion.updateActiveContext => _updateActiveContext(
        memory,
        message,
        results,
      ),
    };
    final updated = _memoryCompactor.append(
      contextualMemory,
      AiAgentMessage(
        role: AiAgentMessageRole.assistant,
        content: response.message,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    await _memoryStore.save(updated, access: memoryAccess);
  }

  @override
  Future<void> clearMemory(AiAgentMemoryAccess memoryAccess) {
    return _memoryStore.clear(access: memoryAccess);
  }

  @override
  AiAgentResponse responseForPolicy({
    required AiAgentConversationPolicyResponse policy,
    required AiAgentRequest request,
  }) {
    final isArabic = _isArabic(request.locale, request.message);
    return switch (policy) {
      AiAgentConversationPolicyResponse.emptyMessage => AiAgentResponse(
        kind: AiAgentResponseKind.clarification,
        message: isArabic
            ? 'اكتب سؤالك أو صف الإجراء اللي تبي نجهّز له مسودة.'
            : 'Enter a question or describe the action you want drafted.',
      ),
      AiAgentConversationPolicyResponse.safetyRefusal => AiAgentResponse(
        kind: AiAgentResponseKind.refusal,
        message: _safetyPolicy.refusal(isArabic: isArabic),
      ),
      AiAgentConversationPolicyResponse.blockedFinancialMutation => AiAgentResponse(
        kind: AiAgentResponseKind.refusal,
        turnKind: AssistantTurnKind.blocked,
        message: isArabic
            ? 'ما نقدرش نحذف أو نغيّر بيانات مالية بهذا الطلب. استخدم شاشة العنصر المخصص وراجع الإجراء يدوياً.'
            : 'I cannot delete or destructively change financial data from this request. Use the relevant item screen and review the action manually.',
      ),
      AiAgentConversationPolicyResponse.highRiskFinancialAdvice =>
        AiAgentResponse(
          kind: AiAgentResponseKind.refusal,
          message: _guidancePolicy.refusal(isArabic: isArabic),
        ),
      AiAgentConversationPolicyResponse.ownerScopeUnavailable =>
        AiAgentResponse(
          kind: AiAgentResponseKind.failure,
          turnKind: AssistantTurnKind.failure,
          message: GeneralAssistantPolicy.unavailableForReason(
            AiUnavailableReason.ownerScopeNotReady,
            locale: request.locale,
          ),
          warnings: const <String>['ownerScopeNotReady'],
          retryable: true,
        ),
      AiAgentConversationPolicyResponse.providerTimedOut => AiAgentResponse(
        kind: AiAgentResponseKind.failure,
        turnKind: AssistantTurnKind.failure,
        message: GeneralAssistantPolicy.unavailableForReason(
          AiUnavailableReason.providerTimedOut,
          locale: request.locale,
        ),
        warnings: <String>[AiUnavailableReason.providerTimedOut.name],
        retryable: true,
      ),
    };
  }

  @override
  AiAgentResponse? responseWithoutOwnerState({
    required AiAgentRequest request,
    required AiIntentRoute? route,
    required bool safetyBlocked,
  }) {
    final isArabic = _isArabic(request.locale, request.message);
    if (safetyBlocked) {
      return AiAgentResponse(
        kind: AiAgentResponseKind.refusal,
        turnKind: AssistantTurnKind.blocked,
        message: _safetyPolicy.refusal(isArabic: isArabic),
      );
    }
    if (route == null) return null;
    if (route.target != AssistantRouteTarget.directConversation &&
        route.target != AssistantRouteTarget.financialRecordOffer) {
      return null;
    }
    if (route.target == AssistantRouteTarget.directConversation &&
        !_capabilities.directConversationAvailable) {
      return capabilityUnavailableResponse(route: route, request: request);
    }
    return localResponse(route: route, request: request);
  }

  @override
  AiAgentResponse? capabilityUnavailableResponse({
    required AiIntentRoute route,
    required AiAgentRequest request,
  }) {
    final unavailable = switch (route.target) {
      AssistantRouteTarget.directConversation =>
        !_capabilities.directConversationAvailable,
      AssistantRouteTarget.generalConversation =>
        !_capabilities.generalConversationAvailable,
      AssistantRouteTarget.groundedCurrentKnowledge =>
        !_capabilities.currentKnowledgeAvailable,
      AssistantRouteTarget.personalFinancialAnalysis =>
        !_capabilities.personalFinancialAnalysisAvailable,
      AssistantRouteTarget.receiptAction =>
        !_capabilities.receiptVisionAvailable,
      AssistantRouteTarget.appNavigation => !_capabilities.navigationAvailable,
      AssistantRouteTarget.financialRecordOffer ||
      AssistantRouteTarget.financialAction ||
      AssistantRouteTarget.blocked => false,
    };
    if (!unavailable) return null;

    final isArabic = _isArabic(request.locale, request.message);
    final reason = switch (route.target) {
      AssistantRouteTarget.personalFinancialAnalysis =>
        AiUnavailableReason.financialAccessDisabled,
      AssistantRouteTarget.receiptAction =>
        AiUnavailableReason.receiptVisionUnavailable,
      AssistantRouteTarget.appNavigation =>
        AiUnavailableReason.financialAccessDisabled,
      _ =>
        _capabilities.unavailableReason ??
            AiUnavailableReason.unknownTemporaryFailure,
    };
    final message = switch (route.target) {
      AssistantRouteTarget.personalFinancialAnalysis =>
        GeneralAssistantPolicy.financialAnalysisUnavailable(
          locale: request.locale,
          generalConversationAvailable:
              _capabilities.generalConversationAvailable,
        ),
      AssistantRouteTarget.groundedCurrentKnowledge =>
        GroundedKnowledgePolicy.unavailable(isArabic: isArabic),
      AssistantRouteTarget.receiptAction =>
        GeneralAssistantPolicy.receiptVisionUnavailable(locale: request.locale),
      AssistantRouteTarget.appNavigation =>
        GeneralAssistantPolicy.navigationUnavailable(locale: request.locale),
      _ => GeneralAssistantPolicy.unavailableForReason(
        reason,
        locale: request.locale,
      ),
    };
    return AiAgentResponse(
      kind: AiAgentResponseKind.failure,
      turnKind: AssistantTurnKind.failure,
      message: message,
      warnings: <String>[reason.name],
      retryable: switch (route.target) {
        AssistantRouteTarget.generalConversation ||
        AssistantRouteTarget.directConversation => _capabilities.retryable,
        AssistantRouteTarget.groundedCurrentKnowledge =>
          _capabilities.unavailableReason == null
              ? false
              : _capabilities.retryable,
        _ => false,
      },
    );
  }

  @override
  AiAgentResponse? localResponse({
    required AiIntentRoute route,
    required AiAgentRequest request,
  }) {
    final isArabic = _isArabic(request.locale, request.message);
    if (route.target == AssistantRouteTarget.directConversation) {
      return AiAgentResponse(
        kind: AiAgentResponseKind.answer,
        turnKind: AssistantTurnKind.directConversation,
        message: GeneralAssistantPolicy.localDirectReply(
          intent: route.intent,
          locale: request.locale,
          capabilities: _capabilities,
        ),
      );
    }
    if (route.target == AssistantRouteTarget.financialRecordOffer) {
      final message = switch (route.recordOfferDecision) {
        FinancialRecordOfferDecision.accept =>
          isArabic
              ? 'تمام. قبل تجهيز المسودة، بنطلب منك أي تفاصيل مالية ناقصة. وبعد المعاينة يبقى لازم تضغط تأكيد.'
              : 'Okay. Before preparing the draft, I will ask for any missing financial details. You will still need to explicitly confirm the preview.',
        FinancialRecordOfferDecision.decline =>
          isArabic
              ? 'تمام، مش حنسجلها وما صار أي تغيير مالي.'
              : 'Okay, I will not record it. No financial change was made.',
        FinancialRecordOfferDecision.none => switch (route.intent) {
          AiIntent.createIncome =>
            isArabic
                ? 'هل تبي تسجل هذا كدخل في CashPilot؟ ما يصير أي تغيير مالي إلا بعد ما تكمل التفاصيل وتأكد المعاينة.'
                : 'Would you like to record this as income in CashPilot? No financial change will be made until you complete the details and explicitly confirm the preview.',
          AiIntent.createExpense =>
            isArabic
                ? 'هل تبي تسجل هذا كمصروف في CashPilot؟ ما يصير أي تغيير مالي إلا بعد ما تكمل التفاصيل وتأكد المعاينة.'
                : 'Would you like to record this as an expense in CashPilot? No financial change will be made until you complete the details and explicitly confirm the preview.',
          _ =>
            isArabic
                ? 'هل تبي تسجل هذه الحركة المالية في CashPilot؟ بنطلب منك نوعها وأي تفاصيل ناقصة قبل المعاينة والتأكيد.'
                : 'Would you like to record this financial event in CashPilot? I will ask for its type and any missing details before preview and confirmation.',
        },
      };
      return AiAgentResponse(
        kind: AiAgentResponseKind.clarification,
        turnKind: AssistantTurnKind.clarification,
        message: message,
      );
    }
    if (route.target == AssistantRouteTarget.financialAction) {
      return AiAgentResponse(
        kind: AiAgentResponseKind.clarification,
        turnKind: AssistantTurnKind.clarification,
        message: isArabic
            ? 'تعذّر تجهيز مسودة الإجراء من هذه المحادثة. لم يتم تنفيذ أي تغيير مالي.'
            : 'The action draft is unavailable in this conversation. No financial change was executed.',
      );
    }
    if (route.target == AssistantRouteTarget.receiptAction) {
      return AiAgentResponse(
        kind: AiAgentResponseKind.navigation,
        turnKind: AssistantTurnKind.receiptAction,
        message: isArabic
            ? 'نفتح مساحة مراجعة الإيصال. راجع البيانات المستخرجة قبل حفظ أي معاملة.'
            : 'Opening receipt review. Check the extracted details before saving any transaction.',
      );
    }
    return null;
  }

  @override
  AiAgentResponse? progressivePartialResponse({
    required AiIntentRoute route,
    required AiAgentModelTurn turn,
    required int lastPartialLength,
  }) {
    if (route.target != AssistantRouteTarget.generalConversation) return null;
    final text = turn.text?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    final boundaries = RegExp(r'[.!?؟](?:\s|$)|\n').allMatches(text);
    if (boundaries.isEmpty) return null;
    final safeBatch = text.substring(0, boundaries.last.end).trim();
    if (safeBatch.length <= lastPartialLength ||
        safeBatch.length - lastPartialLength < 48) {
      return null;
    }
    if (_responseSafetyPolicy.hasUnverifiedMutationClaim(safeBatch)) {
      return null;
    }
    return AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      turnKind: AssistantTurnKind.directConversation,
      message: safeBatch,
      isPartial: true,
    );
  }

  @override
  AiAgentResponse composeFinalResponse({
    required AiIntentRoute route,
    required AiAgentModelTurn? modelTurn,
    required List<AiToolResult> results,
    required String locale,
    required String message,
  }) {
    final isArabic = _isArabic(locale, message);
    if (route.target == AssistantRouteTarget.groundedCurrentKnowledge) {
      final providerText = modelTurn?.text?.trim();
      final hasUnverifiedMutationClaim =
          providerText?.isNotEmpty == true &&
          _responseSafetyPolicy.hasUnverifiedMutationClaim(providerText!);
      final grounded =
          modelTurn != null &&
          modelTurn.warnings.isEmpty &&
          modelTurn.sources.isNotEmpty &&
          providerText?.isNotEmpty == true &&
          !hasUnverifiedMutationClaim;
      if (!grounded) {
        return AiAgentResponse(
          kind: AiAgentResponseKind.failure,
          turnKind: AssistantTurnKind.failure,
          message: GroundedKnowledgePolicy.unavailable(isArabic: isArabic),
          warnings: modelTurn?.warnings.isNotEmpty == true
              ? modelTurn!.warnings
              : const <String>['grounding_unavailable'],
        );
      }
      return AiAgentResponse(
        kind: AiAgentResponseKind.answer,
        turnKind: AssistantTurnKind.groundedKnowledge,
        message: providerText!,
        sources: modelTurn.sources,
        searchEntryPointRenderedContent:
            modelTurn.searchEntryPointRenderedContent,
        responseDate: modelTurn.responseDate,
        warnings: modelTurn.warnings,
      );
    }

    if (route.target == AssistantRouteTarget.generalConversation) {
      final providerText = modelTurn?.text?.trim();
      final hasUnverifiedMutationClaim =
          providerText?.isNotEmpty == true &&
          _responseSafetyPolicy.hasUnverifiedMutationClaim(providerText!);
      final modelText = hasUnverifiedMutationClaim ? null : providerText;
      final offline = GeneralAssistantPolicy.supportedOfflineAnswer(
        message,
        locale: locale,
      );
      final failureReason = _availabilityReasonFromWarnings(
        modelTurn?.warnings ?? const <String>[],
      );
      final hasAnswer = modelText?.isNotEmpty == true || offline != null;
      return AiAgentResponse(
        kind: hasAnswer
            ? AiAgentResponseKind.answer
            : AiAgentResponseKind.failure,
        turnKind: hasAnswer
            ? AssistantTurnKind.directConversation
            : AssistantTurnKind.failure,
        message: modelText?.isNotEmpty == true
            ? modelText!
            : offline ??
                  GeneralAssistantPolicy.unavailableForReason(
                    failureReason ??
                        _capabilities.unavailableReason ??
                        AiUnavailableReason.unknownTemporaryFailure,
                    locale: locale,
                  ),
        warnings: <String>[
          ...?modelTurn?.warnings,
          if (hasUnverifiedMutationClaim) 'unverified_mutation_claim_blocked',
          if (!hasAnswer && failureReason != null) failureReason.name,
        ],
        retryable: hasAnswer
            ? null
            : isAiRequestFailureRetryable(
                failureReason ??
                    _capabilities.unavailableReason ??
                    AiUnavailableReason.unknownTemporaryFailure,
              ),
      );
    }

    if (route.target == AssistantRouteTarget.personalFinancialAnalysis) {
      final providerText = modelTurn?.text;
      final safeModelText =
          providerText?.trim().isNotEmpty == true &&
              _responseSafetyPolicy.hasUnverifiedMutationClaim(providerText!)
          ? null
          : providerText;
      final base = _responseComposer.compose(
        modelText: safeModelText,
        results: results,
        locale: locale,
      );
      return AiAgentResponse(
        kind: base.kind,
        turnKind: AssistantTurnKind.personalFinancialAnalysis,
        message: base.message,
        evidence: base.evidence,
        followUpPrompts: base.followUpPrompts,
        executedToolNames: base.executedToolNames,
        navigationPath: base.navigationPath,
        actionDraft: base.actionDraft,
        isPartial: base.isPartial,
      );
    }

    return AiAgentResponse(
      kind: AiAgentResponseKind.failure,
      turnKind: AssistantTurnKind.failure,
      message: GeneralAssistantPolicy.unavailable(locale: locale),
    );
  }

  @override
  Future<AiAgentResponse> executeApprovedNavigation({
    required AiAgentRequest request,
    required AiIntentRoute route,
    required AiAgentSessionMemory memory,
    required AiAgentNavigationToolExecutor executeTool,
  }) async {
    final isArabic = _isArabic(request.locale, request.message);
    final toolName = route.navigationToolId;
    final expectedPath = AssistantNavigationPolicy.approvedToolPaths[toolName];
    final definition = toolName == null
        ? null
        : _toolRegistry.definitionFor(toolName);
    if (toolName == null ||
        expectedPath == null ||
        definition == null ||
        definition.permission != AiToolPermission.navigate ||
        !_toolRelevancePolicy.allows(
          route: route,
          userMessage: request.message,
          memory: memory,
          definition: definition,
        )) {
      return AiAgentResponse(
        kind: AiAgentResponseKind.failure,
        turnKind: AssistantTurnKind.failure,
        message: isArabic
            ? 'تعذّر فتح الشاشة المطلوبة بأمان.'
            : 'The requested screen could not be opened safely.',
      );
    }

    try {
      final result = await executeTool(
        AiAgentToolCall(
          id: 'local-navigation',
          name: toolName,
          arguments: const <String, Object?>{},
        ),
      );
      if (result.toolName != toolName ||
          result.navigationPath != expectedPath ||
          result.data['navigationApproved'] != true) {
        throw const AiToolFailure(
          code: 'navigation_result_invalid',
          safeMessage: 'The navigation result did not pass local validation.',
        );
      }
      return AiAgentResponse(
        kind: AiAgentResponseKind.navigation,
        turnKind: AssistantTurnKind.appNavigation,
        message: isArabic
            ? 'جارٍ فتح الشاشة المطلوبة.'
            : 'Opening the requested CashPilot screen.',
        executedToolNames: <String>[toolName],
        navigationPath: expectedPath,
      );
    } on AiToolFailure {
      return AiAgentResponse(
        kind: AiAgentResponseKind.failure,
        turnKind: AssistantTurnKind.failure,
        message: isArabic
            ? 'تعذّر فتح الشاشة المطلوبة بأمان.'
            : 'The requested screen could not be opened safely.',
      );
    }
  }

  @override
  String safeModelErrorCode(Object error) {
    if (error is AiProviderEgressRevokedException) {
      return AiUnavailableReason.ownerScopeNotReady.name;
    }
    if (error is AiGatewayException) {
      return switch (error.code) {
        AiGatewayFailureCode.groqNotConfigured => 'groqNotConfigured',
        AiGatewayFailureCode.groqAuthenticationFailed =>
          'groqAuthenticationFailed',
        AiGatewayFailureCode.groqModelUnavailable => 'groqModelUnavailable',
        AiGatewayFailureCode.groqRateLimited => 'groqRateLimited',
        AiGatewayFailureCode.groqRequestTimedOut => 'groqRequestTimedOut',
        AiGatewayFailureCode.groqStreamTimedOut => 'groqStreamTimedOut',
        AiGatewayFailureCode.groqMalformedResponse => 'groqMalformedResponse',
        AiGatewayFailureCode.groqUpstreamUnavailable =>
          'groqUpstreamUnavailable',
        AiGatewayFailureCode.authenticationNotReady =>
          'authentication_not_ready',
        AiGatewayFailureCode.appCheckUnavailable => 'app_check_unavailable',
        AiGatewayFailureCode.appCheckTimedOut => 'app_check_timed_out',
        AiGatewayFailureCode.gatewayAuthenticationRequired =>
          'gatewayAuthenticationRequired',
        AiGatewayFailureCode.gatewayAppCheckRequired =>
          'gatewayAppCheckRequired',
        AiGatewayFailureCode.gatewayRequestInvalid => 'gatewayRequestInvalid',
        AiGatewayFailureCode.gatewayUnavailable => 'gatewayUnavailable',
        AiGatewayFailureCode.unknownTemporaryFailure =>
          'unknownTemporaryFailure',
        AiGatewayFailureCode.unauthenticated => 'unauthenticated',
        AiGatewayFailureCode.appCheckRejected => 'app_check_blocked',
        AiGatewayFailureCode.rateLimited => 'rate_limited',
        AiGatewayFailureCode.providerQuotaExceeded => 'quota_exceeded',
        AiGatewayFailureCode.providerUnavailable => 'provider_unavailable',
        AiGatewayFailureCode.timeout => 'model_timeout',
        AiGatewayFailureCode.invalidResponse => 'invalid_response',
        AiGatewayFailureCode.emptyResponse => 'empty_response',
        AiGatewayFailureCode.malformedSse => 'malformed_sse',
        AiGatewayFailureCode.streamEndedWithoutCompleted =>
          'stream_ended_without_completed',
        AiGatewayFailureCode.toolSelectionInvalid => 'tool_selection_invalid',
        AiGatewayFailureCode.requestTooLarge => 'request_too_large',
        AiGatewayFailureCode.networkFailure => 'network_failure',
        AiGatewayFailureCode.configurationFailure => 'configuration_failure',
      };
    }
    final type = error.runtimeType.toString().toLowerCase();
    if (type.contains('quota')) {
      return 'quota_exceeded';
    }
    if (type.contains('appcheck') || type.contains('app_check')) {
      return 'app_check_blocked';
    }
    if (type.contains('timeout')) {
      return 'model_timeout';
    }
    return 'model_unavailable';
  }

  Future<AiAgentSessionMemory> _freshMemory(
    AiAgentMemoryAccess memoryAccess,
  ) async {
    final memory = await _memoryStore.read(access: memoryAccess);
    final updatedAt = memory.updatedAt;
    if (updatedAt != null &&
        DateTime.now().toUtc().difference(updatedAt) >
            const Duration(hours: 12)) {
      await _memoryStore.clear(access: memoryAccess);
      return const AiAgentSessionMemory();
    }
    return memory;
  }

  AiAgentSessionMemory _updateActiveContext(
    AiAgentSessionMemory memory,
    String message,
    List<AiToolResult> results,
  ) {
    final names = results.map((result) => result.toolName).toSet();
    final topic = names.contains('get_monthly_comparison')
        ? 'monthly_comparison'
        : names.contains('get_budget_progress') ||
              names.contains('get_budget_summary')
        ? 'budgets'
        : names.contains('get_goal_progress') ||
              names.contains('get_goal_summary')
        ? 'goals'
        : names.contains('get_dashboard_summary')
        ? 'dashboard'
        : memory.activeTopic;
    final period = results
        .map((result) => result.period)
        .whereType<String>()
        .lastOrNull;
    final category =
        _firstResultLabel(
          results,
          collection: 'categories',
          label: 'category',
        ) ??
        memory.activeCategory;
    final account =
        _firstResultLabel(results, collection: 'accounts', label: 'name') ??
        memory.activeAccount;
    final budget =
        _firstResultLabel(results, collection: 'budgets', label: 'name') ??
        memory.activeBudget;
    final goal =
        _firstResultLabel(results, collection: 'goals', label: 'title') ??
        memory.activeGoal;
    return memory.copyWith(
      activeTopic: topic,
      activeCategory: category,
      activeAccount: account,
      activeBudget: budget,
      activeGoal: goal,
      activePeriod: period,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  String? _firstResultLabel(
    List<AiToolResult> results, {
    required String collection,
    required String label,
  }) {
    for (final result in results) {
      final values = result.data[collection];
      if (values is! List || values.isEmpty) {
        continue;
      }
      final first = values.first;
      if (first is Map) {
        final value = first[label];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  AiUnavailableReason? _availabilityReasonFromWarnings(List<String> warnings) {
    for (final warning in warnings) {
      final reason = aiUnavailableReasonForSafeCode(warning);
      if (reason != null) return reason;
    }
    return null;
  }

  bool _isArabic(String locale, String value) =>
      locale.toLowerCase().startsWith('ar') ||
      RegExp(r'[\u0600-\u06FF]').hasMatch(value);
}
