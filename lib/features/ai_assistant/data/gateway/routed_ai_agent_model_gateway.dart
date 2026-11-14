import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_runtime_status.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';
import '../config/ai_gateway_feature_flags.dart';
import '../config/ai_runtime_config.dart';

class RoutedAiAgentModelGateway implements ResettableAiAgentModelGateway {
  const RoutedAiAgentModelGateway({
    required this.flags,
    required this.firebaseGateway,
    required this.groqGateway,
    this.groqConfigured = true,
    this.conversationPreference = AiConversationProviderPreference.auto,
    this.generalConversationPlan,
  });

  final AiGatewayFeatureFlags flags;
  final AiAgentModelGateway? firebaseGateway;
  final AiAgentModelGateway groqGateway;
  final bool groqConfigured;
  final AiConversationProviderPreference conversationPreference;
  final AiProviderRoutePlan? generalConversationPlan;

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async {
    egressGuard.assertActive();
    final configuredPlan = generalConversationPlan;
    if (request.taskClass == ModelTask.generalConversation &&
        configuredPlan != null) {
      return _startPlannedGeneralConversation(
        plan: configuredPlan,
        request: request,
        tools: tools,
        egressGuard: egressGuard,
      );
    }
    final automatic =
        conversationPreference == AiConversationProviderPreference.auto ||
        conversationPreference == AiConversationProviderPreference.legacy;
    final explicitGroq =
        conversationPreference == AiConversationProviderPreference.groq;
    final groqConversationPrimary =
        flags.aiGroqGatewayEnabled &&
        flags.aiGroqGeneralChatEnabled &&
        (explicitGroq || automatic);
    final groqConversationRequested = explicitGroq || groqConversationPrimary;
    final firebaseTextFallback =
        flags.aiFirebaseTextFallbackEnabled && groqConversationPrimary
        ? firebaseGateway
        : null;
    if (request.taskClass == ModelTask.generalConversation &&
        groqConversationRequested) {
      if (!groqConversationPrimary || !groqConfigured) {
        final fallback = firebaseTextFallback;
        if (fallback != null) {
          return fallback.startSession(
            request: request,
            tools: tools,
            egressGuard: egressGuard,
          );
        }
        return const _DisabledAiAgentModelSession(warning: 'groqNotConfigured');
      }
      try {
        final primary = await groqGateway.startSession(
          request: request,
          tools: tools,
          egressGuard: egressGuard,
        );
        final fallback = firebaseTextFallback;
        if (fallback == null) return primary;
        return _PreEmissionFallbackSession(
          primary: primary,
          createFallback: () => fallback.startSession(
            request: request,
            tools: tools,
            egressGuard: egressGuard,
          ),
        );
      } on AiGatewayException catch (failure) {
        final fallback = firebaseTextFallback;
        if (fallback == null || !failure.isSafeTransportFailure) rethrow;
        egressGuard.assertActive();
        return fallback.startSession(
          request: request,
          tools: tools,
          egressGuard: egressGuard,
        );
      }
    }
    final groqFinancialRequested =
        explicitGroq ||
        (automatic &&
            flags.aiGroqGatewayEnabled &&
            (flags.aiGroqGeneralChatEnabled ||
                flags.aiGroqFinancialExplanationEnabled));
    if (request.taskClass == ModelTask.personalFinancialAnalysis &&
        groqFinancialRequested) {
      final financialFallback =
          flags.aiFirebaseTextFallbackEnabled &&
              flags.aiGroqGatewayEnabled &&
              (flags.aiGroqGeneralChatEnabled ||
                  flags.aiGroqFinancialExplanationEnabled) &&
              (explicitGroq || automatic)
          ? firebaseGateway
          : null;
      final selected =
          groqConfigured && flags.financialGatewayEnabledFor(request.locale)
          ? groqGateway
          : financialFallback;
      if (selected == null) {
        return _DisabledAiAgentModelSession(
          warning: !groqConfigured ? 'groqNotConfigured' : 'provider_disabled',
        );
      }
      return selected.startSession(
        request: request,
        tools: tools,
        egressGuard: egressGuard,
      );
    }
    final selected = switch (request.taskClass) {
      ModelTask.generalConversation =>
        conversationPreference == AiConversationProviderPreference.firebase
            ? firebaseGateway
            : null,
      ModelTask.personalFinancialAnalysis =>
        conversationPreference == AiConversationProviderPreference.firebase
            ? firebaseGateway
            : null,
      ModelTask.groundedCurrentKnowledge =>
        flags.aiCurrentWebEnabled ? firebaseGateway : null,
      ModelTask.financialCommandExtraction ||
      ModelTask.commandUnderstanding => null,
      ModelTask.receiptAnalysis => null,
      _ =>
        conversationPreference == AiConversationProviderPreference.firebase
            ? firebaseGateway
            : null,
    };
    if (selected == null) {
      return _DisabledAiAgentModelSession(
        warning: request.taskClass == ModelTask.groundedCurrentKnowledge
            ? 'current_information_disabled'
            : 'provider_disabled',
      );
    }
    return selected.startSession(
      request: request,
      tools: tools,
      egressGuard: egressGuard,
    );
  }

  Future<AiAgentModelSession> _startPlannedGeneralConversation({
    required AiProviderRoutePlan plan,
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async {
    if (plan.task != ModelTask.generalConversation) {
      return const _DisabledAiAgentModelSession(warning: 'provider_disabled');
    }
    if (plan.primaryProvider == AiActiveProvider.firebase) {
      final firebase = plan.primaryAvailable ? firebaseGateway : null;
      if (firebase == null) {
        return _DisabledAiAgentModelSession(warning: _warningForPlan(plan));
      }
      return firebase.startSession(
        request: request,
        tools: tools,
        egressGuard: egressGuard,
      );
    }
    if (plan.primaryProvider != AiActiveProvider.groq) {
      return _DisabledAiAgentModelSession(warning: _warningForPlan(plan));
    }
    if (!plan.primaryAvailable) {
      final fallback = plan.fallbackAvailable ? firebaseGateway : null;
      if (fallback == null) {
        return _DisabledAiAgentModelSession(warning: _warningForPlan(plan));
      }
      return fallback.startSession(
        request: request,
        tools: tools,
        egressGuard: egressGuard,
      );
    }

    try {
      final primary = await groqGateway.startSession(
        request: request,
        tools: tools,
        egressGuard: egressGuard,
      );
      final fallback = plan.fallbackAvailable ? firebaseGateway : null;
      if (fallback == null) return primary;
      return _PreEmissionFallbackSession(
        primary: primary,
        createFallback: () => fallback.startSession(
          request: request,
          tools: tools,
          egressGuard: egressGuard,
        ),
      );
    } on AiGatewayException catch (failure) {
      final fallback = plan.fallbackAvailable ? firebaseGateway : null;
      if (fallback == null || !failure.isSafeTransportFailure) rethrow;
      egressGuard.assertActive();
      return fallback.startSession(
        request: request,
        tools: tools,
        egressGuard: egressGuard,
      );
    }
  }

  String _warningForPlan(AiProviderRoutePlan plan) {
    return switch (plan.primaryUnavailableReason) {
      AiUnavailableReason.gatewayUrlMissing => 'groqNotConfigured',
      AiUnavailableReason.appCheckUnavailable => 'gatewayAppCheckRequired',
      AiUnavailableReason.authenticationRequired =>
        'gatewayAuthenticationRequired',
      AiUnavailableReason.gatewayUnreachable => 'gatewayUnavailable',
      AiUnavailableReason.providerTimedOut => 'groqRequestTimedOut',
      AiUnavailableReason.rateLimited => 'groqRateLimited',
      AiUnavailableReason.modelUnavailable => 'groqModelUnavailable',
      _ => 'provider_disabled',
    };
  }

  @override
  void clearSessions() {
    final firebase = firebaseGateway;
    if (firebase is ResettableAiAgentModelGateway) {
      firebase.clearSessions();
    }
    if (groqGateway is ResettableAiAgentModelGateway) {
      (groqGateway as ResettableAiAgentModelGateway).clearSessions();
    }
  }
}

/// Falls back only if the preferred provider fails before any user-visible
/// content is produced. Once text is emitted, cross-provider fallback is
/// prohibited so one request can never splice two model responses together.
class _PreEmissionFallbackSession implements StreamingAiAgentModelSession {
  _PreEmissionFallbackSession({
    required this.primary,
    required this.createFallback,
  });

  final AiAgentModelSession primary;
  final Future<AiAgentModelSession> Function() createFallback;
  AiAgentModelSession? _activeSession;

  @override
  Future<AiAgentModelTurn> sendInitial() async {
    try {
      final turn = await primary.sendInitial();
      _activeSession = primary;
      return turn;
    } on AiGatewayException catch (failure) {
      if (!failure.isSafeTransportFailure) rethrow;
    }
    final fallback = await createFallback();
    _activeSession = fallback;
    return fallback.sendInitial();
  }

  @override
  Stream<AiAgentModelTurn> sendInitialStream() async* {
    final source = primary is StreamingAiAgentModelSession
        ? (primary as StreamingAiAgentModelSession).sendInitialStream()
        : Stream<AiAgentModelTurn>.fromFuture(primary.sendInitial());
    var emittedTurn = false;
    try {
      await for (final turn in source) {
        emittedTurn = true;
        _activeSession = primary;
        yield turn;
      }
      _activeSession = primary;
      return;
    } on AiGatewayException catch (failure) {
      if (emittedTurn || !failure.isSafeTransportFailure) rethrow;
    }

    final fallback = await createFallback();
    _activeSession = fallback;
    if (fallback is StreamingAiAgentModelSession) {
      yield* fallback.sendInitialStream();
    } else {
      yield await fallback.sendInitial();
    }
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) => (_activeSession ?? primary).sendToolResults(calls, results);
}

class _DisabledAiAgentModelSession implements StreamingAiAgentModelSession {
  const _DisabledAiAgentModelSession({required this.warning});

  final String warning;

  @override
  Future<AiAgentModelTurn> sendInitial() async =>
      AiAgentModelTurn(warnings: <String>[warning]);

  @override
  Stream<AiAgentModelTurn> sendInitialStream() async* {
    yield AiAgentModelTurn(warnings: <String>[warning]);
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => AiAgentModelTurn(warnings: <String>[warning]);
}
