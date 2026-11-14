import 'dart:async';
import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/database/app_database_provider.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/core/sync/application/sync_manager.dart';
import 'package:cashpilot_ai/core/sync/application/sync_providers.dart';
import 'package:cashpilot_ai/core/sync/data/firestore_sync_data_source.dart';
import 'package:cashpilot_ai/core/sync/data/sync_preferences_local_data_source.dart';
import 'package:cashpilot_ai/core/sync/data/sync_queue_repository.dart';
import 'package:cashpilot_ai/core/sync/domain/sync_queue_item.dart';
import 'package:cashpilot_ai/core/sync/domain/sync_result.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const _ownerA = AuthUser(
  uid: 'sync-controller-owner-a',
  emailVerified: true,
  isAnonymous: false,
);
const _ownerB = AuthUser(
  uid: 'sync-controller-owner-b',
  emailVerified: true,
  isAnonymous: false,
);

void main() {
  test(
    'late A sync result and metadata cannot publish into owner B epoch',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-sync-controller-epoch-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>('sync-controller-epoch-test');
      addTearDown(() async {
        await box.close();
        await directory.delete(recursive: true);
      });
      final fence = BackupOperationFence();
      final preferences = SyncPreferencesLocalDataSource(
        box,
        operationFence: fence,
      );
      await preferences.saveSyncDeviceId('opaque-device');
      final manualSession = ScopedAppDatabaseSession(
        database: database,
        scope: OwnerScopeDerivation.fromConfirmedFirebaseUid(_ownerA.uid),
        operationFence: fence,
      );
      final manager = _BlockingSyncManager(
        repository: DriftSyncQueueRepository(manualSession),
        fence: fence,
      );
      final auth = StreamController<AuthUser?>.broadcast();
      addTearDown(auth.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authStateProvider.overrideWith((_) => auth.stream),
          ownerScopeDetachServiceProvider.overrideWithValue(
            const _NoopDetachService(),
          ),
          backupOperationFenceProvider.overrideWithValue(fence),
          syncPreferencesLocalDataSourceProvider.overrideWithValue(preferences),
          syncManagerProvider.overrideWithValue(manager),
        ],
      );
      addTearDown(container.dispose);
      final scopeSubscription = container.listen(
        confirmedOwnerScopeSnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(scopeSubscription.close);

      auth.add(_ownerA);
      await _waitForOwner(container, _ownerA.uid);
      await container.read(syncActionControllerProvider.future);
      final synchronization = container
          .read(syncActionControllerProvider.notifier)
          .synchronize(_ownerA);
      await manager.started.future;

      auth.add(_ownerB);
      await _waitForOwner(container, _ownerB.uid);
      manager.finish();
      final result = await synchronization;

      expect(result.blocked, isTrue);
      expect(result.failures.single.code, 'sync_owner_scope_mismatch');
      expect(preferences.readLastBackupAt(_ownerA.uid), isNull);
      expect(container.read(syncActionControllerProvider).value, isNull);
    },
  );
}

Future<void> _waitForOwner(ProviderContainer container, String uid) async {
  final expected = OwnerScopeDerivation.fromConfirmedFirebaseUid(uid).id.value;
  for (var attempt = 0; attempt < 100; attempt += 1) {
    final snapshot = container.read(confirmedOwnerScopeSnapshotProvider);
    if (snapshot.status == OwnerScopeStatus.safe &&
        snapshot.scope?.id.value == expected) {
      return;
    }
    await pumpEventQueue();
  }
  fail('Owner scope did not settle.');
}

final class _BlockingSyncManager extends SyncManager {
  _BlockingSyncManager({
    required SyncQueueRepository repository,
    required BackupOperationFence fence,
  }) : super(
         queueRepository: repository,
         remoteDataSource: const _NoopRemote(),
         operationFence: fence,
         isBackupEnabled: (_) => true,
         readConsentGeneration: (_) => 1,
         isInitialSnapshotComplete: (_) => true,
         saveInitialSnapshotComplete: (_, _) async {},
       );

  final Completer<void> started = Completer<void>();
  final Completer<void> _finished = Completer<void>();

  void finish() => _finished.complete();

  @override
  Future<SyncResult> synchronize({
    required String? userId,
    required String deviceId,
    bool isAnonymous = false,
    bool retryFailed = false,
  }) async {
    started.complete();
    await _finished.future;
    return SyncResult(
      attemptedCount: 1,
      syncedCount: 1,
      deletedCount: 0,
      failedCount: 0,
      failures: const <SyncFailure>[],
      completedAt: DateTime.utc(2026, 8, 10, 12),
    );
  }
}

final class _NoopRemote implements FirestoreSyncDataSource {
  const _NoopRemote();

  @override
  Future<void> uploadItem(String userId, SyncQueueItem item) async {}

  @override
  Future<void> updateSyncMetadata({
    required String userId,
    required String deviceId,
    required DateTime syncedAt,
    required int uploadedCount,
    required int failedCount,
    required bool snapshotComplete,
    required int snapshotVersion,
  }) async {}
}

final class _NoopDetachService implements OwnerScopeDetachService {
  const _NoopDetachService();

  @override
  Future<void> detach(String ownerScopeValue) async {}
}
