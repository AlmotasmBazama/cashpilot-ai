import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/firebase/firebase_ai_backend.dart';
import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';
import '../config/firebase_ai_config.dart';

abstract interface class FirebaseAiAgentChat {
  Future<firebase_ai.GenerateContentResponse> sendMessage(
    firebase_ai.Content content,
  );

  Stream<firebase_ai.GenerateContentResponse> sendMessageStream(
    firebase_ai.Content content,
  );
}

typedef FirebaseAiAgentChatFactory =
    FirebaseAiAgentChat Function({
      required String modelId,
      required AiAgentModelRequest request,
      required List<AiToolDefinition> tools,
      required List<firebase_ai.Content> history,
      required int maxTurns,
    });

class FirebaseAiAgentModelGateway implements ResettableAiAgentModelGateway {
  FirebaseAiAgentModelGateway({
    required FirebaseAiConfig config,
    FirebaseAiAgentChatFactory? chatFactory,
    FirebaseAiBackendConfig? backendConfig,
    void Function(String message)? safeDiagnosticLog,
  }) : _config = config,
       _chatFactory = chatFactory,
       _backendConfig = backendConfig ?? FirebaseAiBackendConfig.current,
       _safeDiagnosticLog = safeDiagnosticLog;

  final FirebaseAiConfig _config;
  final FirebaseAiAgentChatFactory? _chatFactory;
  final FirebaseAiBackendConfig _backendConfig;
  final void Function(String message)? _safeDiagnosticLog;

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async {
    egressGuard.assertActive();
    final declarations = tools
        .map(_toFunctionDeclaration)
        .toList(growable: false);
    final configuredTools =
        request.taskClass == ModelTask.groundedCurrentKnowledge
        ? <firebase_ai.Tool>[firebase_ai.Tool.googleSearch()]
        : declarations.isEmpty
        ? const <firebase_ai.Tool>[]
        : <firebase_ai.Tool>[
            firebase_ai.Tool.functionDeclarations(declarations),
          ];
    firebase_ai.GenerativeModel modelFor(
      String modelId,
    ) => _backendConfig.client().generativeModel(
      model: modelId,
      generationConfig: firebase_ai.GenerationConfig(
        temperature: _temperatureFor(request.taskClass),
        maxOutputTokens: _config.modelConfig.maxOutputTokens,
      ),
      systemInstruction: firebase_ai.Content.system(
        <String>[
          request.systemInstruction,
          if (request.taskClass != ModelTask.generalConversation &&
              request.memoryContext.isNotEmpty)
            'Sanitized local conversation context:\n${request.memoryContext}',
        ].join('\n\n'),
      ),
      tools: configuredTools,
    );
    FirebaseAiAgentChat chatFor(String modelId, int maxTurns) {
      final history = _providerHistory(request);
      final factory = _chatFactory;
      if (factory != null) {
        return factory(
          modelId: modelId,
          request: request,
          tools: tools,
          history: history,
          maxTurns: maxTurns,
        );
      }
      return _FirebaseAiAgentChat(
        modelFor(modelId).startChat(history: history, maxTurns: maxTurns),
      );
    }

    try {
      final modelId = _config.modelFor(request.taskClass);
      final fallbackId = _config.fallbackModelId;
      _safeDiagnosticLog?.call(
        'AI runtime provider=firebase model=$modelId request=started',
      );
      final reusableConversation =
          request.taskClass == ModelTask.generalConversation ||
          request.taskClass == ModelTask.groundedCurrentKnowledge;
      final maxTurns = reusableConversation ? 20 : 5;
      // Every request starts from the bounded provider-safe history carried by
      // the request. Reusing an SDK chat would either duplicate those turns or
      // retain a divergent provider history after Groq/Firebase fallback.
      final chat = chatFor(modelId, maxTurns);
      final fallbackChat = fallbackId == modelId
          ? null
          : chatFor(fallbackId, maxTurns);
      return _FirebaseAiAgentModelSession(
        chat: chat,
        fallbackChat: fallbackId == modelId ? null : fallbackChat,
        userMessage: request.userMessage,
        timeout: _config.modelConfig.requestTimeout,
        expectsGrounding:
            request.taskClass == ModelTask.groundedCurrentKnowledge,
        egressGuard: egressGuard,
        safeDiagnosticLog: _safeDiagnosticLog,
      );
    } on Object catch (error, stackTrace) {
      _throwFirebaseGatewayFailure(
        error,
        stackTrace,
        safeDiagnosticLog: _safeDiagnosticLog,
      );
    }
  }

  @override
  void clearSessions() {}

  List<firebase_ai.Content> _providerHistory(AiAgentModelRequest request) {
    if (request.taskClass != ModelTask.generalConversation) {
      return <firebase_ai.Content>[];
    }
    final current = request.userMessage.trim();
    final bounded = request.conversationHistory
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    if (bounded.isNotEmpty &&
        bounded.last.role == AiAgentMessageRole.user &&
        bounded.last.content.trim() == current) {
      bounded.removeLast();
    }
    final recent = bounded.length <= 4
        ? bounded
        : bounded.sublist(bounded.length - 4);
    return recent.map((message) {
      final normalized = message.content.trim();
      final content = normalized.length <= 500
          ? normalized
          : normalized.substring(0, 500);
      return switch (message.role) {
        AiAgentMessageRole.user => firebase_ai.Content.text(content),
        AiAgentMessageRole.assistant => firebase_ai.Content.model(
          <firebase_ai.Part>[firebase_ai.TextPart(content)],
        ),
      };
    }).toList();
  }

  double _temperatureFor(ModelTask taskClass) => switch (taskClass) {
    ModelTask.financialCommandExtraction ||
    ModelTask.commandUnderstanding => 0.0,
    ModelTask.personalFinancialAnalysis ||
    ModelTask.financialAnalysis => _config.modelConfig.temperature,
    ModelTask.complexFinancialPlanning || ModelTask.complexPlanning => 0.2,
    ModelTask.localConversation ||
    ModelTask.generalConversation ||
    ModelTask.groundedCurrentKnowledge ||
    ModelTask.receiptAnalysis ||
    ModelTask.conversation => 0.2,
  };

  firebase_ai.FunctionDeclaration _toFunctionDeclaration(
    AiToolDefinition definition,
  ) {
    return firebase_ai.FunctionDeclaration(
      definition.name,
      definition.description,
      parameters: definition.arguments.map(
        (name, argument) => MapEntry(name, _toSchema(argument)),
      ),
      optionalParameters: definition.arguments.entries
          .where((entry) => !entry.value.required)
          .map((entry) => entry.key)
          .toList(growable: false),
    );
  }

  firebase_ai.Schema _toSchema(AiToolArgument argument) {
    if (argument.allowedValues.isNotEmpty) {
      return firebase_ai.Schema.enumString(
        enumValues: argument.allowedValues,
        description: argument.description,
      );
    }
    return switch (argument.type) {
      AiToolValueType.string => firebase_ai.Schema.string(
        description: argument.description,
      ),
      AiToolValueType.integer => firebase_ai.Schema.integer(
        description: argument.description,
      ),
      AiToolValueType.number => firebase_ai.Schema.number(
        description: argument.description,
      ),
      AiToolValueType.boolean => firebase_ai.Schema.boolean(
        description: argument.description,
      ),
    };
  }
}

class _FirebaseAiAgentModelSession implements StreamingAiAgentModelSession {
  _FirebaseAiAgentModelSession({
    required FirebaseAiAgentChat chat,
    required FirebaseAiAgentChat? fallbackChat,
    required String userMessage,
    required Duration timeout,
    required bool expectsGrounding,
    required AiProviderEgressGuard egressGuard,
    required void Function(String message)? safeDiagnosticLog,
  }) : _chat = chat,
       _activeChat = chat,
       _fallbackChat = fallbackChat,
       _userMessage = userMessage,
       _timeout = timeout,
       _expectsGrounding = expectsGrounding,
       _egressGuard = egressGuard,
       _safeDiagnosticLog = safeDiagnosticLog;

  final FirebaseAiAgentChat _chat;
  FirebaseAiAgentChat _activeChat;
  final FirebaseAiAgentChat? _fallbackChat;
  final String _userMessage;
  final Duration _timeout;
  final bool _expectsGrounding;
  final AiProviderEgressGuard _egressGuard;
  final void Function(String message)? _safeDiagnosticLog;

  @override
  Future<AiAgentModelTurn> sendInitial() async {
    final content = firebase_ai.Content.text(_userMessage);
    try {
      final response = await _egressGuard.runSerializedAuthOperation(() {
        _egressGuard.assertActive();
        return _chat.sendMessage(content).timeout(_timeout);
      });
      _safeDiagnosticLog?.call(
        'AI runtime provider=firebase request=completed',
      );
      return _toTurn(response);
    } on AiProviderEgressRevokedException {
      rethrow;
    } on Object catch (primaryError, primaryStackTrace) {
      final fallback = _fallbackChat;
      if (fallback == null) {
        _throwFirebaseGatewayFailure(
          primaryError,
          primaryStackTrace,
          safeDiagnosticLog: _safeDiagnosticLog,
        );
      }
      _activeChat = fallback;
      try {
        final response = await _egressGuard.runSerializedAuthOperation(() {
          _egressGuard.assertActive();
          return fallback.sendMessage(content).timeout(_timeout);
        });
        _safeDiagnosticLog?.call(
          'AI runtime provider=firebase request=completed',
        );
        return _toTurn(response);
      } on Object catch (fallbackError, fallbackStackTrace) {
        _throwFirebaseGatewayFailure(
          fallbackError,
          fallbackStackTrace,
          safeDiagnosticLog: _safeDiagnosticLog,
        );
      }
    }
  }

  @override
  Stream<AiAgentModelTurn> sendInitialStream() async* {
    var primaryEmittedOutput = false;
    Object? primaryFailure;
    StackTrace? primaryFailureStack;
    final primaryTurns = StreamIterator<AiAgentModelTurn>(_streamFrom(_chat));
    try {
      while (await primaryTurns.moveNext()) {
        primaryEmittedOutput = true;
        yield primaryTurns.current;
      }
    } on Object catch (error, stackTrace) {
      primaryFailure = error;
      primaryFailureStack = stackTrace;
    } finally {
      await primaryTurns.cancel();
    }

    final failure = primaryFailure;
    if (failure == null) {
      return;
    }
    if (failure is AiProviderEgressRevokedException || primaryEmittedOutput) {
      Error.throwWithStackTrace(failure, primaryFailureStack!);
    }

    final fallback = _fallbackChat;
    if (fallback == null) {
      Error.throwWithStackTrace(failure, primaryFailureStack!);
    }
    _activeChat = fallback;
    _egressGuard.assertActive();
    final fallbackTurns = StreamIterator<AiAgentModelTurn>(
      _streamFrom(fallback),
    );
    try {
      while (await fallbackTurns.moveNext()) {
        yield fallbackTurns.current;
      }
    } finally {
      await fallbackTurns.cancel();
    }
  }

  Stream<AiAgentModelTurn> _streamFrom(FirebaseAiAgentChat chat) async* {
    final text = StringBuffer();
    final sources = <GroundedSource>[];
    final sourceUris = <Uri>{};
    var toolCalls = const <AiAgentToolCall>[];
    String? searchEntryPoint;
    DateTime? responseDate;
    final content = firebase_ai.Content.text(_userMessage);
    StreamIterator<firebase_ai.GenerateContentResponse>? responses;
    try {
      var hasNext = await _egressGuard.runSerializedAuthOperation(() async {
        _egressGuard.assertActive();
        final iterator = StreamIterator<firebase_ai.GenerateContentResponse>(
          chat.sendMessageStream(content).timeout(_timeout),
        );
        responses = iterator;
        return iterator.moveNext();
      });
      final iterator = responses!;
      while (hasNext) {
        _egressGuard.assertActive();
        final turn = _toTurn(iterator.current);
        final chunkText = turn.text;
        if (chunkText != null) {
          text.write(chunkText);
        }
        if (turn.toolCalls.isNotEmpty) {
          toolCalls = turn.toolCalls;
        }
        for (final source in turn.sources) {
          if (sourceUris.add(source.uri)) {
            sources.add(source);
          }
        }
        searchEntryPoint =
            turn.searchEntryPointRenderedContent ?? searchEntryPoint;
        responseDate = turn.responseDate ?? responseDate;
        yield AiAgentModelTurn(
          text: text.toString(),
          toolCalls: toolCalls,
          sources: List<GroundedSource>.unmodifiable(sources),
          searchEntryPointRenderedContent: searchEntryPoint,
          responseDate: responseDate,
          warnings: _expectsGrounding && sources.isEmpty
              ? const <String>['grounding_pending']
              : const <String>[],
        );
        hasNext = await iterator.moveNext();
      }
      _safeDiagnosticLog?.call(
        'AI runtime provider=firebase request=completed',
      );
    } on Object catch (error, stackTrace) {
      _throwFirebaseGatewayFailure(
        error,
        stackTrace,
        safeDiagnosticLog: _safeDiagnosticLog,
      );
    } finally {
      await responses?.cancel();
    }
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async {
    if (calls.length != results.length) {
      throw StateError('Tool call and result counts must match.');
    }
    final parts = <firebase_ai.FunctionResponse>[];
    for (var index = 0; index < calls.length; index++) {
      final payload = results[index];
      parts.add(
        firebase_ai.FunctionResponse(
          calls[index].name,
          payload is Map<String, Object?>
              ? payload
              : <String, Object?>{'ok': false, 'code': 'invalid_tool_result'},
          id: calls[index].id.isEmpty ? null : calls[index].id,
        ),
      );
    }
    final content = firebase_ai.Content.functionResponses(parts);
    try {
      final response = await _egressGuard.runSerializedAuthOperation(() {
        _egressGuard.assertActive();
        return _activeChat.sendMessage(content).timeout(_timeout);
      });
      return _toTurn(response);
    } on Object catch (error, stackTrace) {
      _throwFirebaseGatewayFailure(
        error,
        stackTrace,
        safeDiagnosticLog: _safeDiagnosticLog,
      );
    }
  }

  AiAgentModelTurn _toTurn(firebase_ai.GenerateContentResponse response) {
    final calls = response.functionCalls
        .map(
          (call) => AiAgentToolCall(
            id: call.id ?? '',
            name: call.name,
            arguments: Map<String, Object?>.from(call.args),
          ),
        )
        .toList(growable: false);
    final grounding = response.candidates.firstOrNull?.groundingMetadata;
    final sources = <GroundedSource>[];
    for (final chunk
        in grounding?.groundingChunks ?? const <firebase_ai.GroundingChunk>[]) {
      final web = chunk.web;
      final parsedUri = Uri.tryParse(web?.uri ?? '');
      if (web == null ||
          parsedUri == null ||
          !<String>{'https', 'http'}.contains(parsedUri.scheme)) {
        continue;
      }
      final title = web.title?.trim();
      sources.add(
        GroundedSource(
          title: title == null || title.isEmpty ? parsedUri.host : title,
          uri: parsedUri,
          domain: web.domain?.trim().isNotEmpty == true
              ? web.domain!.trim()
              : parsedUri.host,
        ),
      );
    }
    return AiAgentModelTurn(
      text: response.text,
      toolCalls: calls,
      sources: sources,
      searchEntryPointRenderedContent:
          grounding?.searchEntryPoint?.renderedContent,
      responseDate: grounding == null ? null : DateTime.now().toUtc(),
      warnings: _expectsGrounding && grounding == null
          ? const <String>['grounding_unavailable']
          : const <String>[],
    );
  }
}

Never _throwFirebaseGatewayFailure(
  Object error,
  StackTrace stackTrace, {
  void Function(String message)? safeDiagnosticLog,
}) {
  if (error is AiProviderEgressRevokedException) {
    Error.throwWithStackTrace(error, stackTrace);
  }
  final failure = _firebaseGatewayFailure(error);
  safeDiagnosticLog?.call(
    'AI runtime provider=firebase request=failed code=${failure.code.name}',
  );
  Error.throwWithStackTrace(failure, stackTrace);
}

AiGatewayException _firebaseGatewayFailure(Object error) {
  if (error is AiGatewayException) return error;
  if (error is TimeoutException) {
    return const AiGatewayException(
      code: AiGatewayFailureCode.timeout,
      safeMessage: 'The AI provider request timed out.',
    );
  }
  if (error is firebase_ai.QuotaExceeded) {
    return const AiGatewayException(
      code: AiGatewayFailureCode.providerQuotaExceeded,
      safeMessage: 'The AI provider quota is temporarily unavailable.',
    );
  }
  if (error is firebase_ai.FirebaseAIException &&
      error.message.toLowerCase().contains('prepayment credits')) {
    return const AiGatewayException(
      code: AiGatewayFailureCode.providerQuotaExceeded,
      safeMessage: 'The AI provider quota is temporarily unavailable.',
    );
  }
  if (error is firebase_ai.InvalidApiKey ||
      error is firebase_ai.ServiceApiNotEnabled) {
    return const AiGatewayException(
      code: AiGatewayFailureCode.configurationFailure,
      safeMessage: 'The AI provider is not configured correctly.',
    );
  }
  if (error is firebase_ai.FirebaseAIException &&
      _isFirebaseAiAppCheckRejection(error.message)) {
    return const AiGatewayException(
      code: AiGatewayFailureCode.appCheckRejected,
      safeMessage: 'App Check could not authorize the AI request.',
    );
  }
  if (error is FirebaseException) {
    final plugin = error.plugin.toLowerCase();
    final code = error.code.toLowerCase();
    if (plugin.contains('app_check') || plugin.contains('appcheck')) {
      return const AiGatewayException(
        code: AiGatewayFailureCode.appCheckRejected,
        safeMessage: 'App Check could not authorize the AI request.',
      );
    }
    if (plugin.contains('auth') ||
        code == 'unauthenticated' ||
        code == 'user-token-expired' ||
        code == 'invalid-user-token') {
      return const AiGatewayException(
        code: AiGatewayFailureCode.unauthenticated,
        safeMessage: 'Authentication is required for the AI request.',
      );
    }
    if (code == 'network-request-failed' ||
        code == 'unavailable' ||
        code == 'deadline-exceeded') {
      return const AiGatewayException(
        code: AiGatewayFailureCode.networkFailure,
        safeMessage: 'The AI provider could not be reached.',
      );
    }
  }
  if (error is firebase_ai.ServerException ||
      error is firebase_ai.FirebaseAIException) {
    return const AiGatewayException(
      code: AiGatewayFailureCode.providerUnavailable,
      safeMessage: 'The AI provider is temporarily unavailable.',
    );
  }
  return const AiGatewayException(
    code: AiGatewayFailureCode.providerUnavailable,
    safeMessage: 'The AI provider is temporarily unavailable.',
  );
}

bool _isFirebaseAiAppCheckRejection(String message) {
  final normalized = message.toLowerCase();
  final mentionsAttestation =
      normalized.contains('app check') ||
      normalized.contains('appcheck') ||
      normalized.contains('attestation');
  final rejected =
      normalized.contains('403') ||
      normalized.contains('401') ||
      normalized.contains('permission_denied') ||
      normalized.contains('unauthorized') ||
      normalized.contains('forbidden') ||
      normalized.contains('rejected');
  return mentionsAttestation && rejected;
}

final class _FirebaseAiAgentChat implements FirebaseAiAgentChat {
  const _FirebaseAiAgentChat(this._chat);

  final firebase_ai.ChatSession _chat;

  @override
  Future<firebase_ai.GenerateContentResponse> sendMessage(
    firebase_ai.Content content,
  ) => _chat.sendMessage(content);

  @override
  Stream<firebase_ai.GenerateContentResponse> sendMessageStream(
    firebase_ai.Content content,
  ) => _chat.sendMessageStream(content);
}
