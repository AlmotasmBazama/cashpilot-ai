import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../storage/hive_box_names.dart';
import 'owner_deletion_quarantine_store.dart';

final ownerDeletionQuarantineStoreProvider =
    Provider<OwnerDeletionQuarantineStore>(
      (_) => HiveOwnerDeletionQuarantineStore(
        Hive.box<dynamic>(HiveBoxNames.settings),
      ),
      name: 'ownerDeletionQuarantineStoreProvider',
    );

final backupOperationFenceProvider = Provider<BackupOperationFence>(
  (ref) => BackupOperationFence(
    quarantineStore: ref.watch(ownerDeletionQuarantineStoreProvider),
  ),
  name: 'backupOperationFenceProvider',
);

/// Coordinates owner-scoped backup writers with destructive account deletion.
///
/// A deletion first closes the scope to new writers, cancels writers that have
/// not reached their next guarded boundary, and waits for every writer that was
/// already in flight. Cloud deletion can therefore start only after no backup
/// writer can publish data for that scope.
final class BackupOperationFence {
  BackupOperationFence({
    OwnerDeletionQuarantineStore? quarantineStore,
    Duration drainTimeout = const Duration(seconds: 30),
  }) : _quarantineStore = quarantineStore,
       _drainTimeout = drainTimeout {
    final restored = quarantineStore?.restore() ?? const <String, String>{};
    for (final entry in restored.entries) {
      _states[entry.key] = _OwnerFenceState()
        ..isFenced = true
        ..operationId = entry.value
        ..epoch = 1
        ..activeDeletion = false;
    }
  }

  final Map<String, _OwnerFenceState> _states = <String, _OwnerFenceState>{};
  final OwnerDeletionQuarantineStore? _quarantineStore;
  final Duration _drainTimeout;

  BackupWriterLease? tryAcquireWriter(String ownerScopeValue) {
    final scope = _normalizedScope(ownerScopeValue);
    final state = _states.putIfAbsent(scope, _OwnerFenceState.new);
    if (state.isFenced) {
      return null;
    }
    final lease = BackupWriterLease._(
      state,
      state.epoch,
      (writer) => _releaseWriter(scope, state, writer),
    );
    state.writers.add(lease);
    return lease;
  }

  Future<BackupDeletionLease> fenceAndDrain({
    required String ownerScopeValue,
    required String operationId,
    bool durable = false,
  }) async {
    final scope = _normalizedScope(ownerScopeValue);
    final normalizedOperationId = operationId.trim();
    if (normalizedOperationId.isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'A deletion operation id is required.',
      );
    }
    final state = _states.putIfAbsent(scope, _OwnerFenceState.new);
    if (state.isFenced) {
      if (state.operationId != normalizedOperationId || state.activeDeletion) {
        throw StateError('A deletion operation is already active.');
      }
      state.activeDeletion = true;
      return _deletionLease(
        scope: scope,
        operationId: normalizedOperationId,
        state: state,
        durable: durable,
      );
    }

    state
      ..isFenced = true
      ..operationId = normalizedOperationId
      ..activeDeletion = true
      ..epoch += 1;
    for (final writer in state.writers) {
      writer._cancel();
    }
    var durableQuarantineHeld = false;
    try {
      if (durable) {
        await _quarantineStore?.hold(
          ownerScopeValue: scope,
          operationId: normalizedOperationId,
        );
        durableQuarantineHeld = true;
      }
      await _awaitWriterDrain(state);
    } on Object catch (error, stackTrace) {
      if (durableQuarantineHeld) {
        await _quarantineStore?.release(
          ownerScopeValue: scope,
          operationId: normalizedOperationId,
        );
        _releaseDeletion(
          scope: scope,
          operationId: normalizedOperationId,
          epoch: state.epoch,
        );
      } else if (durable) {
        // Another fence instance may have won the durable compare-and-set.
        // Mirror its marker locally so this instance cannot reopen writers for
        // the quarantined owner. If durable state itself is unreadable, retain
        // the attempted fence as the fail-closed state.
        try {
          final durableOperation = _quarantineStore?.restore()[scope];
          if (durableOperation == null) {
            _releaseDeletion(
              scope: scope,
              operationId: normalizedOperationId,
              epoch: state.epoch,
            );
          } else {
            state
              ..operationId = durableOperation
              ..activeDeletion = false;
          }
        } on Object {
          state.activeDeletion = false;
        }
      } else {
        _releaseDeletion(
          scope: scope,
          operationId: normalizedOperationId,
          epoch: state.epoch,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    return _deletionLease(
      scope: scope,
      operationId: normalizedOperationId,
      state: state,
      durable: durable,
    );
  }

  /// Establishes a temporary, non-durable fence while an authenticated owner
  /// session is detached. If a stronger deletion fence already owns the
  /// scope, this only joins its writer drain and never releases that fence.
  Future<OwnerScopeTransitionFenceLease> fenceAndDrainForOwnerTransition({
    required String ownerScopeValue,
    required String operationId,
  }) async {
    final scope = _normalizedScope(ownerScopeValue);
    final normalizedOperationId = operationId.trim();
    if (normalizedOperationId.isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'An owner transition operation id is required.',
      );
    }
    final state = _states.putIfAbsent(scope, _OwnerFenceState.new);
    if (state.isFenced) {
      for (final writer in state.writers) {
        writer._cancel();
      }
      await _awaitWriterDrain(state);
      return OwnerScopeTransitionFenceLease._(() {});
    }

    final lease = await fenceAndDrain(
      ownerScopeValue: scope,
      operationId: normalizedOperationId,
    );
    return OwnerScopeTransitionFenceLease._(lease.release);
  }

  Future<void> _awaitWriterDrain(_OwnerFenceState state) async {
    if (state.writers.isEmpty) return;
    final current = state.drainCompleter;
    if (current == null || current.isCompleted) {
      state.drainCompleter = Completer<void>();
    }
    await state.drainCompleter!.future.timeout(_drainTimeout);
  }

  BackupDeletionLease _deletionLease({
    required String scope,
    required String operationId,
    required _OwnerFenceState state,
    required bool durable,
  }) {
    final deletionEpoch = state.epoch;
    return BackupDeletionLease._(
      ownerScopeValue: scope,
      operationId: operationId,
      epoch: deletionEpoch,
      durable: durable,
      release: () => _releaseDeletion(
        scope: scope,
        operationId: operationId,
        epoch: deletionEpoch,
      ),
      clearDurable: () async {
        if (durable) {
          await _quarantineStore?.release(
            ownerScopeValue: scope,
            operationId: operationId,
          );
        }
      },
      restoreDurable: () async {
        if (durable) {
          await _quarantineStore?.hold(
            ownerScopeValue: scope,
            operationId: operationId,
          );
        }
      },
      retainDurable: () {
        final current = _states[scope];
        if (current != null &&
            current.isFenced &&
            current.operationId == operationId &&
            current.epoch == deletionEpoch) {
          current.activeDeletion = false;
        }
      },
    );
  }

  void _releaseWriter(
    String scope,
    _OwnerFenceState state,
    BackupWriterLease writer,
  ) {
    state.writers.remove(writer);
    if (state.isFenced && state.writers.isEmpty) {
      final completer = state.drainCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    } else if (!state.isFenced && state.writers.isEmpty) {
      _states.remove(scope);
    }
  }

  bool isFenced(String ownerScopeValue) {
    final scope = _normalizedScope(ownerScopeValue);
    return _states[scope]?.isFenced ?? false;
  }

  void assertDeletionOperation({
    required String ownerScopeValue,
    required String operationId,
  }) {
    final scope = _normalizedScope(ownerScopeValue);
    final state = _states[scope];
    if (state == null ||
        !state.isFenced ||
        state.operationId != operationId.trim()) {
      throw StateError('A matching deletion quarantine is required.');
    }
  }

  void assertDrained({
    required String ownerScopeValue,
    required String operationId,
  }) {
    assertDeletionOperation(
      ownerScopeValue: ownerScopeValue,
      operationId: operationId,
    );
    final state = _states[_normalizedScope(ownerScopeValue)]!;
    if (!state.activeDeletion || state.writers.isNotEmpty) {
      throw StateError('Deletion writers have not drained.');
    }
  }

  void _releaseDeletion({
    required String scope,
    required String operationId,
    required int epoch,
  }) {
    final state = _states[scope];
    if (state == null ||
        state.operationId != operationId ||
        state.epoch != epoch) {
      return;
    }
    state
      ..isFenced = false
      ..operationId = null
      ..activeDeletion = false
      ..drainCompleter = null;
    if (state.writers.isEmpty) {
      _states.remove(scope);
    }
  }

  String _normalizedScope(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        '<redacted>',
        'ownerScopeValue',
        'An owner scope is required.',
      );
    }
    return normalized;
  }
}

final class BackupWriterLease {
  BackupWriterLease._(this._state, this.epoch, this._release);

  final _OwnerFenceState _state;
  final int epoch;
  final void Function(BackupWriterLease writer) _release;
  bool _cancelled = false;
  bool _released = false;

  bool get isCancelled =>
      _cancelled || _released || _state.isFenced || _state.epoch != epoch;

  void assertActive() {
    if (isCancelled) {
      throw const BackupWriterCancelledException();
    }
  }

  void release() {
    if (_released) {
      return;
    }
    _released = true;
    _release(this);
  }

  void _cancel() {
    _cancelled = true;
  }
}

final class OwnerScopeTransitionFenceLease {
  OwnerScopeTransitionFenceLease._(this._release);

  final void Function() _release;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}

final class BackupDeletionLease {
  BackupDeletionLease._({
    required this.ownerScopeValue,
    required this.operationId,
    required this.epoch,
    required this.durable,
    required void Function() release,
    required Future<void> Function() clearDurable,
    required Future<void> Function() restoreDurable,
    required void Function() retainDurable,
  }) : _release = release,
       _clearDurable = clearDurable,
       _restoreDurable = restoreDurable,
       _retainDurable = retainDurable;

  final String ownerScopeValue;
  final String operationId;
  final int epoch;
  final bool durable;
  final void Function() _release;
  final Future<void> Function() _clearDurable;
  final Future<void> Function() _restoreDurable;
  final void Function() _retainDurable;
  bool _released = false;
  bool _durableCleared = false;

  void release() {
    if (_released) {
      return;
    }
    _released = true;
    _release();
  }

  Future<void> releaseAndClearQuarantine() async {
    if (_released) {
      return;
    }
    await clearDurableQuarantineKeepingFence();
    releaseAfterDurableQuarantineCleared();
  }

  /// Removes the restart marker while the in-memory writer fence remains
  /// closed. Callers may perform the final secure erase before opening writers.
  Future<void> clearDurableQuarantineKeepingFence() async {
    if (_released || _durableCleared) {
      return;
    }
    await _clearDurable();
    _durableCleared = true;
  }

  /// Opens writers only after the durable marker has been removed and every
  /// terminal cleanup that required the fence has completed.
  void releaseAfterDurableQuarantineCleared() {
    if (_released) {
      return;
    }
    if (durable && !_durableCleared) {
      throw StateError('Durable deletion quarantine is still active.');
    }
    _released = true;
    _release();
  }

  /// Keeps this owner's in-memory writer fence closed for the rest of the
  /// process after durable and secure deletion cleanup has completed. This is
  /// required after verified Auth deletion so stale provider graphs cannot
  /// reacquire a writer; a clean process restart drops the memory-only fence.
  void retainWriterFenceAfterDurableQuarantineCleared() {
    if (_released) {
      return;
    }
    if (durable && !_durableCleared) {
      throw StateError('Durable deletion quarantine is still active.');
    }
    _released = true;
    _retainDurable();
  }

  /// Re-establishes the durable marker after a split-release failure, then
  /// leaves the in-memory fence retained for startup recovery.
  Future<void> restoreDurableQuarantineAndRetain() async {
    if (_released) {
      return;
    }
    if (_durableCleared) {
      await _restoreDurable();
      _durableCleared = false;
    }
    _released = true;
    _retainDurable();
  }

  void retainQuarantine() {
    if (_released) {
      return;
    }
    _released = true;
    _retainDurable();
  }
}

final class BackupWriterCancelledException implements Exception {
  const BackupWriterCancelledException();

  @override
  String toString() => 'Backup writer cancelled by account deletion.';
}

final class _OwnerFenceState {
  int epoch = 0;
  bool isFenced = false;
  bool activeDeletion = false;
  String? operationId;
  Completer<void>? drainCompleter;
  final Set<BackupWriterLease> writers = <BackupWriterLease>{};
}
