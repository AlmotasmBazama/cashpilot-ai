import '../agent/ai_agent_contracts.dart';

enum AiGatewayMode {
  generalConversation,
  financialExplanation,
  governedToolSelection,
}

enum AiGatewayTimeoutClass { interactive, analysis }

enum AiGatewayEventType {
  started,
  textDelta,
  toolSelection,
  warning,
  completed,
  failure,
}

enum AiGatewayFailureCode {
  groqNotConfigured,
  groqAuthenticationFailed,
  groqModelUnavailable,
  groqRateLimited,
  groqRequestTimedOut,
  groqStreamTimedOut,
  groqMalformedResponse,
  groqUpstreamUnavailable,
  authenticationNotReady,
  appCheckUnavailable,
  appCheckTimedOut,
  gatewayAuthenticationRequired,
  gatewayAppCheckRequired,
  gatewayRequestInvalid,
  gatewayUnavailable,
  unknownTemporaryFailure,
  unauthenticated,
  appCheckRejected,
  rateLimited,
  providerQuotaExceeded,
  providerUnavailable,
  timeout,
  invalidResponse,
  emptyResponse,
  malformedSse,
  streamEndedWithoutCompleted,
  toolSelectionInvalid,
  requestTooLarge,
  networkFailure,
  configurationFailure,
}

class AiGatewayException implements Exception {
  const AiGatewayException({
    required this.code,
    required this.safeMessage,
    this.retryAfterSeconds,
  });

  final AiGatewayFailureCode code;
  final String safeMessage;
  final int? retryAfterSeconds;

  bool get isSafeTransportFailure => switch (code) {
    AiGatewayFailureCode.groqRequestTimedOut ||
    AiGatewayFailureCode.groqStreamTimedOut ||
    AiGatewayFailureCode.groqUpstreamUnavailable ||
    AiGatewayFailureCode.gatewayUnavailable ||
    AiGatewayFailureCode.unknownTemporaryFailure ||
    AiGatewayFailureCode.networkFailure ||
    AiGatewayFailureCode.timeout ||
    AiGatewayFailureCode.providerUnavailable => true,
    _ => false,
  };

  @override
  String toString() => 'AiGatewayException(${code.name})';
}

class AiGatewayMessage {
  const AiGatewayMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, Object?> toJson() => <String, Object?>{
    'role': role,
    'content': content,
  };
}

class AiGatewayFinancialRecord {
  const AiGatewayFinancialRecord({
    required this.toolId,
    required this.values,
    this.period,
    this.partial,
  });

  final String toolId;
  final Map<String, Object?> values;
  final String? period;
  final bool? partial;

  Map<String, Object?> toJson() => <String, Object?>{
    'toolId': toolId,
    if (period != null) 'period': period,
    if (partial != null) 'partial': partial,
    'values': values,
  };
}

class AiGatewayFinancialContext {
  const AiGatewayFinancialContext({
    required this.currency,
    required this.records,
    this.assumptions = const <String>[],
  });

  final String currency;
  final List<AiGatewayFinancialRecord> records;
  final List<String> assumptions;

  Map<String, Object?> toJson() => <String, Object?>{
    'currency': currency,
    'records': records.map((record) => record.toJson()).toList(growable: false),
    'assumptions': assumptions,
  };
}

class AiGatewayRequest {
  const AiGatewayRequest({
    required this.requestId,
    required this.mode,
    required this.locale,
    required this.sanitizedMessages,
    required this.timeoutClass,
    required this.clientVersion,
    this.compactMemorySummary,
    this.sanitizedFinancialContext,
    this.allowedToolIds,
  });

  final String requestId;
  final AiGatewayMode mode;
  final String locale;
  final List<AiGatewayMessage> sanitizedMessages;
  final String? compactMemorySummary;
  final AiGatewayFinancialContext? sanitizedFinancialContext;
  final List<String>? allowedToolIds;
  final AiGatewayTimeoutClass timeoutClass;
  final String clientVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'requestId': requestId,
    'mode': mode.name,
    'locale': locale,
    'sanitizedMessages': sanitizedMessages
        .map((message) => message.toJson())
        .toList(growable: false),
    if (compactMemorySummary != null)
      'compactMemorySummary': compactMemorySummary,
    if (sanitizedFinancialContext != null)
      'sanitizedFinancialContext': sanitizedFinancialContext!.toJson(),
    if (allowedToolIds != null) 'allowedToolIds': allowedToolIds,
    'timeoutClass': timeoutClass.name,
    'clientVersion': clientVersion,
  };
}

class AiGatewayToolCall {
  const AiGatewayToolCall({required this.name, required this.arguments});

  final String name;
  final Map<String, Object?> arguments;
}

class AiGatewayToolSelection {
  const AiGatewayToolSelection({required this.calls, this.clarification});

  final List<AiGatewayToolCall> calls;
  final String? clarification;
}

class AiGatewayEvent {
  const AiGatewayEvent({
    required this.type,
    required this.requestId,
    this.delta,
    this.toolSelection,
    this.warningCode,
    this.failureCode,
    this.retryAfterSeconds,
  });

  final AiGatewayEventType type;
  final String requestId;
  final String? delta;
  final AiGatewayToolSelection? toolSelection;
  final String? warningCode;
  final AiGatewayFailureCode? failureCode;
  final int? retryAfterSeconds;
}

class AiGatewayHealth {
  const AiGatewayHealth({required this.reachable});

  final bool reachable;
}

abstract interface class AiConversationGateway {
  Stream<AiGatewayEvent> streamGeneralConversation(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  });

  Stream<AiGatewayEvent> streamFinancialExplanation(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  });

  Future<AiGatewayToolSelection> selectGovernedTools(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  });

  Future<AiGatewayHealth> healthCheck();
}
