import 'dart:async';
import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/database/app_database_provider.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/storage/hive_box_names.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/core/sync/data/sync_preferences_local_data_source.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test(
    'startup backup repair refreshes cached owner reads after its fence opens',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-sync-startup-provider-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>(HiveBoxNames.settings);
      final database = AppDatabase(executor: NativeDatabase.memory());
      final fence = BackupOperationFence();
      final auth = StreamController<AuthUser?>.broadcast();
      const user = AuthUser(
        uid: 'synthetic-startup-repair-owner',
        emailVerified: true,
        isAnonymous: false,
        authSessionGeneration: 1,
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authStateProvider.overrideWith((_) => auth.stream),
          backupOperationFenceProvider.overrideWithValue(fence),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await auth.close();
        await database.close();
        await box.close();
        await directory.delete(recursive: true);
      });
      final ownerSubscription = container.listen(
        confirmedOwnerScopeSnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(ownerSubscription.close);
      auth.add(user);
      await _waitUntil(
        () =>
            container.read(confirmedOwnerScopeSnapshotProvider).status ==
            OwnerScopeStatus.safe,
      );
      final firstSession = container.read(
        requiredScopedAppDatabaseSessionProvider,
      );

      var downstreamBuilds = 0;
      final ownerReadProvider = Provider<int>((ref) {
        ref.watch(requiredScopedAppDatabaseSessionProvider);
        return ++downstreamBuilds;
      });
      final subscription = container.listen<int>(
        ownerReadProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      expect(subscription.read(), 1);

      container.read(syncPreferencesLocalDataSourceProvider);
      await _waitUntil(() => downstreamBuilds >= 2);

      expect(subscription.read(), 2);
      final refreshedSession = container.read(
        requiredScopedAppDatabaseSessionProvider,
      );
      expect(refreshedSession, isNot(same(firstSession)));
      expect(fence.isFenced(refreshedSession.ownerScopeValue), isFalse);
    },
  );
}

Future<void> _waitUntil(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('The startup repair did not refresh owner-scoped dependents.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
