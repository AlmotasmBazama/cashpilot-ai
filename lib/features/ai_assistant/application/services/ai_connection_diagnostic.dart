import 'dart:async';
import 'dart:convert';

import '../../../../core/error/result.dart';
import '../../../../core/firebase/app_check_token_probe.dart';
import '../../data/config/ai_runtime_config.dart';
import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_connection_diagnostic.dart';
import '../../domain/entities/ai_message.dart';
import '../../domain/entities/ai_request.dart';
import '../../domain/entities/ai_response.dart';
import '../../domain/failures/ai_failure_codes.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/services/financial_command_parser.dart';

/// Probes exactly the provider named by the capability snapshot. Diagnostics
/// intentionally do not use the conversation router's automatic fallback: a
/// Firebase fallback response must never be reported as a successful Groq
/// probe (or vice versa).
final class ProviderSpecificAiConnectionDiagnosticGateway
    implements AiAgentModelGateway {
  const ProviderSpecificAiConnectionDiagnosticGateway({
    required this.expectedProvider,
    required this.firebaseGateway,
    required this.groqGateway,
  });

  final AiActiveProvider expectedProvider;
  final AiAgentModelGateway? firebaseGateway;
  final AiAgentModelGateway? groqGateway;

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) {
    final selected = switch (expectedProvider) {
      AiActiveProvider.firebase => firebaseGateway,
      AiActiveProvider.groq => groqGateway,
      _ => null,
    };
    if (selected == null) {
      throw const AiGatewayException(
        code: AiGatewayFailureCode.providerUnavailable,
        safeMessage: 'The selected AI provider is currently unavailable.',
      );
    }
    return selected.startSession(
      request: request,
      tools: tools,
      egressGuard: egressGuard,
    );
  }
}

class AiConnectionDiagnostic {
  const AiConnectionDiagnostic({
    required AiRuntimeConfig runtimeConfig,
    required AiModelConfig modelConfig,
    required AiRepository repository,
    required FinancialCommandParser localParser,
    required AppCheckTokenProbe appCheckTokenProbe,
    AiAssistantCapabilities? capabilities,
    AiAgentModelGateway? modelGateway,
    AiProviderEgressGuard? egressGuard,
    DateTime Function()? clock,
  }) : _runtimeConfig = runtimeConfig,
       _modelConfig = modelConfig,
       _repository = repository,
       _localParser = localParser,
       _appCheckTokenProbe = appCheckTokenProbe,
       _capabilities = capabilities,
       _modelGateway = modelGateway,
       _egressGuard = egressGuard,
       _clock = clock ?? DateTime.now;

  static const String diagnosticConversationId =
      'cashpilot-ai-connection-diagnostic';
  static const String diagnosticPrompt =
      'Return exactly this harmless JSON object: '
      '{"intent":"unknown","requiresConfirmation":false}. '
      'This is a connection check only. Do not create, change, or propose '
      'any financial action.';

  final AiRuntimeConfig _runtimeConfig;
  final AiModelConfig _modelConfig;
  final AiRepository _repository;
  final FinancialCommandParser _localParser;
  final AppCheckTokenProbe _appCheckTokenProbe;
  final AiAssistantCapabilities? _capabilities;
  final AiAgentModelGateway? _modelGateway;
  final AiProviderEgressGuard? _egressGuard;
  final DateTime Function() _clock;

  Future<AiConnectionDiagnosticResult> call() async {
    final checkedAt = _clock().toUtc();
    final fallbackReady = _probeLocalFallback();
    final capabilities = _capabilities;
    if (capabilities != null) {
      return _runRoutedDiagnostic(
        capabilities: capabilities,
        fallbackReady: fallbackReady,
        checkedAt: checkedAt,
      );
    }
    if (_runtimeConfig.resolvedConversationProviderPreference !=
        AiConversationProviderPreference.firebase) {
      final failureCode = _runtimeConfig.providerMode == AiProviderMode.mock
          ? AiFailureCodes.liveProviderInactive
          : AiFailureCodes.localParserOnly;
      return fallbackReady
          ? AiConnectionDiagnosticResult.fallbackReady(
              providerAttempted: false,
              appCheckReady: null,
              failureCode: failureCode,
              checkedAt: checkedAt,
            )
          : AiConnectionDiagnosticResult.unavailable(
              providerAttempted: false,
              appCheckReady: null,
              failureCode: failureCode,
              checkedAt: checkedAt,
            );
    }

    bool appCheckReady;
    try {
      appCheckReady = await _appCheckTokenProbe.hasValidToken();
    } on Object catch (error) {
      return _failedResult(
        fallbackReady: fallbackReady,
        providerAttempted: false,
        appCheckReady: false,
        failureCode: _appCheckFailureCodeFor(error),
        checkedAt: checkedAt,
      );
    }
    if (!appCheckReady) {
      return _failedResult(
        fallbackReady: fallbackReady,
        providerAttempted: false,
        appCheckReady: false,
        failureCode: AiFailureCodes.appCheckBlocked,
        checkedAt: checkedAt,
      );
    }

    try {
      final result = await _repository.sendMessage(
        AiRequest(
          conversationId: diagnosticConversationId,
          modelId: _modelConfig.modelName,
          systemPrompt:
              'Connection diagnostic only. Return the requested harmless '
              'structured object and no financial action.',
          messages: <AiMessage>[
            AiMessage.user(
              conversationId: diagnosticConversationId,
              content: diagnosticPrompt,
            ),
          ],
          metadata: const <String, Object?>{
            'source': 'AiConnectionDiagnostic',
            'diagnostic': true,
            'output': 'structured_action',
          },
        ),
      );

      return switch (result) {
        AppSuccess(:final data)
            when data.finishReason == AiFinishReason.complete &&
                _isSafeDiagnosticOutput(data.message.content) =>
          AiConnectionDiagnosticResult.providerReady(
            appCheckReady: true,
            fallbackReady: fallbackReady,
            checkedAt: checkedAt,
          ),
        AppSuccess() => _failedResult(
          fallbackReady: fallbackReady,
          providerAttempted: true,
          providerResponded: true,
          appCheckReady: true,
          failureCode: AiFailureCodes.invalidResponse,
          checkedAt: checkedAt,
        ),
        AppFailure(:final failure) => _failedResult(
          fallbackReady: fallbackReady,
          providerAttempted: true,
          appCheckReady: true,
          failureCode: failure.code ?? AiFailureCodes.unknown,
          checkedAt: checkedAt,
        ),
      };
    } on Object {
      return _failedResult(
        fallbackReady: fallbackReady,
        providerAttempted: true,
        appCheckReady: true,
        failureCode: AiFailureCodes.unknown,
        checkedAt: checkedAt,
      );
    }
  }

  Future<AiConnectionDiagnosticResult> _runRoutedDiagnostic({
    required AiAssistantCapabilities capabilities,
    required bool fallbackReady,
    required DateTime checkedAt,
  }) async {
    final provider = capabilities.activeProvider;
    final remoteSelected =
        provider == AiActiveProvider.groq ||
        provider == AiActiveProvider.firebase;
    if (!capabilities.generalConversationAvailable || !remoteSelected) {
      return _failedResult(
        fallbackReady: fallbackReady,
        providerAttempted: false,
        appCheckReady:
            capabilities.unavailableReason ==
                AiUnavailableReason.appCheckUnavailable
            ? false
            : null,
        failureCode: _failureCodeForUnavailable(capabilities),
        checkedAt: checkedAt,
      );
    }
    final gateway = _modelGateway;
    final egressGuard = _egressGuard;
    if (gateway == null || egressGuard == null) {
      return _failedResult(
        fallbackReady: fallbackReady,
        providerAttempted: false,
        appCheckReady: true,
        failureCode: AiFailureCodes.providerUnavailable,
        checkedAt: checkedAt,
      );
    }

    try {
      egressGuard.assertActive();
      final session = await gateway.startSession(
        request: const AiAgentModelRequest(
          userMessage: diagnosticPrompt,
          systemInstruction:
              'Connection diagnostic only. Return the requested harmless '
              'structured object and no financial action.',
          memoryContext: '',
          taskClass: ModelTask.generalConversation,
          locale: 'en',
        ),
        tools: const [],
        egressGuard: egressGuard,
      );
      egressGuard.assertActive();
      final turn = await session.sendInitial();
      egressGuard.assertActive();
      final content = turn.text?.trim() ?? '';
      if (_isSafeDiagnosticOutput(content)) {
        return AiConnectionDiagnosticResult.providerReady(
          appCheckReady: true,
          fallbackReady: fallbackReady,
          checkedAt: checkedAt,
        );
      }
      final warning = turn.warnings.firstOrNull;
      return _failedResult(
        fallbackReady: fallbackReady,
        providerAttempted: true,
        providerResponded: content.isNotEmpty,
        appCheckReady: true,
        failureCode: warning == null
            ? AiFailureCodes.invalidResponse
            : _legacyFailureCodeForSafeWarning(warning),
        checkedAt: checkedAt,
      );
    } on AiGatewayException catch (failure) {
      return _failedResult(
        fallbackReady: fallbackReady,
        providerAttempted: true,
        appCheckReady:
            failure.code == AiGatewayFailureCode.appCheckUnavailable ||
                failure.code == AiGatewayFailureCode.appCheckTimedOut ||
                failure.code == AiGatewayFailureCode.appCheckRejected ||
                failure.code == AiGatewayFailureCode.gatewayAppCheckRequired
            ? false
            : true,
        failureCode: _legacyFailureCodeForGateway(failure.code),
        checkedAt: checkedAt,
      );
    } on AiProviderEgressRevokedException {
      return _failedResult(
        fallbackReady: fallbackReady,
        providerAttempted: false,
        appCheckReady: null,
        failureCode: AiFailureCodes.providerUnavailable,
        checkedAt: checkedAt,
      );
    } on TimeoutException {
      return _failedResult(
        fallbackReady: fallbackReady,
        providerAttempted: true,
        appCheckReady: true,
        failureCode: AiFailureCodes.networkFailure,
        checkedAt: checkedAt,
      );
    } on Object {
      return _failedResult(
        fallbackReady: fallbackReady,
        providerAttempted: true,
        appCheckReady: true,
        failureCode: AiFailureCodes.unknown,
        checkedAt: checkedAt,
      );
    }
  }

  String _failureCodeForUnavailable(AiAssistantCapabilities capabilities) {
    if (capabilities.activeProvider == AiActiveProvider.mock) {
      return AiFailureCodes.liveProviderInactive;
    }
    if (capabilities.activeProvider == AiActiveProvider.localParserOnly) {
      return AiFailureCodes.localParserOnly;
    }
    return switch (capabilities.unavailableReason) {
      AiUnavailableReason.appCheckUnavailable ||
      AiUnavailableReason.appCheckTimedOut ||
      AiUnavailableReason.appCheckRejected => AiFailureCodes.appCheckBlocked,
      AiUnavailableReason.offline ||
      AiUnavailableReason.gatewayUnreachable ||
      AiUnavailableReason.providerTimedOut => AiFailureCodes.networkFailure,
      _ => AiFailureCodes.providerUnavailable,
    };
  }

  String _legacyFailureCodeForGateway(AiGatewayFailureCode code) {
    return switch (code) {
      AiGatewayFailureCode.appCheckUnavailable ||
      AiGatewayFailureCode.appCheckTimedOut ||
      AiGatewayFailureCode.appCheckRejected ||
      AiGatewayFailureCode.gatewayAppCheckRequired =>
        AiFailureCodes.appCheckBlocked,
      AiGatewayFailureCode.authenticationNotReady ||
      AiGatewayFailureCode.gatewayAuthenticationRequired =>
        AiFailureCodes.providerUnavailable,
      AiGatewayFailureCode.groqRequestTimedOut ||
      AiGatewayFailureCode.groqStreamTimedOut ||
      AiGatewayFailureCode.groqUpstreamUnavailable ||
      AiGatewayFailureCode.gatewayUnavailable ||
      AiGatewayFailureCode.unknownTemporaryFailure ||
      AiGatewayFailureCode.networkFailure ||
      AiGatewayFailureCode.timeout => AiFailureCodes.networkFailure,
      AiGatewayFailureCode.groqRateLimited ||
      AiGatewayFailureCode.rateLimited ||
      AiGatewayFailureCode.providerQuotaExceeded => AiFailureCodes.rateLimited,
      AiGatewayFailureCode.groqMalformedResponse ||
      AiGatewayFailureCode.gatewayRequestInvalid ||
      AiGatewayFailureCode.invalidResponse ||
      AiGatewayFailureCode.emptyResponse ||
      AiGatewayFailureCode.malformedSse ||
      AiGatewayFailureCode.streamEndedWithoutCompleted ||
      AiGatewayFailureCode.toolSelectionInvalid =>
        AiFailureCodes.invalidResponse,
      _ => AiFailureCodes.providerUnavailable,
    };
  }

  String _legacyFailureCodeForSafeWarning(String warning) {
    final reason = aiUnavailableReasonForSafeCode(warning);
    return switch (reason) {
      AiUnavailableReason.appCheckUnavailable ||
      AiUnavailableReason.appCheckTimedOut ||
      AiUnavailableReason.appCheckRejected => AiFailureCodes.appCheckBlocked,
      AiUnavailableReason.offline ||
      AiUnavailableReason.gatewayUnreachable ||
      AiUnavailableReason.providerTimedOut => AiFailureCodes.networkFailure,
      AiUnavailableReason.rateLimited ||
      AiUnavailableReason.providerRejectedRequest => AiFailureCodes.rateLimited,
      _ => AiFailureCodes.providerUnavailable,
    };
  }

  AiConnectionDiagnosticResult _failedResult({
    required bool fallbackReady,
    required bool providerAttempted,
    required bool? appCheckReady,
    required String failureCode,
    required DateTime checkedAt,
    bool providerResponded = false,
  }) {
    return fallbackReady
        ? AiConnectionDiagnosticResult.fallbackReady(
            providerAttempted: providerAttempted,
            providerResponded: providerResponded,
            appCheckReady: appCheckReady,
            failureCode: failureCode,
            checkedAt: checkedAt,
          )
        : AiConnectionDiagnosticResult.unavailable(
            providerAttempted: providerAttempted,
            providerResponded: providerResponded,
            appCheckReady: appCheckReady,
            failureCode: failureCode,
            checkedAt: checkedAt,
          );
  }

  bool _isSafeDiagnosticOutput(String content) {
    try {
      final decoded = jsonDecode(content.trim());
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 2 ||
          !decoded.containsKey('intent') ||
          !decoded.containsKey('requiresConfirmation')) {
        return false;
      }
      return decoded['intent'] == 'unknown' &&
          decoded['requiresConfirmation'] == false;
    } on FormatException {
      return false;
    }
  }

  String _appCheckFailureCodeFor(Object error) {
    if (error is TimeoutException) {
      return AiFailureCodes.networkFailure;
    }
    final message = error.toString().toLowerCase();
    if (message.contains('app check') ||
        message.contains('appcheck') ||
        message.contains('attestation')) {
      return AiFailureCodes.appCheckBlocked;
    }
    if (message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('clientexception') ||
        message.contains('xmlhttprequest') ||
        message.contains('offline') ||
        message.contains('timed out') ||
        message.contains('failed host lookup')) {
      return AiFailureCodes.networkFailure;
    }
    return AiFailureCodes.appCheckBlocked;
  }

  bool _probeLocalFallback() {
    try {
      _localParser.parse(
        input: 'Local parser readiness check',
        accounts: const [],
        categories: const [],
        baseCurrencyCode: 'LYD',
        paymentMethodClarificationMessage: 'Select an account.',
      );
      return true;
    } on Object {
      return false;
    }
  }
}
