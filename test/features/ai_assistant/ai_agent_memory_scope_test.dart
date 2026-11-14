import 'dart:convert';
import 'dart:io';

import 'package:cashpilot_ai/core/storage/settings_keys.dart';
import 'package:cashpilot_ai/core/storage/settings_local_data_source.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final _memoryOwnerScopeProvider = StateProvider<String?>((_) => _ownerA);

final _ownerA = OwnerScopeDerivation.fromConfirmedFirebaseUid(
  'synthetic-account-a',
).id.value;
final _ownerB = OwnerScopeDerivation.fromConfirmedFirebaseUid(
  'synthetic-account-b',
).id.value;

void main() {
  late Directory directory;
  late Box<dynamic> box;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'cashpilot_ai_memory_scope_',
    );
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('settings');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('account A memory consent does not opt account B in', () async {
    final firstAccount = _ownerA;
    final secondAccount = _ownerB;
    final settings = SettingsLocalDataSource(box);

    await settings.saveAiAgentMemoryPersistenceEnabled(
      accountScope: firstAccount,
      enabled: true,
    );

    expect(
      settings.readAiAgentMemoryPersistenceEnabled(accountScope: firstAccount),
      isTrue,
    );
    expect(
      settings.readAiAgentMemoryPersistenceEnabled(accountScope: secondAccount),
      isFalse,
    );
    final storedKeys = box.keys.whereType<String>().join('|');
    expect(storedKeys, isNot(contains(firstAccount)));
    expect(storedKeys, isNot(contains(secondAccount)));
  });

  test('persisted assistant memory never crosses account scopes', () async {
    final firstScopeHash = sha256.convert(utf8.encode(_ownerA)).toString();
    final secondScopeHash = sha256.convert(utf8.encode(_ownerB)).toString();

    final firstAccount = HiveAiAgentMemoryStore(
      settingsBox: box,
      persistenceEnabled: true,
      accountScope: firstScopeHash,
    );
    final secondAccount = HiveAiAgentMemoryStore(
      settingsBox: box,
      persistenceEnabled: true,
      accountScope: secondScopeHash,
    );
    await firstAccount.save(
      AiAgentSessionMemory(
        messages: <AiAgentMessage>[
          AiAgentMessage(
            role: AiAgentMessageRole.user,
            content: 'Synthetic account-scoped message',
            createdAt: DateTime.utc(2026, 7, 28),
          ),
        ],
      ),
    );
    await secondAccount.save(
      AiAgentSessionMemory(
        messages: <AiAgentMessage>[
          AiAgentMessage(
            role: AiAgentMessageRole.user,
            content: 'Second synthetic account-scoped message',
            createdAt: DateTime.utc(2026, 7, 29),
          ),
        ],
      ),
    );

    expect((await firstAccount.read()).messages, hasLength(1));
    expect(
      (await firstAccount.read()).messages.single.content,
      'Synthetic account-scoped message',
    );
    expect((await secondAccount.read()).messages, hasLength(1));
    expect(
      box.containsKey(SettingsKeys.aiAgentMemoryForScopeHash(firstScopeHash)),
      isTrue,
    );
    expect(
      box.containsKey(SettingsKeys.aiAgentMemoryForScopeHash(secondScopeHash)),
      isTrue,
    );
  });

  test(
    'A to B to logout to A restores only the current owner memory',
    () async {
      final ownerA = _ownerA;
      final ownerB = _ownerB;
      final settings = SettingsLocalDataSource(box);
      await settings.saveAiAgentMemoryPersistenceEnabled(
        accountScope: ownerA,
        enabled: true,
      );
      await settings.saveAiAgentMemoryPersistenceEnabled(
        accountScope: ownerB,
        enabled: true,
      );
      final container = ProviderContainer(
        overrides: [
          aiAgentAccountScopeProvider.overrideWith(
            (ref) => ref.watch(_memoryOwnerScopeProvider),
          ),
          settingsLocalDataSourceProvider.overrideWithValue(settings),
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

      await container
          .read(aiAgentMemoryStoreProvider)
          .save(
            AiAgentSessionMemory(
              messages: <AiAgentMessage>[
                AiAgentMessage(
                  role: AiAgentMessageRole.user,
                  content: 'Synthetic memory A',
                  createdAt: DateTime.utc(2026, 8, 10),
                ),
              ],
            ),
          );
      container.read(_memoryOwnerScopeProvider.notifier).state = ownerB;
      expect(
        (await container.read(aiAgentMemoryStoreProvider).read()).messages,
        isEmpty,
      );
      await container
          .read(aiAgentMemoryStoreProvider)
          .save(
            AiAgentSessionMemory(
              messages: <AiAgentMessage>[
                AiAgentMessage(
                  role: AiAgentMessageRole.user,
                  content: 'Synthetic memory B',
                  createdAt: DateTime.utc(2026, 8, 10),
                ),
              ],
            ),
          );

      container.read(_memoryOwnerScopeProvider.notifier).state = null;
      final loggedOutStore = container.read(aiAgentMemoryStoreProvider);
      expect((await loggedOutStore.read()).messages, isEmpty);
      await loggedOutStore.save(
        AiAgentSessionMemory(
          messages: <AiAgentMessage>[
            AiAgentMessage(
              role: AiAgentMessageRole.user,
              content: 'Synthetic logged-out memory',
              createdAt: DateTime.utc(2026, 8, 10),
            ),
          ],
        ),
      );

      container.read(_memoryOwnerScopeProvider.notifier).state = ownerA;
      final restoredA = await container.read(aiAgentMemoryStoreProvider).read();
      expect(restoredA.messages.single.content, 'Synthetic memory A');
      container.read(_memoryOwnerScopeProvider.notifier).state = ownerB;
      final restoredB = await container.read(aiAgentMemoryStoreProvider).read();
      expect(restoredB.messages.single.content, 'Synthetic memory B');
    },
  );
}
