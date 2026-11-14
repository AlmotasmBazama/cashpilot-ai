import '../../../core/sync/application/backup_operation_fence.dart';
import '../../../core/sync/application/owner_deletion_quarantine_store.dart';
import '../data/datasources/account_deletion_session_proof_store.dart';
import '../domain/entities/data_deletion_operation_context.dart';

/// Read-only Auth-last confirmation. Implementations must send App Check and
/// the deletion proof to `/v1/account-deletion/auth` without inventing a UID.
abstract interface class AccountDeletionStartupRecoveryGateway {
  Future<AccountDeletionStartupRecoveryDisposition> confirmAlreadyDeleted({
    required AccountDeletionRecoveryTarget target,
    required AccountDeletionSessionProof proof,
  });
}

/// Closed, non-sensitive diagnostic exposed by a recovery adapter.
abstract interface class AccountDeletionStartupRecoveryFailure {
  String get safeFailureCode;
}

enum AccountDeletionStartupRecoveryDisposition {
  alreadyDeleted,
  authenticatedContinuationRequired,
}

/// Owns the restored in-memory writer fence while a startup recovery target is
/// inspected and finalized.
abstract interface class AccountDeletionStartupRecoveryFence {
  Future<AccountDeletionStartupRecoveryLease> acquireRecoveryLease(
    AccountDeletionRecoveryTarget target,
  );
}

abstract interface class AccountDeletionStartupRecoveryLease {
  /// Opens the in-memory writer fence and removes its durable quarantine.
  Future<void> releaseAndClearQuarantine();

  /// Removes only the durable marker; the in-memory writer fence stays shut.
  Future<void> clearDurableQuarantineKeepingFence();

  /// Opens the in-memory fence after secure terminal cleanup has completed.
  void releaseAfterDurableQuarantineCleared();

  /// Restores a split-released durable marker and retains the writer fence.
  Future<void> restoreDurableQuarantineAndRetain();

  /// Keeps (or restores) both the in-memory fence and durable quarantine.
  Future<void> retainQuarantine();
}

/// Production bridge to the same fence and quarantine store used by backup
/// writers. Both constructor arguments must refer to the same durable store.
final class BackupOperationFenceStartupRecoveryAdapter
    implements AccountDeletionStartupRecoveryFence {
  const BackupOperationFenceStartupRecoveryAdapter({
    required BackupOperationFence operationFence,
    required OwnerDeletionQuarantineStore quarantineStore,
  }) : _operationFence = operationFence,
       _quarantineStore = quarantineStore;

  final BackupOperationFence _operationFence;
  final OwnerDeletionQuarantineStore _quarantineStore;

  @override
  Future<AccountDeletionStartupRecoveryLease> acquireRecoveryLease(
    AccountDeletionRecoveryTarget target,
  ) async {
    final lease = await _operationFence.fenceAndDrain(
      ownerScopeValue: target.ownerScopeValue,
      operationId: target.operationId,
      durable: true,
    );
    return _BackupOperationFenceStartupRecoveryLease(
      lease: lease,
      quarantineStore: _quarantineStore,
    );
  }
}

final class _BackupOperationFenceStartupRecoveryLease
    implements AccountDeletionStartupRecoveryLease {
  _BackupOperationFenceStartupRecoveryLease({
    required BackupDeletionLease lease,
    required OwnerDeletionQuarantineStore quarantineStore,
  }) : _lease = lease,
       _quarantineStore = quarantineStore;

  final BackupDeletionLease _lease;
  final OwnerDeletionQuarantineStore _quarantineStore;
  bool _released = false;
  bool _retained = false;

  @override
  Future<void> releaseAndClearQuarantine() async {
    if (_released || _retained) return;
    await _lease.releaseAndClearQuarantine();
    _released = true;
  }

  @override
  Future<void> clearDurableQuarantineKeepingFence() async {
    if (_released || _retained) return;
    await _lease.clearDurableQuarantineKeepingFence();
  }

  @override
  void releaseAfterDurableQuarantineCleared() {
    if (_released || _retained) return;
    _lease.releaseAfterDurableQuarantineCleared();
    _released = true;
  }

  @override
  Future<void> restoreDurableQuarantineAndRetain() async {
    if (_released || _retained) return;
    await _lease.restoreDurableQuarantineAndRetain();
    _retained = true;
  }

  @override
  Future<void> retainQuarantine() async {
    if (_released || _retained) return;
    // Rewriting the same marker makes an ambiguous durable-release failure
    // fail closed across the next process restart.
    await _quarantineStore.hold(
      ownerScopeValue: _lease.ownerScopeValue,
      operationId: _lease.operationId,
    );
    _lease.retainQuarantine();
    _retained = true;
  }
}

/// UID-free, owner-scope cleanup used only after the server has confirmed that
/// Auth is already absent. Every operation must be idempotent.
abstract interface class AccountDeletionScopeRecoveryFinalizer {
  Future<void> deleteLocalRows(AccountDeletionRecoveryTarget target);

  Future<bool> verifyLocalRowsEmpty(AccountDeletionRecoveryTarget target);

  Future<void> deleteReceiptFiles(AccountDeletionRecoveryTarget target);

  Future<void> clearPreferences(AccountDeletionRecoveryTarget target);

  Future<void> markCompletionOverlay(AccountDeletionRecoveryTarget target);

  Future<void> clearOperationState(AccountDeletionRecoveryTarget target);
}

final class AccountDeletionStartupRecoveryReport {
  const AccountDeletionStartupRecoveryReport({
    required this.completed,
    required this.retained,
    required this.rejected,
    this.authenticatedContinuations = const <AccountDeletionRecoveryTarget>[],
  });

  final int completed;
  final int retained;
  final int rejected;
  final List<AccountDeletionRecoveryTarget> authenticatedContinuations;
}

final class AccountDeletionStartupRecoveryUnavailableException
    implements Exception {
  const AccountDeletionStartupRecoveryUnavailableException();

  @override
  String toString() => 'Account deletion startup recovery is unavailable.';
}

/// Recovers an Auth-last operation when Firebase no longer exposes a User.
///
/// Quarantine is used only to discover opaque coordinates. Authority comes
/// exclusively from the platform-secure operation record. An active record is
/// converted to [AccountDeletionSecureOperationStatus.serverConfirmed] only
/// after the server's proof-bound, read-only endpoint succeeds. The secure
/// record is erased last.
final class AccountDeletionStartupRecoveryCoordinator {
  AccountDeletionStartupRecoveryCoordinator({
    required OwnerDeletionQuarantineStore quarantineStore,
    required AccountDeletionStartupRecoveryFence recoveryFence,
    required AccountDeletionSessionProofStore secureOperationStore,
    required AccountDeletionStartupRecoveryGateway gateway,
    required AccountDeletionScopeRecoveryFinalizer localFinalizer,
    void Function(String safeFailureCode)? onRetainedFailure,
  }) : _quarantineStore = quarantineStore,
       _recoveryFence = recoveryFence,
       _secureOperationStore = secureOperationStore,
       _gateway = gateway,
       _localFinalizer = localFinalizer,
       _onRetainedFailure = onRetainedFailure;

  final OwnerDeletionQuarantineStore _quarantineStore;
  final AccountDeletionStartupRecoveryFence _recoveryFence;
  final AccountDeletionSessionProofStore _secureOperationStore;
  final AccountDeletionStartupRecoveryGateway _gateway;
  final AccountDeletionScopeRecoveryFinalizer _localFinalizer;
  final void Function(String safeFailureCode)? _onRetainedFailure;
  Future<void> _barrier = Future<void>.value();

  Future<AccountDeletionStartupRecoveryReport> recoverPending() {
    final result = _barrier.then((_) => _recoverPending());
    _barrier = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<AccountDeletionStartupRecoveryReport> _recoverPending() async {
    late final Map<String, String> quarantined;
    late final List<AccountDeletionRecoveryTarget> secureTargets;
    try {
      quarantined = _quarantineStore.restore();
      secureTargets = await _secureOperationStore.recoveryTargets();
    } on Object {
      throw const AccountDeletionStartupRecoveryUnavailableException();
    }

    var completed = 0;
    var retained = 0;
    var rejected = 0;
    final authenticatedContinuations = <AccountDeletionRecoveryTarget>[];
    final recoveryCoordinates = Map<String, String>.of(quarantined);
    for (final target in secureTargets) {
      final indexedOperation = recoveryCoordinates[target.ownerScopeValue];
      if (indexedOperation != null && indexedOperation != target.operationId) {
        // One owner cannot safely recover two competing deletion operations.
        // Preserve both records and keep the entire startup gate locked.
        throw const AccountDeletionStartupRecoveryUnavailableException();
      }
      recoveryCoordinates[target.ownerScopeValue] = target.operationId;
    }
    final entries = recoveryCoordinates.entries.toList(growable: false)
      ..sort((left, right) => left.key.compareTo(right.key));
    for (final entry in entries) {
      late final AccountDeletionRecoveryTarget target;
      try {
        target = AccountDeletionRecoveryTarget(
          operationId: entry.value,
          ownerScopeValue: entry.key,
        );
      } on Object {
        rejected += 1;
        continue;
      }
      switch (await _recoverTarget(target)) {
        case _AccountDeletionRecoveryOutcome.completed:
          completed += 1;
        case _AccountDeletionRecoveryOutcome.retained:
          retained += 1;
        case _AccountDeletionRecoveryOutcome.authenticatedContinuation:
          authenticatedContinuations.add(target);
      }
    }
    return AccountDeletionStartupRecoveryReport(
      completed: completed,
      retained: retained,
      rejected: rejected,
      authenticatedContinuations:
          List<AccountDeletionRecoveryTarget>.unmodifiable(
            authenticatedContinuations,
          ),
    );
  }

  Future<_AccountDeletionRecoveryOutcome> _recoverTarget(
    AccountDeletionRecoveryTarget target,
  ) async {
    AccountDeletionStartupRecoveryLease? recoveryLease;
    var durableQuarantineCleared = false;
    try {
      recoveryLease = await _recoveryFence.acquireRecoveryLease(target);
      final status = await _secureOperationStore.recoveryStatus(target);
      switch (status) {
        case AccountDeletionSecureOperationStatus.active:
          final proof = await _secureOperationStore.requireExistingForRecovery(
            target,
          );
          final disposition = await _gateway.confirmAlreadyDeleted(
            target: target,
            proof: proof,
          );
          if (disposition ==
              AccountDeletionStartupRecoveryDisposition
                  .authenticatedContinuationRequired) {
            await recoveryLease.retainQuarantine();
            return _AccountDeletionRecoveryOutcome.authenticatedContinuation;
          }
          await _secureOperationStore.markServerConfirmedForRecovery(target);
          if (await _secureOperationStore.recoveryStatus(target) !=
              AccountDeletionSecureOperationStatus.serverConfirmed) {
            throw StateError('Secure server confirmation was not persisted.');
          }
        case AccountDeletionSecureOperationStatus.serverConfirmed:
          break;
        case AccountDeletionSecureOperationStatus.abandonedBeforeRemote:
          // This platform-secure terminal marker proves no remote deletion was
          // started. It authorizes only checkpoint/quarantine cleanup, never
          // deletion of owner data or a completion overlay.
          await _localFinalizer.clearOperationState(target);
          await recoveryLease.clearDurableQuarantineKeepingFence();
          durableQuarantineCleared = true;
          await _secureOperationStore.clearRecovery(target);
          recoveryLease.releaseAfterDurableQuarantineCleared();
          durableQuarantineCleared = false;
          return _AccountDeletionRecoveryOutcome.completed;
      }

      await _localFinalizer.deleteLocalRows(target);
      if (!await _localFinalizer.verifyLocalRowsEmpty(target)) {
        throw StateError('Scope-only local deletion was not verified.');
      }
      await _localFinalizer.deleteReceiptFiles(target);
      await _localFinalizer.clearPreferences(target);
      await _localFinalizer.markCompletionOverlay(target);
      await _localFinalizer.clearOperationState(target);

      await recoveryLease.clearDurableQuarantineKeepingFence();
      durableQuarantineCleared = true;
      await _secureOperationStore.clearRecovery(target);
      recoveryLease.releaseAfterDurableQuarantineCleared();
      durableQuarantineCleared = false;
      return _AccountDeletionRecoveryOutcome.completed;
    } on Object catch (error) {
      _onRetainedFailure?.call(
        error is AccountDeletionStartupRecoveryFailure
            ? error.safeFailureCode
            : 'localRecoveryFailure',
      );
      try {
        if (durableQuarantineCleared) {
          // The secure erase runs while the in-memory fence remains closed. If
          // it fails, restore the durable marker before returning.
          await recoveryLease?.restoreDurableQuarantineAndRetain();
        } else {
          await recoveryLease?.retainQuarantine();
        }
      } on Object {
        throw const AccountDeletionStartupRecoveryUnavailableException();
      }
      return _AccountDeletionRecoveryOutcome.retained;
    }
  }
}

enum _AccountDeletionRecoveryOutcome {
  completed,
  retained,
  authenticatedContinuation,
}
