import 'dart:async';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_assistant_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/datasources/ai_provider_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_message.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_model.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_provider_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_request.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_response.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _conversationAuthProvider = StateProvider<AuthUser?>((ref) => null);
final _conversationSessionProvider = StateProvider<ScopedAppDatabaseSession?>(
  (ref) => null,
);

void main() {
  test('late A assistant success is discarded after A to B', () async {
    final fixture = _ConversationFixture();
    addTearDown(fixture.dispose);
    await fixture.setOwner('owner-a', generation: 1);

    final send = fixture.controller.sendMessage('private A prompt');
    await fixture.dataSource.started.future;
    await fixture.setOwner('owner-b', generation: 2);
    fixture.dataSource.completeSuccess();

    expect(await send, isA<AppFailure<AiMessage>>());
    await fixture.pump();
    final state = fixture.container.read(aiConversationControllerProvider);
    expect(state.isSending, isFalse);
    expect(state.failure, isNull);
    expect(state.conversation.messages, isEmpty);
  });

  test('late A provider error is discarded after logout', () async {
    final fixture = _ConversationFixture();
    addTearDown(fixture.dispose);
    await fixture.setOwner('owner-a', generation: 8);

    final send = fixture.controller.sendMessage('private A prompt');
    await fixture.dataSource.started.future;
    await fixture.logout();
    fixture.dataSource.completeError(StateError('late private A response'));

    expect(await send, isA<AppFailure<AiMessage>>());
    await fixture.pump();
    final state = fixture.container.read(aiConversationControllerProvider);
    expect(state.isSending, isFalse);
    expect(state.failure, isNull);
    expect(state.conversation.messages, isEmpty);
  });
}

final class _ConversationFixture {
  _ConversationFixture() {
    database = AppDatabase(executor: NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        currentAuthUserProvider.overrideWith(
          (ref) => ref.watch(_conversationAuthProvider),
        ),
        scopedAppDatabaseSessionProvider.overrideWith(
          (ref) => ref.watch(_conversationSessionProvider),
        ),
        aiProviderDataSourceProvider.overrideWithValue(dataSource),
        defaultAiModelIdProvider.overrideWithValue('controlled-model'),
      ],
    );
    subscription = container.listen(
      aiConversationControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
  }

  final _ControlledAiProviderDataSource dataSource =
      _ControlledAiProviderDataSource();
  late final AppDatabase database;
  late final ProviderContainer container;
  late final ProviderSubscription<Object?> subscription;
  ScopedAppDatabaseSession? activeSession;

  AiConversationController get controller =>
      container.read(aiConversationControllerProvider.notifier);

  Future<void> setOwner(String uid, {required int generation}) async {
    activeSession?.invalidate();
    final session = ScopedAppDatabaseSession(
      database: database,
      scope: OwnerScopeDerivation.fromConfirmedFirebaseUid(uid),
    );
    activeSession = session;
    container.read(_conversationAuthProvider.notifier).state = AuthUser(
      uid: uid,
      emailVerified: true,
      isAnonymous: false,
      authSessionGeneration: generation,
    );
    container.read(_conversationSessionProvider.notifier).state = session;
    await pump();
  }

  Future<void> logout() async {
    activeSession?.invalidate();
    activeSession = null;
    container.read(_conversationAuthProvider.notifier).state = null;
    container.read(_conversationSessionProvider.notifier).state = null;
    await pump();
  }

  Future<void> pump() async {
    for (var index = 0; index < 8; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> dispose() async {
    subscription.close();
    container.dispose();
    await database.close();
  }
}

final class _ControlledAiProviderDataSource implements AiProviderDataSource {
  final Completer<void> started = Completer<void>();
  final Completer<AiResponse> result = Completer<AiResponse>();
  AiRequest? request;

  @override
  AiProviderType get providerType => AiProviderType.mock;

  @override
  Future<List<AiModel>> getAvailableModels() async => const <AiModel>[];

  @override
  Future<AiResponse> sendMessage(AiRequest request) {
    this.request = request;
    started.complete();
    return result.future;
  }

  void completeSuccess() {
    final captured = request!;
    result.complete(
      AiResponse(
        message: AiMessage.assistant(
          conversationId: captured.conversationId,
          content: 'private A answer',
        ),
        providerType: AiProviderType.mock,
        modelId: 'controlled-model',
        finishReason: AiFinishReason.complete,
        tokenUsage: const AiTokenUsage(inputTokens: 1, outputTokens: 1),
      ),
    );
  }

  void completeError(Object error) => result.completeError(error);
}
