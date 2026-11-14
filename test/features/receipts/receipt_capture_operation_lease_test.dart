import 'dart:typed_data';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/receipts/application/receipt_capture_operation_lease.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/prepared_receipt_image.dart';
import 'package:cashpilot_ai/features/receipts/domain/repositories/receipt_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  test(
    'cancel completes once, purges bytes and deletes one owned reference',
    () async {
      final fixture = _LeaseFixture.create();
      addTearDown(fixture.dispose);
      final deleted = <String?>[];
      var consentChecks = 0;
      final lease = fixture.lease(
        hasRemoteConsent: () {
          consentChecks += 1;
          return true;
        },
        deleteImageReference: (reference) async => deleted.add(reference),
      );
      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
      lease.trackPreparedImage(_prepared(bytes));
      lease.trackLocalImageReference('owned-reference');

      expect(lease.hasCurrentRemoteConsent, isTrue);
      final cancelled = expectLater(lease.whenCancelled, completes);
      lease.cancel();
      lease.cancel();
      await cancelled;
      await lease.waitForCleanup();

      expect(lease.isCancelled, isTrue);
      expect(lease.hasCurrentRemoteConsent, isFalse);
      expect(
        consentChecks,
        1,
        reason: 'Cancellation must short-circuit consent.',
      );
      expect(bytes, everyElement(0));
      expect(deleted, <String?>['owned-reference']);
      expect(lease.isWriterCancelled, isFalse);
      lease.releaseWriter();
      expect(lease.isWriterCancelled, isTrue);
    },
  );

  test(
    'direct deletion propagates while cancellation cleanup stays best effort',
    () async {
      final fixture = _LeaseFixture.create();
      addTearDown(fixture.dispose);
      final attempts = <String?>[];
      final lease = fixture.lease(
        deleteImageReference: (reference) async {
          attempts.add(reference);
          throw StateError('synthetic delete failure');
        },
      );

      await expectLater(
        lease.deleteImageReference('strict-reference'),
        throwsA(isA<StateError>()),
      );
      lease.trackLocalImageReference('cleanup-reference');
      lease.cancel();
      await lease.waitForCleanup();

      expect(attempts, <String?>['strict-reference', 'cleanup-reference']);
    },
  );

  test(
    'retained image ownership is not deleted by final lease cleanup',
    () async {
      final fixture = _LeaseFixture.create();
      addTearDown(fixture.dispose);
      final deleted = <String?>[];
      final lease = fixture.lease(
        deleteImageReference: (reference) async => deleted.add(reference),
      );
      final bytes = Uint8List.fromList(<int>[9, 8, 7]);
      lease.trackPreparedImage(_prepared(bytes));
      lease.trackLocalImageReference('persisted-reference');
      lease.retainLocalImageReference();

      lease.purgePreparedBytes();
      lease.cancel();
      await lease.waitForCleanup();

      expect(bytes, everyElement(0));
      expect(deleted, isEmpty);
    },
  );
}

PreparedReceiptImage _prepared(Uint8List bytes) {
  return PreparedReceiptImage(
    bytes: bytes,
    mimeType: 'image/jpeg',
    width: 800,
    height: 1000,
    sha256: '0000000000000000000000000000000000000000000000000000000000000000',
  );
}

final class _LeaseFixture {
  _LeaseFixture({
    required this.database,
    required this.session,
    required this.writer,
  });

  factory _LeaseFixture.create() {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final session = scopedTestSession(database);
    final writer = BackupOperationFence().tryAcquireWriter(
      session.ownerScopeValue,
    )!;
    return _LeaseFixture(database: database, session: session, writer: writer);
  }

  final AppDatabase database;
  final ScopedAppDatabaseSession session;
  final BackupWriterLease writer;

  ReceiptCaptureOperationLease lease({
    bool Function()? hasRemoteConsent,
    required DeleteReceiptImageReference deleteImageReference,
  }) {
    return ReceiptCaptureOperationLease(
      generation: 1,
      ownerScope: session.confirmedScope,
      authSessionGeneration: 1,
      session: session,
      writer: writer,
      repository: _UnusedReceiptRepository(),
      acquireImage: ({cancellationSignal}) async => null,
      analyzeReceipt: null,
      hasRemoteConsent: hasRemoteConsent ?? () => false,
      deleteImageReference: deleteImageReference,
    );
  }

  Future<void> dispose() async {
    writer.release();
    await database.close();
  }
}

final class _UnusedReceiptRepository implements ReceiptRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
