import 'dart:async';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_assistant_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/firebase_ai_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/datasources/ai_provider_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/datasources/firebase_ai_provider_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/datasources/local_parser_only_ai_provider_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/datasources/mock_ai_provider_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/repositories/ai_repository_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_message.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_model.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_provider_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_request.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_response.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/failures/ai_failure_codes.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:drift/native.dart';
import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockAiProviderDataSource', () {
    test('exposes a default provider-agnostic finance model', () async {
      const dataSource = MockAiProviderDataSource();

      final models = await dataSource.getAvailableModels();

      expect(models, hasLength(1));
      expect(models.single.id, MockAiProviderDataSource.defaultModelId);
      expect(models.single.providerType, AiProviderType.mock);
      expect(models.single.isDefault, isTrue);
      expect(models.single.supports(AiCapability.financialInsights), isTrue);
      expect(models.single.supports(AiCapability.transactionParsing), isTrue);
    });

    test('generates a deterministic mock assistant response', () async {
      const dataSource = MockAiProviderDataSource();
      const conversationId = 'conversation-1';
      final request = AiRequest(
        conversationId: conversationId,
        messages: <AiMessage>[
          AiMessage.user(
            conversationId: conversationId,
            content: 'Analyze my spending this month',
          ),
        ],
      );

      final response = await dataSource.sendMessage(request);

      expect(response.providerType, AiProviderType.mock);
      expect(response.modelId, MockAiProviderDataSource.defaultModelId);
      expect(response.finishReason, AiFinishReason.complete);
      expect(response.message.role, AiMessageRole.assistant);
      expect(response.message.conversationId, conversationId);
      expect(response.message.content, contains('spending'));
      expect(response.tokenUsage.totalTokens, greaterThan(0));
    });
  });

  group('AiRepositoryImpl', () {
    test('wraps provider success in AppSuccess', () async {
      final repository = AiRepositoryImpl(
        providerDataSource: const MockAiProviderDataSource(),
        logger: AppLogger.instance,
      );

      final result = await repository.getAvailableModels();

      expect(result, isA<AppSuccess<List<AiModel>>>());
    });

    test('maps provider errors to AppFailure', () async {
      final repository = AiRepositoryImpl(
        providerDataSource: const _ThrowingAiProviderDataSource(),
        logger: AppLogger.instance,
      );

      final result = await repository.getAvailableModels();

      expect(result, isA<AppFailure<List<AiModel>>>());
      expect(
        (result as AppFailure<List<AiModel>>).failure.message,
        'Unable to load AI models.',
      );
    });
  });

  group('FirebaseAiProviderDataSource retry', () {
    test(
      'forwards only allowlisted context in the system instruction',
      () async {
        firebase_ai.Content? capturedInstruction;
        final dataSource = FirebaseAiProviderDataSource(
          config: FirebaseAiConfig.current,
          generateContent:
              ({
                required String modelId,
                required List<firebase_ai.Content> contents,
                firebase_ai.Content? systemInstruction,
                required firebase_ai.GenerationConfig generationConfig,
              }) async {
                capturedInstruction = systemInstruction;
                return _firebaseAiResponse('ok');
              },
        );
        final request = _aiRequest(
          context: <String, Object?>{
            'locale': 'ar-LY',
            'supportedCurrencies': <String>['LYD', 'USD'],
            'accountAliases': <String>['Daily account'],
            'paymentMethodAliases': <String>['Edfaly'],
            'categoryNames': <String>['Groceries'],
            'payeeAliases': <String>['Al Nawar'],
            'uid': 'firebase-uid-secret',
            'email': 'secret@example.com',
            'balance': '999999',
          },
        );

        await dataSource.sendMessage(request);

        final instruction = capturedInstruction!;
        final text = (instruction.parts.single as firebase_ai.TextPart).text;
        expect(text, contains('Daily account'));
        expect(text, contains('LYD'));
        expect(text, contains('Edfaly'));
        expect(text, isNot(contains('Al Nawar')));
        expect(text, isNot(contains('firebase-uid-secret')));
        expect(text, isNot(contains('secret@example.com')));
        expect(text, isNot(contains('999999')));
      },
    );

    test('retries transient 500 errors before returning a response', () async {
      var attempts = 0;
      final delays = <Duration>[];
      final dataSource = FirebaseAiProviderDataSource(
        config: FirebaseAiConfig.current,
        generateContent:
            ({
              required String modelId,
              required List<firebase_ai.Content> contents,
              firebase_ai.Content? systemInstruction,
              required firebase_ai.GenerationConfig generationConfig,
            }) async {
              attempts += 1;
              if (attempts < 3) {
                throw firebase_ai.FirebaseAIException(
                  'Server Error [500]: {"error":{"status":"INTERNAL"}}',
                );
              }

              return _firebaseAiResponse('Hello from Gemini');
            },
        retryDelay: (duration) async {
          delays.add(duration);
        },
      );

      final response = await dataSource.sendMessage(_aiRequest());

      expect(attempts, 3);
      expect(delays, <Duration>[
        const Duration(milliseconds: 250),
        const Duration(milliseconds: 500),
      ]);
      expect(response.message.content, 'Hello from Gemini');
    });

    test(
      'returns friendly failure after retryable errors are exhausted',
      () async {
        var attempts = 0;
        final delays = <Duration>[];
        final dataSource = FirebaseAiProviderDataSource(
          config: FirebaseAiConfig.current,
          generateContent:
              ({
                required String modelId,
                required List<firebase_ai.Content> contents,
                firebase_ai.Content? systemInstruction,
                required firebase_ai.GenerationConfig generationConfig,
              }) async {
                attempts += 1;
                throw firebase_ai.FirebaseAIException(
                  'Server Error [500]: {"error":{"status":"INTERNAL"}}',
                );
              },
          retryDelay: (duration) async {
            delays.add(duration);
          },
        );
        final repository = AiRepositoryImpl(
          providerDataSource: dataSource,
          logger: AppLogger.instance,
        );

        final result = await repository.sendMessage(_aiRequest());

        expect(attempts, 4);
        expect(delays, <Duration>[
          const Duration(milliseconds: 250),
          const Duration(milliseconds: 500),
          const Duration(seconds: 1),
        ]);
        expect(result, isA<AppFailure<AiResponse>>());
        expect(
          (result as AppFailure<AiResponse>).failure.message,
          firebaseAiTemporarilyBusyMessage,
        );
      },
    );
  });

  group('AiConversationController', () {
    test('debug and test dependency injection uses local parser only', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(defaultAiModelIdProvider),
        LocalParserOnlyAiProviderDataSource.modelId,
      );
      expect(
        container.read(aiProviderDataSourceProvider),
        isA<LocalParserOnlyAiProviderDataSource>(),
      );
    });

    test('sends a message through injected AI use cases', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final session = _ownerSession(database);
      final container = ProviderContainer(
        overrides: [
          currentAuthUserProvider.overrideWithValue(_ownerUser),
          scopedAppDatabaseSessionProvider.overrideWithValue(session),
          aiProviderDataSourceProvider.overrideWith(
            (_) => const MockAiProviderDataSource(),
          ),
          defaultAiModelIdProvider.overrideWith(
            (_) => MockAiProviderDataSource.defaultModelId,
          ),
        ],
      );
      addTearDown(container.dispose);

      final initial = container.read(aiConversationControllerProvider);
      expect(initial.providerType, AiProviderType.mock);
      expect(initial.conversation.messages, isEmpty);

      final result = await container
          .read(aiConversationControllerProvider.notifier)
          .sendMessage('Find savings opportunities');

      expect(result, isA<AppSuccess<AiMessage>>());
      final state = container.read(aiConversationControllerProvider);
      expect(state.isSending, isFalse);
      expect(state.failure, isNull);
      expect(state.conversation.messages, hasLength(2));
      expect(state.conversation.messages.first.role, AiMessageRole.user);
      expect(state.conversation.messages.last.role, AiMessageRole.assistant);
    });

    test('concurrent send is rejected and provider is called once', () async {
      final dataSource = _BlockingAiProviderDataSource();
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final session = _ownerSession(database);
      final container = ProviderContainer(
        overrides: [
          currentAuthUserProvider.overrideWithValue(_ownerUser),
          scopedAppDatabaseSessionProvider.overrideWithValue(session),
          aiProviderDataSourceProvider.overrideWith((_) => dataSource),
          defaultAiModelIdProvider.overrideWith((_) => 'blocking-model'),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        aiConversationControllerProvider.notifier,
      );

      final first = controller.sendMessage('first request');
      final second = await controller.sendMessage('second request');

      expect(second, isA<AppFailure<AiMessage>>());
      expect(
        (second as AppFailure<AiMessage>).failure.code,
        AiFailureCodes.requestInFlight,
      );
      expect(dataSource.sendCalls, 1);

      dataSource.complete();
      expect(await first, isA<AppSuccess<AiMessage>>());
      final messages = container
          .read(aiConversationControllerProvider)
          .conversation
          .messages;
      expect(messages.map((message) => message.role), <AiMessageRole>[
        AiMessageRole.user,
        AiMessageRole.assistant,
      ]);
    });
  });
}

const _ownerUser = AuthUser(
  uid: 'owner-a',
  emailVerified: true,
  isAnonymous: false,
  authSessionGeneration: 1,
);

ScopedAppDatabaseSession _ownerSession(AppDatabase database) =>
    ScopedAppDatabaseSession(
      database: database,
      scope: OwnerScopeDerivation.fromConfirmedFirebaseUid(_ownerUser.uid),
    );

AiRequest _aiRequest({
  Map<String, Object?> context = const <String, Object?>{},
}) {
  const conversationId = 'conversation-1';
  return AiRequest(
    conversationId: conversationId,
    messages: <AiMessage>[
      AiMessage.user(conversationId: conversationId, content: 'Hello'),
    ],
    context: context,
  );
}

firebase_ai.GenerateContentResponse _firebaseAiResponse(String text) {
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

class _ThrowingAiProviderDataSource implements AiProviderDataSource {
  const _ThrowingAiProviderDataSource();

  @override
  AiProviderType get providerType => AiProviderType.mock;

  @override
  Future<List<AiModel>> getAvailableModels() {
    throw StateError('Model loading failed.');
  }

  @override
  Future<AiResponse> sendMessage(AiRequest request) {
    throw StateError('Message sending failed.');
  }
}

class _BlockingAiProviderDataSource implements AiProviderDataSource {
  final _completer = Completer<AiResponse>();
  AiRequest? _request;
  int sendCalls = 0;

  @override
  AiProviderType get providerType => AiProviderType.mock;

  @override
  Future<List<AiModel>> getAvailableModels() async => <AiModel>[];

  @override
  Future<AiResponse> sendMessage(AiRequest request) {
    sendCalls += 1;
    _request = request;
    return _completer.future;
  }

  void complete() {
    final request = _request!;
    _completer.complete(
      AiResponse(
        message: AiMessage.assistant(
          conversationId: request.conversationId,
          content: 'ready',
        ),
        providerType: AiProviderType.mock,
        modelId: 'blocking-model',
        finishReason: AiFinishReason.complete,
        tokenUsage: const AiTokenUsage(inputTokens: 1, outputTokens: 1),
      ),
    );
  }
}
