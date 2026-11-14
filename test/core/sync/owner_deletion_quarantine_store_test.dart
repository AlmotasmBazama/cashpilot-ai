import 'dart:convert';
import 'dart:io';

import 'package:cashpilot_ai/core/storage/settings_keys.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/core/sync/application/owner_deletion_quarantine_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  const scope =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test(
    'malformed scope suffix fails closed instead of restoring clean',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-quarantine-corrupt-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>('quarantine-corrupt');
      addTearDown(() async {
        await box.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      await box.put(
        '${SettingsKeys.ownerDeletionQuarantinePrefix}not-a-valid-scope',
        '{"version":1,"operationId":"operation-corrupt"}',
      );

      const storeFactory = HiveOwnerDeletionQuarantineStore.new;
      final store = storeFactory(box);

      expect(
        store.restore,
        throwsA(isA<OwnerDeletionQuarantineCorruptException>()),
      );
      expect(
        () => BackupOperationFence(quarantineStore: store),
        throwsA(isA<OwnerDeletionQuarantineCorruptException>()),
      );
    },
  );

  test(
    'durable hold is an exact compare-and-set across fence instances',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-quarantine-cas-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>('quarantine-cas');
      addTearDown(() async {
        await box.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final firstFence = BackupOperationFence(
        quarantineStore: HiveOwnerDeletionQuarantineStore(box),
      );
      final secondFence = BackupOperationFence(
        quarantineStore: HiveOwnerDeletionQuarantineStore(box),
      );

      final outcomes = await Future.wait<Object>([
        firstFence
            .fenceAndDrain(
              ownerScopeValue: scope,
              operationId: 'operation-one',
              durable: true,
            )
            .then<Object>((lease) => lease)
            .catchError((Object error) => error),
        secondFence
            .fenceAndDrain(
              ownerScopeValue: scope,
              operationId: 'operation-two',
              durable: true,
            )
            .then<Object>((lease) => lease)
            .catchError((Object error) => error),
      ]);

      final leases = outcomes.whereType<BackupDeletionLease>().toList();
      final conflicts = outcomes
          .whereType<OwnerDeletionQuarantineConflictException>()
          .toList();
      expect(leases, hasLength(1));
      expect(conflicts, hasLength(1));
      final winner = leases.single;
      expect(
        HiveOwnerDeletionQuarantineStore(box).restore()[scope],
        winner.operationId,
      );
      expect(firstFence.tryAcquireWriter(scope), isNull);
      expect(secondFence.tryAcquireWriter(scope), isNull);
      winner.retainQuarantine();
    },
  );

  test(
    'release rejects a replaced operation and keeps writers fenced',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-quarantine-release-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>('quarantine-release');
      addTearDown(() async {
        await box.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final store = HiveOwnerDeletionQuarantineStore(box);
      final fence = BackupOperationFence(quarantineStore: store);
      final lease = await fence.fenceAndDrain(
        ownerScopeValue: scope,
        operationId: 'operation-one',
        durable: true,
      );
      await box.put(
        '${SettingsKeys.ownerDeletionQuarantinePrefix}$scope',
        jsonEncode(<String, Object>{
          'version': 1,
          'operationId': 'operation-two',
        }),
      );

      await expectLater(
        lease.releaseAndClearQuarantine(),
        throwsA(isA<OwnerDeletionQuarantineConflictException>()),
      );

      expect(fence.isFenced(scope), isTrue);
      expect(fence.tryAcquireWriter(scope), isNull);
      expect(store.restore()[scope], 'operation-two');
      lease.retainQuarantine();
    },
  );
}
