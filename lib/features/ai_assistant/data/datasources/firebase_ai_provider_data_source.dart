import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;

import '../../../../core/firebase/firebase_ai_backend.dart';
import '../../domain/entities/ai_message.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/entities/ai_provider_type.dart';
import '../../domain/entities/ai_request.dart';
import '../../domain/entities/ai_response.dart';
import '../../domain/entities/ai_structured_action_output.dart';
import '../../domain/failures/ai_failure_codes.dart';
import '../config/firebase_ai_config.dart';
import 'ai_provider_data_source.dart';

typedef FirebaseAiGenerateContent =
    Future<firebase_ai.GenerateContentResponse> Function({
      required String modelId,
      required List<firebase_ai.Content> contents,
      firebase_ai.Content? systemInstruction,
      required firebase_ai.GenerationConfig generationConfig,
    });

typedef FirebaseAiRetryDelay = Future<void> Function(Duration duration);

const firebaseAiTemporarilyBusyMessage =
    'The AI service is temporarily busy. Please try again in a moment.';
const firebaseAiRateLimitedMessage =
    'The AI request limit has been reached. Please try again later.';
const firebaseAiAppCheckBlockedMessage =
    'App Check could not verify this app for AI access.';
const firebaseAiNetworkFailureMessage =
    'The AI service could not be reached. Check the connection and try again.';
const firebaseAiProviderUnavailableMessage =
    'The configured AI service is unavailable.';
const firebaseAiInvalidResponseMessage =
    'The AI service returned an invalid response.';
const firebaseAiUnsupportedSchemaMessage =
    'The AI service returned an unsupported response shape.';

class FirebaseAiProviderDataSource implements AiProviderDataSource {
  FirebaseAiProviderDataSource({
    required FirebaseAiConfig config,
    FirebaseAiGenerateContent? generateContent,
    FirebaseAiRetryDelay? retryDelay,
    FirebaseAiBackendConfig? backendConfig,
    List<Duration> retryBackoff = const <Duration>[
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
      Duration(seconds: 1),
    ],
  }) : _config = config,
       _generateContent = generateContent,
       _retryDelay = retryDelay,
       _backendConfig = backendConfig ?? FirebaseAiBackendConfig.current,
       _retryBackoff = retryBackoff;

  final FirebaseAiConfig _config;
  final FirebaseAiGenerateContent? _generateContent;
  final FirebaseAiRetryDelay? _retryDelay;
  final FirebaseAiBackendConfig _backendConfig;
  final List<Duration> _retryBackoff;

  @override
  AiProviderType get providerType => AiProviderType.gemini;

  @override
  Future<List<AiModel>> getAvailableModels() async {
    return _config.availableModels;
  }

  @override
  Future<AiResponse> sendMessage(AiRequest request) async {
    try {
      final modelId = request.modelId ?? _config.defaultModelId;
      if (!_config.availableModels.any((model) => model.id == modelId)) {
        throw const AiProviderException(
          code: AiFailureCodes.providerUnavailable,
          message: firebaseAiProviderUnavailableMessage,
        );
      }
      final usesStructuredOutput =
          _config.modelConfig.structuredOutputEnabled &&
          request.metadata['output'] == 'structured_action';
      final generationConfig = _generationConfigFor(
        usesStructuredOutput: usesStructuredOutput,
      );
      final response = await _generateContentWithRetry(
        modelId: modelId,
        contents: _contentFor(request),
        systemInstruction: _systemInstructionFor(request),
        generationConfig: generationConfig,
      );
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        throw const AiProviderException(
          code: AiFailureCodes.invalidResponse,
          message: firebaseAiInvalidResponseMessage,
        );
      }
      if (usesStructuredOutput) {
        _validateStructuredActionResponse(text);
      }

      final candidate = response.candidates.firstOrNull;
      final usage = response.usageMetadata;
      final assistantMessage = AiMessage.assistant(
        conversationId: request.conversationId,
        content: text,
        metadata: <String, Object?>{
          'provider': 'firebase_ai',
          'modelId': modelId,
          'finishReason': candidate?.finishReason?.toJson(),
        },
      );

      return AiResponse(
        message: assistantMessage,
        providerType: providerType,
        modelId: modelId,
        finishReason: _finishReasonFor(candidate?.finishReason),
        tokenUsage: AiTokenUsage(
          inputTokens: _inputTokens(usage),
          outputTokens: _outputTokens(usage),
        ),
        metadata: <String, Object?>{
          'provider': 'firebase_ai',
          'firebaseFinishReason': candidate?.finishReason?.toJson(),
          'totalTokenCount': usage?.totalTokenCount,
          'structuredOutput': usesStructuredOutput,
        },
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_providerExceptionFor(error), stackTrace);
    }
  }

  Future<firebase_ai.GenerateContentResponse> _generateContentWithRetry({
    required String modelId,
    required List<firebase_ai.Content> contents,
    required firebase_ai.Content? systemInstruction,
    required firebase_ai.GenerationConfig generationConfig,
  }) async {
    for (var retryCount = 0; ; retryCount += 1) {
      try {
        return await _generate(
          modelId: modelId,
          contents: contents,
          systemInstruction: systemInstruction,
          generationConfig: generationConfig,
        );
      } on Object catch (error, stackTrace) {
        if (!_isRetryableServerError(error)) {
          rethrow;
        }

        if (retryCount >= _retryBackoff.length) {
          Error.throwWithStackTrace(
            const AiProviderException(
              code: AiFailureCodes.providerUnavailable,
              message: firebaseAiTemporarilyBusyMessage,
            ),
            stackTrace,
          );
        }

        await (_retryDelay ?? Future<void>.delayed)(_retryBackoff[retryCount]);
      }
    }
  }

  Future<firebase_ai.GenerateContentResponse> _generate({
    required String modelId,
    required List<firebase_ai.Content> contents,
    required firebase_ai.Content? systemInstruction,
    required firebase_ai.GenerationConfig generationConfig,
  }) {
    if (_generateContent case final generateContent?) {
      return generateContent(
        modelId: modelId,
        contents: contents,
        systemInstruction: systemInstruction,
        generationConfig: generationConfig,
      );
    }

    final model = _backendConfig.client().generativeModel(
      model: modelId,
      systemInstruction: systemInstruction,
      generationConfig: generationConfig,
    );
    return model
        .generateContent(contents)
        .timeout(_config.modelConfig.requestTimeout);
  }

  bool _isRetryableServerError(Object error) {
    if (error is firebase_ai.QuotaExceeded) {
      return false;
    }
    final message = _errorMessage(error);
    return message.contains('server error [500]') ||
        message.contains('server error [502]') ||
        message.contains('server error [503]') ||
        message.contains('server error [504]') ||
        message.contains('"code": 500') ||
        message.contains('code: 500') ||
        message.contains('"status": "internal"') ||
        message.contains('status: internal');
  }

  List<firebase_ai.Content> _contentFor(AiRequest request) {
    AiMessage? latestUserMessage;
    for (final message in request.messages.reversed) {
      if (message.role == AiMessageRole.user) {
        latestUserMessage = message;
        break;
      }
    }
    if (latestUserMessage == null) {
      return <firebase_ai.Content>[firebase_ai.Content.text('')];
    }
    return <firebase_ai.Content>[
      firebase_ai.Content.text(latestUserMessage.content),
    ];
  }

  firebase_ai.Content? _systemInstructionFor(AiRequest request) {
    final instructions = <String>[
      if (request.systemPrompt case final prompt? when prompt.trim().isNotEmpty)
        prompt.trim(),
      if (_safeContextFor(request) case final context? when context.isNotEmpty)
        'Allowed command context (JSON): ${jsonEncode(context)}',
    ];

    if (instructions.isEmpty) {
      return null;
    }

    return firebase_ai.Content.system(instructions.join('\n\n'));
  }

  Map<String, Object?>? _safeContextFor(AiRequest request) {
    if (request.context.isEmpty) {
      return null;
    }

    final safeContext = <String, Object?>{};
    for (final key in _allowedContextKeys) {
      final value = _sanitizedContextValue(key, request.context[key]);
      if (value != null) {
        safeContext[key] = value;
      }
    }
    return safeContext.isEmpty ? null : safeContext;
  }

  Object? _sanitizedContextValue(String key, Object? value) {
    if (key == 'locale' && value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty || !_safeLocalePattern.hasMatch(normalized)) {
        return null;
      }
      return normalized.length <= 24 ? normalized : normalized.substring(0, 24);
    }
    if (value is! Iterable) {
      return null;
    }
    final values = value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(50)
        .map((item) => key == 'supportedCurrencies' ? item.toUpperCase() : item)
        .where(
          (item) => key == 'supportedCurrencies'
              ? _safeCurrencyPattern.hasMatch(item)
              : _isSafeAlias(item),
        )
        .map((item) {
          final maxLength = key == 'categorySemantics' ? 240 : 64;
          return item.length <= maxLength ? item : item.substring(0, maxLength);
        })
        .toList(growable: false);
    return values.isEmpty ? null : values;
  }

  bool _isSafeAlias(String value) {
    if (_emailPattern.hasMatch(value) ||
        _firestorePathPattern.hasMatch(value) ||
        _tokenLikePattern.hasMatch(value)) {
      return false;
    }
    final digitCount = _phoneDigitPattern.allMatches(value).length;
    return digitCount < 7;
  }

  AiFinishReason _finishReasonFor(firebase_ai.FinishReason? finishReason) {
    return switch (finishReason) {
      null ||
      firebase_ai.FinishReason.stop ||
      firebase_ai.FinishReason.unknown ||
      firebase_ai.FinishReason.other => AiFinishReason.complete,
      firebase_ai.FinishReason.maxTokens => AiFinishReason.length,
      firebase_ai.FinishReason.safety ||
      firebase_ai.FinishReason.recitation ||
      firebase_ai.FinishReason.blocklist ||
      firebase_ai.FinishReason.prohibitedContent ||
      firebase_ai.FinishReason.spii ||
      firebase_ai.FinishReason.imageSafety ||
      firebase_ai.FinishReason.imageProhibitedContent ||
      firebase_ai.FinishReason.noImage ||
      firebase_ai.FinishReason.imageRecitation ||
      firebase_ai.FinishReason.language => AiFinishReason.contentFiltered,
      firebase_ai.FinishReason.malformedFunctionCall ||
      firebase_ai.FinishReason.unexpectedToolCall ||
      firebase_ai.FinishReason.tooManyToolCalls ||
      firebase_ai.FinishReason.missingThoughtSignature ||
      firebase_ai.FinishReason.malformedResponse ||
      firebase_ai.FinishReason.imageOther => AiFinishReason.error,
    };
  }

  int _inputTokens(firebase_ai.UsageMetadata? usage) {
    if (usage == null) {
      return 0;
    }

    return usage.promptTokenCount ??
        _nonNegative(
          (usage.totalTokenCount ?? 0) - (usage.candidatesTokenCount ?? 0),
        );
  }

  int _outputTokens(firebase_ai.UsageMetadata? usage) {
    if (usage == null) {
      return 0;
    }

    return usage.candidatesTokenCount ??
        _nonNegative(
          (usage.totalTokenCount ?? 0) - (usage.promptTokenCount ?? 0),
        );
  }

  int _nonNegative(int value) => value < 0 ? 0 : value;

  firebase_ai.GenerationConfig _generationConfigFor({
    required bool usesStructuredOutput,
  }) {
    return firebase_ai.GenerationConfig(
      temperature: _config.modelConfig.temperature,
      maxOutputTokens: _config.modelConfig.maxOutputTokens,
      responseMimeType: usesStructuredOutput ? 'application/json' : null,
      responseSchema: usesStructuredOutput ? _financialActionSchema : null,
    );
  }

  void _validateStructuredActionResponse(String text) {
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');
    if (firstBrace < 0 || lastBrace <= firstBrace) {
      throw const AiProviderException(
        code: AiFailureCodes.invalidResponse,
        message: firebaseAiInvalidResponseMessage,
      );
    }
    try {
      final decoded = jsonDecode(text.substring(firstBrace, lastBrace + 1));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
    } on FormatException {
      throw const AiProviderException(
        code: AiFailureCodes.invalidResponse,
        message: firebaseAiInvalidResponseMessage,
      );
    }
    if (AiStructuredActionOutput.tryParse(text) == null) {
      throw const AiProviderException(
        code: AiFailureCodes.unsupportedSchema,
        message: firebaseAiUnsupportedSchemaMessage,
      );
    }
  }

  AiProviderException _providerExceptionFor(Object error) {
    if (error is AiProviderException) {
      return error;
    }
    final message = _errorMessage(error);
    if (error is firebase_ai.QuotaExceeded ||
        message.contains('429') ||
        message.contains('quota') ||
        message.contains('resource_exhausted') ||
        message.contains('rate limit')) {
      return const AiProviderException(
        code: AiFailureCodes.rateLimited,
        message: firebaseAiRateLimitedMessage,
      );
    }
    if (message.contains('app check') ||
        message.contains('appcheck') ||
        message.contains('attestation')) {
      return const AiProviderException(
        code: AiFailureCodes.appCheckBlocked,
        message: firebaseAiAppCheckBlockedMessage,
      );
    }
    if (error is TimeoutException ||
        message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('clientexception') ||
        message.contains('xmlhttprequest') ||
        message.contains('offline') ||
        message.contains('timed out') ||
        message.contains('failed host lookup')) {
      return const AiProviderException(
        code: AiFailureCodes.networkFailure,
        message: firebaseAiNetworkFailureMessage,
      );
    }
    if (error is firebase_ai.ServiceApiNotEnabled ||
        error is firebase_ai.InvalidApiKey ||
        error is firebase_ai.UnsupportedUserLocation ||
        error is firebase_ai.FirebaseAIException ||
        message.contains('403') ||
        message.contains('permission_denied')) {
      return const AiProviderException(
        code: AiFailureCodes.providerUnavailable,
        message: firebaseAiProviderUnavailableMessage,
      );
    }
    return const AiProviderException(
      code: AiFailureCodes.unknown,
      message: firebaseAiProviderUnavailableMessage,
    );
  }

  String _errorMessage(Object error) {
    return switch (error) {
      firebase_ai.FirebaseAIException(:final message) => message.toLowerCase(),
      _ => error.toString().toLowerCase(),
    };
  }
}

const _allowedContextKeys = <String>{
  'locale',
  'supportedCurrencies',
  'accountAliases',
  'paymentMethodAliases',
  'categoryNames',
  'categorySemantics',
};

final _safeLocalePattern = RegExp(r'^[A-Za-z]{2,3}(?:[-_][A-Za-z0-9]{2,8})*$');
final _safeCurrencyPattern = RegExp(r'^[A-Z]{3}$');
final _emailPattern = RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]+');
final _phoneDigitPattern = RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]');
final _firestorePathPattern = RegExp(
  r'(?:^|\s)(?:users|projects)/|/documents/',
  caseSensitive: false,
);
final _tokenLikePattern = RegExp(
  r'(?:token|secret|bearer|auth)[\s_:=.-]+[A-Za-z0-9_-]{12,}'
  r'|AIza[0-9A-Za-z_-]{20,}|eyJ[A-Za-z0-9_-]{10,}\.',
  caseSensitive: false,
);

final firebase_ai.Schema _financialActionSchema = firebase_ai.Schema.object(
  properties: <String, firebase_ai.Schema>{
    'intent': firebase_ai.Schema.enumString(
      enumValues: const <String>[
        'create_expense',
        'create_income',
        'create_transfer',
        'create_category',
        'create_budget',
        'create_goal',
        'add_goal_contribution',
        'ask_financial_question',
        'unknown',
      ],
    ),
    'confidence': firebase_ai.Schema.string(nullable: true),
    'amount': firebase_ai.Schema.string(nullable: true),
    'currency': firebase_ai.Schema.string(nullable: true),
    'description': firebase_ai.Schema.string(nullable: true),
    'itemDescription': firebase_ai.Schema.string(nullable: true),
    'categoryHint': firebase_ai.Schema.string(nullable: true),
    'categoryConfidence': firebase_ai.Schema.string(nullable: true),
    'categoryAlternatives': firebase_ai.Schema.array(
      items: firebase_ai.Schema.string(),
      nullable: true,
    ),
    'accountHint': firebase_ai.Schema.string(nullable: true),
    'sourceAccountHint': firebase_ai.Schema.string(nullable: true),
    'destinationAccountHint': firebase_ai.Schema.string(nullable: true),
    'destinationAmount': firebase_ai.Schema.string(nullable: true),
    'exchangeRate': firebase_ai.Schema.string(nullable: true),
    'periodType': firebase_ai.Schema.string(nullable: true),
    'goalType': firebase_ai.Schema.string(nullable: true),
    'goalHint': firebase_ai.Schema.string(nullable: true),
    'payeeHint': firebase_ai.Schema.string(nullable: true),
    'incomeSourceType': firebase_ai.Schema.enumString(
      enumValues: const <String>[
        'salary',
        'freelance',
        'business_revenue',
        'gift',
        'allowance',
        'refund',
        'sale',
        'rental_income',
        'government_support',
        'scholarship',
        'investment_return',
        'reimbursement',
        'prize',
        'loan_proceeds',
        'external_transfer',
        'other',
      ],
      nullable: true,
    ),
    'incomeSourceHint': firebase_ai.Schema.string(nullable: true),
    'incomeSourcePayeeHint': firebase_ai.Schema.string(nullable: true),
    'dateText': firebase_ai.Schema.string(nullable: true),
    'isRefund': firebase_ai.Schema.boolean(nullable: true),
    'isReimbursement': firebase_ai.Schema.boolean(nullable: true),
    'isLoanProceeds': firebase_ai.Schema.boolean(nullable: true),
    'isInternalTransfer': firebase_ai.Schema.boolean(nullable: true),
    'requiresConfirmation': firebase_ai.Schema.boolean(),
    'clarificationQuestion': firebase_ai.Schema.string(nullable: true),
  },
  optionalProperties: const <String>[
    'confidence',
    'amount',
    'currency',
    'description',
    'itemDescription',
    'categoryHint',
    'categoryConfidence',
    'categoryAlternatives',
    'accountHint',
    'sourceAccountHint',
    'destinationAccountHint',
    'destinationAmount',
    'exchangeRate',
    'periodType',
    'goalType',
    'goalHint',
    'payeeHint',
    'incomeSourceType',
    'incomeSourceHint',
    'incomeSourcePayeeHint',
    'dateText',
    'isRefund',
    'isReimbursement',
    'isLoanProceeds',
    'isInternalTransfer',
    'clarificationQuestion',
  ],
);
