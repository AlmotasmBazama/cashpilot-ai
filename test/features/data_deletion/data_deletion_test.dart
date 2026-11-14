import 'dart:async';
import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/application/legacy_data_claim_service.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/storage/settings_keys.dart';
import 'package:cashpilot_ai/core/storage/owner_scoped_storage_keys.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/data_deletion/application/account_deletion_execution_coordinator.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_auth_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_auth_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_session_proof_store.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/cloud_user_data_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/data_deletion_operation_state_store.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/deletion_preferences_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/local_user_data_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/receipt_file_deletion_journal.dart';
import 'package:cashpilot_ai/features/data_deletion/data/repositories/data_deletion_repository_impl.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_request.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/failures/data_deletion_failure_codes.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_local_image_store.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/scoped_database_test_helper.dart';
import 'package:hive/hive.dart';

void main() {
  group('DataDeletionRepositoryImpl', () {
    test('deletes every layer in the required order', () async {
      final harness = _DeletionHarness();

      final result = await harness.repository.deleteAllUserData(_request());

      expect(result, isA<AppSuccess<DataDeletionReport>>());
      expect(harness.events, [
        'reauthenticate',
        'cloud',
        'localDatabase',
        'receiptFiles',
        'preferences',
        'auth',
      ]);
      final report = (result as AppSuccess<DataDeletionReport>).data;
      expect(report.cloudDocumentsDeleted, 10);
      expect(report.localRowsDeleted, 9);
    });

    test('requires explicit confirmation before reauthentication', () async {
      final harness = _DeletionHarness();

      final result = await harness.repository.deleteAllUserData(
        _request(confirmationAccepted: false),
      );

      _expectFailure(result, DataDeletionFailureCodes.confirmationRequired);
      expect(harness.events, isEmpty);
    });

    test(
      'reauthentication failure before proof creation can start fresh on retry',
      () async {
        final harness = _DeletionHarness(reauthFailureOnce: true);

        final first = await harness.repository.deleteAllUserData(_request());

        _expectFailure(first, DataDeletionFailureCodes.reauthenticationFailed);
        expect(harness.operationStateStore.stored, isNull);
        expect(harness.sessionProofStore.createCalls, 0);

        final retryLease = await harness.authDataSource
            .issueConfirmationLease();
        final retry = await harness.repository.deleteAllUserData(
          _request(confirmationLease: retryLease),
        );

        expect(retry, isA<AppSuccess<DataDeletionReport>>());
        expect(
          harness.events.where((event) => event == 'reauthenticate'),
          hasLength(2),
        );
      },
    );

    test(
      'forged captured Hive downgrade cannot erase secure server confirmation',
      () async {
        final harness = _DeletionHarness(
          storedOperation: StoredDataDeletionOperation(
            operationId: '01900000-0000-7000-8000-000000000099',
            startedAtUtc: DateTime.utc(2026, 8, 10),
            lastCompletedStage: DataDeletionStage.captured,
          ),
          initialSecureStatus:
              AccountDeletionSecureOperationStatus.serverConfirmed,
        );

        final result = await harness.repository.deleteAllUserData(_request());

        _expectFailure(
          result,
          DataDeletionFailureCodes.authDeletionFinalizationFailed,
        );
        expect(harness.events, isEmpty);
        expect(
          harness.operationStateStore.stored?.lastCompletedStage,
          DataDeletionStage.captured,
        );
        expect(
          harness.sessionProofStore.status,
          AccountDeletionSecureOperationStatus.serverConfirmed,
        );
        expect(harness.sessionProofStore.clearCalls, 0);
      },
    );

    test(
      'active proof with captured checkpoint reauthenticates and replays safely',
      () async {
        final harness = _DeletionHarness(
          storedOperation: StoredDataDeletionOperation(
            operationId: '01900000-0000-7000-8000-000000000100',
            startedAtUtc: DateTime.utc(2026, 8, 10),
            lastCompletedStage: DataDeletionStage.captured,
          ),
          initialSecureStatus: AccountDeletionSecureOperationStatus.active,
        );

        final result = await harness.repository.deleteAllUserData(_request());

        expect(result, isA<AppSuccess<DataDeletionReport>>());
        expect(harness.sessionProofStore.createCalls, 1);
        expect(harness.authDeletionAttempts, 1);
        expect(harness.events, <String>[
          'reauthenticate',
          'cloud',
          'localDatabase',
          'receiptFiles',
          'preferences',
          'auth',
        ]);
      },
    );

    test(
      'exact active continuation with missing Hive state retains proof on reauth failure',
      () async {
        final harness = _DeletionHarness(
          reauthFailureOnce: true,
          initialSecureStatus: AccountDeletionSecureOperationStatus.active,
        );
        final target = AccountDeletionRecoveryTarget(
          operationId: 'active-missing-state-reauth',
          ownerScopeValue: OwnerScopeDerivation.fromConfirmedFirebaseUid(
            'user-1',
          ).id.value,
        );

        final result = await harness.repository.deleteAllUserData(
          _request(expectedRecoveryTarget: target),
        );

        _expectFailure(result, DataDeletionFailureCodes.reauthenticationFailed);
        expect(
          harness.sessionProofStore.status,
          AccountDeletionSecureOperationStatus.active,
        );
        expect(harness.sessionProofStore.abandonedCalls, 0);
        expect(harness.sessionProofStore.clearCalls, 0);
        expect(
          harness.operationStateStore.stored?.operationId,
          target.operationId,
        );
      },
    );

    test(
      'exact active continuation retains authority on pre-cloud local failure',
      () async {
        final harness = _DeletionHarness(
          unresolvedLegacyData: true,
          initialSecureStatus: AccountDeletionSecureOperationStatus.active,
        );
        final target = AccountDeletionRecoveryTarget(
          operationId: 'active-missing-state-local',
          ownerScopeValue: OwnerScopeDerivation.fromConfirmedFirebaseUid(
            'user-1',
          ).id.value,
        );

        final result = await harness.repository.deleteAllUserData(
          _request(expectedRecoveryTarget: target),
        );

        _expectFailure(
          result,
          DataDeletionFailureCodes.legacyOwnerResolutionRequired,
        );
        expect(
          harness.sessionProofStore.status,
          AccountDeletionSecureOperationStatus.active,
        );
        expect(harness.sessionProofStore.abandonedCalls, 0);
        expect(harness.sessionProofStore.clearCalls, 0);
        expect(
          harness.backupOperationFence.isFenced(target.ownerScopeValue),
          isTrue,
        );
      },
    );

    test(
      'exact active continuation never clears authority for a stale B local source',
      () async {
        final harness = _DeletionHarness(
          localOwnerUserId: 'user-2',
          initialSecureStatus: AccountDeletionSecureOperationStatus.active,
        );
        final target = AccountDeletionRecoveryTarget(
          operationId: 'active-missing-state-stale-local',
          ownerScopeValue: OwnerScopeDerivation.fromConfirmedFirebaseUid(
            'user-1',
          ).id.value,
        );

        final result = await harness.repository.deleteAllUserData(
          _request(expectedRecoveryTarget: target),
        );

        _expectFailure(result, DataDeletionFailureCodes.identityChanged);
        expect(
          harness.sessionProofStore.status,
          AccountDeletionSecureOperationStatus.active,
        );
        expect(harness.sessionProofStore.abandonedCalls, 0);
        expect(harness.sessionProofStore.clearCalls, 0);
        expect(
          harness.operationStateStore.stored?.operationId,
          target.operationId,
        );
      },
    );

    test(
      'exact continuation never mints a replacement when secure state disappears',
      () async {
        final harness = _DeletionHarness(
          secureStatusUnavailable: true,
          initialSecureStatus: AccountDeletionSecureOperationStatus.active,
        );
        final target = AccountDeletionRecoveryTarget(
          operationId: 'active-secure-state-disappeared',
          ownerScopeValue: OwnerScopeDerivation.fromConfirmedFirebaseUid(
            'user-1',
          ).id.value,
        );

        final result = await harness.repository.deleteAllUserData(
          _request(expectedRecoveryTarget: target),
        );

        _expectFailure(
          result,
          DataDeletionFailureCodes.secureAuthorizationUnavailable,
        );
        expect(harness.sessionProofStore.createCalls, 0);
        expect(harness.sessionProofStore.clearCalls, 0);
        expect(harness.sessionProofStore.abandonedCalls, 0);
        expect(harness.events, isNot(contains('cloud')));
        expect(
          harness.operationStateStore.stored?.operationId,
          target.operationId,
        );
      },
    );

    test(
      'execution-coordinator conflict releases the captured auth session',
      () async {
        final coordinator = AccountDeletionExecutionCoordinator();
        final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          'user-1',
        ).id.value;
        final competing = coordinator.tryAcquire(scope)!;
        addTearDown(competing.release);
        final harness = _DeletionHarness(executionCoordinator: coordinator);

        final result = await harness.repository.deleteAllUserData(_request());

        _expectFailure(result, DataDeletionFailureCodes.operationInProgress);
        expect(harness.releasedAuthSessions, 1);
        expect(harness.operationStateStore.stored, isNull);
        expect(harness.sessionProofStore.createCalls, 0);
      },
    );

    test(
      'rebuilt repository cannot overlap or clear the winning owner operation',
      () async {
        final harness = _DeletionHarness(blockFirstReauthentication: true);
        addTearDown(() {
          if (!harness.releaseFirstReauthentication.isCompleted) {
            harness.releaseFirstReauthentication.complete();
          }
        });
        final winner = harness.repository.deleteAllUserData(_request());
        await harness.firstReauthenticationStarted.future;
        final secondLease = await harness.authDataSource
            .issueConfirmationLease();

        final loser = await harness.createSiblingRepository().deleteAllUserData(
          _request(confirmationLease: secondLease),
        );

        _expectFailure(loser, DataDeletionFailureCodes.operationInProgress);
        expect(harness.releasedAuthSessions, 1);
        expect(harness.operationStateStore.stored, isNotNull);
        expect(harness.sessionProofStore.clearCalls, 0);
        expect(harness.sessionProofStore.createCalls, 0);

        harness.releaseFirstReauthentication.complete();
        expect(await winner, isA<AppSuccess<DataDeletionReport>>());
        expect(harness.releasedAuthSessions, 2);
      },
    );

    test(
      'state-claim corruption releases the captured auth session once',
      () async {
        final harness = _DeletionHarness(operationClaimCorrupt: true);

        final result = await harness.repository.deleteAllUserData(_request());

        _expectFailure(result, DataDeletionFailureCodes.operationStateCorrupt);
        expect(harness.releasedAuthSessions, 1);
        expect(harness.sessionProofStore.createCalls, 0);
        expect(harness.sessionProofStore.clearCalls, 0);
      },
    );

    test(
      'verified deletion retains A writer fence through secure clear and process lifetime',
      () async {
        final harness = _DeletionHarness(
          blockCompletionDetach: true,
          attemptWriterDuringSecureClear: true,
        );
        addTearDown(() {
          if (!harness.releaseCompletionDetach.isCompleted) {
            harness.releaseCompletionDetach.complete();
          }
        });
        final deletion = harness.repository.deleteAllUserData(_request());
        await harness.completionDetachStarted.future;
        final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          'user-1',
        ).id.value;

        expect(harness.backupOperationFence.isFenced(scope), isTrue);
        expect(harness.sessionProofStore.clearCalls, 0);
        expect(harness.backupOperationFence.tryAcquireWriter(scope), isNull);

        harness.releaseCompletionDetach.complete();
        expect(await deletion, isA<AppSuccess<DataDeletionReport>>());
        expect(harness.writerDuringSecureClear, isNull);
        expect(harness.resurrectionWrites, 0);
        expect(harness.backupOperationFence.isFenced(scope), isTrue);
        expect(harness.backupOperationFence.tryAcquireWriter(scope), isNull);
      },
    );

    test('cloud failure preserves local data, preferences, and auth', () async {
      final harness = _DeletionHarness(failureStage: _Stage.cloud);

      final result = await harness.repository.deleteAllUserData(_request());

      _expectFailure(result, DataDeletionFailureCodes.cloudDeletionFailed);
      expect(harness.events, ['reauthenticate', 'cloud']);
    });

    for (final failureCase in <(String, String)>[
      (
        'providerUnavailable',
        DataDeletionFailureCodes.cloudGatewayProviderUnavailable,
      ),
      ('rateLimited', DataDeletionFailureCodes.cloudGatewayRateLimited),
      ('timeout', DataDeletionFailureCodes.cloudGatewayTimeout),
      ('cloudDeleteTimedOut', DataDeletionFailureCodes.cloudGatewayTimeout),
      (
        'cloudDeletePartial',
        DataDeletionFailureCodes.cloudGatewayDeletePartial,
      ),
      (
        'cloudVerificationFailed',
        DataDeletionFailureCodes.cloudGatewayVerificationFailed,
      ),
      (
        'permissionDenied',
        DataDeletionFailureCodes.cloudGatewayPermissionDenied,
      ),
      (
        'authenticationRequired',
        DataDeletionFailureCodes.cloudGatewayAuthenticationRequired,
      ),
      (
        'appCheckUnavailable',
        DataDeletionFailureCodes.cloudGatewayAppCheckUnavailable,
      ),
      (
        'deletionProofInvalid',
        DataDeletionFailureCodes.cloudGatewayDeletionProofInvalid,
      ),
      ('networkFailure', DataDeletionFailureCodes.cloudGatewayNetworkFailed),
      (
        'deletionNotReady',
        DataDeletionFailureCodes.cloudGatewayDeletionNotReady,
      ),
    ]) {
      test(
        'typed gateway ${failureCase.$1} remains distinguishable and non-destructive',
        () async {
          final harness = _DeletionHarness(
            cloudDataSource: _FailingGatewayCloudDataSource(failureCase.$1),
          );

          final result = await harness.repository.deleteAllUserData(_request());

          _expectFailure(result, failureCase.$2);
          expect(harness.events, ['reauthenticate']);
          expect(harness.deletedAuthUsers, isEmpty);
        },
      );
    }

    test(
      'unclaimed legacy financial data blocks every remote and destructive stage',
      () async {
        final harness = _DeletionHarness(unresolvedLegacyData: true);

        final result = await harness.repository.deleteAllUserData(_request());

        _expectFailure(
          result,
          DataDeletionFailureCodes.legacyOwnerResolutionRequired,
        );
        expect(harness.events, ['reauthenticate']);
        expect(harness.cloudUserId, isNull);
        expect(harness.deletedAuthUsers, isEmpty);
        expect(harness.operationStateStore.stored, isNull);
      },
    );

    test(
      'pre-cloud legacy failure cannot reuse reauthentication in a new session',
      () async {
        final harness = _DeletionHarness(unresolvedLegacyData: true);

        _expectFailure(
          await harness.repository.deleteAllUserData(_request()),
          DataDeletionFailureCodes.legacyOwnerResolutionRequired,
        );
        expect(harness.operationStateStore.stored, isNull);

        harness
          ..unresolvedLegacyData = false
          ..switchAuth(userId: 'user-1', isAnonymous: false);
        final newSessionLease = await harness.authDataSource
            .issueConfirmationLease();
        final retried = await harness.repository.deleteAllUserData(
          _request(confirmationLease: newSessionLease),
        );

        expect(retried, isA<AppSuccess<DataDeletionReport>>());
        expect(
          harness.events.where((event) => event == 'reauthenticate'),
          hasLength(2),
        );
      },
    );

    test(
      'identity race at the cloud dispatch boundary is identityChanged with zero HTTP calls',
      () async {
        var gatewayCalls = 0;
        final harness = _DeletionHarness(
          cloudDataSource: HttpRecursiveCloudUserDataDeletionDataSource(
            config: AccountDeletionGatewayConfig(
              baseUri: Uri.parse('https://gateway.example'),
            ),
            tokenProvider: const _StaleRepositoryBoundaryTokens(),
            httpClient: MockClient((_) async {
              gatewayCalls += 1;
              return http.Response('{}', 500);
            }),
          ),
        );

        final result = await harness.repository.deleteAllUserData(_request());

        _expectFailure(result, DataDeletionFailureCodes.identityChanged);
        expect(gatewayCalls, 0);
        expect(harness.deletedAuthUsers, isEmpty);
        expect(harness.events, ['reauthenticate']);
      },
    );

    test('local failure preserves preferences and auth for retry', () async {
      final harness = _DeletionHarness(failureStage: _Stage.localDatabase);

      final result = await harness.repository.deleteAllUserData(_request());

      _expectFailure(result, DataDeletionFailureCodes.localDeletionFailed);
      expect(harness.events, ['reauthenticate', 'cloud', 'localDatabase']);
      final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
        'user-1',
      ).id.value;
      expect(harness.backupOperationFence.isFenced(scope), isTrue);
      expect(harness.backupOperationFence.tryAcquireWriter(scope), isNull);
      await expectLater(
        harness.backupOperationFence.fenceAndDrain(
          ownerScopeValue: scope,
          operationId: 'conflicting-operation',
          durable: true,
        ),
        throwsStateError,
      );
      expect(harness.backupOperationFence.isFenced(scope), isTrue);
    });

    test('preferences failure preserves auth for retry', () async {
      final harness = _DeletionHarness(failureStage: _Stage.preferences);

      final result = await harness.repository.deleteAllUserData(_request());

      _expectFailure(
        result,
        DataDeletionFailureCodes.preferencesDeletionFailed,
      );
      expect(harness.events, [
        'reauthenticate',
        'cloud',
        'localDatabase',
        'receiptFiles',
        'preferences',
      ]);
      expect(
        harness.operationStateStore.stored?.lastCompletedStage,
        DataDeletionStage.receiptFilesDeleted,
      );
      expect(harness.deletedAuthUsers, isEmpty);
      final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
        'user-1',
      ).id.value;
      expect(harness.backupOperationFence.isFenced(scope), isTrue);
    });

    test('Hive preferences failure is surfaced before Auth deletion', () async {
      final failingBox = _FailingHiveBox();
      final harness = _DeletionHarness(
        preferencesDataSource: HiveDeletionPreferencesDataSource(failingBox),
      );

      final result = await harness.repository.deleteAllUserData(_request());

      _expectFailure(
        result,
        DataDeletionFailureCodes.preferencesDeletionFailed,
      );
      expect(failingBox.deleteAllCalls, 1);
      expect(harness.deletedAuthUsers, isEmpty);
      expect(
        harness.operationStateStore.stored?.lastCompletedStage,
        DataDeletionStage.receiptFilesDeleted,
      );
    });

    test(
      'receipt-files failure preserves preferences and auth for retry',
      () async {
        final harness = _DeletionHarness(failureStage: _Stage.receiptFiles);

        final result = await harness.repository.deleteAllUserData(_request());

        _expectFailure(
          result,
          DataDeletionFailureCodes.receiptFileDeletionFailed,
        );
        expect(harness.events, [
          'reauthenticate',
          'cloud',
          'localDatabase',
          'receiptFiles',
        ]);
        expect(
          harness.operationStateStore.stored?.lastCompletedStage,
          DataDeletionStage.localDatabaseDeleted,
        );
        expect(harness.deletedAuthUsers, isEmpty);
        final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          'user-1',
        ).id.value;
        expect(harness.backupOperationFence.isFenced(scope), isTrue);
      },
    );

    test('auth failure retains quarantine without a global sign-out', () async {
      final harness = _DeletionHarness(failureStage: _Stage.auth);

      final result = await harness.repository.deleteAllUserData(_request());

      _expectFailure(result, DataDeletionFailureCodes.authDeletionFailed);
      expect(harness.events, [
        'reauthenticate',
        'cloud',
        'localDatabase',
        'receiptFiles',
        'preferences',
        'auth',
      ]);
      final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
        'user-1',
      ).id.value;
      expect(harness.backupOperationFence.isFenced(scope), isTrue);
    });

    test(
      'verified Auth deletion plus local marker failure is reported truthfully',
      () async {
        final harness = _DeletionHarness(overlayWriteFailure: true);

        final result = await harness.repository.deleteAllUserData(_request());

        _expectFailure(
          result,
          DataDeletionFailureCodes.authDeletionFinalizationFailed,
        );
        final failure = (result as AppFailure<DataDeletionReport>).failure;
        expect(failure.message, contains('authentication profile was deleted'));
        expect(failure.message, isNot(contains('account was kept')));
        expect(harness.deletedAuthUsers, ['user-1']);
        expect(
          harness.operationStateStore.stored?.lastCompletedStage,
          DataDeletionStage.preferencesDeleted,
        );
        final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          'user-1',
        ).id.value;
        expect(harness.backupOperationFence.isFenced(scope), isTrue);
      },
    );

    test(
      'expired Auth continuation reauthenticates once and reuses the proof',
      () async {
        final harness = _DeletionHarness(
          continuationExpiredOnce: true,
          storedOperation: StoredDataDeletionOperation(
            operationId: '01900000-0000-7000-8000-000000000077',
            startedAtUtc: DateTime.utc(2026, 8, 1),
            lastCompletedStage: DataDeletionStage.preferencesDeleted,
          ),
        );

        final result = await harness.repository.deleteAllUserData(_request());

        expect(result, isA<AppSuccess<DataDeletionReport>>());
        expect(
          harness.events.where((event) => event == 'reauthenticate'),
          hasLength(1),
        );
        expect(harness.authDeletionAttempts, 2);
        expect(harness.sessionProofStore.createCalls, 0);
        expect(harness.sessionProofStore.requireCalls, greaterThanOrEqualTo(2));
        expect(harness.deletedAuthUsers, ['user-1']);
      },
    );

    test(
      'proof-free secure marker survives terminal cleanup interruption',
      () async {
        final harness = _DeletionHarness(proofClearFailureOnce: true);

        final first = await harness.repository.deleteAllUserData(_request());

        _expectFailure(
          first,
          DataDeletionFailureCodes.authDeletionFinalizationFailed,
        );
        expect(harness.operationStateStore.stored, isNull);
        expect(harness.authDeletionAttempts, 1);
        expect(
          harness.sessionProofStore.status,
          AccountDeletionSecureOperationStatus.serverConfirmed,
        );
        final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          'user-1',
        ).id.value;
        expect(harness.backupOperationFence.isFenced(scope), isTrue);
        expect(harness.sessionProofStore.clearCalls, 1);
      },
    );

    test(
      'server-confirmed secure marker retains quarantine when state clear fails',
      () async {
        final harness = _DeletionHarness(operationClearFailureOnce: true);

        final first = await harness.repository.deleteAllUserData(_request());

        _expectFailure(
          first,
          DataDeletionFailureCodes.authDeletionFinalizationFailed,
        );
        expect(
          harness.operationStateStore.stored?.lastCompletedStage,
          DataDeletionStage.preferencesDeleted,
        );
        expect(harness.sessionProofStore.clearCalls, 0);
        expect(
          harness.sessionProofStore.status,
          AccountDeletionSecureOperationStatus.serverConfirmed,
        );
        expect(harness.authDeletionAttempts, 1);
        final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          'user-1',
        ).id.value;
        expect(harness.backupOperationFence.isFenced(scope), isTrue);
      },
    );

    test(
      'pre-remote cleanup marker recovers an interrupted pair of deletes',
      () async {
        final harness = _DeletionHarness(
          unresolvedLegacyData: true,
          operationClearFailureOnce: true,
        );

        final first = await harness.repository.deleteAllUserData(_request());

        _expectFailure(
          first,
          DataDeletionFailureCodes.legacyOwnerResolutionRequired,
        );
        expect(
          harness.operationStateStore.stored?.lastCompletedStage,
          DataDeletionStage.writersVerified,
        );
        expect(
          harness.sessionProofStore.status,
          AccountDeletionSecureOperationStatus.abandonedBeforeRemote,
        );
        expect(harness.cloudUserId, isNull);

        final cleanupLease = await harness.authDataSource
            .issueConfirmationLease();
        final cleanup = await harness.repository.deleteAllUserData(
          _request(confirmationLease: cleanupLease),
        );

        _expectFailure(cleanup, DataDeletionFailureCodes.operationInProgress);
        expect(harness.operationStateStore.stored, isNull);
        expect(harness.cloudUserId, isNull);
      },
    );

    test(
      'identity race inside Auth deletion never signs out or deletes another session',
      () async {
        final harness = _DeletionHarness(identityRaceDuringAuthDelete: true);

        final result = await harness.repository.deleteAllUserData(_request());

        _expectFailure(result, DataDeletionFailureCodes.identityChanged);
        expect(harness.deletedAuthUsers, isEmpty);
        expect(harness.events, [
          'reauthenticate',
          'cloud',
          'localDatabase',
          'receiptFiles',
          'preferences',
        ]);
        expect(harness.events, isNot(contains('signOut')));
      },
    );

    test('logout during deletion aborts before Auth deletion', () async {
      final harness = _DeletionHarness(logoutBeforeAuthDelete: true);

      final result = await harness.repository.deleteAllUserData(_request());

      _expectFailure(result, DataDeletionFailureCodes.identityChanged);
      expect(harness.events, [
        'reauthenticate',
        'cloud',
        'localDatabase',
        'receiptFiles',
        'preferences',
        'logout',
      ]);
      expect(harness.deletedAuthUsers, isEmpty);
      expect(
        harness.operationStateStore.stored?.lastCompletedStage,
        DataDeletionStage.preferencesDeleted,
      );
    });

    test('caller cannot forge the trusted uid or anonymous state', () async {
      final harness = _DeletionHarness();

      final result = await harness.repository.deleteAllUserData(
        DataDeletionRequest(
          confirmationAccepted: true,
          confirmationLease: const AccountDeletionConfirmationLease(
            opaqueToken: 'confirmation-lease-1',
            isAnonymous: false,
          ),
          email: 'forged-user@example.com',
          password: 'secret',
        ),
      );

      expect(result, isA<AppSuccess<DataDeletionReport>>());
      expect(harness.cloudUserId, 'user-1');
      expect(harness.cloudIsAnonymous, isFalse);
    });

    test(
      'one trusted operation identity survives every deletion stage',
      () async {
        final harness = _DeletionHarness();

        expect(
          await harness.repository.deleteAllUserData(_request()),
          isA<AppSuccess<DataDeletionReport>>(),
        );

        expect(harness.capturedOperationId, isNotEmpty);
        expect(
          harness.observedContexts.map((value) => value.operationId).toSet(),
          <String>{harness.capturedOperationId!},
        );
        expect(
          harness.observedContexts
              .map((value) => value.identity.authSessionId)
              .toSet(),
          <String>{'auth-session-1'},
        );
        expect(
          harness.observedContexts.map((value) => value.startedAtUtc).toSet(),
          hasLength(1),
        );
        expect(
          harness.observedContexts.every((value) => value.startedAtUtc.isUtc),
          isTrue,
        );
      },
    );

    test('switching from A to B during deletion never deletes B', () async {
      final harness = _DeletionHarness(switchToUserBeforeAuthDelete: true);

      final result = await harness.repository.deleteAllUserData(_request());

      _expectFailure(result, DataDeletionFailureCodes.identityChanged);
      expect(harness.deletedAuthUsers, isNot(contains('user-2')));
    });

    test(
      'registered confirmation lease cannot delete a switched account',
      () async {
        final harness = _DeletionHarness();
        final lease = await harness.authDataSource.issueConfirmationLease();
        harness.switchAuth(userId: 'user-2', isAnonymous: false);

        final result = await harness.repository.deleteAllUserData(
          _request(confirmationLease: lease),
        );

        _expectFailure(result, DataDeletionFailureCodes.identityChanged);
        expect(harness.events, isEmpty);
      },
    );

    test('registered confirmation lease cannot delete anonymous B', () async {
      final harness = _DeletionHarness();
      final lease = await harness.authDataSource.issueConfirmationLease();
      harness.switchAuth(userId: 'guest-2', isAnonymous: true);

      final result = await harness.repository.deleteAllUserData(
        _request(confirmationLease: lease),
      );

      _expectFailure(result, DataDeletionFailureCodes.identityChanged);
      expect(harness.events, isEmpty);
    });

    test(
      'logout and same-uid relogin invalidates the confirmation epoch',
      () async {
        final harness = _DeletionHarness();
        final lease = await harness.authDataSource.issueConfirmationLease();
        harness.switchAuth(userId: 'user-1', isAnonymous: false);

        final result = await harness.repository.deleteAllUserData(
          _request(confirmationLease: lease),
        );

        _expectFailure(result, DataDeletionFailureCodes.identityChanged);
        expect(harness.events, isEmpty);
      },
    );

    test('token refresh keeps the same confirmation epoch valid', () async {
      final harness = _DeletionHarness();
      final lease = await harness.authDataSource.issueConfirmationLease();
      harness.refreshToken();

      expect(
        await harness.repository.deleteAllUserData(
          _request(confirmationLease: lease),
        ),
        isA<AppSuccess<DataDeletionReport>>(),
      );
    });

    test(
      'deletion fences and drains an already captured backup writer',
      () async {
        final harness = _DeletionHarness();
        final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          'user-1',
        ).id.value;
        final writer = harness.backupOperationFence.tryAcquireWriter(scope)!;

        final deletion = harness.repository.deleteAllUserData(_request());
        for (
          var attempt = 0;
          attempt < 50 && !harness.backupOperationFence.isFenced(scope);
          attempt += 1
        ) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(harness.backupOperationFence.isFenced(scope), isTrue);
        expect(harness.events, isNot(contains('cloud')));
        writer.release();
        expect(await deletion, isA<AppSuccess<DataDeletionReport>>());
        expect(harness.events, contains('cloud'));
      },
    );

    test('a concurrent deletion is rejected before cloud mutation', () async {
      final harness = _DeletionHarness();
      final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
        'user-1',
      ).id.value;
      final existing = await harness.backupOperationFence.fenceAndDrain(
        ownerScopeValue: scope,
        operationId: 'existing-deletion',
      );
      addTearDown(existing.release);

      final result = await harness.repository.deleteAllUserData(_request());

      _expectFailure(result, DataDeletionFailureCodes.operationInProgress);
      expect(harness.events, isNot(contains('cloud')));
    });

    test(
      'two confirmation leases cannot run the same deletion concurrently',
      () async {
        final harness = _DeletionHarness(blockCloud: true);
        final firstLease = await harness.authDataSource
            .issueConfirmationLease();
        final secondLease = await harness.authDataSource
            .issueConfirmationLease();

        final first = harness.repository.deleteAllUserData(
          _request(confirmationLease: firstLease),
        );
        await harness.cloudStarted.future;
        final second = await harness.repository.deleteAllUserData(
          _request(confirmationLease: secondLease),
        );

        _expectFailure(second, DataDeletionFailureCodes.operationInProgress);
        expect(harness.events.where((event) => event == 'cloud'), hasLength(1));
        harness.releaseCloud.complete();
        expect(await first, isA<AppSuccess<DataDeletionReport>>());
      },
    );

    test(
      'double-click with the same confirmation lease starts only once',
      () async {
        final harness = _DeletionHarness(blockCloud: true);
        final lease = await harness.authDataSource.issueConfirmationLease();

        final first = harness.repository.deleteAllUserData(
          _request(confirmationLease: lease),
        );
        await harness.cloudStarted.future;
        final second = await harness.repository.deleteAllUserData(
          _request(confirmationLease: lease),
        );

        _expectFailure(second, DataDeletionFailureCodes.operationInProgress);
        expect(harness.events.where((event) => event == 'cloud'), hasLength(1));
        harness.releaseCloud.complete();
        expect(await first, isA<AppSuccess<DataDeletionReport>>());
      },
    );

    test(
      'a restart resumes the same id and idempotently re-verifies every stage',
      () async {
        final startedAt = DateTime.utc(2026, 8, 9, 12);
        final harness = _DeletionHarness(
          storedOperation: StoredDataDeletionOperation(
            operationId: '01989f80-4e00-7000-8000-000000000001',
            startedAtUtc: startedAt,
            lastCompletedStage: DataDeletionStage.cloudDeleted,
          ),
        );

        expect(
          await harness.repository.deleteAllUserData(_request()),
          isA<AppSuccess<DataDeletionReport>>(),
        );
        expect(
          harness.observedContexts.map((value) => value.operationId).toSet(),
          {'01989f80-4e00-7000-8000-000000000001'},
        );
        expect(
          harness.observedContexts.every(
            (value) =>
                value.idempotencyState == DataDeletionIdempotencyState.resumed,
          ),
          isTrue,
        );
        expect(
          harness.observedContexts.every(
            (value) => value.startedAtUtc == startedAt,
          ),
          isTrue,
        );
        expect(harness.events, [
          'reauthenticate',
          'cloud',
          'localDatabase',
          'receiptFiles',
          'preferences',
          'auth',
        ]);
      },
    );

    test('every nonterminal stored deletion stage resumes safely', () async {
      const expectedEvents = <DataDeletionStage, List<String>>{
        DataDeletionStage.captured: <String>[
          'reauthenticate',
          'cloud',
          'localDatabase',
          'receiptFiles',
          'preferences',
          'auth',
        ],
        DataDeletionStage.reauthenticated: <String>[
          'reauthenticate',
          'cloud',
          'localDatabase',
          'receiptFiles',
          'preferences',
          'auth',
        ],
        DataDeletionStage.backupFenced: <String>[
          'reauthenticate',
          'cloud',
          'localDatabase',
          'receiptFiles',
          'preferences',
          'auth',
        ],
        DataDeletionStage.writersVerified: <String>[
          'reauthenticate',
          'cloud',
          'localDatabase',
          'receiptFiles',
          'preferences',
          'auth',
        ],
        DataDeletionStage.cloudDeleted: <String>[
          'reauthenticate',
          'cloud',
          'localDatabase',
          'receiptFiles',
          'preferences',
          'auth',
        ],
        DataDeletionStage.localDatabaseDeleted: <String>[
          'reauthenticate',
          'cloud',
          'localDatabase',
          'receiptFiles',
          'preferences',
          'auth',
        ],
        DataDeletionStage.receiptFilesDeleted: <String>[
          'reauthenticate',
          'cloud',
          'localDatabase',
          'receiptFiles',
          'preferences',
          'auth',
        ],
        DataDeletionStage.preferencesDeleted: <String>[
          'localDatabase',
          'receiptFiles',
          'preferences',
          'auth',
        ],
      };
      final storableStages = DataDeletionStage.values
          .where(
            (stage) =>
                stage != DataDeletionStage.authDeleted &&
                stage != DataDeletionStage.aborted,
          )
          .toSet();
      expect(expectedEvents.keys.toSet(), storableStages);

      for (final stage in storableStages) {
        final startedAt = DateTime.utc(2026, 8, 9, stage.index);
        final operationId = 'stored-operation-${stage.index}';
        final harness = _DeletionHarness(
          storedOperation: StoredDataDeletionOperation(
            operationId: operationId,
            startedAtUtc: startedAt,
            lastCompletedStage: stage,
          ),
        );

        final result = await harness.repository.deleteAllUserData(_request());

        expect(
          result,
          isA<AppSuccess<DataDeletionReport>>(),
          reason: 'Stored ${stage.name} must resume.',
        );
        expect(
          harness.events,
          expectedEvents[stage],
          reason: 'Stored ${stage.name} replayed the wrong stages.',
        );
        expect(
          harness.observedContexts.map((value) => value.operationId).toSet(),
          <String>{operationId},
        );
        expect(
          harness.observedContexts.every(
            (value) =>
                value.idempotencyState == DataDeletionIdempotencyState.resumed,
          ),
          isTrue,
        );
        expect(
          harness.observedContexts.every(
            (value) => value.startedAtUtc == startedAt,
          ),
          isTrue,
        );
      }
    });

    test(
      'writersVerified checkpoint older than five minutes reauthenticates before recursive deletion',
      () async {
        final now = DateTime.utc(2026, 8, 10, 12);
        final harness = _DeletionHarness(
          nowUtc: () => now,
          storedOperation: StoredDataDeletionOperation(
            operationId: 'old-writers-verified-operation',
            startedAtUtc: now.subtract(const Duration(minutes: 6)),
            lastCompletedStage: DataDeletionStage.writersVerified,
          ),
        );

        expect(
          await harness.repository.deleteAllUserData(_request()),
          isA<AppSuccess<DataDeletionReport>>(),
        );
        expect(harness.events.take(2), ['reauthenticate', 'cloud']);
      },
    );
  });

  test('operation context is UTC, monotonic, and rejects stage replay', () {
    final identity = TrustedDeletionIdentity(
      authSessionId: 'session-1',
      authStateGeneration: 1,
      userId: 'user-1',
      isAnonymous: false,
      ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid('user-1'),
    );
    final captured = DataDeletionOperationContext.captured(
      operationId: 'operation-1',
      identity: identity,
      startedAtUtc: DateTime.parse('2026-08-10T13:00:00+02:00'),
    );
    final reauthenticated = captured.advance(DataDeletionStage.reauthenticated);

    expect(captured.stage, DataDeletionStage.captured);
    expect(captured.startedAtUtc.isUtc, isTrue);
    expect(
      () => reauthenticated.advance(DataDeletionStage.reauthenticated),
      throwsStateError,
    );
    final aborted = reauthenticated.abort(
      DataDeletionFailureCodes.identityChanged,
    );
    expect(aborted.stage, DataDeletionStage.aborted);
    expect(aborted.failureCode, DataDeletionFailureCodes.identityChanged);
    expect(
      () => aborted.advance(DataDeletionStage.backupFenced),
      throwsStateError,
    );
  });

  test('local deletion commits rows before draining receipt files', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final directory = await Directory.systemTemp.createTemp(
      'cashpilot-deletion-receipts-',
    );
    Hive.init(directory.path);
    final journalBox = await Hive.openBox<dynamic>('deletion-journal');
    addTearDown(() async {
      await database.close();
      await journalBox.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    await _seedEveryLocalTable(database);
    final session = scopedTestSession(database);
    final imageStore = ReceiptLocalImageStore(
      ownerScopeValue: session.ownerScopeValue,
      baseDirectory: () async => directory,
    );
    final imagePath = await imageStore.write('receipt-1', const [1, 2, 3]);
    await database.customUpdate(
      'UPDATE receipts SET local_image_reference = ? WHERE id = ?',
      variables: <Variable<Object>>[
        Variable<String>(imagePath),
        const Variable<String>('receipt-1'),
      ],
    );
    expect(await File(imagePath).exists(), isTrue);
    final context = DataDeletionOperationContext.captured(
      operationId: 'operation-local',
      identity: TrustedDeletionIdentity(
        authSessionId: 'session-local',
        authStateGeneration: 1,
        userId: 'cashpilot-test-owner',
        isAnonymous: false,
        ownerScope: session.confirmedScope,
      ),
      startedAtUtc: DateTime.utc(2026, 8, 10),
    );
    final local = DriftLocalUserDataDeletionDataSource(
      session,
      receiptFileJournal: HiveReceiptFileDeletionJournal(
        journalBox,
        receiptImageStore: imageStore,
      ),
    );
    expect(await local.hasUnresolvedLegacyFinancialData(context), isTrue);
    await LegacyDataClaimService(
      session: session,
      currentConfirmedScope: () => session.confirmedScope,
    ).claim(protectedConfirmationAccepted: true);
    expect(await local.hasUnresolvedLegacyFinancialData(context), isFalse);
    await _seedAiAndAuditTables(database, session.ownerScopeValue);
    expect(await _ownerScopedTableNames(database), _allLocalTables.toSet());
    final deleted = await local.deleteLocalDatabase(context);

    expect(deleted, _allLocalTables.length);
    expect(await File(imagePath).exists(), isTrue);
    for (final table in _allLocalTables) {
      final row = await database
          .customSelect('SELECT COUNT(*) AS count FROM $table')
          .getSingle();
      expect(row.read<int>('count'), 0, reason: '$table was not cleared');
    }
    expect(await local.deleteReceiptFiles(context), 1);
    expect(await File(imagePath).exists(), isFalse);
  });

  test(
    'preference deletion clears only A keys and preserves B/global settings',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-deletion-test-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>('settings');
      addTearDown(() async {
        await box.close();
        await directory.delete(recursive: true);
      });
      final user1Identity = _trustedIdentity('user-1');
      final user2Identity = _trustedIdentity('user-2');
      final user1Keys = OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity(
        firebaseUid: user1Identity.userId,
        ownerScope: user1Identity.ownerScope,
      );
      final user2Keys = OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity(
        firebaseUid: user2Identity.userId,
        ownerScope: user2Identity.ownerScope,
      );
      await box.putAll({
        SettingsKeys.themeMode: 'dark',
        SettingsKeys.locale: 'ar',
        SettingsKeys.onboardingCompleted: true,
        SettingsKeys.syncDeviceId: 'device-1',
        SettingsKeys.baseCurrencyCode: 'USD',
        SettingsKeys.rememberMe: true,
        '${SettingsKeys.backupEnabled}_user-1': true,
        '${SettingsKeys.lastBackupAt}_user-1': '2026-01-01',
        '${SettingsKeys.backupEnabled}_user-2': true,
        SettingsKeys.receiptAiPrivacyConsent: true,
        user1Keys.receiptAiPrivacyConsent: true,
        user2Keys.receiptAiPrivacyConsent: true,
        user1Keys.aiAgentMemory: 'user-1-memory',
        user2Keys.aiAgentMemory: 'user-2-memory',
        user1Keys.aiAgentMemoryPersistence: true,
        user2Keys.aiAgentMemoryPersistence: true,
        user1Keys.aiAppControlPolicy: '{"version":1}',
        user2Keys.aiAppControlPolicy: '{"version":1}',
      });

      await HiveDeletionPreferencesDataSource(
        box,
      ).clearForIdentity(user1Identity);

      // Unscoped legacy/app preferences cannot be attributed to A once B is
      // active, so account deletion must not mutate them.
      expect(box.get(SettingsKeys.baseCurrencyCode), 'USD');
      expect(box.get(SettingsKeys.rememberMe), isTrue);
      expect(box.containsKey('${SettingsKeys.backupEnabled}_user-1'), isFalse);
      expect(box.containsKey('${SettingsKeys.lastBackupAt}_user-1'), isFalse);
      expect(box.get(SettingsKeys.receiptAiPrivacyConsent), isTrue);
      expect(box.containsKey(user1Keys.receiptAiPrivacyConsent), isFalse);
      expect(box.containsKey(user1Keys.aiAgentMemory), isFalse);
      expect(box.containsKey(user1Keys.aiAgentMemoryPersistence), isFalse);
      expect(box.containsKey(user1Keys.aiAppControlPolicy), isFalse);
      expect(box.get(SettingsKeys.themeMode), 'dark');
      expect(box.get(SettingsKeys.locale), 'ar');
      expect(box.get(SettingsKeys.onboardingCompleted), isTrue);
      expect(box.get(SettingsKeys.syncDeviceId), 'device-1');
      expect(box.get('${SettingsKeys.backupEnabled}_user-2'), isTrue);
      expect(box.get(user2Keys.receiptAiPrivacyConsent), isTrue);
      expect(box.get(user2Keys.aiAgentMemory), 'user-2-memory');
      expect(box.get(user2Keys.aiAgentMemoryPersistence), isTrue);
      expect(box.containsKey(user2Keys.aiAppControlPolicy), isTrue);
    },
  );
}

DataDeletionRequest _request({
  bool confirmationAccepted = true,
  AccountDeletionRecoveryTarget? expectedRecoveryTarget,
  AccountDeletionConfirmationLease confirmationLease =
      const AccountDeletionConfirmationLease(
        opaqueToken: 'confirmation-lease-1',
        isAnonymous: false,
      ),
}) {
  return DataDeletionRequest(
    confirmationAccepted: confirmationAccepted,
    confirmationLease: confirmationLease,
    email: 'person@example.com',
    password: 'secret',
    expectedRecoveryTarget: expectedRecoveryTarget,
  );
}

void _expectFailure(AppResult<DataDeletionReport> result, String expectedCode) {
  expect(result, isA<AppFailure<DataDeletionReport>>());
  expect((result as AppFailure<DataDeletionReport>).failure.code, expectedCode);
}

enum _Stage {
  reauthenticate,
  cloud,
  localDatabase,
  receiptFiles,
  preferences,
  auth,
}

class _DeletionHarness {
  _DeletionHarness({
    this.failureStage,
    this.switchToUserBeforeAuthDelete = false,
    this.logoutBeforeAuthDelete = false,
    this.identityRaceDuringAuthDelete = false,
    this.overlayWriteFailure = false,
    this.unresolvedLegacyData = false,
    this.blockCloud = false,
    this.continuationExpiredOnce = false,
    this.reauthFailureOnce = false,
    this.proofClearFailureOnce = false,
    this.operationClearFailureOnce = false,
    this.terminalCheckpointFailureOnce = false,
    this.localOwnerUserId = 'user-1',
    this.secureStatusUnavailable = false,
    this.operationClaimCorrupt = false,
    this.blockCompletionDetach = false,
    this.attemptWriterDuringSecureClear = false,
    this.blockFirstReauthentication = false,
    this.initialSecureStatus,
    AccountDeletionExecutionCoordinator? executionCoordinator,
    StoredDataDeletionOperation? storedOperation,
    DeletionPreferencesDataSource? preferencesDataSource,
    CloudUserDataDeletionDataSource? cloudDataSource,
    DateTime Function()? nowUtc,
  }) : events = <String>[],
       executionCoordinator =
           executionCoordinator ?? AccountDeletionExecutionCoordinator(),
       backupOperationFence = BackupOperationFence(),
       operationStateStore = _FakeOperationStateStore(
         storedOperation,
         failClearOnce: operationClearFailureOnce,
         failTerminalCheckpointOnce: terminalCheckpointFailureOnce,
         failClaimCorrupt: operationClaimCorrupt,
       ) {
    operationStateStore.harness = this;
    authDataSource = _FakeAuthDataSource(this);
    sessionProofStore = _FakeSessionProofStore(
      failClearOnce: proofClearFailureOnce,
      exists:
          initialSecureStatus != null ||
          (storedOperation != null &&
              storedOperation.lastCompletedStage.index >=
                  DataDeletionStage.reauthenticated.index),
      initialStatus:
          initialSecureStatus ?? AccountDeletionSecureOperationStatus.active,
      recoveryStatusUnavailable: secureStatusUnavailable,
    )..harness = this;
    repository = DataDeletionRepositoryImpl(
      authDataSource: authDataSource,
      authDeletionDataSource: _FakeAccountAuthDeletionDataSource(this),
      cloudDataSource: cloudDataSource ?? _FakeCloudDataSource(this),
      localDataSource: _FakeLocalDataSource(this),
      preferencesDataSource:
          preferencesDataSource ?? _FakePreferencesDataSource(this),
      operationStateStore: operationStateStore,
      sessionProofStore: sessionProofStore,
      backupOperationFence: backupOperationFence,
      executionCoordinator: this.executionCoordinator,
      logger: AppLogger.instance,
      nowUtc: nowUtc,
    );
  }

  final List<String> events;
  final _Stage? failureStage;
  final bool switchToUserBeforeAuthDelete;
  final bool logoutBeforeAuthDelete;
  final bool identityRaceDuringAuthDelete;
  final bool overlayWriteFailure;
  bool unresolvedLegacyData;
  final bool blockCloud;
  final bool continuationExpiredOnce;
  bool reauthFailureOnce;
  final bool proofClearFailureOnce;
  final bool operationClearFailureOnce;
  final bool terminalCheckpointFailureOnce;
  final String localOwnerUserId;
  final bool secureStatusUnavailable;
  final bool operationClaimCorrupt;
  final bool blockCompletionDetach;
  final bool attemptWriterDuringSecureClear;
  final bool blockFirstReauthentication;
  final AccountDeletionSecureOperationStatus? initialSecureStatus;
  int authDeletionAttempts = 0;
  int releasedAuthSessions = 0;
  int resurrectionWrites = 0;
  BackupWriterLease? writerDuringSecureClear;
  final BackupOperationFence backupOperationFence;
  final AccountDeletionExecutionCoordinator executionCoordinator;
  final _FakeOperationStateStore operationStateStore;
  late final _FakeSessionProofStore sessionProofStore;
  late final _FakeAuthDataSource authDataSource;
  String currentAuthUserId = 'user-1';
  bool currentAuthIsAnonymous = false;
  int authStateGeneration = 1;
  bool signedIn = true;
  final List<String> deletedAuthUsers = <String>[];
  final Completer<void> cloudStarted = Completer<void>();
  final Completer<void> releaseCloud = Completer<void>();
  final Completer<void> completionDetachStarted = Completer<void>();
  final Completer<void> releaseCompletionDetach = Completer<void>();
  final Completer<void> firstReauthenticationStarted = Completer<void>();
  final Completer<void> releaseFirstReauthentication = Completer<void>();
  String? cloudUserId;
  bool? cloudIsAnonymous;
  String? capturedOperationId;
  final List<DataDeletionOperationContext> observedContexts =
      <DataDeletionOperationContext>[];
  late final DataDeletionRepositoryImpl repository;

  DataDeletionRepositoryImpl createSiblingRepository() {
    return DataDeletionRepositoryImpl(
      authDataSource: authDataSource,
      authDeletionDataSource: _FakeAccountAuthDeletionDataSource(this),
      cloudDataSource: _FakeCloudDataSource(this),
      localDataSource: _FakeLocalDataSource(this),
      preferencesDataSource: _FakePreferencesDataSource(this),
      operationStateStore: operationStateStore,
      sessionProofStore: sessionProofStore,
      backupOperationFence: backupOperationFence,
      executionCoordinator: executionCoordinator,
      logger: AppLogger.instance,
    );
  }

  void switchAuth({required String userId, required bool isAnonymous}) {
    signedIn = true;
    currentAuthUserId = userId;
    currentAuthIsAnonymous = isAnonymous;
    authStateGeneration += 1;
  }

  void logout() {
    signedIn = false;
    authStateGeneration += 1;
    events.add('logout');
  }

  void refreshToken() {}

  void record(String event, _Stage stage) {
    events.add(event);
    if (failureStage == stage) {
      throw StateError('$event failed');
    }
  }
}

final class _FakeSessionProofStore implements AccountDeletionSessionProofStore {
  _FakeSessionProofStore({
    bool failClearOnce = false,
    bool exists = false,
    AccountDeletionSecureOperationStatus initialStatus =
        AccountDeletionSecureOperationStatus.active,
    bool recoveryStatusUnavailable = false,
  }) : _failClearOnce = failClearOnce,
       _exists = exists,
       _recoveryStatusUnavailable = recoveryStatusUnavailable,
       status = initialStatus;

  final proof = AccountDeletionSessionProof.parse(
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  );
  _DeletionHarness? harness;
  var createCalls = 0;
  var requireCalls = 0;
  var clearCalls = 0;
  var serverConfirmedCalls = 0;
  var abandonedCalls = 0;
  AccountDeletionSecureOperationStatus status;
  bool _failClearOnce;
  bool _exists;
  final bool _recoveryStatusUnavailable;

  @override
  Future<void> clear(DataDeletionOperationContext context) async {
    await clearRecovery(context.recoveryTarget);
  }

  @override
  Future<void> clearRecovery(AccountDeletionRecoveryTarget target) async {
    clearCalls += 1;
    final targetHarness = harness;
    if (targetHarness?.attemptWriterDuringSecureClear ?? false) {
      final writer = targetHarness!.backupOperationFence.tryAcquireWriter(
        target.ownerScopeValue,
      );
      targetHarness.writerDuringSecureClear = writer;
      if (writer != null) {
        targetHarness.resurrectionWrites += 1;
        writer.release();
      }
    }
    if (_failClearOnce) {
      _failClearOnce = false;
      throw StateError('synthetic secure proof clear failure');
    }
    _exists = false;
  }

  @override
  Future<AccountDeletionSessionProof> createAfterReauthentication(
    DataDeletionOperationContext context,
  ) async {
    createCalls += 1;
    _exists = true;
    status = AccountDeletionSecureOperationStatus.active;
    return proof;
  }

  @override
  Future<void> markAbandonedBeforeRemote(
    DataDeletionOperationContext context,
  ) async {
    if (!_exists) {
      throw const AccountDeletionSessionProofUnavailableException();
    }
    abandonedCalls += 1;
    status = AccountDeletionSecureOperationStatus.abandonedBeforeRemote;
  }

  @override
  Future<void> markServerConfirmed(DataDeletionOperationContext context) =>
      markServerConfirmedForRecovery(context.recoveryTarget);

  @override
  Future<void> markServerConfirmedForRecovery(
    AccountDeletionRecoveryTarget target,
  ) async {
    if (!_exists) {
      throw const AccountDeletionSessionProofUnavailableException();
    }
    serverConfirmedCalls += 1;
    status = AccountDeletionSecureOperationStatus.serverConfirmed;
  }

  @override
  Future<AccountDeletionSecureOperationStatus> recoveryStatus(
    AccountDeletionRecoveryTarget target,
  ) async {
    if (_recoveryStatusUnavailable) {
      throw const AccountDeletionSessionProofUnavailableException();
    }
    if (!_exists) {
      throw const AccountDeletionSessionProofUnavailableException();
    }
    return status;
  }

  @override
  Future<List<AccountDeletionRecoveryTarget>> recoveryTargets() async =>
      const <AccountDeletionRecoveryTarget>[];

  @override
  Future<AccountDeletionSessionProof> requireExisting(
    DataDeletionOperationContext context,
  ) => requireExistingForRecovery(context.recoveryTarget);

  @override
  Future<AccountDeletionSessionProof> requireExistingForRecovery(
    AccountDeletionRecoveryTarget target,
  ) async {
    requireCalls += 1;
    if (!_exists || status != AccountDeletionSecureOperationStatus.active) {
      throw const AccountDeletionSessionProofUnavailableException();
    }
    return proof;
  }
}

class _FakeAuthDataSource implements AccountDeletionAuthDataSource {
  _FakeAuthDataSource(this.harness)
    : _leaseUserId = harness.currentAuthUserId,
      _leaseIsAnonymous = harness.currentAuthIsAnonymous,
      _leaseGeneration = harness.authStateGeneration;

  final _DeletionHarness harness;
  String _leaseUserId;
  bool _leaseIsAnonymous;
  int _leaseGeneration;
  var _leaseCounter = 0;
  final Set<String> _availableLeaseTokens = <String>{'confirmation-lease-1'};

  @override
  Future<TrustedDeletionIdentity> captureSession(
    AccountDeletionConfirmationLease lease,
  ) async {
    if (!_availableLeaseTokens.remove(lease.opaqueToken) ||
        !harness.signedIn ||
        harness.currentAuthUserId != _leaseUserId ||
        harness.currentAuthIsAnonymous != _leaseIsAnonymous ||
        harness.authStateGeneration != _leaseGeneration ||
        lease.isAnonymous != _leaseIsAnonymous) {
      throw const AccountDeletionIdentityChangedException();
    }
    return TrustedDeletionIdentity(
      authSessionId: 'auth-session-1',
      authStateGeneration: harness.authStateGeneration,
      userId: harness.currentAuthUserId,
      isAnonymous: harness.currentAuthIsAnonymous,
      ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid(
        harness.currentAuthUserId,
      ),
    );
  }

  @override
  Future<AccountDeletionConfirmationLease> issueConfirmationLease() async {
    _leaseUserId = harness.currentAuthUserId;
    _leaseIsAnonymous = harness.currentAuthIsAnonymous;
    _leaseGeneration = harness.authStateGeneration;
    _leaseCounter += 1;
    final token = 'confirmation-lease-$_leaseCounter';
    _availableLeaseTokens.add(token);
    return AccountDeletionConfirmationLease(
      opaqueToken: token,
      isAnonymous: _leaseIsAnonymous,
    );
  }

  @override
  void releaseConfirmationLease(AccountDeletionConfirmationLease lease) {
    _availableLeaseTokens.remove(lease.opaqueToken);
  }

  @override
  Future<void> reauthenticate(
    DataDeletionOperationContext context, {
    String? email,
    String? password,
  }) async {
    harness.observedContexts.add(context);
    if (harness.blockFirstReauthentication &&
        !harness.firstReauthenticationStarted.isCompleted) {
      harness.firstReauthenticationStarted.complete();
      await harness.releaseFirstReauthentication.future;
    }
    if (harness.reauthFailureOnce) {
      harness.reauthFailureOnce = false;
      harness.events.add('reauthenticate');
      throw StateError('synthetic one-shot reauthentication failure');
    }
    harness.record('reauthenticate', _Stage.reauthenticate);
  }

  @override
  Future<void> revalidate(DataDeletionOperationContext context) async {
    harness.observedContexts.add(context);
    if (!harness.signedIn ||
        harness.currentAuthUserId != context.identity.userId ||
        harness.currentAuthIsAnonymous != context.identity.isAnonymous ||
        harness.authStateGeneration != context.identity.authStateGeneration) {
      throw StateError('authenticated identity changed');
    }
  }

  @override
  Future<String> freshIdToken(DataDeletionOperationContext context) async {
    assertSessionCurrent(context);
    return 'test-id-token';
  }

  @override
  Future<String> cachedIdTokenForFinalization(
    DataDeletionOperationContext context,
  ) => freshIdToken(context);

  @override
  void assertSessionCurrent(DataDeletionOperationContext context) {
    if (!harness.signedIn ||
        harness.currentAuthUserId != context.identity.userId ||
        harness.currentAuthIsAnonymous != context.identity.isAnonymous ||
        harness.authStateGeneration != context.identity.authStateGeneration) {
      throw const AccountDeletionIdentityChangedException();
    }
  }

  @override
  Future<void> markServerDeletionCompleted(
    DataDeletionOperationContext context,
  ) async {
    assertSessionCurrent(context);
    if (!harness.completionDetachStarted.isCompleted) {
      harness.completionDetachStarted.complete();
    }
    if (harness.blockCompletionDetach) {
      await harness.releaseCompletionDetach.future;
    }
    if (harness.overlayWriteFailure) {
      throw StateError('durable completion marker unavailable');
    }
  }

  @override
  void releaseSession(TrustedDeletionIdentity identity) {
    harness.releasedAuthSessions += 1;
  }
}

final class _FakeAccountAuthDeletionDataSource
    implements AccountAuthDeletionDataSource {
  const _FakeAccountAuthDeletionDataSource(this.harness);

  final _DeletionHarness harness;

  @override
  Future<AccountAuthDeletionReceipt> deleteAuthAccount(
    DataDeletionOperationContext context, {
    bool finalizationRecovery = false,
  }) async {
    harness.authDeletionAttempts += 1;
    if (finalizationRecovery &&
        harness.continuationExpiredOnce &&
        harness.authDeletionAttempts == 1) {
      throw const AccountDeletionReauthenticationRequiredException();
    }
    await harness.authDataSource.revalidate(context);
    if (harness.identityRaceDuringAuthDelete) {
      throw const AccountDeletionIdentityChangedException();
    }
    harness.record('auth', _Stage.auth);
    harness.deletedAuthUsers.add(harness.currentAuthUserId);
    return AccountAuthDeletionReceipt(
      operationId: context.operationId,
      authDeleted: true,
      alreadyDeleted: false,
    );
  }
}

class _FakeCloudDataSource implements CloudUserDataDeletionDataSource {
  const _FakeCloudDataSource(this.harness);

  final _DeletionHarness harness;

  @override
  Future<CloudDeletionReceipt> deleteUserData(
    DataDeletionOperationContext context,
  ) async {
    harness.record('cloud', _Stage.cloud);
    if (harness.blockCloud) {
      if (!harness.cloudStarted.isCompleted) {
        harness.cloudStarted.complete();
      }
      await harness.releaseCloud.future;
    }
    harness.cloudUserId = context.identity.userId;
    harness.cloudIsAnonymous = context.identity.isAnonymous;
    return CloudDeletionReceipt(
      operationId: context.operationId,
      deletedDocuments: 10,
      verifiedEmpty: true,
    );
  }
}

final class _FailingGatewayCloudDataSource
    implements CloudUserDataDeletionDataSource {
  const _FailingGatewayCloudDataSource(this.failureCode);

  final String failureCode;

  @override
  Future<CloudDeletionReceipt> deleteUserData(
    DataDeletionOperationContext context,
  ) async {
    throw AccountDeletionGatewayFailure(
      failureCode: failureCode,
      statusCode: 503,
      retryable: true,
    );
  }
}

class _FakeLocalDataSource implements LocalUserDataDeletionDataSource {
  const _FakeLocalDataSource(this.harness);

  final _DeletionHarness harness;

  @override
  String get ownerScopeValue => OwnerScopeDerivation.fromConfirmedFirebaseUid(
    harness.localOwnerUserId,
  ).id.value;

  @override
  Future<bool> hasUnresolvedLegacyFinancialData(
    DataDeletionOperationContext context,
  ) async => harness.unresolvedLegacyData;

  @override
  Future<int> deleteLocalDatabase(DataDeletionOperationContext context) async {
    harness.record('localDatabase', _Stage.localDatabase);
    return 9;
  }

  @override
  Future<int> deleteReceiptFiles(DataDeletionOperationContext context) async {
    harness.record('receiptFiles', _Stage.receiptFiles);
    return 1;
  }

  @override
  Future<bool> verifyLocalDatabaseEmpty(
    DataDeletionOperationContext context,
  ) async => true;
}

class _FakePreferencesDataSource implements DeletionPreferencesDataSource {
  const _FakePreferencesDataSource(this.harness);

  final _DeletionHarness harness;

  @override
  Future<void> clearForIdentity(TrustedDeletionIdentity identity) async {
    harness.record('preferences', _Stage.preferences);
    if (harness.switchToUserBeforeAuthDelete) {
      harness.currentAuthUserId = 'user-2';
    }
    if (harness.logoutBeforeAuthDelete) {
      harness.logout();
    }
  }
}

class _FakeOperationStateStore implements DataDeletionOperationStateStore {
  _FakeOperationStateStore(
    this.stored, {
    bool failClearOnce = false,
    bool failTerminalCheckpointOnce = false,
    bool failClaimCorrupt = false,
  }) : _failClearOnce = failClearOnce,
       _failTerminalCheckpointOnce = failTerminalCheckpointOnce,
       _failClaimCorrupt = failClaimCorrupt;

  StoredDataDeletionOperation? stored;
  _DeletionHarness? harness;
  bool _failClearOnce;
  bool _failTerminalCheckpointOnce;
  final bool _failClaimCorrupt;

  @override
  Future<DataDeletionOperationClaim> claim(
    TrustedDeletionIdentity identity, {
    required String proposedOperationId,
    required DateTime proposedStartedAtUtc,
  }) async {
    if (_failClaimCorrupt) {
      throw const DataDeletionOperationStateCorruptException();
    }
    final existing = stored;
    if (existing != null) {
      return DataDeletionOperationClaim(operation: existing, wasCreated: false);
    }
    final created = StoredDataDeletionOperation(
      operationId: proposedOperationId,
      startedAtUtc: proposedStartedAtUtc,
      lastCompletedStage: DataDeletionStage.captured,
    );
    stored = created;
    return DataDeletionOperationClaim(operation: created, wasCreated: true);
  }

  @override
  Future<StoredDataDeletionOperation?> read(
    TrustedDeletionIdentity identity,
  ) async => stored;

  @override
  Future<void> checkpoint(DataDeletionOperationContext context) async {
    if (context.stage == DataDeletionStage.authDeleted &&
        _failTerminalCheckpointOnce) {
      _failTerminalCheckpointOnce = false;
      throw StateError('synthetic terminal checkpoint failure');
    }
    final targetHarness = harness;
    if (targetHarness != null) {
      targetHarness.capturedOperationId ??= context.operationId;
    }
    final previous = stored;
    if (previous != null && previous.operationId != context.operationId) {
      throw const DataDeletionOperationConflictException();
    }
    final stage =
        previous != null &&
            previous.operationId == context.operationId &&
            previous.lastCompletedStage.index > context.stage.index
        ? previous.lastCompletedStage
        : context.stage;
    stored = StoredDataDeletionOperation(
      operationId: context.operationId,
      startedAtUtc: context.startedAtUtc,
      lastCompletedStage: stage,
    );
  }

  @override
  Future<void> clear(DataDeletionOperationContext context) async {
    await clearRecovery(context.recoveryTarget);
  }

  @override
  Future<void> clearRecovery(AccountDeletionRecoveryTarget target) async {
    if (_failClearOnce) {
      _failClearOnce = false;
      throw StateError('synthetic operation clear failure');
    }
    if (stored?.operationId == target.operationId) {
      stored = null;
    }
  }
}

final class _FailingHiveBox implements Box<dynamic> {
  var deleteAllCalls = 0;

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    deleteAllCalls += 1;
    throw StateError('simulated Hive deleteAll failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _StaleRepositoryBoundaryTokens
    implements AccountDeletionGatewayTokenProvider {
  const _StaleRepositoryBoundaryTokens();

  @override
  Future<AccountDeletionGatewayTokens> freshTokens(
    DataDeletionOperationContext context,
  ) async => AccountDeletionGatewayTokens(
    authToken: 'captured-auth-token',
    appCheckToken: 'app-check-token',
    deletionSessionProof: AccountDeletionSessionProof.parse(
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    ),
  );

  @override
  void assertSessionCurrent(DataDeletionOperationContext context) {
    throw const AccountDeletionIdentityChangedException();
  }

  @override
  Future<AccountDeletionGatewayTokens> finalizationRecoveryTokens(
    DataDeletionOperationContext context,
  ) => freshTokens(context);
}

TrustedDeletionIdentity _trustedIdentity(String uid) => TrustedDeletionIdentity(
  authSessionId: 'session-$uid',
  authStateGeneration: 1,
  userId: uid,
  isAnonymous: false,
  ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid(uid),
);

const _allLocalTables = <String>[
  'ai_agent_plan_steps',
  'ai_agent_plans',
  'ai_agent_confirmation_proofs',
  'ai_agent_execution_results',
  'ai_agent_execution_attempts',
  'ai_agent_business_operations',
  'ai_agent_idempotency_records',
  'ai_agent_previews',
  'ai_agent_audit_events',
  'ai_agent_commands',
  'transaction_splits',
  'receipt_line_items',
  'receipts',
  'transactions',
  'goal_contributions',
  'goals',
  'budgets',
  'exchange_rates',
  'payees',
  'categories',
  'accounts',
  'sync_queue',
  'owner_scope_migration_audits',
];

Future<Set<String>> _ownerScopedTableNames(AppDatabase database) async {
  final tables = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  final owned = <String>{};
  for (final table in tables) {
    final name = table.read<String>('name');
    final columns = await database
        .customSelect('PRAGMA table_info($name)')
        .get();
    if (columns.any(
      (column) => column.read<String>('name') == 'owner_scope_id',
    )) {
      owned.add(name);
    }
  }
  return owned;
}

Future<void> _seedAiAndAuditTables(
  AppDatabase database,
  String ownerScope,
) async {
  final variables = <Object?>[ownerScope];
  await database.customStatement('''
    INSERT INTO ai_agent_commands (
      id, owner_scope_id, conversation_id, command_type, tool_id,
      normalized_arguments_json, permission, risk, status, revision,
      expires_at, created_at, updated_at
    ) VALUES (
      'agent-command-1', ?, 'conversation-1', 'create', 'create_transaction',
      '{}', 'executeConfirmedAction', 'high', 'confirmed', 1, 2, 1, 1
    )
  ''', variables);
  await database.customStatement('''
    INSERT INTO ai_agent_previews (
      id, owner_scope_id, command_id, revision, status, state_fingerprint,
      payload_json, expires_at, created_at, updated_at
    ) VALUES ('agent-preview-1', ?, 'agent-command-1', 1, 'valid', 'fp', '{}', 2, 1, 1)
  ''', variables);
  await database.customStatement('''
    INSERT INTO ai_agent_confirmation_proofs (
      id, owner_scope_id, command_id, preview_revision, confirmation_method,
      proof_hash, proof_salt, status, expires_at, created_at, updated_at
    ) VALUES ('agent-proof-1', ?, 'agent-command-1', 1, 'explicit', 'hash', 'salt', 'active', 2, 1, 1)
  ''', variables);
  await database.customStatement('''
    INSERT INTO ai_agent_business_operations (
      id, owner_scope_id, command_id, command_revision, action_type,
      entity_type, expected_entity_ids_json, verification_method, status,
      automatic_resume_allowed, automatic_retry_prohibited,
      created_at, updated_at
    ) VALUES ('agent-operation-1', ?, 'agent-command-1', 1, 'create',
      'transaction', '[]', 'readAfterWrite', 'claimed', 0, 1, 1, 1)
  ''', variables);
  await database.customStatement('''
    INSERT INTO ai_agent_execution_attempts (
      id, owner_scope_id, command_id, idempotency_key, command_revision,
      action_type, status, business_operation_id, claimed_at,
      created_at, updated_at
    ) VALUES ('agent-attempt-1', ?, 'agent-command-1', 'key', 1, 'create',
      'claimed', 'agent-operation-1', 1, 1, 1)
  ''', variables);
  await database.customStatement('''
    INSERT INTO ai_agent_execution_results (
      id, owner_scope_id, command_id, attempt_id, status, verified,
      entity_type, affected_count, safe_result_json, created_at, updated_at
    ) VALUES ('agent-result-1', ?, 'agent-command-1', 'agent-attempt-1',
      'succeeded', 1, 'transaction', 1, '{}', 1, 1)
  ''', variables);
  await database.customStatement('''
    INSERT INTO ai_agent_plans (
      id, owner_scope_id, conversation_id, status, atomic, expires_at,
      created_at, updated_at
    ) VALUES ('agent-plan-1', ?, 'conversation-1', 'confirmed', 0, 2, 1, 1)
  ''', variables);
  await database.customStatement('''
    INSERT INTO ai_agent_plan_steps (
      id, owner_scope_id, plan_id, command_id, position, status,
      created_at, updated_at
    ) VALUES ('agent-step-1', ?, 'agent-plan-1', 'agent-command-1', 0, 'ready', 1, 1)
  ''', variables);
  await database.customStatement('''
    INSERT INTO ai_agent_audit_events (
      id, owner_scope_id, command_id, action_type, entity_type, result,
      confirmation_method, undo_available, created_at, updated_at
    ) VALUES ('agent-audit-1', ?, 'agent-command-1', 'create', 'transaction',
      'succeeded', 'explicit', 0, 1, 1)
  ''', variables);
  await database.customStatement('''
    INSERT INTO ai_agent_idempotency_records (
      id, owner_scope_id, command_id, command_revision, action_type,
      idempotency_hash, status, execution_result_id, created_at, updated_at
    ) VALUES ('agent-idempotency-1', ?, 'agent-command-1', 1, 'create',
      'idempotency-hash', 'completed', 'agent-result-1', 1, 1)
  ''', variables);
}

Future<void> _seedEveryLocalTable(AppDatabase database) async {
  await database.customStatement('''
    INSERT INTO accounts (
      id, name, type, currency_code, balance, icon, color, created_at, updated_at
    ) VALUES ('account-1', 'Cash', 'cash', 'USD', '10', 'wallet', 1, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO categories (
      id, name, type, icon, color, sort_order, created_at, updated_at
    ) VALUES ('category-1', 'Food', 'expense', 'food', 1, 0, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO payees (
      id, name, normalized_name, created_at, updated_at
    ) VALUES ('payee-1', 'Shop', 'shop', 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO transactions (
      id, account_id, category_id, payee_id, amount, currency_code, type,
      payment_method, source, status, transaction_date, created_at, updated_at
    ) VALUES (
      'transaction-1', 'account-1', 'category-1', 'payee-1', '1', 'USD',
      'expense', 'cash', 'manual', 'posted', 1, 1, 1
    )
  ''');
  await database.customStatement('''
    INSERT INTO exchange_rates (
      id, base_currency, quote_currency, rate, source, fetched_at,
      created_at, updated_at
    ) VALUES ('rate-1', 'USD', 'LYD', '4.8', 'manual', 1, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO budgets (
      id, name, category_id, amount, currency, period_type, start_date,
      end_date, alert_threshold_percent, created_at, updated_at
    ) VALUES (
      'budget-1', 'Food', 'category-1', '100', 'USD', 'monthly', 1, 2, 80, 1, 1
    )
  ''');
  await database.customStatement('''
    INSERT INTO goals (
      id, title, type, target_amount, current_amount, currency, icon, color,
      status, created_at, updated_at
    ) VALUES (
      'goal-1', 'Emergency fund', 'savings', '1000', '100', 'USD', 'target',
      1, 'active', 1, 1
    )
  ''');
  await database.customStatement('''
    INSERT INTO goal_contributions (
      id, goal_id, amount, currency, credited_amount, date, created_at,
      updated_at
    ) VALUES ('contribution-1', 'goal-1', '10', 'USD', '10', 1, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO sync_queue (
      id, owner_user_id, entity_type, entity_id, operation, payload_json,
      created_at, updated_at
    ) VALUES (
      'queue-1', 'cashpilot-test-owner', 'account', 'account-1', 'upsert',
      '{}', 1, 1
    )
  ''');
  await database.customStatement('''
    INSERT INTO receipts (
      id, document_type, payment_status, confidence, image_retention_choice,
      status, created_at, updated_at
    ) VALUES (
      'receipt-1', 'purchase_receipt', 'paid', 90, 'keep_locally',
      'review_required', 1, 1
    )
  ''');
  await database.customStatement('''
    INSERT INTO receipt_line_items (
      id, receipt_id, description, normalized_description,
      category_suggestion_source
    ) VALUES (
      'receipt-item-1', 'receipt-1', 'Milk', 'milk', 'localKeyword'
    )
  ''');
  await database.customStatement('''
    INSERT INTO transaction_splits (
      id, receipt_id, category_id, amount
    ) VALUES ('split-1', 'receipt-1', 'category-1', '1')
  ''');
}
