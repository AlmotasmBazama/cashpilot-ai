import 'dart:async';

import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/firebase_ai_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/datasources/firebase_ai_provider_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/repositories/ai_repository_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_message.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_request.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_response.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/failures/ai_failure_codes.dart';
import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase AI Logic structured configuration', () {
    test('financial actions use low-temperature JSON schema output', () async {
      firebase_ai.GenerationConfig? capturedConfig;
      final dataSource = FirebaseAiProviderDataSource(
        config: _config(),
        generateContent:
            ({
              required String modelId,
              required List<firebase_ai.Content> contents,
              firebase_ai.Content? systemInstruction,
              required firebase_ai.GenerationConfig generationConfig,
            }) async {
              capturedConfig = generationConfig;
              return _response(
                '{"intent":"unknown","requiresConfirmation":false}',
              );
            },
      );

      final response = await dataSource.sendMessage(_structuredRequest());

      expect(response.metadata['structuredOutput'], isTrue);
      expect(capturedConfig?.temperature, 0.1);
      expect(capturedConfig?.maxOutputTokens, 512);
      expect(capturedConfig?.responseMimeType, 'application/json');
      expect(capturedConfig?.responseSchema, isNotNull);
    });

    test(
      'ordinary safe replies do not force financial action schema',
      () async {
        firebase_ai.GenerationConfig? capturedConfig;
        final dataSource = FirebaseAiProviderDataSource(
          config: _config(),
          generateContent:
              ({
                required String modelId,
                required List<firebase_ai.Content> contents,
                firebase_ai.Content? systemInstruction,
                required firebase_ai.GenerationConfig generationConfig,
              }) async {
                capturedConfig = generationConfig;
                return _response('ready');
              },
        );

        await dataSource.sendMessage(_request());

        expect(capturedConfig?.responseMimeType, isNull);
        expect(capturedConfig?.responseSchema, isNull);
      },
    );

    test('invalid JSON is a typed safe failure', () async {
      final result = await _repositoryReturning(
        'not json',
      ).sendMessage(_structuredRequest());

      expect(result, isA<AppFailure<AiResponse>>());
      expect(
        (result as AppFailure<AiResponse>).failure.code,
        AiFailureCodes.invalidResponse,
      );
    });

    test('unsupported JSON schema is a typed safe failure', () async {
      final result = await _repositoryReturning(
        '{"intent":"unsupported","requiresConfirmation":false}',
      ).sendMessage(_structuredRequest());

      expect(result, isA<AppFailure<AiResponse>>());
      expect(
        (result as AppFailure<AiResponse>).failure.code,
        AiFailureCodes.unsupportedSchema,
      );
    });
  });

  group('Firebase AI Logic provider failures', () {
    test('rate limit is friendly, typed, and not retried', () async {
      var calls = 0;
      final repository = _repositoryThrowing(() {
        calls += 1;
        throw firebase_ai.QuotaExceeded('429 quota exceeded');
      });

      final result = await repository.sendMessage(_request());

      expect(calls, 1);
      expect(
        (result as AppFailure<AiResponse>).failure.code,
        AiFailureCodes.rateLimited,
      );
    });

    test('App Check rejection is friendly, typed, and not retried', () async {
      var calls = 0;
      final repository = _repositoryThrowing(() {
        calls += 1;
        throw firebase_ai.FirebaseAIException(
          'Server Error [403]: App Check attestation rejected',
        );
      });

      final result = await repository.sendMessage(_request());

      expect(calls, 1);
      expect(
        (result as AppFailure<AiResponse>).failure.code,
        AiFailureCodes.appCheckBlocked,
      );
    });

    test('generic permission denied is not mislabeled as App Check', () async {
      final repository = _repositoryThrowing(
        () => throw firebase_ai.FirebaseAIException(
          'Server Error [403]: permission_denied for model access',
        ),
      );

      final result = await repository.sendMessage(_request());

      expect(
        (result as AppFailure<AiResponse>).failure.code,
        AiFailureCodes.providerUnavailable,
      );
    });

    test('network timeout maps to localized failure code', () async {
      final repository = _repositoryThrowing(
        () => throw TimeoutException('request timed out'),
      );

      final result = await repository.sendMessage(_request());

      expect(
        (result as AppFailure<AiResponse>).failure.code,
        AiFailureCodes.networkFailure,
      );
    });

    test('web XMLHttpRequest failure maps to network failure', () async {
      final repository = _repositoryThrowing(
        () => throw Exception('ClientException: XMLHttpRequest error'),
      );

      final result = await repository.sendMessage(_request());

      expect(
        (result as AppFailure<AiResponse>).failure.code,
        AiFailureCodes.networkFailure,
      );
    });

    test('exhausted service-unavailable retries map safely', () async {
      var calls = 0;
      final repository = AiRepositoryImpl(
        providerDataSource: FirebaseAiProviderDataSource(
          config: _config(),
          generateContent:
              ({
                required String modelId,
                required List<firebase_ai.Content> contents,
                firebase_ai.Content? systemInstruction,
                required firebase_ai.GenerationConfig generationConfig,
              }) async {
                calls += 1;
                throw firebase_ai.FirebaseAIException(
                  'Server Error [503]: service unavailable',
                );
              },
          retryBackoff: const <Duration>[Duration.zero, Duration.zero],
          retryDelay: (_) async {},
        ),
        logger: AppLogger.instance,
      );

      final result = await repository.sendMessage(_request());

      expect(calls, 3);
      expect(
        (result as AppFailure<AiResponse>).failure.code,
        AiFailureCodes.providerUnavailable,
      );
    });

    test('unconfigured service maps to provider unavailable', () async {
      final repository = _repositoryThrowing(
        () => throw firebase_ai.ServiceApiNotEnabled('projects/test'),
      );

      final result = await repository.sendMessage(_request());

      expect(
        (result as AppFailure<AiResponse>).failure.code,
        AiFailureCodes.providerUnavailable,
      );
    });

    test('repository logs only safe labels and codes', () async {
      final logged = <String>[];
      final repository = AiRepositoryImpl(
        providerDataSource: FirebaseAiProviderDataSource(
          config: _config(),
          generateContent:
              ({
                required String modelId,
                required List<firebase_ai.Content> contents,
                firebase_ai.Content? systemInstruction,
                required firebase_ai.GenerationConfig generationConfig,
              }) async {
                throw Exception(
                  'secret@example.com 0912345678 token_abcdefghijklmnopqrstuvwxyz',
                );
              },
          retryBackoff: const <Duration>[],
        ),
        logger: AppLogger.instance,
        safeErrorLog: logged.add,
      );

      await repository.sendMessage(_request());

      expect(logged, hasLength(1));
      expect(logged.single, contains('AI provider operation failed safely'));
      expect(logged.single, contains(AiFailureCodes.unknown));
      expect(logged.single, isNot(contains('secret@example.com')));
      expect(logged.single, isNot(contains('0912345678')));
      expect(
        logged.single,
        isNot(contains('token_abcdefghijklmnopqrstuvwxyz')),
      );
    });
  });

  test(
    'only the current message and semantically safe context reach Firebase',
    () async {
      List<firebase_ai.Content>? capturedContents;
      firebase_ai.Content? capturedInstruction;
      final dataSource = FirebaseAiProviderDataSource(
        config: _config(),
        generateContent:
            ({
              required String modelId,
              required List<firebase_ai.Content> contents,
              firebase_ai.Content? systemInstruction,
              required firebase_ai.GenerationConfig generationConfig,
            }) async {
              capturedContents = contents;
              capturedInstruction = systemInstruction;
              return _response('ready');
            },
      );
      const conversationId = 'safe-test';
      final request = AiRequest(
        conversationId: conversationId,
        messages: <AiMessage>[
          AiMessage.user(
            conversationId: conversationId,
            content: 'old prompt uid=user-secret balance=5000',
          ),
          AiMessage.assistant(
            conversationId: conversationId,
            content: 'old response secret@example.com',
          ),
          AiMessage.system(
            conversationId: conversationId,
            content: 'untrusted system message phone=0912345678',
          ),
          AiMessage(
            id: 'tool-message',
            conversationId: conversationId,
            role: AiMessageRole.tool,
            content: 'secret tool payload balance=5000 uid=user-secret',
            createdAt: DateTime.utc(2026, 7, 19),
          ),
          AiMessage.user(
            conversationId: conversationId,
            content: 'hello current request',
          ),
        ],
        context: const <String, Object?>{
          'locale': 'en',
          'supportedCurrencies': <String>['LYD', 'USD', 'secret@example.com'],
          'accountAliases': <String>[
            'Daily account',
            'secret@example.com',
            'Account 0912345678',
            'هاتف ٠٩١٢٣٤٥٦٧٨',
            'حساب ۰۹۱۲۳۴۵۶۷۸',
            'users/private/documents/secret',
          ],
          'categoryNames': <String>[
            'Groceries',
            'فئة ٠١٢٣٤٥٦٧',
            'token_abcdefghijklmnopqrstuvwxyz',
          ],
          'uid': 'user-secret',
          'email': 'secret@example.com',
          'balance': 5000,
          'payeeAliases': <String>['Private Payee'],
        },
      );

      await dataSource.sendMessage(request);

      final sent =
          <firebase_ai.Content>[...capturedContents!, ?capturedInstruction]
              .expand((content) => content.parts)
              .whereType<firebase_ai.TextPart>()
              .map((part) => part.text)
              .join('\n')
              .toLowerCase();
      expect(sent, contains('hello current request'));
      expect(sent, contains('locale'));
      expect(sent, contains('daily account'));
      expect(sent, contains('groceries'));
      expect(sent, isNot(contains('secret tool payload')));
      expect(sent, isNot(contains('old prompt')));
      expect(sent, isNot(contains('old response')));
      expect(sent, isNot(contains('untrusted system')));
      expect(sent, isNot(contains('user-secret')));
      expect(sent, isNot(contains('secret@example.com')));
      expect(sent, isNot(contains('5000')));
      expect(sent, isNot(contains('0912345678')));
      expect(sent, isNot(contains('٠٩١٢٣٤٥٦٧٨')));
      expect(sent, isNot(contains('۰۹۱۲۳۴۵۶۷۸')));
      expect(sent, isNot(contains('٠١٢٣٤٥٦٧')));
      expect(sent, isNot(contains('users/private')));
      expect(sent, isNot(contains('token_abcdefghijklmnopqrstuvwxyz')));
      expect(sent, isNot(contains('private payee')));
    },
  );
}

FirebaseAiConfig _config() {
  return FirebaseAiConfig.fromModelConfig(
    const AiModelConfig(
      modelName: AiModelConfig.defaultEconomicalModel,
      temperature: 0.1,
      maxOutputTokens: 512,
      structuredOutputEnabled: true,
      streamingEnabled: false,
      requestTimeout: Duration(seconds: 1),
    ),
  );
}

AiRepositoryImpl _repositoryReturning(String text) {
  return AiRepositoryImpl(
    providerDataSource: FirebaseAiProviderDataSource(
      config: _config(),
      generateContent:
          ({
            required String modelId,
            required List<firebase_ai.Content> contents,
            firebase_ai.Content? systemInstruction,
            required firebase_ai.GenerationConfig generationConfig,
          }) async => _response(text),
    ),
    logger: AppLogger.instance,
  );
}

AiRepositoryImpl _repositoryThrowing(Object Function() error) {
  return AiRepositoryImpl(
    providerDataSource: FirebaseAiProviderDataSource(
      config: _config(),
      generateContent:
          ({
            required String modelId,
            required List<firebase_ai.Content> contents,
            firebase_ai.Content? systemInstruction,
            required firebase_ai.GenerationConfig generationConfig,
          }) async {
            error();
            return _response('unreachable');
          },
      retryBackoff: const <Duration>[],
    ),
    logger: AppLogger.instance,
  );
}

AiRequest _request() {
  const conversationId = 'conversation';
  return AiRequest(
    conversationId: conversationId,
    messages: <AiMessage>[
      AiMessage.user(conversationId: conversationId, content: 'hello'),
    ],
  );
}

AiRequest _structuredRequest() {
  const conversationId = 'structured';
  return AiRequest(
    conversationId: conversationId,
    messages: <AiMessage>[
      AiMessage.user(conversationId: conversationId, content: 'question'),
    ],
    metadata: const <String, Object?>{'output': 'structured_action'},
  );
}

firebase_ai.GenerateContentResponse _response(String text) {
  return firebase_ai.GenerateContentResponse(<firebase_ai.Candidate>[
    firebase_ai.Candidate(
      firebase_ai.Content.model(<firebase_ai.Part>[firebase_ai.TextPart(text)]),
      null,
      null,
      firebase_ai.FinishReason.stop,
      null,
    ),
  ], null);
}
