import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_runtime_status.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';

@immutable
final class AiRuntimeLiveProbeResult {
  const AiRuntimeLiveProbeResult({
    required this.fingerprint,
    required this.status,
    required this.probedProvider,
    required this.respondingProvider,
    required this.receivedNonEmptyContent,
    required this.failureCode,
    required this.checkedAt,
    required this.latency,
  });

  final AiRuntimeStatusFingerprint fingerprint;
  final AiRuntimeLiveStatus status;
  final AiActiveProvider? probedProvider;
  final AiActiveProvider? respondingProvider;
  final bool receivedNonEmptyContent;
  final AiGatewayFailureCode? failureCode;
  final DateTime checkedAt;
  final Duration latency;
}

abstract interface class AiRuntimeLiveProbe {
  Future<AiRuntimeLiveProbeResult> run({
    required AiRuntimeStatusFingerprint fingerprint,
    required AiProviderRoutePlan routePlan,
  });
}

/// A provider-specific acceptance probe. It deliberately uses the direct Groq
/// production gateway and never the routed gateway, so Firebase fallback can
/// neither satisfy nor disguise this check.
final class GroqAiRuntimeStatusProbe implements AiRuntimeLiveProbe {
  GroqAiRuntimeStatusProbe({
    required AiAgentModelGateway groqGateway,
    required AiProviderEgressGuard? egressGuard,
    this.requestTimeout = const Duration(seconds: 45),
    this.streamTimeout = const Duration(seconds: 50),
    DateTime Function()? clock,
  }) : _groqGateway = groqGateway,
       _egressGuard = egressGuard,
       _clock = clock ?? DateTime.now;

  static const String probePrompt =
      'Explain in one short sentence why planning ahead can reduce '
      'avoidable surprises.';
  static const String probeSystemInstruction =
      'Connection verification only. Answer the harmless general question '
      'briefly. Do not request or infer personal or financial data.';

  final AiAgentModelGateway _groqGateway;
  final AiProviderEgressGuard? _egressGuard;
  final Duration requestTimeout;
  final Duration streamTimeout;
  final DateTime Function() _clock;

  @override
  Future<AiRuntimeLiveProbeResult> run({
    required AiRuntimeStatusFingerprint fingerprint,
    required AiProviderRoutePlan routePlan,
  }) async {
    final startedAt = _clock().toUtc();
    final stopwatch = Stopwatch()..start();
    if (routePlan.primaryProvider != AiActiveProvider.groq) {
      return _result(
        fingerprint: fingerprint,
        status: AiRuntimeLiveStatus.groqNotSelected,
        startedAt: startedAt,
        stopwatch: stopwatch,
      );
    }
    if (!routePlan.primaryAvailable) {
      return _result(
        fingerprint: fingerprint,
        status: _statusForUnavailableReason(routePlan.primaryUnavailableReason),
        probedProvider: AiActiveProvider.groq,
        startedAt: startedAt,
        stopwatch: stopwatch,
      );
    }
    final guard = _egressGuard;
    if (guard == null) {
      return _result(
        fingerprint: fingerprint,
        status: AiRuntimeLiveStatus.gatewayAuthenticationRequired,
        probedProvider: AiActiveProvider.groq,
        failureCode: AiGatewayFailureCode.gatewayAuthenticationRequired,
        startedAt: startedAt,
        stopwatch: stopwatch,
      );
    }

    try {
      guard.assertActive();
      AiAgentModelSession session;
      try {
        session = await _groqGateway
            .startSession(
              request: const AiAgentModelRequest(
                userMessage: probePrompt,
                systemInstruction: probeSystemInstruction,
                memoryContext: '',
                taskClass: ModelTask.generalConversation,
                locale: 'en',
                conversationHistory: <AiAgentMessage>[],
              ),
              tools: const [],
              egressGuard: guard,
            )
            .timeout(requestTimeout);
      } on TimeoutException {
        return _result(
          fingerprint: fingerprint,
          status: AiRuntimeLiveStatus.groqRequestTimedOut,
          probedProvider: AiActiveProvider.groq,
          failureCode: AiGatewayFailureCode.groqRequestTimedOut,
          startedAt: startedAt,
          stopwatch: stopwatch,
        );
      }
      if (session is! StreamingAiAgentModelSession) {
        return _result(
          fingerprint: fingerprint,
          status: AiRuntimeLiveStatus.groqMalformedResponse,
          probedProvider: AiActiveProvider.groq,
          failureCode: AiGatewayFailureCode.groqMalformedResponse,
          startedAt: startedAt,
          stopwatch: stopwatch,
        );
      }
      var receivedNonEmptyContent = false;
      await for (final turn in session.sendInitialStream().timeout(
        streamTimeout,
      )) {
        guard.assertActive();
        if ((turn.text?.trim().isNotEmpty ?? false)) {
          receivedNonEmptyContent = true;
        }
      }
      guard.assertActive();
      if (!receivedNonEmptyContent) {
        return _result(
          fingerprint: fingerprint,
          status: AiRuntimeLiveStatus.groqMalformedResponse,
          probedProvider: AiActiveProvider.groq,
          failureCode: AiGatewayFailureCode.groqMalformedResponse,
          startedAt: startedAt,
          stopwatch: stopwatch,
        );
      }
      return _result(
        fingerprint: fingerprint,
        status: AiRuntimeLiveStatus.ready,
        probedProvider: AiActiveProvider.groq,
        respondingProvider: AiActiveProvider.groq,
        receivedNonEmptyContent: true,
        startedAt: startedAt,
        stopwatch: stopwatch,
      );
    } on AiGatewayException catch (failure) {
      return _result(
        fingerprint: fingerprint,
        status: aiRuntimeLiveStatusForGatewayFailure(failure.code),
        probedProvider: AiActiveProvider.groq,
        failureCode: failure.code,
        startedAt: startedAt,
        stopwatch: stopwatch,
      );
    } on AiProviderEgressRevokedException {
      return _result(
        fingerprint: fingerprint,
        status: AiRuntimeLiveStatus.cancelled,
        probedProvider: AiActiveProvider.groq,
        startedAt: startedAt,
        stopwatch: stopwatch,
      );
    } on TimeoutException {
      return _result(
        fingerprint: fingerprint,
        status: AiRuntimeLiveStatus.groqStreamTimedOut,
        probedProvider: AiActiveProvider.groq,
        failureCode: AiGatewayFailureCode.groqStreamTimedOut,
        startedAt: startedAt,
        stopwatch: stopwatch,
      );
    } on Object {
      return _result(
        fingerprint: fingerprint,
        status: AiRuntimeLiveStatus.unknownTemporaryFailure,
        probedProvider: AiActiveProvider.groq,
        failureCode: AiGatewayFailureCode.unknownTemporaryFailure,
        startedAt: startedAt,
        stopwatch: stopwatch,
      );
    }
  }

  AiRuntimeLiveStatus _statusForUnavailableReason(
    AiUnavailableReason? reason,
  ) => switch (reason) {
    AiUnavailableReason.gatewayUrlMissing ||
    AiUnavailableReason.gatewayDisabled =>
      AiRuntimeLiveStatus.groqNotConfigured,
    AiUnavailableReason.authenticationRequired ||
    AiUnavailableReason.authenticationNotReady =>
      AiRuntimeLiveStatus.gatewayAuthenticationRequired,
    AiUnavailableReason.appCheckUnavailable ||
    AiUnavailableReason.appCheckTimedOut ||
    AiUnavailableReason.appCheckRejected =>
      AiRuntimeLiveStatus.gatewayAppCheckRequired,
    AiUnavailableReason.gatewayUnreachable ||
    AiUnavailableReason.offline => AiRuntimeLiveStatus.gatewayUnavailable,
    AiUnavailableReason.providerTimedOut =>
      AiRuntimeLiveStatus.groqRequestTimedOut,
    AiUnavailableReason.rateLimited => AiRuntimeLiveStatus.groqRateLimited,
    AiUnavailableReason.modelUnavailable =>
      AiRuntimeLiveStatus.groqModelUnavailable,
    _ => AiRuntimeLiveStatus.providerUnavailable,
  };

  AiRuntimeLiveProbeResult _result({
    required AiRuntimeStatusFingerprint fingerprint,
    required AiRuntimeLiveStatus status,
    required DateTime startedAt,
    required Stopwatch stopwatch,
    AiActiveProvider? probedProvider,
    AiActiveProvider? respondingProvider,
    bool receivedNonEmptyContent = false,
    AiGatewayFailureCode? failureCode,
  }) {
    stopwatch.stop();
    return AiRuntimeLiveProbeResult(
      fingerprint: fingerprint,
      status: status,
      probedProvider: probedProvider,
      respondingProvider: respondingProvider,
      receivedNonEmptyContent: receivedNonEmptyContent,
      failureCode: failureCode,
      checkedAt: startedAt,
      latency: stopwatch.elapsed,
    );
  }
}
