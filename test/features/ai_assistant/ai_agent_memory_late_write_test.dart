import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cashpilot_ai/core/storage/settings_local_data_source.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

const _scopeA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _scopeB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _bindingA1 = AiToolOwnerScopeBinding(accountScope: _scopeA, epoch: 1);
const _bindingA2 = AiToolOwnerScopeBinding(accountScope: _scopeA, epoch: 2);
const _bindingB = AiToolOwnerScopeBinding(accountScope: _scopeB, epoch: 1);

final _bindingStateProvider = StateProvider<AiToolOwnerScopeBinding?>(
  (_) => _bindingA1,
);

void main() {
  late Directory directory;
  late Box<dynamic> box;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'cashpilot_ai_memory_late_write_',
    );
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('settings');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final transition in <({String name, AiToolOwnerScopeBinding? middle})>[
    (name: 'A to B to A', middle: _bindingB),
    (name: 'logout then relogin A', middle: null),
  ]) {
    test(
      'old delayed response cannot overwrite new A memory after ${transition.name}',
      () async {
        final fence = BackupOperationFence();
        AiToolOwnerScopeBinding? current = _bindingA1;
        final store = HiveAiAgentMemoryStore(
          settingsBox: box,
          persistenceEnabled: true,
          accountScope: sha256.convert(utf8.encode(_scopeA)).toString(),
        );
        final delayed = _ControlledModelGateway();
        final oldOperation = _orchestrator(
          memoryStore: store,
          gateway: delayed,
          binding: _bindingA1,
          currentBinding: () => current,
          fence: fence,
        ).respond(_request('Explain ocean tides simply.'));
        await delayed.started.future;

        current = transition.middle;
        current = _bindingA2;
        await _orchestrator(
          memoryStore: store,
          gateway: _ImmediateModelGateway('New A response'),
          binding: _bindingA2,
          currentBinding: () => current,
          fence: fence,
        ).respond(_request('Describe a rainbow simply.'));

        delayed.complete('Old A response');
        await oldOperation;

        final contents = (await store.read()).messages
            .map((message) => message.content)
            .toList(growable: false);
        expect(
          contents,
          containsAll(<String>['Describe a rainbow simply.', 'New A response']),
        );
        expect(contents, isNot(contains('Explain ocean tides simply.')));
        expect(contents, isNot(contains('Old A response')));
      },
    );
  }

  test('owner epoch is rechecked at delayed memory-store commit', () async {
    final fence = BackupOperationFence();
    AiToolOwnerScopeBinding? current = _bindingA1;
    final store = _DelayedFirstSaveMemoryStore();
    final oldOperation = _orchestrator(
      memoryStore: store,
      gateway: _ImmediateModelGateway('Old A response'),
      binding: _bindingA1,
      currentBinding: () => current,
      fence: fence,
    ).respond(_request('Explain ocean tides simply.'));
    await store.firstSaveStarted.future;

    current = _bindingB;
    current = _bindingA2;
    await _orchestrator(
      memoryStore: store,
      gateway: _ImmediateModelGateway('New A response'),
      binding: _bindingA2,
      currentBinding: () => current,
      fence: fence,
    ).respond(_request('Describe a rainbow simply.'));

    store.finishFirstSave();
    await oldOperation;

    final contents = (await store.read()).messages
        .map((message) => message.content)
        .toList(growable: false);
    expect(contents, contains('New A response'));
    expect(contents, isNot(contains('Old A response')));
  });

  test('bound orchestrator without owner guards fails closed', () async {
    final store = InMemoryAiAgentMemoryStore();
    final response = await AiAgentOrchestratorImpl(
      toolRegistry: const _EmptyToolRegistry(),
      memoryStore: store,
      memoryCompactor: const DefaultAiAgentMemoryCompactor(),
      modelRouter: const DefaultAiAgentModelRouter(),
      contextSanitizer: const DefaultAiAgentContextSanitizer(),
      responseComposer: const DefaultAiAgentResponseComposer(),
      modelGateway: const _ImmediateModelGateway('must not run'),
      providerEgressGuardFactory: (_) => testAiProviderEgressGuard,
      toolOwnerScope: _bindingA1,
    ).respond(_request('Explain ocean tides simply.'));

    expect(response.kind, AiAgentResponseKind.failure);
    expect((await store.read()).messages, isEmpty);
  });

  test(
    'deletion fence drains delayed response before purge and memory stays absent',
    () async {
      final fence = BackupOperationFence();
      AiToolOwnerScopeBinding? current = _bindingA1;
      final store = HiveAiAgentMemoryStore(
        settingsBox: box,
        persistenceEnabled: true,
        accountScope: sha256.convert(utf8.encode(_scopeA)).toString(),
      );
      await store.save(_memory('Existing A memory'));
      final delayed = _ControlledModelGateway();
      final response = _orchestrator(
        memoryStore: store,
        gateway: delayed,
        binding: _bindingA1,
        currentBinding: () => current,
        fence: fence,
      ).respond(_request('Explain ocean tides simply.'));
      await delayed.started.future;

      final purgeCompleted = Completer<void>();
      final deletion = () async {
        final lease = await fence.fenceAndDrain(
          ownerScopeValue: _scopeA,
          operationId: 'delete-memory-race',
        );
        await store.clear();
        purgeCompleted.complete();
        return lease;
      }();
      await _waitUntil(() => fence.isFenced(_scopeA));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      delayed.complete('Old A response');
      await response;
      final deletionLease = await deletion;
      await purgeCompleted.future;
      deletionLease.release();

      expect((await store.read()).messages, isEmpty);
    },
  );

  test(
    'old A memory preference cannot update new A state or persisted flag',
    () async {
      final settings = _DelayedMemoryPreferenceSettings(box);
      final fence = BackupOperationFence();
      final container = ProviderContainer(
        overrides: [
          aiToolOwnerScopeBindingProvider.overrideWith(
            (ref) => ref.watch(_bindingStateProvider),
          ),
          settingsLocalDataSourceProvider.overrideWithValue(settings),
          backupOperationFenceProvider.overrideWithValue(fence),
          aiAgentFeatureFlagsProvider.overrideWithValue(
            const AiAgentFeatureFlags(
              agentEnabled: true,
              readOnlyToolsEnabled: true,
              draftToolsEnabled: true,
              conversationMemoryEnabled: true,
              complexPlanningEnabled: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(aiAgentMemoryPreferenceControllerProvider),
        isFalse,
      );
      expect(
        settings.readAiAgentMemoryPersistenceEnabled(accountScope: _scopeA),
        isFalse,
      );

      final oldSave = container
          .read(aiAgentMemoryPreferenceControllerProvider.notifier)
          .setPersistence(true);
      await settings.saveStarted.future;
      container.read(_bindingStateProvider.notifier).state = _bindingA2;
      await pumpEventQueue();
      expect(
        container.read(aiAgentMemoryPreferenceControllerProvider),
        isFalse,
      );

      settings.finishSave();
      await oldSave;
      expect(
        container.read(aiAgentMemoryPreferenceControllerProvider),
        isFalse,
      );
      expect(
        settings.readAiAgentMemoryPersistenceEnabled(accountScope: _scopeA),
        isFalse,
      );
    },
  );

  test('old A clear-history cannot delete new-session A memory', () async {
    final store = _DelayedClearMemoryStore(_memory('Old A memory'));
    final fence = BackupOperationFence();
    final container = ProviderContainer(
      overrides: [
        aiToolOwnerScopeBindingProvider.overrideWith(
          (ref) => ref.watch(_bindingStateProvider),
        ),
        aiAgentMemoryStoreProvider.overrideWithValue(store),
        backupOperationFenceProvider.overrideWithValue(fence),
      ],
    );
    addTearDown(container.dispose);

    final oldClear = container
        .read(aiAgentMemoryPreferenceControllerProvider.notifier)
        .clearHistory();
    await store.clearStarted.future;
    container.read(_bindingStateProvider.notifier).state = _bindingA2;
    await store.save(_memory('New A memory'));

    store.finishClear();
    await oldClear;
    expect((await store.read()).messages.single.content, 'New A memory');
  });
}

AiAgentOrchestrator _orchestrator({
  required AiAgentMemoryStore memoryStore,
  required AiAgentModelGateway gateway,
  required AiToolOwnerScopeBinding binding,
  required AiToolOwnerScopeReader currentBinding,
  required BackupOperationFence fence,
}) {
  return AiAgentOrchestratorImpl(
    toolRegistry: const _EmptyToolRegistry(),
    memoryStore: memoryStore,
    memoryCompactor: const DefaultAiAgentMemoryCompactor(),
    modelRouter: const DefaultAiAgentModelRouter(),
    contextSanitizer: const DefaultAiAgentContextSanitizer(),
    responseComposer: const DefaultAiAgentResponseComposer(),
    modelGateway: gateway,
    providerEgressGuardFactory: (_) => testAiProviderEgressGuard,
    toolOwnerScope: binding,
    currentToolOwnerScope: currentBinding,
    operationFence: fence,
  );
}

AiAgentRequest _request(String message) =>
    AiAgentRequest(message: message, locale: 'en', baseCurrencyCode: 'LYD');

AiAgentSessionMemory _memory(String content) => AiAgentSessionMemory(
  messages: <AiAgentMessage>[
    AiAgentMessage(
      role: AiAgentMessageRole.user,
      content: content,
      createdAt: DateTime.utc(2026, 8, 10),
    ),
  ],
);

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Condition was not reached.');
}

final class _EmptyToolRegistry implements AiToolRegistry {
  const _EmptyToolRegistry();

  @override
  List<AiToolDefinition> get definitions => const <AiToolDefinition>[];

  @override
  AiToolDefinition? definitionFor(String name) => null;

  @override
  Future<AiToolResult> execute(
    AiAgentToolCall call,
    AiToolExecutionContext context,
  ) {
    throw UnimplementedError();
  }
}

final class _ImmediateModelGateway implements AiAgentModelGateway {
  const _ImmediateModelGateway(this.text);

  final String text;

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async => _ImmediateModelSession(text);
}

final class _ImmediateModelSession implements AiAgentModelSession {
  const _ImmediateModelSession(this.text);

  final String text;

  @override
  Future<AiAgentModelTurn> sendInitial() async => AiAgentModelTurn(text: text);

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async => AiAgentModelTurn(text: text);
}

final class _ControlledModelGateway implements AiAgentModelGateway {
  final Completer<void> started = Completer<void>();
  final Completer<AiAgentModelTurn> _result = Completer<AiAgentModelTurn>();

  void complete(String text) => _result.complete(AiAgentModelTurn(text: text));

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async => _ControlledModelSession(this);
}

final class _ControlledModelSession implements AiAgentModelSession {
  const _ControlledModelSession(this.gateway);

  final _ControlledModelGateway gateway;

  @override
  Future<AiAgentModelTurn> sendInitial() {
    if (!gateway.started.isCompleted) gateway.started.complete();
    return gateway._result.future;
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) => sendInitial();
}

final class _DelayedFirstSaveMemoryStore implements AiAgentMemoryStore {
  AiAgentSessionMemory _memory = const AiAgentSessionMemory();
  int _saveCount = 0;
  final Completer<void> firstSaveStarted = Completer<void>();
  final Completer<void> _finishFirst = Completer<void>();

  void finishFirstSave() => _finishFirst.complete();

  @override
  Future<AiAgentSessionMemory> read({AiAgentMemoryAccess? access}) async {
    access?.assertActive();
    return _memory;
  }

  @override
  Future<void> save(
    AiAgentSessionMemory memory, {
    AiAgentMemoryAccess? access,
  }) async {
    _saveCount += 1;
    if (_saveCount == 1) {
      firstSaveStarted.complete();
      await _finishFirst.future;
    }
    access?.assertActive();
    _memory = memory;
  }

  @override
  Future<void> clear({AiAgentMemoryAccess? access}) async {
    access?.assertActive();
    _memory = const AiAgentSessionMemory();
  }
}

final class _DelayedClearMemoryStore implements AiAgentMemoryStore {
  _DelayedClearMemoryStore(this._memory);

  AiAgentSessionMemory _memory;
  final Completer<void> clearStarted = Completer<void>();
  final Completer<void> _finish = Completer<void>();

  void finishClear() => _finish.complete();

  @override
  Future<AiAgentSessionMemory> read({AiAgentMemoryAccess? access}) async {
    access?.assertActive();
    return _memory;
  }

  @override
  Future<void> save(
    AiAgentSessionMemory memory, {
    AiAgentMemoryAccess? access,
  }) async {
    access?.assertActive();
    _memory = memory;
  }

  @override
  Future<void> clear({AiAgentMemoryAccess? access}) async {
    clearStarted.complete();
    await _finish.future;
    access?.assertActive();
    _memory = const AiAgentSessionMemory();
  }
}

final class _DelayedMemoryPreferenceSettings extends SettingsLocalDataSource {
  _DelayedMemoryPreferenceSettings(super.box);

  final Completer<void> saveStarted = Completer<void>();
  final Completer<void> _finish = Completer<void>();

  void finishSave() => _finish.complete();

  @override
  Future<void> saveAiAgentMemoryPersistenceEnabled({
    required String accountScope,
    required bool enabled,
    void Function()? assertWriteAllowed,
  }) async {
    saveStarted.complete();
    await _finish.future;
    await super.saveAiAgentMemoryPersistenceEnabled(
      accountScope: accountScope,
      enabled: enabled,
      assertWriteAllowed: assertWriteAllowed,
    );
  }
}
