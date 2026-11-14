import 'package:cashpilot_ai/core/sync/application/owner_deletion_quarantine_store.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/data_deletion/application/account_deletion_startup_recovery_coordinator.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_session_proof_store.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth-null startup deletion recovery', () {
    test(
      'active proof confirms server before ordered scope-only cleanup',
      () async {
        final harness = _Harness(AccountDeletionSecureOperationStatus.active);

        final report = await harness.coordinator.recoverPending();

        expect(report.completed, 1);
        expect(report.retained, 0);
        expect(report.rejected, 0);
        expect(harness.events, <String>[
          'quarantine.restore',
          'fence.acquire',
          'secure.status',
          'secure.proof',
          'server.confirm',
          'secure.serverConfirmed',
          'secure.status',
          'local.rows',
          'local.verify',
          'local.receipts',
          'local.preferences',
          'local.overlay',
          'local.operationState',
          'lease.releaseAndClearQuarantine',
          'quarantine.release',
          'secure.clear',
        ]);
        expect(harness.gateway.calls, 1);
        expect(harness.quarantine.values, isEmpty);
        expect(harness.secure.statuses, isEmpty);
      },
    );

    test(
      'production fence adapter releases restored in-memory writer gate',
      () async {
        final quarantine = _Quarantine(<String>[], <String, String>{
          _ownerScope: _operationId,
        });
        final operationFence = BackupOperationFence(
          quarantineStore: quarantine,
        );
        final adapter = BackupOperationFenceStartupRecoveryAdapter(
          operationFence: operationFence,
          quarantineStore: quarantine,
        );
        expect(operationFence.tryAcquireWriter(_ownerScope), isNull);

        final recoveryLease = await adapter.acquireRecoveryLease(_testTarget);
        await recoveryLease.releaseAndClearQuarantine();

        final writer = operationFence.tryAcquireWriter(_ownerScope);
        expect(writer, isNotNull);
        writer!.release();
        expect(quarantine.values, isEmpty);
      },
    );

    test(
      'durable release failure remains retainable and can be reacquired',
      () async {
        final quarantine = _Quarantine(<String>[], <String, String>{
          _ownerScope: _operationId,
        })..failReleaseOnce = true;
        final operationFence = BackupOperationFence(
          quarantineStore: quarantine,
        );
        final adapter = BackupOperationFenceStartupRecoveryAdapter(
          operationFence: operationFence,
          quarantineStore: quarantine,
        );

        final failedLease = await adapter.acquireRecoveryLease(_testTarget);
        await expectLater(
          failedLease.releaseAndClearQuarantine(),
          throwsStateError,
        );
        await failedLease.retainQuarantine();

        final retryLease = await adapter.acquireRecoveryLease(_testTarget);
        await retryLease.releaseAndClearQuarantine();
        final writer = operationFence.tryAcquireWriter(_ownerScope);
        expect(writer, isNotNull);
        writer!.release();
      },
    );

    test(
      'server-confirmed state skips proof and remote confirmation',
      () async {
        final harness = _Harness(
          AccountDeletionSecureOperationStatus.serverConfirmed,
        );

        final report = await harness.coordinator.recoverPending();

        expect(report.completed, 1);
        expect(harness.gateway.calls, 0);
        expect(harness.secure.proofReads, 0);
        expect(harness.events, isNot(contains('secure.serverConfirmed')));
        expect(harness.events, isNot(contains('server.confirm')));
      },
    );

    test(
      'secure-only target restores its fence after split-release crash',
      () async {
        final harness = _Harness(
          AccountDeletionSecureOperationStatus.serverConfirmed,
        );
        harness.quarantine.values.clear();

        final report = await harness.coordinator.recoverPending();

        expect(report.completed, 1);
        expect(report.retained, 0);
        expect(report.rejected, 0);
        expect(harness.fence.acquisitions, 1);
        expect(
          harness.events,
          containsAllInOrder(<String>[
            'quarantine.restore',
            'fence.acquire',
            'secure.status',
            'local.rows',
            'secure.clear',
          ]),
        );
        expect(harness.secure.statuses, isEmpty);
      },
    );

    test(
      'local failure retains confirmed authority and retry skips server',
      () async {
        final harness = _Harness(
          AccountDeletionSecureOperationStatus.active,
          failLocalRowsOnce: true,
        );

        final first = await harness.coordinator.recoverPending();
        final second = await harness.coordinator.recoverPending();

        expect(first.retained, 1);
        expect(second.completed, 1);
        expect(harness.gateway.calls, 1);
        expect(harness.secure.serverConfirmations, 1);
        expect(harness.quarantine.values, isEmpty);
        expect(harness.secure.statuses, isEmpty);
      },
    );

    test(
      'server failure retains active proof and performs no local cleanup',
      () async {
        final harness = _Harness(
          AccountDeletionSecureOperationStatus.active,
          failServerOnce: true,
        );

        final first = await harness.coordinator.recoverPending();

        expect(first.retained, 1);
        expect(harness.finalizer.calls, 0);
        expect(harness.quarantine.values, isNotEmpty);
        expect(harness.fence.retentions, 1);
        expect(
          harness.secure.statuses[_targetKey],
          AccountDeletionSecureOperationStatus.active,
        );

        final second = await harness.coordinator.recoverPending();
        expect(second.completed, 1);
        expect(harness.gateway.calls, 2);
        expect(harness.secure.serverConfirmations, 1);
      },
    );

    test(
      'active pre-cloud proof yields only authenticated continuation',
      () async {
        final harness = _Harness(AccountDeletionSecureOperationStatus.active);
        harness.gateway.disposition = AccountDeletionStartupRecoveryDisposition
            .authenticatedContinuationRequired;

        final report = await harness.coordinator.recoverPending();

        expect(report.completed, 0);
        expect(report.retained, 0);
        expect(report.rejected, 0);
        expect(report.authenticatedContinuations, hasLength(1));
        expect(
          report.authenticatedContinuations.single.operationId,
          _testTarget.operationId,
        );
        expect(
          report.authenticatedContinuations.single.ownerScopeValue,
          _testTarget.ownerScopeValue,
        );
        expect(harness.finalizer.calls, 0);
        expect(harness.quarantine.values, <String, String>{
          _ownerScope: _operationId,
        });
        expect(harness.fence.retentions, 1);
        expect(
          harness.secure.statuses[_targetKey],
          AccountDeletionSecureOperationStatus.active,
        );
      },
    );

    test(
      'secure clear failure restores quarantine before a safe retry',
      () async {
        final harness = _Harness(
          AccountDeletionSecureOperationStatus.serverConfirmed,
          failSecureClearOnce: true,
        );

        final first = await harness.coordinator.recoverPending();

        expect(first.retained, 1);
        expect(harness.quarantine.values, <String, String>{
          _ownerScope: _operationId,
        });
        expect(harness.events, contains('quarantine.hold'));
        expect(harness.fence.acquisitions, 1);
        expect(harness.fence.retentions, 1);
        expect(
          harness.secure.statuses[_targetKey],
          AccountDeletionSecureOperationStatus.serverConfirmed,
        );

        final second = await harness.coordinator.recoverPending();
        expect(second.completed, 1);
        expect(harness.gateway.calls, 0);
        expect(harness.quarantine.values, isEmpty);
      },
    );

    test(
      'unverified local emptiness retains quarantine and secure state',
      () async {
        final harness = _Harness(
          AccountDeletionSecureOperationStatus.serverConfirmed,
          localRowsEmpty: false,
        );

        final report = await harness.coordinator.recoverPending();

        expect(report.retained, 1);
        expect(harness.quarantine.values, isNotEmpty);
        expect(
          harness.secure.statuses[_targetKey],
          AccountDeletionSecureOperationStatus.serverConfirmed,
        );
        expect(harness.events, isNot(contains('local.receipts')));
        expect(harness.events, isNot(contains('secure.clear')));
      },
    );

    test(
      'trusted pre-remote abandonment clears only state and quarantine',
      () async {
        final abandoned = _Harness(
          AccountDeletionSecureOperationStatus.abandonedBeforeRemote,
        );
        abandoned.quarantine.values['not-a-scope'] = 'forged-operation';

        final report = await abandoned.coordinator.recoverPending();

        expect(report.completed, 1);
        expect(report.retained, 0);
        expect(report.rejected, 1);
        expect(abandoned.gateway.calls, 0);
        expect(abandoned.finalizer.calls, 1);
        expect(abandoned.finalizer.overlayCalls, 0);
        expect(abandoned.events, isNot(contains('local.rows')));
        expect(abandoned.events, isNot(contains('local.receipts')));
        expect(abandoned.events, contains('local.operationState'));
        expect(abandoned.quarantine.values, <String, String>{
          'not-a-scope': 'forged-operation',
        });
        expect(abandoned.secure.statuses, isEmpty);
      },
    );

    test('concurrent recovery calls serialize and confirm only once', () async {
      final harness = _Harness(AccountDeletionSecureOperationStatus.active);

      final reports =
          await Future.wait(<Future<AccountDeletionStartupRecoveryReport>>[
            harness.coordinator.recoverPending(),
            harness.coordinator.recoverPending(),
          ]);

      expect(reports[0].completed, 1);
      expect(reports[1].completed, 0);
      expect(harness.gateway.calls, 1);
      expect(harness.finalizer.overlayCalls, 1);
    });
  });
}

const _ownerScope =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _operationId = '01900000-0000-7000-8000-000000000111';
final _testTarget = AccountDeletionRecoveryTarget(
  operationId: _operationId,
  ownerScopeValue: _ownerScope,
);
const _targetKey = '$_ownerScope\u0000$_operationId';

final class _Harness {
  _Harness(
    AccountDeletionSecureOperationStatus initialStatus, {
    bool failLocalRowsOnce = false,
    bool failServerOnce = false,
    bool failSecureClearOnce = false,
    bool localRowsEmpty = true,
  }) : events = <String>[],
       quarantine = _Quarantine(<String>[], <String, String>{}),
       secure = _SecureStore(
         <String>[],
         <String, AccountDeletionSecureOperationStatus>{},
       ),
       gateway = _Gateway(<String>[]),
       finalizer = _Finalizer(<String>[]) {
    quarantine.events = events;
    quarantine.values[_ownerScope] = _operationId;
    secure.events = events;
    secure.statuses[_targetKey] = initialStatus;
    secure.failClearOnce = failSecureClearOnce;
    gateway.events = events;
    gateway.failOnce = failServerOnce;
    finalizer.events = events;
    finalizer.failRowsOnce = failLocalRowsOnce;
    finalizer.localRowsEmpty = localRowsEmpty;
    fence = _RecoveryFence(events, quarantine);
    coordinator = AccountDeletionStartupRecoveryCoordinator(
      quarantineStore: quarantine,
      recoveryFence: fence,
      secureOperationStore: secure,
      gateway: gateway,
      localFinalizer: finalizer,
    );
  }

  final List<String> events;
  final _Quarantine quarantine;
  final _SecureStore secure;
  final _Gateway gateway;
  final _Finalizer finalizer;
  late final _RecoveryFence fence;
  late final AccountDeletionStartupRecoveryCoordinator coordinator;
}

final class _RecoveryFence implements AccountDeletionStartupRecoveryFence {
  _RecoveryFence(this.events, this.quarantine);

  final List<String> events;
  final _Quarantine quarantine;
  bool active = false;
  int acquisitions = 0;
  int retentions = 0;

  @override
  Future<AccountDeletionStartupRecoveryLease> acquireRecoveryLease(
    AccountDeletionRecoveryTarget target,
  ) async {
    events.add('fence.acquire');
    acquisitions += 1;
    if (active) {
      throw StateError('synthetic active recovery lease');
    }
    final existing = quarantine.values[target.ownerScopeValue];
    if (existing != null && existing != target.operationId) {
      throw StateError('synthetic quarantine conflict');
    }
    if (existing == null) {
      await quarantine.hold(
        ownerScopeValue: target.ownerScopeValue,
        operationId: target.operationId,
      );
    }
    active = true;
    return _RecoveryLease(this, target);
  }
}

final class _RecoveryLease implements AccountDeletionStartupRecoveryLease {
  _RecoveryLease(this.fence, this.target);

  final _RecoveryFence fence;
  final AccountDeletionRecoveryTarget target;
  bool finished = false;
  bool durableCleared = false;

  @override
  Future<void> releaseAndClearQuarantine() async {
    if (finished) return;
    await clearDurableQuarantineKeepingFence();
    releaseAfterDurableQuarantineCleared();
  }

  @override
  Future<void> clearDurableQuarantineKeepingFence() async {
    if (finished || durableCleared) return;
    fence.events.add('lease.releaseAndClearQuarantine');
    await fence.quarantine.release(
      ownerScopeValue: target.ownerScopeValue,
      operationId: target.operationId,
    );
    durableCleared = true;
  }

  @override
  void releaseAfterDurableQuarantineCleared() {
    if (finished) return;
    if (!durableCleared) {
      throw StateError('synthetic durable quarantine remains');
    }
    fence.active = false;
    finished = true;
  }

  @override
  Future<void> restoreDurableQuarantineAndRetain() async {
    if (finished) return;
    fence.events.add('lease.retainQuarantine');
    await fence.quarantine.hold(
      ownerScopeValue: target.ownerScopeValue,
      operationId: target.operationId,
    );
    durableCleared = false;
    fence.retentions += 1;
    fence.active = false;
    finished = true;
  }

  @override
  Future<void> retainQuarantine() async {
    if (finished) return;
    fence.events.add('lease.retainQuarantine');
    await fence.quarantine.hold(
      ownerScopeValue: target.ownerScopeValue,
      operationId: target.operationId,
    );
    fence.retentions += 1;
    fence.active = false;
    finished = true;
  }
}

final class _Quarantine implements OwnerDeletionQuarantineStore {
  _Quarantine(this.events, this.values);

  List<String> events;
  final Map<String, String> values;
  bool failReleaseOnce = false;

  @override
  Future<void> hold({
    required String ownerScopeValue,
    required String operationId,
  }) async {
    events.add('quarantine.hold');
    values[ownerScopeValue] = operationId;
  }

  @override
  Future<void> release({
    required String ownerScopeValue,
    required String operationId,
  }) async {
    events.add('quarantine.release');
    if (failReleaseOnce) {
      failReleaseOnce = false;
      throw StateError('synthetic durable quarantine release failure');
    }
    if (values[ownerScopeValue] == operationId) {
      values.remove(ownerScopeValue);
    }
  }

  @override
  Map<String, String> restore() {
    events.add('quarantine.restore');
    return Map<String, String>.unmodifiable(values);
  }
}

final class _SecureStore implements AccountDeletionSessionProofStore {
  _SecureStore(this.events, this.statuses);

  List<String> events;
  final Map<String, AccountDeletionSecureOperationStatus> statuses;
  final proof = AccountDeletionSessionProof.parse(
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  );
  int proofReads = 0;
  int serverConfirmations = 0;
  bool failClearOnce = false;

  String _key(AccountDeletionRecoveryTarget target) =>
      '${target.ownerScopeValue}\u0000${target.operationId}';

  @override
  Future<void> clear(DataDeletionOperationContext context) =>
      clearRecovery(context.recoveryTarget);

  @override
  Future<void> clearRecovery(AccountDeletionRecoveryTarget target) async {
    events.add('secure.clear');
    if (failClearOnce) {
      failClearOnce = false;
      throw StateError('synthetic secure clear failure');
    }
    statuses.remove(_key(target));
  }

  @override
  Future<AccountDeletionSessionProof> createAfterReauthentication(
    DataDeletionOperationContext context,
  ) async => proof;

  @override
  Future<void> markAbandonedBeforeRemote(
    DataDeletionOperationContext context,
  ) async {
    statuses[_key(context.recoveryTarget)] =
        AccountDeletionSecureOperationStatus.abandonedBeforeRemote;
  }

  @override
  Future<void> markServerConfirmed(DataDeletionOperationContext context) =>
      markServerConfirmedForRecovery(context.recoveryTarget);

  @override
  Future<void> markServerConfirmedForRecovery(
    AccountDeletionRecoveryTarget target,
  ) async {
    events.add('secure.serverConfirmed');
    serverConfirmations += 1;
    statuses[_key(target)] =
        AccountDeletionSecureOperationStatus.serverConfirmed;
  }

  @override
  Future<AccountDeletionSessionProof> requireExisting(
    DataDeletionOperationContext context,
  ) => requireExistingForRecovery(context.recoveryTarget);

  @override
  Future<AccountDeletionSessionProof> requireExistingForRecovery(
    AccountDeletionRecoveryTarget target,
  ) async {
    events.add('secure.proof');
    proofReads += 1;
    if (statuses[_key(target)] != AccountDeletionSecureOperationStatus.active) {
      throw StateError('proof unavailable');
    }
    return proof;
  }

  @override
  Future<AccountDeletionSecureOperationStatus> recoveryStatus(
    AccountDeletionRecoveryTarget target,
  ) async {
    events.add('secure.status');
    final status = statuses[_key(target)];
    if (status == null) {
      throw StateError('secure recovery state unavailable');
    }
    return status;
  }

  @override
  Future<List<AccountDeletionRecoveryTarget>> recoveryTargets() async {
    return statuses.keys
        .map((coordinate) {
          final separator = coordinate.indexOf('\u0000');
          return AccountDeletionRecoveryTarget(
            ownerScopeValue: coordinate.substring(0, separator),
            operationId: coordinate.substring(separator + 1),
          );
        })
        .toList(growable: false);
  }
}

final class _Gateway implements AccountDeletionStartupRecoveryGateway {
  _Gateway(this.events);

  List<String> events;
  int calls = 0;
  bool failOnce = false;
  AccountDeletionStartupRecoveryDisposition disposition =
      AccountDeletionStartupRecoveryDisposition.alreadyDeleted;

  @override
  Future<AccountDeletionStartupRecoveryDisposition> confirmAlreadyDeleted({
    required AccountDeletionRecoveryTarget target,
    required AccountDeletionSessionProof proof,
  }) async {
    events.add('server.confirm');
    calls += 1;
    if (failOnce) {
      failOnce = false;
      throw StateError('synthetic server confirmation failure');
    }
    expect(target.ownerScopeValue, _ownerScope);
    expect(target.operationId, _operationId);
    expect(proof.toString(), contains('redacted'));
    return disposition;
  }
}

final class _Finalizer implements AccountDeletionScopeRecoveryFinalizer {
  _Finalizer(this.events);

  List<String> events;
  bool failRowsOnce = false;
  bool localRowsEmpty = true;
  int calls = 0;
  int overlayCalls = 0;

  void _event(String value) {
    events.add(value);
    calls += 1;
  }

  @override
  Future<void> clearOperationState(AccountDeletionRecoveryTarget target) async {
    _event('local.operationState');
  }

  @override
  Future<void> clearPreferences(AccountDeletionRecoveryTarget target) async {
    _event('local.preferences');
  }

  @override
  Future<void> deleteLocalRows(AccountDeletionRecoveryTarget target) async {
    _event('local.rows');
    if (failRowsOnce) {
      failRowsOnce = false;
      throw StateError('synthetic local row failure');
    }
  }

  @override
  Future<void> deleteReceiptFiles(AccountDeletionRecoveryTarget target) async {
    _event('local.receipts');
  }

  @override
  Future<void> markCompletionOverlay(
    AccountDeletionRecoveryTarget target,
  ) async {
    _event('local.overlay');
    overlayCalls += 1;
  }

  @override
  Future<bool> verifyLocalRowsEmpty(
    AccountDeletionRecoveryTarget target,
  ) async {
    _event('local.verify');
    return localRowsEmpty;
  }
}
