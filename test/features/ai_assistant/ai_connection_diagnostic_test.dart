import 'dart:async';

import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/firebase/app_check_token_probe.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_connection_diagnostic.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_connection_diagnostic.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_message.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_model.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_provider_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_request.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_response.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/failures/ai_failure_codes.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/repositories/ai_repository.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

const _safeDiagnosticJson = '{"intent":"unknown","requiresConfirmation":false}';
final _checkedAt = DateTime.utc(2026, 7, 21, 12, 30);

void main() {
  test(
    'live request is harmless, structured, minimized, and timestamped',
    () async {
      final repository = _DiagnosticRepository();
      final diagnostic = _diagnostic(
        mode: AiProviderMode.firebaseGemini,
        repository: repository,
      );

      final result = await diagnostic();

      expect(result.status, AiConnectionDiagnosticStatus.providerReady);
      expect(result.testStatus, AiConnectionTestStatus.success);
      expect(result.checkedAt, _checkedAt);
      expect(result.providerAttempted, isTrue);
      expect(result.providerResponded, isTrue);
      expect(repository.sendCalls, 1);
      final request = repository.lastRequest!;
      expect(request.modelId, AiModelConfig.defaultEconomicalModel);
      expect(request.context, isEmpty);
      expect(request.messages, hasLength(1));
      expect(
        request.messages.single.content,
        AiConnectionDiagnostic.diagnosticPrompt,
      );
      expect(request.metadata['diagnostic'], isTrue);
      expect(request.metadata['output'], 'structured_action');
      final serialized = <Object?>[
        request.context,
        request.metadata,
        request.messages.map((message) => message.content).toList(),
      ].toString().toLowerCase();
      for (final blocked in <String>[
        'email',
        'uid',
        'phone',
        'balance',
        'transaction history',
        'accountalias',
        'payee',
      ]) {
        expect(serialized, isNot(contains(blocked)));
      }
    },
  );

  test(
    'App Check rejection uses fallback and never contacts provider',
    () async {
      final repository = _DiagnosticRepository();
      final result = await _diagnostic(
        mode: AiProviderMode.firebaseGemini,
        repository: repository,
        appCheckReady: false,
      )();

      expect(result.status, AiConnectionDiagnosticStatus.fallbackReady);
      expect(result.testStatus, AiConnectionTestStatus.appCheckBlocked);
      expect(result.failureCode, AiFailureCodes.appCheckBlocked);
      expect(result.appCheckReady, isFalse);
      expect(repository.sendCalls, 0);
    },
  );

  test('App Check network failure is not mislabeled as attestation', () async {
    final repository = _DiagnosticRepository();
    final result = await _diagnostic(
      mode: AiProviderMode.firebaseGemini,
      repository: repository,
      appCheckError: Exception('ClientException: XMLHttpRequest error'),
    )();

    expect(result.testStatus, AiConnectionTestStatus.networkFailure);
    expect(result.failureCode, AiFailureCodes.networkFailure);
    expect(repository.sendCalls, 0);
  });

  test('typed App Check timeout is a network failure', () async {
    final result = await _diagnostic(
      mode: AiProviderMode.firebaseGemini,
      repository: _DiagnosticRepository(),
      appCheckError: TimeoutException('probe'),
    )();

    expect(result.testStatus, AiConnectionTestStatus.networkFailure);
    expect(result.failureCode, AiFailureCodes.networkFailure);
  });

  test('explicit App Check marker wins over generic connection text', () async {
    final result = await _diagnostic(
      mode: AiProviderMode.firebaseGemini,
      repository: _DiagnosticRepository(),
      appCheckError: Exception('App Check connection attestation rejected'),
    )();

    expect(result.testStatus, AiConnectionTestStatus.appCheckBlocked);
    expect(result.failureCode, AiFailureCodes.appCheckBlocked);
  });

  for (final entry in <(String, AiConnectionTestStatus)>[
    (AiFailureCodes.rateLimited, AiConnectionTestStatus.rateLimited),
    (
      AiFailureCodes.providerUnavailable,
      AiConnectionTestStatus.providerUnavailable,
    ),
    (AiFailureCodes.networkFailure, AiConnectionTestStatus.networkFailure),
    (AiFailureCodes.invalidResponse, AiConnectionTestStatus.invalidResponse),
    (AiFailureCodes.unsupportedSchema, AiConnectionTestStatus.invalidResponse),
  ]) {
    test(
      '${entry.$1} retains a safe diagnostic status with fallback',
      () async {
        final result = await _diagnostic(
          mode: AiProviderMode.firebaseGemini,
          repository: _DiagnosticRepository(
            failure: Failure(message: 'safe provider failure', code: entry.$1),
          ),
        )();

        expect(result.status, AiConnectionDiagnosticStatus.fallbackReady);
        expect(result.testStatus, entry.$2);
        expect(result.failureCode, entry.$1);
      },
    );
  }

  test('arbitrary nonempty provider reply is an invalid response', () async {
    final result = await _diagnostic(
      mode: AiProviderMode.firebaseGemini,
      repository: _DiagnosticRepository(responseText: 'ready'),
    )();

    expect(result.testStatus, AiConnectionTestStatus.invalidResponse);
    expect(result.failureCode, AiFailureCodes.invalidResponse);
    expect(result.providerResponded, isTrue);
  });

  test('JSON wrapped in prose is rejected as an invalid response', () async {
    final result = await _diagnostic(
      mode: AiProviderMode.firebaseGemini,
      repository: _DiagnosticRepository(
        responseText: 'ready: $_safeDiagnosticJson',
      ),
    )();

    expect(result.testStatus, AiConnectionTestStatus.invalidResponse);
    expect(result.failureCode, AiFailureCodes.invalidResponse);
  });

  test('diagnostic JSON with any extra key is rejected', () async {
    final result = await _diagnostic(
      mode: AiProviderMode.firebaseGemini,
      repository: _DiagnosticRepository(
        responseText:
            '{"intent":"unknown","requiresConfirmation":false,'
            '"confidence":null}',
      ),
    )();

    expect(result.testStatus, AiConnectionTestStatus.invalidResponse);
  });

  test(
    'diagnostic JSON with a wrong typed optional field is rejected',
    () async {
      final result = await _diagnostic(
        mode: AiProviderMode.firebaseGemini,
        repository: _DiagnosticRepository(
          responseText:
              '{"intent":"unknown","requiresConfirmation":false,'
              '"amount":1}',
        ),
      )();

      expect(result.testStatus, AiConnectionTestStatus.invalidResponse);
    },
  );

  test(
    'financial structured reply is rejected by harmless diagnostic',
    () async {
      final result = await _diagnostic(
        mode: AiProviderMode.firebaseGemini,
        repository: _DiagnosticRepository(
          responseText:
              '{"intent":"create_expense","amount":"1",'
              '"requiresConfirmation":true}',
        ),
      )();

      expect(result.testStatus, AiConnectionTestStatus.invalidResponse);
    },
  );

  test('mock diagnostic clearly stays off the live provider', () async {
    final repository = _DiagnosticRepository();
    final result = await _diagnostic(
      mode: AiProviderMode.mock,
      repository: repository,
    )();

    expect(result.status, AiConnectionDiagnosticStatus.fallbackReady);
    expect(result.testStatus, AiConnectionTestStatus.fallbackUsed);
    expect(result.failureCode, AiFailureCodes.liveProviderInactive);
    expect(result.providerAttempted, isFalse);
    expect(repository.sendCalls, 0);
  });

  test('local-only diagnostic cannot contact AI or mutate finance', () async {
    final repository = _DiagnosticRepository();
    final result = await _diagnostic(
      mode: AiProviderMode.localParserOnly,
      repository: repository,
    )();

    expect(result.status, AiConnectionDiagnosticStatus.fallbackReady);
    expect(result.testStatus, AiConnectionTestStatus.fallbackUsed);
    expect(result.failureCode, AiFailureCodes.localParserOnly);
    expect(result.providerAttempted, isFalse);
    expect(repository.sendCalls, 0);
  });

  test('unexpected repository exception is contained safely', () async {
    final result = await _diagnostic(
      mode: AiProviderMode.firebaseGemini,
      repository: _DiagnosticRepository(throwsOnSend: true),
    )();

    expect(result.status, AiConnectionDiagnosticStatus.fallbackReady);
    expect(result.testStatus, AiConnectionTestStatus.fallbackUsed);
    expect(result.failureCode, AiFailureCodes.unknown);
  });

  for (final entry in <(String, AiRuntimeConfig, AiActiveProvider)>[
    (
      'explicit Firebase',
      AiRuntimeConfig.resolve(providerValue: 'firebase'),
      AiActiveProvider.firebase,
    ),
    (
      'explicit Groq',
      AiRuntimeConfig.resolve(providerValue: 'groq'),
      AiActiveProvider.groq,
    ),
  ]) {
    test('${entry.$1} diagnostic probes the routed remote provider', () async {
      final repository = _DiagnosticRepository();
      final gateway = _DiagnosticModelGateway();
      final result = await _routedDiagnostic(
        runtime: entry.$2,
        activeProvider: entry.$3,
        repository: repository,
        gateway: gateway,
      )();

      expect(result.status, AiConnectionDiagnosticStatus.providerReady);
      expect(result.providerAttempted, isTrue);
      expect(gateway.calls, 1);
      expect(gateway.lastRequest?.taskClass, ModelTask.generalConversation);
      expect(gateway.lastRequest?.conversationHistory, isEmpty);
      expect(repository.sendCalls, 0);
    });
  }

  test(
    'Groq diagnostic failure never reports Firebase fallback as Groq success',
    () async {
      final groq = _ThrowingDiagnosticGateway();
      final firebase = _DiagnosticModelGateway();
      final result = await _routedDiagnostic(
        runtime: AiRuntimeConfig.resolve(providerValue: 'groq'),
        activeProvider: AiActiveProvider.groq,
        repository: _DiagnosticRepository(),
        gateway: ProviderSpecificAiConnectionDiagnosticGateway(
          expectedProvider: AiActiveProvider.groq,
          firebaseGateway: firebase,
          groqGateway: groq,
        ),
      )();

      expect(result.status, isNot(AiConnectionDiagnosticStatus.providerReady));
      expect(result.providerAttempted, isTrue);
      expect(groq.calls, 1);
      expect(firebase.calls, 0);
    },
  );

  test(
    'local parser is never labeled or probed as a remote provider',
    () async {
      final repository = _DiagnosticRepository();
      final gateway = _DiagnosticModelGateway();
      final result = await _routedDiagnostic(
        runtime: AiRuntimeConfig.resolve(providerValue: 'local'),
        activeProvider: AiActiveProvider.localParserOnly,
        repository: repository,
        gateway: gateway,
        generalAvailable: false,
        unavailableReason: AiUnavailableReason.gatewayDisabled,
      )();

      expect(result.status, AiConnectionDiagnosticStatus.fallbackReady);
      expect(result.failureCode, AiFailureCodes.localParserOnly);
      expect(result.providerAttempted, isFalse);
      expect(gateway.calls, 0);
      expect(repository.sendCalls, 0);
    },
  );
}

AiConnectionDiagnostic _routedDiagnostic({
  required AiRuntimeConfig runtime,
  required AiActiveProvider activeProvider,
  required _DiagnosticRepository repository,
  required AiAgentModelGateway gateway,
  bool generalAvailable = true,
  AiUnavailableReason? unavailableReason,
}) {
  return AiConnectionDiagnostic(
    runtimeConfig: runtime,
    modelConfig: const AiModelConfig(
      modelName: AiModelConfig.defaultEconomicalModel,
      temperature: 0.1,
      maxOutputTokens: 512,
      structuredOutputEnabled: true,
      streamingEnabled: false,
      requestTimeout: Duration(seconds: 20),
    ),
    repository: repository,
    localParser: const FinancialCommandParser(),
    appCheckTokenProbe: const _FakeAppCheckTokenProbe(ready: true),
    capabilities: AiAssistantCapabilities(
      directConversationAvailable: true,
      generalConversationAvailable: generalAvailable,
      currentKnowledgeAvailable: false,
      personalFinancialAnalysisAvailable: false,
      financialDraftsAvailable: false,
      confirmedExecutionAvailable: false,
      receiptVisionAvailable: false,
      navigationAvailable: false,
      activeProvider: activeProvider,
      unavailableReason: unavailableReason,
      retryable: false,
      platformSupported: true,
    ),
    modelGateway: gateway,
    egressGuard: testAiProviderEgressGuard,
    clock: () => _checkedAt,
  );
}

AiConnectionDiagnostic _diagnostic({
  required AiProviderMode mode,
  required _DiagnosticRepository repository,
  bool appCheckReady = true,
  Object? appCheckError,
}) {
  return AiConnectionDiagnostic(
    runtimeConfig: AiRuntimeConfig(
      providerMode: mode,
      diagnosticsEnabled: true,
    ),
    modelConfig: const AiModelConfig(
      modelName: AiModelConfig.defaultEconomicalModel,
      temperature: 0.1,
      maxOutputTokens: 512,
      structuredOutputEnabled: true,
      streamingEnabled: false,
      requestTimeout: Duration(seconds: 20),
    ),
    repository: repository,
    localParser: const FinancialCommandParser(),
    appCheckTokenProbe: _FakeAppCheckTokenProbe(
      ready: appCheckReady,
      error: appCheckError,
    ),
    clock: () => _checkedAt,
  );
}

class _FakeAppCheckTokenProbe implements AppCheckTokenProbe {
  const _FakeAppCheckTokenProbe({required this.ready, this.error});

  final bool ready;
  final Object? error;

  @override
  Future<bool> hasValidToken() async {
    if (error case final error?) {
      throw error;
    }
    return ready;
  }
}

class _DiagnosticRepository implements AiRepository {
  _DiagnosticRepository({
    this.failure,
    this.responseText = _safeDiagnosticJson,
    this.throwsOnSend = false,
  });

  final Failure? failure;
  final String responseText;
  final bool throwsOnSend;
  int sendCalls = 0;
  AiRequest? lastRequest;

  @override
  Future<AppResult<List<AiModel>>> getAvailableModels() async {
    return const AppResult.success(<AiModel>[]);
  }

  @override
  Future<AppResult<AiResponse>> sendMessage(AiRequest request) async {
    sendCalls += 1;
    lastRequest = request;
    if (throwsOnSend) {
      throw StateError('raw provider details');
    }
    final failure = this.failure;
    if (failure != null) {
      return AppResult.failure(failure);
    }
    return AppResult.success(
      AiResponse(
        message: AiMessage.assistant(
          conversationId: request.conversationId,
          content: responseText,
        ),
        providerType: AiProviderType.gemini,
        modelId: request.modelId ?? 'diagnostic-model',
        finishReason: AiFinishReason.complete,
        tokenUsage: const AiTokenUsage(inputTokens: 1, outputTokens: 1),
      ),
    );
  }
}

final class _DiagnosticModelGateway implements AiAgentModelGateway {
  int calls = 0;
  AiAgentModelRequest? lastRequest;

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async {
    calls += 1;
    lastRequest = request;
    return const _DiagnosticModelSession();
  }
}

final class _ThrowingDiagnosticGateway implements AiAgentModelGateway {
  int calls = 0;

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async {
    calls += 1;
    throw const AiGatewayException(
      code: AiGatewayFailureCode.providerUnavailable,
      safeMessage: 'The selected provider is unavailable.',
    );
  }
}

final class _DiagnosticModelSession implements AiAgentModelSession {
  const _DiagnosticModelSession();

  @override
  Future<AiAgentModelTurn> sendInitial() async =>
      const AiAgentModelTurn(text: _safeDiagnosticJson);

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => const AiAgentModelTurn(text: _safeDiagnosticJson);
}
