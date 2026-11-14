import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;

import '../../../../core/firebase/firebase_app_check_readiness.dart';
import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../data/config/ai_agent_feature_flags.dart';
import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_agent_safety_policy.dart';
import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_intent.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';
import '../../domain/services/ai_intent_router.dart';
import '../agent/general_assistant_policy.dart';
import '../app_agent/effective_ai_app_control_policy.dart';

/// Provider inputs required by the conversation controller capability.
///
/// The bundle keeps this owner independent from the legacy provider facade and
/// makes the composition seam explicit without creating a reverse import.
class AiAgentConversationControllerDependencies {
  const AiAgentConversationControllerDependencies({
    required this.accountScopeProvider,
    required this.featureFlagsProvider,
    required this.orchestratorProvider,
    required this.assistantCapabilitiesProvider,
    required this.safeDiagnosticLogProvider,
    required this.intentRouterProvider,
    required this.effectiveAppControlPolicyProvider,
    required this.appCheckReadinessCoordinatorProvider,
  });

  final Provider<String?> accountScopeProvider;
  final Provider<AiAgentFeatureFlags> featureFlagsProvider;
  final Provider<AiAgentOrchestrator> orchestratorProvider;
  final Provider<AiAssistantCapabilities> assistantCapabilitiesProvider;
  final Provider<void Function(String)?> safeDiagnosticLogProvider;
  final Provider<AiIntentRouter> intentRouterProvider;
  final Provider<EffectiveAiAppControlPolicy> effectiveAppControlPolicyProvider;
  final Provider<FirebaseAppCheckReadinessCoordinator>
  appCheckReadinessCoordinatorProvider;
}

class AiAgentConversationState {
  const AiAgentConversationState({
    this.messages = const <AiAgentMessage>[],
    this.isSending = false,
    this.lastResponse,
    this.errorMessage,
    this.retryRequest,
    this.unavailableReason,
    this.retryable = false,
  });

  final List<AiAgentMessage> messages;
  final bool isSending;
  final AiAgentResponse? lastResponse;
  final String? errorMessage;
  final AiAgentRequest? retryRequest;
  final AiUnavailableReason? unavailableReason;
  final bool retryable;

  AiAgentConversationState copyWith({
    List<AiAgentMessage>? messages,
    bool? isSending,
    AiAgentResponse? lastResponse,
    String? errorMessage,
    AiAgentRequest? retryRequest,
    AiUnavailableReason? unavailableReason,
    bool? retryable,
    bool clearResponse = false,
    bool clearError = false,
    bool clearRetry = false,
  }) {
    return AiAgentConversationState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      lastResponse: clearResponse ? null : lastResponse ?? this.lastResponse,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      retryRequest: clearRetry ? null : retryRequest ?? this.retryRequest,
      unavailableReason: clearRetry
          ? null
          : unavailableReason ?? this.unavailableReason,
      retryable: clearRetry ? false : retryable ?? this.retryable,
    );
  }
}

/// Owns the AI conversation state machine while its provider wiring remains in
/// the legacy facade.
abstract class AiAgentConversationControllerCapability
    extends Notifier<AiAgentConversationState> {
  AiAgentConversationControllerCapability(this.dependencies);

  final AiAgentConversationControllerDependencies dependencies;
  int _generation = 0;
  StreamSubscription<AiAgentResponse>? _activeStreamSubscription;
  Completer<void>? _activeStreamCompletion;

  @override
  AiAgentConversationState build() {
    ref.watch(dependencies.accountScopeProvider);
    // Rebuilds are account-scope boundaries. Invalidate any request that began
    // under the previous scope before its late response can update new state.
    _generation += 1;
    _detachActiveStream();
    return const AiAgentConversationState();
  }

  void _invalidateActiveRequestForPolicyChange() {
    if (!ref.mounted ||
        (!state.isSending && _activeStreamSubscription == null)) {
      return;
    }
    // Any orchestrator, registry, or tool authorization captured by the
    // active request belongs to the previous effective policy. Invalidate the
    // request generation before detaching its stream so neither streaming nor
    // Future-based late completions can update the conversation.
    _generation += 1;
    _detachActiveStream();
    state = state.copyWith(
      isSending: false,
      clearError: true,
      clearResponse: true,
      clearRetry: true,
    );
  }

  ProviderSubscription<_AiAgentPolicySignature>? _listenForActivePolicyChanges({
    required int requestGeneration,
    required _AiAgentPolicySignature? capturedSignature,
  }) {
    final policyProvider = dependencies.effectiveAppControlPolicyProvider;
    if (capturedSignature == null || !ref.exists(policyProvider)) {
      return null;
    }
    final subscription = ref.listen(
      policyProvider.select(_agentPolicySignature),
      (previous, next) {
        if (requestGeneration == _generation && next != capturedSignature) {
          _invalidateActiveRequestForPolicyChange();
        }
      },
    );
    // Close the read/listen race: if policy changed after the orchestrator was
    // captured but before the listener attached, cancel this request now.
    if (requestGeneration == _generation &&
        _agentPolicySignature(ref.read(policyProvider)) != capturedSignature) {
      _invalidateActiveRequestForPolicyChange();
    }
    return subscription;
  }

  Future<AiAgentResponse?> send({
    required String content,
    required String locale,
    required String baseCurrencyCode,
  }) {
    return _send(
      AiAgentRequest(
        message: content,
        locale: locale,
        baseCurrencyCode: baseCurrencyCode,
        allowComplexPlanning: ref
            .read(dependencies.featureFlagsProvider)
            .complexPlanningEnabled,
      ),
      appendUserMessage: true,
    );
  }

  Future<AiAgentResponse?> retry() async {
    final request = state.retryRequest;
    if (request == null || !state.retryable || state.isSending) {
      return Future<AiAgentResponse?>.value(null);
    }
    final retryGeneration = _generation;
    ref.read(dependencies.appCheckReadinessCoordinatorProvider).requestRetry();
    if (!ref.mounted ||
        retryGeneration != _generation ||
        state.retryRequest != request) {
      return null;
    }
    return _send(request, appendUserMessage: false);
  }

  Future<AiAgentResponse?> _send(
    AiAgentRequest request, {
    required bool appendUserMessage,
  }) async {
    final message = request.message.trim();
    if (message.isEmpty || state.isSending) {
      return null;
    }
    final requestGeneration = ++_generation;
    ProviderSubscription<_AiAgentPolicySignature>? policySubscription;
    final messages = <AiAgentMessage>[...state.messages];
    if (!appendUserMessage &&
        state.lastResponse?.kind == AiAgentResponseKind.failure &&
        messages.isNotEmpty &&
        messages.last.role == AiAgentMessageRole.assistant) {
      messages.removeLast();
    }
    if (appendUserMessage) {
      messages.add(
        AiAgentMessage(
          role: AiAgentMessageRole.user,
          content: message,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    state = state.copyWith(
      messages: messages,
      isSending: true,
      clearError: true,
      clearResponse: true,
      clearRetry: true,
    );
    try {
      final directResponse = _directConversationResponse(request);
      if (directResponse != null) {
        _appendAssistantResponse(directResponse, request: request);
        return directResponse;
      }
      final policyProvider = dependencies.effectiveAppControlPolicyProvider;
      final signatureBeforeOrchestrator = ref.exists(policyProvider)
          ? _agentPolicySignature(ref.read(policyProvider))
          : null;
      final orchestrator = ref.read(dependencies.orchestratorProvider);
      final requestPolicySignature =
          signatureBeforeOrchestrator ??
          (ref.exists(policyProvider)
              ? _agentPolicySignature(ref.read(policyProvider))
              : null);
      policySubscription = _listenForActivePolicyChanges(
        requestGeneration: requestGeneration,
        capturedSignature: requestPolicySignature,
      );
      if (requestGeneration != _generation) {
        return null;
      }
      if (orchestrator is StreamingAiAgentOrchestrator) {
        AiAgentResponse? finalResponse;
        var hasAssistantMessage = false;
        Object? streamError;
        final completion = Completer<void>();
        _activeStreamCompletion = completion;
        _activeStreamSubscription = orchestrator
            .respondStream(request)
            .listen(
              (response) {
                if (!ref.mounted ||
                    requestGeneration != _generation ||
                    response.message.trim().isEmpty) {
                  return;
                }
                final assistantMessage = AiAgentMessage(
                  role: AiAgentMessageRole.assistant,
                  content: response.message,
                  createdAt: DateTime.now().toUtc(),
                );
                final messages = <AiAgentMessage>[...state.messages];
                if (hasAssistantMessage && messages.isNotEmpty) {
                  messages[messages.length - 1] = assistantMessage;
                } else {
                  messages.add(assistantMessage);
                  hasAssistantMessage = true;
                }
                state = state.copyWith(
                  messages: messages,
                  isSending: response.isPartial,
                  lastResponse: response,
                  clearError: true,
                  retryRequest: response.kind == AiAgentResponseKind.failure
                      ? request
                      : null,
                  unavailableReason: _reasonFor(response),
                  retryable: _isRetryableResponse(response),
                  clearRetry: response.kind != AiAgentResponseKind.failure,
                );
                if (!response.isPartial) {
                  finalResponse = response;
                }
              },
              onError: (Object error, StackTrace _) {
                streamError = error;
                if (!completion.isCompleted) completion.complete();
              },
              onDone: () {
                if (!completion.isCompleted) completion.complete();
              },
              cancelOnError: true,
            );
        await completion.future;
        if (identical(_activeStreamCompletion, completion)) {
          _activeStreamCompletion = null;
          _activeStreamSubscription = null;
        }
        if (!ref.mounted || requestGeneration != _generation) {
          return null;
        }
        if (streamError != null ||
            (hasAssistantMessage && finalResponse == null)) {
          _recordRequestFailure(
            request,
            removePartialAssistant: hasAssistantMessage,
          );
          return null;
        }
        if (state.isSending) {
          state = state.copyWith(isSending: false);
        }
        return finalResponse;
      }

      final response = await orchestrator.respond(request);
      if (!ref.mounted || requestGeneration != _generation) {
        return null;
      }
      _appendAssistantResponse(response, request: request);
      return response;
    } on Object catch (error, stackTrace) {
      if (!ref.mounted || requestGeneration != _generation) {
        return null;
      }
      ref
          .read(dependencies.safeDiagnosticLogProvider)
          ?.call(
            jsonEncode(<String, Object?>{
              'kind': 'cashpilot_ai_controller_failure',
              'code': _safeControllerFailureCode(error),
              'source': _safeControllerFailureSource(error, stackTrace),
              'typedUnavailableReason':
                  AiUnavailableReason.unknownTemporaryFailure.name,
              'retryable': true,
            }),
          );
      _recordRequestFailure(request);
      return null;
    } finally {
      policySubscription?.close();
      if (ref.mounted && requestGeneration == _generation && state.isSending) {
        state = state.copyWith(isSending: false);
      }
    }
  }

  AiAgentResponse? _directConversationResponse(AiAgentRequest request) {
    final message = request.message.trim();
    if (message.isEmpty || const AiAgentSafetyPolicy().isBlocked(message)) {
      return null;
    }
    final route = ref.read(dependencies.intentRouterProvider).route(message);
    if (route.target != AssistantRouteTarget.directConversation) {
      return null;
    }
    AiAssistantCapabilities? capabilities;
    if (route.intent == AiIntent.help ||
        route.intent == AiIntent.supportedCapabilities) {
      try {
        capabilities = ref.read(dependencies.assistantCapabilitiesProvider);
      } on Object {
        // Local help must remain available while preflight providers start.
      }
    }
    return AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      turnKind: AssistantTurnKind.directConversation,
      message: GeneralAssistantPolicy.localDirectReply(
        intent: route.intent,
        locale: request.locale,
        capabilities: capabilities,
      ),
    );
  }

  void _appendAssistantResponse(
    AiAgentResponse response, {
    required AiAgentRequest request,
  }) {
    final assistantMessage = AiAgentMessage(
      role: AiAgentMessageRole.assistant,
      content: response.message,
      createdAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(
      messages: <AiAgentMessage>[...state.messages, assistantMessage],
      isSending: false,
      lastResponse: response,
      clearError: true,
      retryRequest: response.kind == AiAgentResponseKind.failure
          ? request
          : null,
      unavailableReason: _reasonFor(response),
      retryable: _isRetryableResponse(response),
      clearRetry: response.kind != AiAgentResponseKind.failure,
    );
  }

  AiUnavailableReason? _reasonFor(AiAgentResponse response) {
    for (final warning in response.warnings.reversed) {
      final reason = aiUnavailableReasonForSafeCode(warning);
      if (reason != null) return reason;
    }
    return null;
  }

  bool _isRetryableResponse(AiAgentResponse response) {
    if (response.kind != AiAgentResponseKind.failure) return false;
    return response.retryable ??
        isAiRequestFailureRetryable(_reasonFor(response));
  }

  void _recordRequestFailure(
    AiAgentRequest request, {
    bool removePartialAssistant = false,
  }) {
    final messages = <AiAgentMessage>[...state.messages];
    if (removePartialAssistant &&
        messages.isNotEmpty &&
        messages.last.role == AiAgentMessageRole.assistant) {
      messages.removeLast();
    }
    state = state.copyWith(
      messages: messages,
      isSending: false,
      clearResponse: true,
      errorMessage: GeneralAssistantPolicy.unavailableForReason(
        AiUnavailableReason.unknownTemporaryFailure,
        locale: request.locale,
      ),
      retryRequest: request,
      unavailableReason: AiUnavailableReason.unknownTemporaryFailure,
      retryable: true,
    );
  }

  void recordLocalUserMessage(String content) {
    final message = content.trim();
    if (message.isEmpty || state.isSending) {
      return;
    }
    state = state.copyWith(
      messages: <AiAgentMessage>[
        ...state.messages,
        AiAgentMessage(
          role: AiAgentMessageRole.user,
          content: message,
          createdAt: DateTime.now().toUtc(),
        ),
      ],
      clearResponse: true,
      clearError: true,
      clearRetry: true,
    );
  }

  void recordLocalAssistantMessage(String content) {
    final message = content.trim();
    if (message.isEmpty) {
      return;
    }
    state = state.copyWith(
      messages: <AiAgentMessage>[
        ...state.messages,
        AiAgentMessage(
          role: AiAgentMessageRole.assistant,
          content: message,
          createdAt: DateTime.now().toUtc(),
        ),
      ],
      clearResponse: true,
      clearError: true,
      clearRetry: true,
    );
  }

  void cancel() {
    if (!ref.mounted) {
      return;
    }
    if (!state.isSending && _activeStreamSubscription == null) {
      return;
    }
    _generation += 1;
    _detachActiveStream();
    state = state.copyWith(
      isSending: false,
      clearError: true,
      clearResponse: true,
      clearRetry: true,
    );
  }

  Future<void> clear() async {
    _generation += 1;
    _detachActiveStream();
    await ref.read(dependencies.orchestratorProvider).clearConversation();
    state = const AiAgentConversationState();
  }

  Future<void> startNew() async {
    _generation += 1;
    _detachActiveStream();
    state = const AiAgentConversationState();
    await ref.read(dependencies.orchestratorProvider).startNewConversation();
  }

  void _detachActiveStream() {
    final subscription = _activeStreamSubscription;
    _activeStreamSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    final completion = _activeStreamCompletion;
    _activeStreamCompletion = null;
    if (completion != null && !completion.isCompleted) {
      completion.complete();
    }
  }
}

typedef _AiAgentPolicySignature = ({
  int configurationRevision,
  String provenance,
  String controlLevel,
  bool configurationResolved,
  bool hasAuthenticatedScope,
  bool runtimeOwnerScopeSafe,
  bool canReadFinancialData,
  bool canNavigate,
  bool canCreateTransactionDraft,
  bool canCreateBudgetOrGoalDraft,
  bool canCreateAccountCategoryPayeeDraft,
  bool canExecuteConfirmedFinancialCreate,
  bool canExecuteConfirmedTransfer,
  bool canUpdateDraft,
  bool canArchiveDraft,
  bool canUseRecurringDrafts,
  bool canUseMultiStepPlans,
});

_AiAgentPolicySignature _agentPolicySignature(
  EffectiveAiAppControlPolicy policy,
) => (
  configurationRevision: policy.configurationRevision,
  provenance: policy.provenance.name,
  controlLevel: policy.settings.level.name,
  configurationResolved: policy.configurationResolved,
  hasAuthenticatedScope: policy.hasAuthenticatedScope,
  runtimeOwnerScopeSafe: policy.runtimeOwnerScopeSafe,
  canReadFinancialData: policy.canReadFinancialData,
  canNavigate: policy.canNavigate,
  canCreateTransactionDraft: policy.canCreateTransactionDraft,
  canCreateBudgetOrGoalDraft: policy.canCreateBudgetOrGoalDraft,
  canCreateAccountCategoryPayeeDraft: policy.canCreateAccountCategoryPayeeDraft,
  canExecuteConfirmedFinancialCreate: policy.canExecuteConfirmedFinancialCreate,
  canExecuteConfirmedTransfer: policy.canExecuteConfirmedTool(
    'createTransferDraft',
  ),
  canUpdateDraft: policy.canUpdateDraft,
  canArchiveDraft: policy.canArchiveDraft,
  canUseRecurringDrafts: policy.canUseRecurringDrafts,
  canUseMultiStepPlans: policy.canUseMultiStepPlans,
);

String _safeControllerFailureSource(Object error, StackTrace stackTrace) {
  var sourceStackTrace = stackTrace;
  var root = error;
  while (root is ProviderException) {
    sourceStackTrace = root.stackTrace;
    root = root.exception;
  }
  final matches = RegExp(
    r'package:cashpilot_ai/([A-Za-z0-9_./-]+\.dart):(\d+)',
  ).allMatches(sourceStackTrace.toString());
  final match = matches.cast<RegExpMatch?>().firstWhere(
    (candidate) =>
        candidate != null &&
        !(candidate.group(1) ==
                'features/ai_assistant/application/providers/ai_agent_providers.dart' &&
            candidate.group(2) == '720'),
    orElse: () => null,
  );
  if (match == null) return 'unavailable';
  return '${match.group(1)}:${match.group(2)}';
}

String _safeControllerFailureCode(Object error) {
  var root = error;
  while (root is ProviderException) {
    root = root.exception;
  }
  return switch (root) {
    AiGatewayException(:final code) => 'gateway_${code.name}',
    AiProviderEgressRevokedException() => 'egress_revoked',
    OwnerScopeException(:final failure) => 'owner_scope_${failure.name}',
    FirebaseException(:final plugin) => switch (plugin) {
      'firebase_auth' => 'firebase_auth',
      'firebase_app_check' => 'firebase_app_check',
      'firebase_ai' => 'firebase_ai',
      _ => 'firebase_other',
    },
    TimeoutException() => 'timeout',
    StateError() => 'state_error',
    ArgumentError() => 'argument_error',
    _ =>
      'type_${root.runtimeType.toString().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase()}',
  };
}
