import 'dart:async';

import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_session_guard.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_operation_coordinator.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_oauth_credential_provider.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_auth_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_auth_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_session_proof_store.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/cloud_user_data_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/data_deletion_operation_state_store.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/deletion_preferences_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/local_user_data_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/repositories/data_deletion_repository_impl.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_request.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/failures/data_deletion_failure_codes.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tamperScenarios =
      <
        ({
          String field,
          AccountDeletionConfirmationLease Function(
            AccountDeletionConfirmationLease issued,
          )
          tamper,
        })
      >[
        (
          field: 'isAnonymous',
          tamper: (issued) =>
              _copyLease(issued, isAnonymous: !issued.isAnonymous),
        ),
        (
          field: 'ownerScopeValue',
          tamper: (issued) => _copyLease(
            issued,
            ownerScopeValue: OwnerScopeDerivation.fromConfirmedFirebaseUid(
              'different-owner',
            ).id.value,
          ),
        ),
        (
          field: 'authSessionGeneration',
          tamper: (issued) => _copyLease(
            issued,
            authSessionGeneration: issued.authSessionGeneration! + 1,
          ),
        ),
        (
          field: 'removed ownerScopeValue',
          tamper: (issued) => AccountDeletionConfirmationLease(
            opaqueToken: issued.opaqueToken,
            email: issued.email,
            isAnonymous: issued.isAnonymous,
            authSessionGeneration: issued.authSessionGeneration,
          ),
        ),
        (
          field: 'removed authSessionGeneration',
          tamper: (issued) => AccountDeletionConfirmationLease(
            opaqueToken: issued.opaqueToken,
            email: issued.email,
            isAnonymous: issued.isAnonymous,
            ownerScopeValue: issued.ownerScopeValue,
          ),
        ),
      ];

  for (final scenario in tamperScenarios) {
    test('production deletion datasource rejects tampered ${scenario.field} '
        'before cloud, local, or Auth mutation', () async {
      final user = _LeaseTestUser(uid: 'lease-owner');
      final firebaseAuth = _LeaseTestFirebaseAuth(user);
      final sessionGuard = FirebaseAuthSessionEpochGuard(firebaseAuth);
      final overlay = _LeaseTestCompletedDeletionOverlay();
      final authDataSource = FirebaseAccountDeletionAuthDataSource(
        auth: firebaseAuth,
        sessionGuard: sessionGuard,
        completedDeletionOverlay: overlay,
        operationCoordinator: FirebaseAuthOperationCoordinator(),
        oauthCredentialProvider: _UnavailableOAuthCredentialProvider(),
      );
      addTearDown(() async {
        await authDataSource.dispose();
        await sessionGuard.dispose();
        await overlay.dispose();
        await firebaseAuth.dispose();
      });
      firebaseAuth.emitCurrentAuthState();

      final issuedLease = await authDataSource.issueConfirmationLease();
      expect(issuedLease.ownerScopeValue, isNotNull);
      expect(issuedLease.authSessionGeneration, isNotNull);

      final mutationTrap = _DeletionMutationTrap();
      final repository = DataDeletionRepositoryImpl(
        authDataSource: authDataSource,
        authDeletionDataSource: mutationTrap,
        cloudDataSource: mutationTrap,
        localDataSource: mutationTrap,
        preferencesDataSource: mutationTrap,
        operationStateStore: mutationTrap,
        sessionProofStore: mutationTrap,
        backupOperationFence: BackupOperationFence(),
        logger: AppLogger.instance,
      );

      final result = await repository.deleteAllUserData(
        DataDeletionRequest(
          confirmationAccepted: true,
          confirmationLease: scenario.tamper(issuedLease),
          email: issuedLease.email,
          password: 'unused-test-password',
        ),
      );

      expect(result, isA<AppFailure<DataDeletionReport>>());
      expect(
        (result as AppFailure<DataDeletionReport>).failure.code,
        DataDeletionFailureCodes.identityChanged,
      );
      expect(mutationTrap.cloudMutationCalls, 0);
      expect(mutationTrap.localStageCalls, 0);
      expect(mutationTrap.authMutationCalls, 0);
      expect(mutationTrap.supportingStateCalls, 0);
      expect(firebaseAuth.authMutationCalls, 0);
      expect(user.authMutationCalls, 0);
      expect(user.tokenRequests, 0);
    });
  }
}

AccountDeletionConfirmationLease _copyLease(
  AccountDeletionConfirmationLease issued, {
  bool? isAnonymous,
  String? ownerScopeValue,
  int? authSessionGeneration,
}) => AccountDeletionConfirmationLease(
  opaqueToken: issued.opaqueToken,
  email: issued.email,
  isAnonymous: isAnonymous ?? issued.isAnonymous,
  ownerScopeValue: ownerScopeValue ?? issued.ownerScopeValue,
  authSessionGeneration: authSessionGeneration ?? issued.authSessionGeneration,
);

final class _DeletionMutationTrap
    implements
        AccountAuthDeletionDataSource,
        CloudUserDataDeletionDataSource,
        LocalUserDataDeletionDataSource,
        DeletionPreferencesDataSource,
        DataDeletionOperationStateStore,
        AccountDeletionSessionProofStore {
  var cloudMutationCalls = 0;
  var localStageCalls = 0;
  var authMutationCalls = 0;
  var supportingStateCalls = 0;

  @override
  Future<CloudDeletionReceipt> deleteUserData(
    DataDeletionOperationContext context,
  ) async {
    cloudMutationCalls += 1;
    throw StateError('Cloud deletion must not be reached.');
  }

  @override
  Future<AccountAuthDeletionReceipt> deleteAuthAccount(
    DataDeletionOperationContext context, {
    bool finalizationRecovery = false,
  }) async {
    authMutationCalls += 1;
    throw StateError('Auth deletion must not be reached.');
  }

  @override
  String get ownerScopeValue {
    localStageCalls += 1;
    throw StateError('Local deletion scope must not be read.');
  }

  @override
  Future<bool> hasUnresolvedLegacyFinancialData(
    DataDeletionOperationContext context,
  ) async {
    localStageCalls += 1;
    throw StateError('Local deletion checks must not be reached.');
  }

  @override
  Future<int> deleteLocalDatabase(DataDeletionOperationContext context) async {
    localStageCalls += 1;
    throw StateError('Local deletion must not be reached.');
  }

  @override
  Future<int> deleteReceiptFiles(DataDeletionOperationContext context) async {
    localStageCalls += 1;
    throw StateError('Receipt-file deletion must not be reached.');
  }

  @override
  Future<bool> verifyLocalDatabaseEmpty(
    DataDeletionOperationContext context,
  ) async {
    localStageCalls += 1;
    throw StateError('Local deletion verification must not be reached.');
  }

  @override
  Future<void> clearForIdentity(TrustedDeletionIdentity identity) async {
    localStageCalls += 1;
    throw StateError('Local preferences deletion must not be reached.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    supportingStateCalls += 1;
    throw StateError(
      'Deletion state must not be reached: ${invocation.memberName}',
    );
  }
}

final class _LeaseTestFirebaseAuth implements firebase_auth.FirebaseAuth {
  _LeaseTestFirebaseAuth(this._currentUser);

  final firebase_auth.User? _currentUser;
  var authMutationCalls = 0;
  final StreamController<firebase_auth.User?> _authStates =
      StreamController<firebase_auth.User?>.broadcast(sync: true);

  @override
  firebase_auth.User? get currentUser => _currentUser;

  @override
  Stream<firebase_auth.User?> authStateChanges() => _authStates.stream;

  @override
  Future<void> signOut() async {
    authMutationCalls += 1;
  }

  void emitCurrentAuthState() => _authStates.add(_currentUser);

  Future<void> dispose() => _authStates.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _LeaseTestUser implements firebase_auth.User {
  _LeaseTestUser({required this.uid});

  var authMutationCalls = 0;
  var tokenRequests = 0;

  @override
  final String uid;

  @override
  String? get email => 'person@example.com';

  @override
  bool get isAnonymous => false;

  @override
  String? get tenantId => null;

  @override
  Future<void> delete() async {
    authMutationCalls += 1;
  }

  @override
  Future<firebase_auth.UserCredential> reauthenticateWithCredential(
    firebase_auth.AuthCredential credential,
  ) async {
    authMutationCalls += 1;
    throw StateError('Reauthentication must not be reached.');
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    tokenRequests += 1;
    return 'unused-test-token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _LeaseTestCompletedDeletionOverlay
    implements CompletedAccountDeletionOverlay {
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  @override
  Stream<void> get changes => _changes.stream;

  @override
  bool hasTrustedCompletion({
    required String operationId,
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
  }) => false;

  @override
  Future<void> markCompleted({
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
    required String operationId,
  }) async {
    throw StateError('Completion overlay mutation must not be reached.');
  }

  @override
  bool shouldSuppress(firebase_auth.User? user) => false;

  Future<void> dispose() => _changes.close();
}

final class _UnavailableOAuthCredentialProvider
    implements FirebaseOAuthCredentialProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
