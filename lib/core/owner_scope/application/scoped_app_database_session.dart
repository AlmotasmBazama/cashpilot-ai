import 'dart:async';

import '../../database/app_database.dart';
import '../../sync/application/backup_operation_fence.dart';
import '../domain/owner_scope.dart';

/// Binds an AppDatabase to one trusted confirmed scope. Financial data
/// sources receive this object instead of accepting caller-provided scope IDs.
final class ScopedAppDatabaseSession {
  ScopedAppDatabaseSession({
    required AppDatabase database,
    required ConfirmedOwnerScope scope,
    BackupOperationFence? operationFence,
  }) : _database = database,
       _scope = scope,
       _operationFence = operationFence;

  final AppDatabase _database;
  final ConfirmedOwnerScope _scope;
  final BackupOperationFence? _operationFence;
  final Object _guardedWriterZoneKey = Object();
  final Completer<void> _invalidated = Completer<void>();
  bool _active = true;

  AppDatabase get database {
    assertActive();
    _assertNotQuarantined();
    return _database;
  }

  AppDatabase deletionDatabase({required String operationId}) {
    assertActive();
    _operationFence?.assertDeletionOperation(
      ownerScopeValue: _scope.id.value,
      operationId: operationId,
    );
    return _database;
  }

  Future<T> runGuardedWrite<T>(Future<T> Function() operation) async {
    assertActive();
    final inheritedWriter = Zone.current[_guardedWriterZoneKey];
    if (inheritedWriter is BackupWriterLease) {
      inheritedWriter.assertActive();
      final result = await operation();
      inheritedWriter.assertActive();
      assertActive();
      return result;
    }
    final fence = _operationFence;
    if (fence == null) {
      return operation();
    }
    final writer = fence.tryAcquireWriter(_scope.id.value);
    if (writer == null) {
      throw const OwnerScopeException(OwnerScopeFailure.deletionQuarantined);
    }
    try {
      writer.assertActive();
      final result = await runZoned(
        operation,
        zoneValues: <Object, Object>{_guardedWriterZoneKey: writer},
      );
      writer.assertActive();
      assertActive();
      return result;
    } finally {
      writer.release();
    }
  }

  String get ownerScopeValue {
    assertActive();
    return _scope.id.value;
  }

  ConfirmedOwnerScope get confirmedScope {
    assertActive();
    return _scope;
  }

  bool get isActive => _active;

  void assertActive() {
    if (!_active) {
      throw const OwnerScopeException(OwnerScopeFailure.activeScopeChanged);
    }
  }

  void _assertNotQuarantined() {
    if (_operationFence?.isFenced(_scope.id.value) ?? false) {
      throw const OwnerScopeException(OwnerScopeFailure.deletionQuarantined);
    }
  }

  /// Stops an already-subscribed scoped stream at the same boundary that
  /// invalidates reads and writes. Late Drift emissions from an old owner can
  /// therefore never enter a newly authenticated provider tree.
  Stream<T> guardStream<T>(Stream<T> source) {
    assertActive();
    late final StreamController<T> controller;
    StreamSubscription<T>? sourceSubscription;
    var closing = false;

    Future<void> close() async {
      if (closing) return;
      closing = true;
      await sourceSubscription?.cancel();
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    controller = StreamController<T>(sync: true);
    controller.onListen = () {
      if (!_active) {
        unawaited(close());
        return;
      }
      sourceSubscription = source.listen(
        (value) {
          if (_active && !controller.isClosed) {
            controller.add(value);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_active && !controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () => unawaited(close()),
      );
      _invalidated.future.then((_) => close());
    };
    controller.onPause = () => sourceSubscription?.pause();
    controller.onResume = () => sourceSubscription?.resume();
    controller.onCancel = close;
    return controller.stream;
  }

  void invalidate() {
    if (!_active) return;
    _active = false;
    if (!_invalidated.isCompleted) {
      _invalidated.complete();
    }
  }
}
