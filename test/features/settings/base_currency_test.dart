import 'dart:async';
import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/database/app_database_provider.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/storage/settings_local_data_source.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/core/sync/application/sync_mutation_queue.dart';
import 'package:cashpilot_ai/core/sync/application/sync_providers.dart';
import 'package:cashpilot_ai/core/sync/domain/sync_types.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/deletion_preferences_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/base_currency_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'cashpilot-base-currency-',
    );
    Hive.init(tempDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('defaults to LYD and persists a supported base currency', () async {
    var box = await Hive.openBox<dynamic>('base-currency-test');
    var dataSource = SettingsLocalDataSource(box);

    expect(dataSource.readBaseCurrencyCode(), 'LYD');
    await dataSource.saveBaseCurrencyCode('usd');
    await box.close();

    box = await Hive.openBox<dynamic>('base-currency-test');
    dataSource = SettingsLocalDataSource(box);
    expect(dataSource.readBaseCurrencyCode(), 'USD');
  });

  test('unsupported base currency safely falls back to LYD', () async {
    final box = await Hive.openBox<dynamic>('base-currency-invalid-test');
    final dataSource = SettingsLocalDataSource(box);

    await dataSource.saveBaseCurrencyCode('XYZ');

    expect(dataSource.readBaseCurrencyCode(), 'LYD');
  });

  test(
    'authenticated B never inherits A or legacy global base currency',
    () async {
      final box = await Hive.openBox<dynamic>('base-currency-owner-scope');
      final settings = SettingsLocalDataSource(box);
      final ownerA = OwnerScopeDerivation.fromConfirmedFirebaseUid('owner-a');
      await settings.saveBaseCurrencyCode('USD');
      await settings.saveOwnerBaseCurrencyCode(ownerA, 'USD');
      final authEvents = StreamController<AuthUser?>.broadcast(sync: true);
      addTearDown(authEvents.close);
      final container = ProviderContainer(
        overrides: [
          settingsLocalDataSourceProvider.overrideWithValue(settings),
          authStateProvider.overrideWith((ref) => authEvents.stream),
          ownerScopeDetachServiceProvider.overrideWithValue(
            const _NoopOwnerScopeDetachService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final seen = <String>[];
      final subscription = container.listen(
        effectiveBaseCurrencyCodeProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      authEvents.add(_authUser('owner-a'));
      await _pumpAsync();
      expect(container.read(effectiveBaseCurrencyCodeProvider), 'USD');

      authEvents.add(null);
      await _pumpAsync();
      authEvents.add(_authUser('owner-b'));
      final bStart = seen.length;
      await _pumpAsync();

      expect(container.read(effectiveBaseCurrencyCodeProvider), 'LYD');
      expect(seen.skip(bStart), isNot(contains('USD')));

      authEvents.add(_authUser('anonymous-c', isAnonymous: true));
      final anonymousStart = seen.length;
      await _pumpAsync();
      expect(container.read(effectiveBaseCurrencyCodeProvider), 'LYD');
      expect(seen.skip(anonymousStart), isNot(contains('USD')));
    },
  );

  test(
    'deletion fence drains an in-flight scoped currency write before preferences clear it',
    () async {
      final box = await Hive.openBox<dynamic>('base-currency-writer-fence');
      final saveStarted = Completer<void>();
      final releaseSave = Completer<void>();
      final settings = _DelayedOwnerCurrencySettings(
        box,
        saveStarted: saveStarted,
        releaseSave: releaseSave,
      );
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final fence = BackupOperationFence();
      final queue = _TrackingSyncMutationQueue();
      final authEvents = StreamController<AuthUser?>.broadcast(sync: true);
      addTearDown(authEvents.close);
      final container = ProviderContainer(
        overrides: [
          settingsLocalDataSourceProvider.overrideWithValue(settings),
          appDatabaseProvider.overrideWithValue(database),
          backupOperationFenceProvider.overrideWithValue(fence),
          syncMutationQueueProvider.overrideWithValue(queue),
          authStateProvider.overrideWith((ref) => authEvents.stream),
          ownerScopeDetachServiceProvider.overrideWithValue(
            const _NoopOwnerScopeDetachService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final scopeSubscription = container.listen(
        confirmedOwnerScopeSnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(scopeSubscription.close);
      final user = _authUser('owner-a');
      authEvents.add(user);
      await _pumpAsync();
      expect(
        container.read(confirmedOwnerScopeSnapshotProvider).status,
        OwnerScopeStatus.safe,
      );

      final write = container
          .read(baseCurrencyControllerProvider.notifier)
          .setBaseCurrencyCode('USD', expectedSession: user.sessionIdentity);
      await saveStarted.future;
      final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid('owner-a');
      final deletion = fence.fenceAndDrain(
        ownerScopeValue: scope.id.value,
        operationId: 'currency-delete-operation',
      );
      releaseSave.complete();
      expect(await write, isFalse);
      final deletionLease = await deletion;
      await HiveDeletionPreferencesDataSource(
        box,
      ).clearForIdentity(_identity('owner-a'));
      deletionLease.release();

      expect(settings.readOwnerBaseCurrencyCode(scope), isNull);
      expect(queue.upserts, 0);
    },
  );

  test(
    'paused A currency write cannot enqueue for or become visible to B',
    () async {
      final box = await Hive.openBox<dynamic>('base-currency-owner-race');
      final saveStarted = Completer<void>();
      final releaseSave = Completer<void>();
      final settings = _DelayedOwnerCurrencySettings(
        box,
        saveStarted: saveStarted,
        releaseSave: releaseSave,
      );
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final queue = _TrackingSyncMutationQueue();
      final authEvents = StreamController<AuthUser?>.broadcast(sync: true);
      addTearDown(authEvents.close);
      final container = ProviderContainer(
        overrides: [
          settingsLocalDataSourceProvider.overrideWithValue(settings),
          appDatabaseProvider.overrideWithValue(database),
          backupOperationFenceProvider.overrideWithValue(
            BackupOperationFence(),
          ),
          syncMutationQueueProvider.overrideWithValue(queue),
          authStateProvider.overrideWith((ref) => authEvents.stream),
          ownerScopeDetachServiceProvider.overrideWithValue(
            const _NoopOwnerScopeDetachService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        effectiveBaseCurrencyCodeProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final userA = _authUser('owner-a');
      authEvents.add(userA);
      await _pumpAsync();

      final write = container
          .read(baseCurrencyControllerProvider.notifier)
          .setBaseCurrencyCode('USD', expectedSession: userA.sessionIdentity);
      await saveStarted.future;
      authEvents.add(_authUser('owner-b'));
      await _pumpAsync();
      releaseSave.complete();

      expect(await write, isFalse);
      expect(queue.upserts, 0);
      expect(
        settings.readOwnerBaseCurrencyCode(
          OwnerScopeDerivation.fromConfirmedFirebaseUid('owner-b'),
        ),
        isNull,
      );
      expect(container.read(effectiveBaseCurrencyCodeProvider), 'LYD');
    },
  );

  test(
    'authenticated A currency update never becomes the logout or anonymous B default',
    () async {
      final box = await Hive.openBox<dynamic>('base-currency-no-global-leak');
      final settings = SettingsLocalDataSource(box);
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final authEvents = StreamController<AuthUser?>.broadcast(sync: true);
      addTearDown(authEvents.close);
      final container = ProviderContainer(
        overrides: [
          settingsLocalDataSourceProvider.overrideWithValue(settings),
          appDatabaseProvider.overrideWithValue(database),
          backupOperationFenceProvider.overrideWithValue(
            BackupOperationFence(),
          ),
          syncMutationQueueProvider.overrideWithValue(
            _TrackingSyncMutationQueue(),
          ),
          authStateProvider.overrideWith((ref) => authEvents.stream),
          ownerScopeDetachServiceProvider.overrideWithValue(
            const _NoopOwnerScopeDetachService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        effectiveBaseCurrencyCodeProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final userA = _authUser('owner-a');
      authEvents.add(userA);
      await _pumpAsync();

      expect(
        await container
            .read(baseCurrencyControllerProvider.notifier)
            .setBaseCurrencyCode('USD', expectedSession: userA.sessionIdentity),
        isTrue,
      );
      expect(container.read(effectiveBaseCurrencyCodeProvider), 'USD');
      expect(container.read(baseCurrencyControllerProvider), 'LYD');
      expect(settings.readBaseCurrencyCode(), 'LYD');

      authEvents.add(null);
      await _pumpAsync();
      expect(container.read(effectiveBaseCurrencyCodeProvider), 'LYD');
      authEvents.add(_authUser('anonymous-b', isAnonymous: true));
      await _pumpAsync();
      expect(container.read(effectiveBaseCurrencyCodeProvider), 'LYD');
    },
  );
}

AuthUser _authUser(String uid, {bool isAnonymous = false}) => AuthUser(
  uid: uid,
  emailVerified: !isAnonymous,
  isAnonymous: isAnonymous,
  authSessionGeneration: 1,
);

TrustedDeletionIdentity _identity(String uid) => TrustedDeletionIdentity(
  authSessionId: 'session-$uid',
  authStateGeneration: 1,
  userId: uid,
  isAnonymous: false,
  ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid(uid),
);

Future<void> _pumpAsync() async {
  for (var index = 0; index < 12; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _NoopOwnerScopeDetachService implements OwnerScopeDetachService {
  const _NoopOwnerScopeDetachService();

  @override
  Future<void> detach(String ownerScopeValue) async {}
}

final class _DelayedOwnerCurrencySettings extends SettingsLocalDataSource {
  _DelayedOwnerCurrencySettings(
    super.box, {
    required this.saveStarted,
    required this.releaseSave,
  });

  final Completer<void> saveStarted;
  final Completer<void> releaseSave;

  @override
  Future<void> saveOwnerBaseCurrencyCode(
    ConfirmedOwnerScope ownerScope,
    String currencyCode,
  ) async {
    saveStarted.complete();
    await releaseSave.future;
    await super.saveOwnerBaseCurrencyCode(ownerScope, currencyCode);
  }
}

final class _TrackingSyncMutationQueue implements SyncMutationQueue {
  var upserts = 0;

  @override
  Future<void> enqueueDelete(
    SyncEntityType entityType,
    String entityId,
  ) async {}

  @override
  Future<void> enqueueUpsert(
    SyncEntityType entityType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    upserts += 1;
  }
}
