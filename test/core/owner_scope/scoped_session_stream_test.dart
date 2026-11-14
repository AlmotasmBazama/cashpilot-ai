import 'dart:async';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase 1 stale scoped stream closes before a late A event', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final session = ScopedAppDatabaseSession(
      database: database,
      scope: OwnerScopeDerivation.fromConfirmedFirebaseUid(
        'synthetic-owner-a',
        confirmedAt: DateTime.utc(2026, 8, 10),
      ),
    );
    final source = StreamController<int>(sync: true);
    addTearDown(source.close);
    final values = <int>[];
    final done = Completer<void>();
    final subscription = session
        .guardStream(source.stream)
        .listen(values.add, onDone: done.complete);
    addTearDown(subscription.cancel);

    source.add(1);
    session.invalidate();
    source.add(2);
    await done.future;

    expect(values, <int>[1]);
  });
}
