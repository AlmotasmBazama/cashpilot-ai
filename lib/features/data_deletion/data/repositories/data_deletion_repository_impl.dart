import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/sync/application/backup_operation_fence.dart';
import '../../application/account_deletion_execution_coordinator.dart';
import '../../domain/entities/data_deletion_operation_context.dart';
import '../../domain/entities/data_deletion_request.dart';
import '../../domain/failures/data_deletion_failure_codes.dart';
import '../../domain/repositories/data_deletion_repository.dart';
import '../datasources/account_auth_deletion_data_source.dart';
import '../datasources/account_deletion_auth_data_source.dart';
import '../datasources/account_deletion_session_proof_store.dart';
import '../datasources/cloud_user_data_deletion_data_source.dart';
import '../datasources/data_deletion_operation_state_store.dart';
import '../datasources/deletion_preferences_data_source.dart';
import '../datasources/local_user_data_deletion_data_source.dart';

class DataDeletionRepositoryImpl implements DataDeletionRepository {
  DataDeletionRepositoryImpl({
    required AccountDeletionAuthDataSource authDataSource,
    required AccountAuthDeletionDataSource authDeletionDataSource,
    required CloudUserDataDeletionDataSource cloudDataSource,
    required LocalUserDataDeletionDataSource localDataSource,
    required DeletionPreferencesDataSource preferencesDataSource,
    required DataDeletionOperationStateStore operationStateStore,
    required AccountDeletionSessionProofStore sessionProofStore,
    required BackupOperationFence backupOperationFence,
    AccountDeletionExecutionCoordinator? executionCoordinator,
    required AppLogger logger,
    DateTime Function()? nowUtc,
  }) : _authDataSource = authDataSource,
       _authDeletionDataSource = authDeletionDataSource,
       _cloudDataSource = cloudDataSource,
       _localDataSource = localDataSource,
       _preferencesDataSource = preferencesDataSource,
       _operationStateStore = operationStateStore,
       _sessionProofStore = sessionProofStore,
       _backupOperationFence = backupOperationFence,
       _executionCoordinator =
           executionCoordinator ?? _defaultExecutionCoordinator,
       _logger = logger,
       _nowUtc = nowUtc ?? _systemNowUtc;

  final AccountDeletionAuthDataSource _authDataSource;
  final AccountAuthDeletionDataSource _authDeletionDataSource;
  final CloudUserDataDeletionDataSource _cloudDataSource;
  final LocalUserDataDeletionDataSource _localDataSource;
  final DeletionPreferencesDataSource _preferencesDataSource;
  final DataDeletionOperationStateStore _operationStateStore;
  final AccountDeletionSessionProofStore _sessionProofStore;
  final BackupOperationFence _backupOperationFence;
  final AccountDeletionExecutionCoordinator _executionCoordinator;
  final AppLogger _logger;
  final DateTime Function() _nowUtc;
  bool _operationActive = false;

  static final AccountDeletionExecutionCoordinator
  _defaultExecutionCoordinator = AccountDeletionExecutionCoordinator();

  static const _recentAuthenticationLifetime = Duration(minutes: 5);
  static DateTime _systemNowUtc() => DateTime.now().toUtc();

  @override
  Future<AppResult<DataDeletionReport>> deleteAllUserData(
    DataDeletionRequest request,
  ) async {
    if (!request.confirmationAccepted) {
      return const AppResult.failure(
        Failure(
          message: 'Explicit confirmation is required.',
          code: DataDeletionFailureCodes.confirmationRequired,
        ),
      );
    }
    if (_operationActive) {
      return const AppResult.failure(
        Failure(
          message: 'Another account deletion operation is already active.',
          code: DataDeletionFailureCodes.operationInProgress,
        ),
      );
    }
    _operationActive = true;

    DataDeletionOperationContext? context;
    TrustedDeletionIdentity? capturedIdentity;
    BackupDeletionLease? deletionLease;
    AccountDeletionExecutionLease? executionLease;
    var remoteDeletionStarted = false;
    var preRemoteCheckpointInvalidated = false;
    var finalizationRecovery = false;
    var resumedOperation = false;
    var secureProofEstablished = false;
    var secureRecoveryMustBeRetained = false;

    try {
      try {
        final identity = await _authDataSource.captureSession(
          request.confirmationLease,
        );
        capturedIdentity = identity;
        final expectedRecoveryTarget = request.expectedRecoveryTarget;
        if (expectedRecoveryTarget != null &&
            expectedRecoveryTarget.ownerScopeValue !=
                identity.ownerScope.id.value) {
          throw const _DeletionIdentityChanged();
        }
        // Startup already found an active secure operation for this exact
        // target. From this point every failure is remote-ambiguous until its
        // secure status proves otherwise; never clear its authority because a
        // local provider/checkpoint is missing or stale.
        if (expectedRecoveryTarget != null) {
          remoteDeletionStarted = true;
        }
        executionLease = _executionCoordinator.tryAcquire(
          identity.ownerScope.id.value,
        );
        if (executionLease == null) {
          throw const DataDeletionOperationConflictException();
        }
        final claim = await _operationStateStore.claim(
          identity,
          proposedOperationId:
              expectedRecoveryTarget?.operationId ?? const Uuid().v7(),
          proposedStartedAtUtc: _nowUtc(),
        );
        final storedOperation = claim.operation;
        if (expectedRecoveryTarget != null &&
            storedOperation.operationId != expectedRecoveryTarget.operationId) {
          // Do not attach a different durable checkpoint to [context]. The
          // finally block may clean only an operation proven to be the exact
          // continuation target supplied by the startup gate.
          throw const _DeletionIdentityChanged();
        }
        // An exact startup-continuation target is a resumed secure operation
        // even when its non-authoritative Hive checkpoint was lost. Its active
        // proof may already have crossed a remote byte boundary.
        resumedOperation = !claim.wasCreated || expectedRecoveryTarget != null;
        context = DataDeletionOperationContext.captured(
          operationId: storedOperation.operationId,
          identity: identity,
          startedAtUtc: storedOperation.startedAtUtc,
          idempotencyState: claim.wasCreated
              ? DataDeletionIdempotencyState.newOperation
              : DataDeletionIdempotencyState.resumed,
        );
        if (resumedOperation) {
          context = _restoreCompletedStage(
            context,
            storedOperation.lastCompletedStage,
          );
        }
        finalizationRecovery =
            resumedOperation &&
            storedOperation.lastCompletedStage ==
                DataDeletionStage.preferencesDeleted;
        remoteDeletionStarted =
            remoteDeletionStarted ||
            storedOperation.lastCompletedStage.index >=
                DataDeletionStage.cloudDeleted.index;
        if (_localDataSource.ownerScopeValue != identity.ownerScope.id.value) {
          throw const _DeletionIdentityChanged();
        }
        if (resumedOperation) {
          AccountDeletionSecureOperationStatus? secureStatus;
          try {
            secureStatus = await _sessionProofStore.recoveryStatus(
              context.recoveryTarget,
            );
          } on AccountDeletionSessionProofUnavailableException {
            if (expectedRecoveryTarget != null ||
                context.stage != DataDeletionStage.captured) {
              rethrow;
            }
          }
          if (secureStatus ==
              AccountDeletionSecureOperationStatus.abandonedBeforeRemote) {
            try {
              deletionLease = await _backupOperationFence.fenceAndDrain(
                ownerScopeValue: context.identity.ownerScope.id.value,
                operationId: context.operationId,
                durable: true,
              );
              await _operationStateStore.clear(context);
              await _clearSecureRecordThenReleaseFence(
                context,
                deletionLease,
                reopenWriters: true,
              );
              deletionLease = null;
              context = null;
            } on Object catch (error, stackTrace) {
              return _failure(
                code: DataDeletionFailureCodes.operationInProgress,
                message:
                    'A previous deletion abandonment remains quarantined and must be recovered.',
                error: error,
                stackTrace: stackTrace,
              );
            }
            return _failure(
              code: DataDeletionFailureCodes.operationInProgress,
              message:
                  'A previous pre-remote deletion attempt was cleaned safely. Confirm deletion again to start a new operation.',
              error: StateError('Previous deletion cleanup completed.'),
              stackTrace: StackTrace.current,
            );
          }
          if (secureStatus ==
              AccountDeletionSecureOperationStatus.serverConfirmed) {
            secureRecoveryMustBeRetained = true;
            return _failure(
              code: DataDeletionFailureCodes.authDeletionFinalizationFailed,
              message:
                  'Verified account deletion awaits trusted startup cleanup. The owner remains quarantined.',
              error: StateError('Startup deletion recovery is required.'),
              stackTrace: StackTrace.current,
            );
          }
          if (secureStatus == AccountDeletionSecureOperationStatus.active) {
            // A restored active proof cannot establish that the prior process
            // crashed before its first cloud byte. This includes captured,
            // reauthenticated, backupFenced, and writersVerified checkpoints:
            // the server may have completed recursive deletion before the
            // cloudDeleted checkpoint was persisted. Preserve the same proof,
            // operation, and quarantine across every replay failure.
            remoteDeletionStarted = true;
            secureProofEstablished = true;
          }
        }
        final mustRefreshOldRemoteAuthentication =
            resumedOperation &&
            !finalizationRecovery &&
            (context.stage.index < DataDeletionStage.cloudDeleted.index ||
                _nowUtc().difference(storedOperation.startedAtUtc) >=
                    _recentAuthenticationLifetime);
        if (context.stage == DataDeletionStage.captured) {
          await _authDataSource.reauthenticate(
            context,
            email: request.email,
            password: request.password,
          );
          await _sessionProofStore.createAfterReauthentication(context);
          secureProofEstablished = true;
          context = context.advance(DataDeletionStage.reauthenticated);
          await _operationStateStore.checkpoint(context);
          if (!finalizationRecovery) {
            await _revalidate(context);
          }
        } else {
          await _sessionProofStore.requireExisting(context);
          secureProofEstablished = true;
          if (mustRefreshOldRemoteAuthentication) {
            await _authDataSource.reauthenticate(
              context,
              email: request.email,
              password: request.password,
            );
          }
          if (!finalizationRecovery) {
            await _revalidate(context);
          }
        }
      } on DataDeletionOperationStateCorruptException catch (
        error,
        stackTrace
      ) {
        return _failure(
          code: DataDeletionFailureCodes.operationStateCorrupt,
          message:
              'The deletion checkpoint is invalid. This owner remains quarantined.',
          error: error,
          stackTrace: stackTrace,
        );
      } on DataDeletionOperationConflictException catch (error, stackTrace) {
        return _failure(
          code: DataDeletionFailureCodes.operationInProgress,
          message: 'Another account deletion operation is already active.',
          error: error,
          stackTrace: stackTrace,
        );
      } on AccountDeletionSessionProofCorruptException catch (
        error,
        stackTrace
      ) {
        return _failure(
          code: DataDeletionFailureCodes.secureAuthorizationUnavailable,
          message:
              'Secure deletion authorization is invalid. No further deletion was performed.',
          error: error,
          stackTrace: stackTrace,
        );
      } on AccountDeletionSessionProofUnavailableException catch (
        error,
        stackTrace
      ) {
        return _failure(
          code: DataDeletionFailureCodes.secureAuthorizationUnavailable,
          message:
              'Secure deletion authorization is unavailable. No further deletion was performed.',
          error: error,
          stackTrace: stackTrace,
        );
      } on AccountDeletionIdentityChangedException catch (error, stackTrace) {
        context = context?.abort(DataDeletionFailureCodes.identityChanged);
        return _failure(
          code: DataDeletionFailureCodes.identityChanged,
          message:
              'The signed-in account changed. No further deletion was performed.',
          error: error,
          stackTrace: stackTrace,
        );
      } on _DeletionIdentityChanged catch (error, stackTrace) {
        context = context?.abort(DataDeletionFailureCodes.identityChanged);
        return _failure(
          code: DataDeletionFailureCodes.identityChanged,
          message:
              'The signed-in account changed. No further deletion was performed.',
          error: error,
          stackTrace: stackTrace,
        );
      } on Object catch (error, stackTrace) {
        context = context?.abort(
          DataDeletionFailureCodes.reauthenticationFailed,
        );
        return _failure(
          code: DataDeletionFailureCodes.reauthenticationFailed,
          message: 'Account reauthentication failed.',
          error: error,
          stackTrace: stackTrace,
        );
      }

      try {
        deletionLease = await _backupOperationFence.fenceAndDrain(
          ownerScopeValue: context.identity.ownerScope.id.value,
          operationId: context.operationId,
          durable: true,
        );
        _backupOperationFence.assertDrained(
          ownerScopeValue: context.identity.ownerScope.id.value,
          operationId: context.operationId,
        );
        if (context.stage == DataDeletionStage.reauthenticated) {
          context = context.advance(
            DataDeletionStage.backupFenced,
            backupFenceEpoch: deletionLease.epoch,
          );
        }
        if (context.stage == DataDeletionStage.backupFenced) {
          context = context.advance(DataDeletionStage.writersVerified);
          await _operationStateStore.checkpoint(context);
        }
        if (!finalizationRecovery) {
          await _revalidate(context);
        }
      } on _DeletionIdentityChanged catch (error, stackTrace) {
        context = context!.abort(DataDeletionFailureCodes.identityChanged);
        return _failure(
          code: DataDeletionFailureCodes.identityChanged,
          message:
              'The signed-in account changed. No further deletion was performed.',
          error: error,
          stackTrace: stackTrace,
        );
      } on Object catch (error, stackTrace) {
        context = context!.abort(DataDeletionFailureCodes.operationInProgress);
        return _failure(
          code: DataDeletionFailureCodes.operationInProgress,
          message: 'Another account deletion operation is already active.',
          error: error,
          stackTrace: stackTrace,
        );
      }

      final shouldVerifyCloudPostcondition =
          context.stage.index < DataDeletionStage.cloudDeleted.index ||
          (resumedOperation && !finalizationRecovery);
      if (context.stage.index < DataDeletionStage.cloudDeleted.index) {
        try {
          await _revalidate(context);
          if (await _localDataSource.hasUnresolvedLegacyFinancialData(
            context,
          )) {
            return _failure(
              code: DataDeletionFailureCodes.legacyOwnerResolutionRequired,
              message:
                  'Unclaimed legacy financial data must be explicitly assigned or resolved before account deletion. No cloud or local deletion was started.',
              error: StateError('Legacy owner resolution is required.'),
              stackTrace: StackTrace.current,
            );
          }
        } on _DeletionIdentityChanged catch (error, stackTrace) {
          context = context.abort(DataDeletionFailureCodes.identityChanged);
          return _identityFailure(error, stackTrace);
        } on Object catch (error, stackTrace) {
          return _failure(
            code: DataDeletionFailureCodes.legacyOwnerResolutionRequired,
            message:
                'Legacy financial ownership could not be verified. No cloud or local deletion was started.',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      var cloudDeleted = 0;
      var localDeleted = 0;
      if (shouldVerifyCloudPostcondition) {
        try {
          if (!finalizationRecovery) {
            await _revalidate(context);
          }
          remoteDeletionStarted = true;
          final receipt = await _cloudDataSource.deleteUserData(context);
          if (!receipt.verifiedEmpty ||
              receipt.operationId != context.operationId) {
            throw StateError('Cloud deletion receipt was not verified.');
          }
          cloudDeleted = receipt.deletedDocuments;
          if (context.stage.index < DataDeletionStage.cloudDeleted.index) {
            context = context.advance(DataDeletionStage.cloudDeleted);
            await _operationStateStore.checkpoint(context);
          }
        } on _DeletionIdentityChanged catch (error, stackTrace) {
          context = context!.abort(DataDeletionFailureCodes.identityChanged);
          return _identityFailure(error, stackTrace);
        } on AccountDeletionIdentityChangedException catch (error, stackTrace) {
          context = context!.abort(DataDeletionFailureCodes.identityChanged);
          return _identityFailure(error, stackTrace);
        } on AccountDeletionGatewayFailure catch (error, stackTrace) {
          context = context!.abort(
            DataDeletionFailureCodes.cloudDeletionFailed,
          );
          return _failure(
            code: _cloudGatewayFailureCode(error),
            message:
                'Cloud deletion did not finish. The account and local data were kept so the operation can be retried.',
            error: error,
            stackTrace: stackTrace,
          );
        } on Object catch (error, stackTrace) {
          context = context!.abort(
            DataDeletionFailureCodes.cloudDeletionFailed,
          );
          return _failure(
            code: DataDeletionFailureCodes.cloudDeletionFailed,
            message:
                'Cloud deletion did not finish. The account and local data were kept so the operation can be retried.',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      if (resumedOperation ||
          context.stage.index < DataDeletionStage.localDatabaseDeleted.index) {
        try {
          if (!finalizationRecovery) {
            await _revalidate(context);
          }
          localDeleted = await _localDataSource.deleteLocalDatabase(context);
          _backupOperationFence.assertDrained(
            ownerScopeValue: context.identity.ownerScope.id.value,
            operationId: context.operationId,
          );
          if (!await _localDataSource.verifyLocalDatabaseEmpty(context)) {
            throw StateError('Local owner deletion could not be verified.');
          }
          if (context.stage.index <
              DataDeletionStage.localDatabaseDeleted.index) {
            context = context.advance(DataDeletionStage.localDatabaseDeleted);
            await _operationStateStore.checkpoint(context);
          }
        } on _DeletionIdentityChanged catch (error, stackTrace) {
          context = context!.abort(DataDeletionFailureCodes.identityChanged);
          return _identityFailure(error, stackTrace);
        } on AccountDeletionIdentityChangedException catch (error, stackTrace) {
          context = context!.abort(DataDeletionFailureCodes.identityChanged);
          return _identityFailure(error, stackTrace);
        } on Object catch (error, stackTrace) {
          context = context!.abort(
            DataDeletionFailureCodes.localDeletionFailed,
          );
          return _failure(
            code: DataDeletionFailureCodes.localDeletionFailed,
            message:
                'Cloud data was removed, but local deletion failed. The signed-in account was kept so deletion can be retried.',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      if (resumedOperation ||
          context.stage.index < DataDeletionStage.receiptFilesDeleted.index) {
        try {
          if (!finalizationRecovery) {
            await _revalidate(context);
          }
          await _localDataSource.deleteReceiptFiles(context);
          if (context.stage.index <
              DataDeletionStage.receiptFilesDeleted.index) {
            context = context.advance(DataDeletionStage.receiptFilesDeleted);
            await _operationStateStore.checkpoint(context);
          }
        } on _DeletionIdentityChanged catch (error, stackTrace) {
          context = context!.abort(DataDeletionFailureCodes.identityChanged);
          return _identityFailure(error, stackTrace);
        } on Object catch (error, stackTrace) {
          context = context!.abort(
            DataDeletionFailureCodes.receiptFileDeletionFailed,
          );
          return _failure(
            code: DataDeletionFailureCodes.receiptFileDeletionFailed,
            message:
                'Local rows were removed, but receipt files are pending a safe retry. The account was kept.',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      if (resumedOperation ||
          context.stage.index < DataDeletionStage.preferencesDeleted.index) {
        try {
          if (!finalizationRecovery) {
            await _revalidate(context);
          }
          await _preferencesDataSource.clearForIdentity(context.identity);
          if (context.stage.index <
              DataDeletionStage.preferencesDeleted.index) {
            context = context.advance(DataDeletionStage.preferencesDeleted);
            await _operationStateStore.checkpoint(context);
          }
        } on _DeletionIdentityChanged catch (error, stackTrace) {
          context = context!.abort(DataDeletionFailureCodes.identityChanged);
          return _identityFailure(error, stackTrace);
        } on Object catch (error, stackTrace) {
          context = context!.abort(
            DataDeletionFailureCodes.preferencesDeletionFailed,
          );
          return _failure(
            code: DataDeletionFailureCodes.preferencesDeletionFailed,
            message:
                'Financial data was removed, but local preferences could not be cleared. The account was kept for a safe retry.',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      try {
        if (finalizationRecovery) {
          remoteDeletionStarted = true;
        } else {
          await _revalidate(context);
        }
        late AccountAuthDeletionReceipt authReceipt;
        try {
          authReceipt = await _authDeletionDataSource.deleteAuthAccount(
            context,
            finalizationRecovery: finalizationRecovery,
          );
        } on AccountDeletionReauthenticationRequiredException {
          if (!finalizationRecovery) {
            rethrow;
          }
          await _authDataSource.reauthenticate(
            context,
            email: request.email,
            password: request.password,
          );
          await _sessionProofStore.requireExisting(context);
          await _revalidate(context);
          authReceipt = await _authDeletionDataSource.deleteAuthAccount(
            context,
          );
        }
        if (!authReceipt.authDeleted ||
            authReceipt.operationId != context.operationId) {
          throw StateError('Authentication deletion receipt was not verified.');
        }
      } on _DeletionIdentityChanged catch (error, stackTrace) {
        context = context.abort(DataDeletionFailureCodes.identityChanged);
        return _identityFailure(error, stackTrace);
      } on AccountDeletionIdentityChangedException catch (error, stackTrace) {
        context = context.abort(DataDeletionFailureCodes.identityChanged);
        return _identityFailure(error, stackTrace);
      } on Object catch (error, stackTrace) {
        context = context.abort(DataDeletionFailureCodes.authDeletionFailed);
        return _failure(
          code: DataDeletionFailureCodes.authDeletionFailed,
          message:
              'Data was removed, but the authentication profile could not be deleted. The account remains quarantined; retry from the same account session.',
          error: error,
          stackTrace: stackTrace,
        );
      }

      try {
        // The platform-secure bearer is replaced by a proof-free terminal
        // marker before any fallible local cleanup. A forged Hive stage can
        // therefore never authorize completion or release the quarantine.
        await _sessionProofStore.markServerConfirmed(context);
        context = context.advance(DataDeletionStage.authDeleted);
        await _authDataSource.markServerDeletionCompleted(context);
        await _operationStateStore.clear(context);
        await _clearSecureRecordThenReleaseFence(
          context,
          deletionLease,
          reopenWriters: false,
        );
        deletionLease = null;
      } on Object catch (error, stackTrace) {
        return _failure(
          code: DataDeletionFailureCodes.authDeletionFinalizationFailed,
          message:
              'The authentication profile was deleted, but trusted local finalization did not finish. A retained quarantine or secure terminal marker requires recovery.',
          error: error,
          stackTrace: stackTrace,
        );
      }

      return AppResult.success(
        _completionReport(
          context,
          cloudDocumentsDeleted: cloudDeleted,
          localRowsDeleted: localDeleted,
        ),
      );
    } finally {
      final lease = deletionLease;
      if (!remoteDeletionStarted &&
          !secureRecoveryMustBeRetained &&
          context != null) {
        try {
          // A pre-remote checkpoint must never carry a prior session's
          // reauthentication across a released quarantine. A retry starts a
          // fresh operation and must prove the then-current Auth generation.
          final abandonment = context.stage == DataDeletionStage.aborted
              ? context
              : context.abort('pre_remote_abandoned');
          final abandonedFrom = abandonment.abandonedFromStage;
          if (!secureProofEstablished &&
              abandonedFrom == DataDeletionStage.captured) {
            // Before a proof exists there is no authorization capable of
            // reaching a remote deletion endpoint. The in-process captured
            // stage is sufficient to discard its non-authoritative claim.
          } else {
            // Only platform-secure state may authorize restart cleanup. Hive
            // checkpoints remain non-authoritative and never store terminals.
            await _sessionProofStore.markAbandonedBeforeRemote(abandonment);
          }
          await _operationStateStore.clear(abandonment);
          preRemoteCheckpointInvalidated = true;
        } on Object catch (error, stackTrace) {
          _logger.error(
            'Unable to invalidate the pre-remote deletion checkpoint.',
            error,
            stackTrace,
          );
        }
      }
      if (lease != null && !remoteDeletionStarted) {
        if (preRemoteCheckpointInvalidated) {
          try {
            if (context != null) {
              await _clearSecureRecordThenReleaseFence(
                context,
                lease,
                reopenWriters: true,
              );
            } else {
              lease.retainQuarantine();
            }
          } on Object catch (error, stackTrace) {
            _logger.error(
              'Unable to clear a proof-free deletion abandonment marker while retaining its writer fence.',
              error,
              stackTrace,
            );
            lease.retainQuarantine();
          }
        } else {
          lease.retainQuarantine();
        }
      } else if (lease != null) {
        lease.retainQuarantine();
      } else if (!remoteDeletionStarted &&
          preRemoteCheckpointInvalidated &&
          context != null) {
        try {
          await _sessionProofStore.clear(context);
        } on Object catch (error, stackTrace) {
          _logger.error(
            'Unable to clear a proof-free deletion abandonment marker.',
            error,
            stackTrace,
          );
        }
      }
      if (capturedIdentity != null) {
        _authDataSource.releaseSession(capturedIdentity);
      }
      executionLease?.release();
      _operationActive = false;
    }
  }

  DataDeletionOperationContext _restoreCompletedStage(
    DataDeletionOperationContext context,
    DataDeletionStage completedStage,
  ) {
    if (completedStage == DataDeletionStage.captured) {
      return context;
    }
    if (completedStage == DataDeletionStage.aborted ||
        completedStage == DataDeletionStage.authDeleted) {
      throw StateError('A local terminal checkpoint is not authoritative.');
    }
    var restored = context;
    for (final stage in DataDeletionStage.values) {
      if (stage == DataDeletionStage.captured ||
          stage == DataDeletionStage.aborted) {
        continue;
      }
      restored = restored.advance(stage);
      if (stage == completedStage) {
        return restored;
      }
    }
    throw StateError('Unsupported deletion recovery checkpoint.');
  }

  Future<void> _clearSecureRecordThenReleaseFence(
    DataDeletionOperationContext context,
    BackupDeletionLease lease, {
    required bool reopenWriters,
  }) async {
    var durableQuarantineCleared = false;
    try {
      // Remove the restart index first but keep the in-memory fence closed.
      // Secure v3 records are self-describing, so a process crash here is
      // rediscovered by the route-free startup gate before any writer exists.
      await lease.clearDurableQuarantineKeepingFence();
      durableQuarantineCleared = true;
      await _sessionProofStore.clear(context);
      if (reopenWriters) {
        lease.releaseAfterDurableQuarantineCleared();
      } else {
        lease.retainWriterFenceAfterDurableQuarantineCleared();
      }
    } on Object catch (error, stackTrace) {
      if (durableQuarantineCleared) {
        try {
          await lease.restoreDurableQuarantineAndRetain();
        } on Object {
          Error.throwWithStackTrace(
            StateError(
              'Secure terminal cleanup and quarantine compensation failed.',
            ),
            stackTrace,
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _revalidate(DataDeletionOperationContext context) async {
    try {
      await _authDataSource.revalidate(context);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_DeletionIdentityChanged(error), stackTrace);
    }
  }

  DataDeletionReport _completionReport(
    DataDeletionOperationContext context, {
    int cloudDocumentsDeleted = 0,
    int localRowsDeleted = 0,
  }) {
    return DataDeletionReport(
      cloudDocumentsDeleted: cloudDocumentsDeleted,
      localRowsDeleted: localRowsDeleted,
      completionProof: DataDeletionCompletionProof(
        operationId: context.operationId,
        targetOwnerScopeValue: context.identity.ownerScope.id.value,
        authStateGeneration: context.identity.authStateGeneration,
        authDeletionCompleted: context.stage == DataDeletionStage.authDeleted,
      ),
    );
  }

  AppResult<DataDeletionReport> _identityFailure(
    Object error,
    StackTrace stackTrace,
  ) {
    return _failure(
      code: DataDeletionFailureCodes.identityChanged,
      message:
          'The signed-in account changed. No further deletion was performed.',
      error: error,
      stackTrace: stackTrace,
    );
  }

  AppResult<DataDeletionReport> _failure({
    required String code,
    required String message,
    required Object error,
    required StackTrace stackTrace,
  }) {
    // The closed failure code is safe operational evidence. The logger still
    // redacts the exception itself, so credentials, UIDs, and response bodies
    // cannot cross the diagnostic boundary.
    _logger.error('$message [code=$code]', error, stackTrace);
    return AppResult.failure(Failure(message: message, code: code));
  }

  String _cloudGatewayFailureCode(AccountDeletionGatewayFailure failure) {
    return switch (failure.failureCode) {
      'gatewayRequestInvalid' =>
        DataDeletionFailureCodes.cloudGatewayRequestInvalid,
      'configurationFailure' =>
        DataDeletionFailureCodes.cloudGatewayConfigurationFailed,
      'unauthenticated' || 'appCheckRejected' =>
        DataDeletionFailureCodes.cloudGatewayAuthorizationFailed,
      'authenticationRequired' =>
        DataDeletionFailureCodes.cloudGatewayAuthenticationRequired,
      'appCheckUnavailable' =>
        DataDeletionFailureCodes.cloudGatewayAppCheckUnavailable,
      'deletionProofInvalid' =>
        DataDeletionFailureCodes.cloudGatewayDeletionProofInvalid,
      'permissionDenied' =>
        DataDeletionFailureCodes.cloudGatewayPermissionDenied,
      'operationConflict' =>
        DataDeletionFailureCodes.cloudGatewayOperationConflict,
      'deletionReauthenticationRequired' =>
        DataDeletionFailureCodes.cloudGatewayReauthenticationRequired,
      'rateLimited' => DataDeletionFailureCodes.cloudGatewayRateLimited,
      'providerUnavailable' =>
        DataDeletionFailureCodes.cloudGatewayProviderUnavailable,
      'timeout' => DataDeletionFailureCodes.cloudGatewayTimeout,
      'cloudDeleteTimedOut' => DataDeletionFailureCodes.cloudGatewayTimeout,
      'cloudDeletePartial' =>
        DataDeletionFailureCodes.cloudGatewayDeletePartial,
      'cloudVerificationFailed' =>
        DataDeletionFailureCodes.cloudGatewayVerificationFailed,
      'networkFailure' => DataDeletionFailureCodes.cloudGatewayNetworkFailed,
      'invalidResponse' => DataDeletionFailureCodes.cloudGatewayInvalidResponse,
      'deletionNotReady' =>
        DataDeletionFailureCodes.cloudGatewayDeletionNotReady,
      'unknownTemporaryFailure' =>
        DataDeletionFailureCodes.cloudGatewayUnknownTemporaryFailure,
      _ => DataDeletionFailureCodes.cloudDeletionFailed,
    };
  }
}

final class _DeletionIdentityChanged implements Exception {
  const _DeletionIdentityChanged([this.cause]);

  final Object? cause;

  @override
  String toString() => 'Authenticated identity changed during deletion.';
}
