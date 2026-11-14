import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../core/owner_scope/domain/owner_scope.dart';
import '../../../core/storage/hive_box_names.dart';
import '../../../core/sync/application/backup_operation_fence.dart';
import '../../auth/auth_composition.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../data/datasources/account_auth_deletion_data_source.dart';
import '../data/datasources/account_deletion_auth_data_source.dart';
import '../data/datasources/account_deletion_scope_recovery_finalizer.dart';
import '../data/datasources/account_deletion_session_proof_store.dart';
import '../data/datasources/account_deletion_startup_recovery_gateway.dart';
import '../data/datasources/cloud_user_data_deletion_data_source.dart';
import '../data/datasources/data_deletion_operation_state_store.dart';
import '../data/datasources/deletion_preferences_data_source.dart';
import '../data/datasources/local_user_data_deletion_data_source.dart';
import '../data/datasources/receipt_file_deletion_journal.dart';
import '../data/repositories/data_deletion_repository_impl.dart';
import '../../receipts/receipt_cleanup.dart';
import '../domain/entities/data_deletion_request.dart';
import '../domain/failures/data_deletion_failure_codes.dart';
import '../domain/repositories/data_deletion_repository.dart';
import '../domain/usecases/delete_all_user_data.dart';
import 'account_deletion_authenticated_continuation.dart';
import 'account_deletion_execution_coordinator.dart';
import 'account_deletion_restricted_auth.dart';
import 'account_deletion_startup_recovery_coordinator.dart';

final accountDeletionRestrictedAuthProvider =
    Provider<AccountDeletionRestrictedAuth>(
      (ref) => AccountDeletionRestrictedAuthAdapter(
        sessionRestorer: ref.watch(restrictedAuthSessionRestorerProvider),
      ),
      name: 'accountDeletionRestrictedAuthProvider',
    );

final accountDeletionExecutionCoordinatorProvider =
    Provider<AccountDeletionExecutionCoordinator>(
      (_) => AccountDeletionExecutionCoordinator(),
      name: 'accountDeletionExecutionCoordinatorProvider',
    );

final accountDeletionAuthDataSourceProvider =
    Provider<AccountDeletionAuthDataSource>((ref) {
      final source = FirebaseAccountDeletionAuthDataSource(
        auth: ref.watch(firebaseAuthProvider),
        sessionGuard: ref.watch(firebaseAuthSessionEpochGuardProvider),
        operationCoordinator: ref.watch(
          firebaseAuthOperationCoordinatorProvider,
        ),
        oauthCredentialProvider: ref
            .watch(firebaseOAuthCredentialProviderFactoryProvider)
            .create(),
        completedDeletionOverlay: ref.watch(
          completedAccountDeletionOverlayProvider,
        ),
      );
      ref.onDispose(source.dispose);
      return source;
    }, name: 'accountDeletionAuthDataSourceProvider');

final cloudUserDataDeletionDataSourceProvider =
    Provider<CloudUserDataDeletionDataSource>(
      (ref) => HttpRecursiveCloudUserDataDeletionDataSource(
        config: AccountDeletionGatewayConfig.current(),
        tokenProvider: ref.watch(accountDeletionGatewayTokenProviderProvider),
        httpClient: ref.watch(accountDeletionHttpClientProvider),
      ),
      name: 'cloudUserDataDeletionDataSourceProvider',
    );

final accountDeletionGatewayTokenProviderProvider =
    Provider<AccountDeletionGatewayTokenProvider>(
      (ref) => FirebaseAccountDeletionGatewayTokenProvider(
        authDataSource: ref.watch(accountDeletionAuthDataSourceProvider),
        appCheck: ref.watch(firebaseAppCheckProvider),
        sessionProofStore: ref.watch(accountDeletionSessionProofStoreProvider),
      ),
      name: 'accountDeletionGatewayTokenProviderProvider',
    );

final accountDeletionSecretStorageProvider =
    Provider<AccountDeletionSecretStorage>(
      (ref) => const FlutterSecureAccountDeletionSecretStorage(),
      name: 'accountDeletionSecretStorageProvider',
    );

final accountDeletionSessionProofStoreProvider =
    Provider<AccountDeletionSessionProofStore>(
      (ref) => SecureAccountDeletionSessionProofStore(
        storage: ref.watch(accountDeletionSecretStorageProvider),
      ),
      name: 'accountDeletionSessionProofStoreProvider',
    );

final accountAuthDeletionDataSourceProvider =
    Provider<AccountAuthDeletionDataSource>(
      (ref) => HttpAccountAuthDeletionDataSource(
        config: AccountDeletionGatewayConfig.current(),
        tokenProvider: ref.watch(accountDeletionGatewayTokenProviderProvider),
        httpClient: ref.watch(accountDeletionHttpClientProvider),
      ),
      name: 'accountAuthDeletionDataSourceProvider',
    );

final accountDeletionHttpClientProvider = Provider.autoDispose<http.Client>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
}, name: 'accountDeletionHttpClientProvider');

final accountDeletionRecoveryAttestationProvider =
    Provider<AccountDeletionRecoveryAttestationProvider>(
      (ref) => FirebaseAccountDeletionRecoveryAttestationProvider(
        ref.watch(firebaseAppCheckProvider),
      ),
      name: 'accountDeletionRecoveryAttestationProvider',
    );

final accountDeletionStartupRecoveryGatewayProvider =
    Provider<AccountDeletionStartupRecoveryGateway>(
      (ref) => HttpAccountDeletionStartupRecoveryGateway(
        config: AccountDeletionGatewayConfig.current(),
        attestationProvider: ref.watch(
          accountDeletionRecoveryAttestationProvider,
        ),
        httpClient: ref.watch(accountDeletionHttpClientProvider),
      ),
      name: 'accountDeletionStartupRecoveryGatewayProvider',
    );

final receiptFileDeletionJournalProvider = Provider<ReceiptFileDeletionJournal>(
  (ref) {
    final session = ref.watch(requiredScopedAppDatabaseSessionProvider);
    return HiveReceiptFileDeletionJournal(
      Hive.box<dynamic>(HiveBoxNames.settings),
      receiptImageStore: createReceiptImageCleanupPort(
        ownerScopeValue: session.ownerScopeValue,
      ),
    );
  },
  name: 'receiptFileDeletionJournalProvider',
);

final localUserDataDeletionDataSourceProvider =
    Provider<LocalUserDataDeletionDataSource>(
      (ref) => DriftLocalUserDataDeletionDataSource(
        ref.watch(requiredScopedAppDatabaseSessionProvider),
        receiptFileJournal: ref.watch(receiptFileDeletionJournalProvider),
      ),
      name: 'localUserDataDeletionDataSourceProvider',
    );

final dataDeletionOperationStateStoreProvider =
    Provider<DataDeletionOperationStateStore>(
      (ref) => HiveDataDeletionOperationStateStore(
        Hive.box<dynamic>(HiveBoxNames.settings),
      ),
      name: 'dataDeletionOperationStateStoreProvider',
    );

final accountDeletionScopeRecoveryFinalizerProvider =
    Provider<AccountDeletionScopeRecoveryFinalizer>(
      (ref) => UidFreeAccountDeletionScopeRecoveryFinalizer(
        database: ref.watch(appDatabaseProvider),
        operationFence: ref.watch(backupOperationFenceProvider),
        settingsBox: Hive.box<dynamic>(HiveBoxNames.settings),
        completedDeletionOverlay: ref.watch(
          completedAccountDeletionOverlayProvider,
        ),
        operationStateStore: ref.watch(dataDeletionOperationStateStoreProvider),
        receiptImageStoreFactory: (ownerScopeValue) =>
            createReceiptImageCleanupPort(ownerScopeValue: ownerScopeValue),
      ),
      name: 'accountDeletionScopeRecoveryFinalizerProvider',
    );

final accountDeletionStartupRecoveryCoordinatorProvider =
    Provider<AccountDeletionStartupRecoveryCoordinator>(
      (ref) => AccountDeletionStartupRecoveryCoordinator(
        quarantineStore: ref.watch(ownerDeletionQuarantineStoreProvider),
        recoveryFence: BackupOperationFenceStartupRecoveryAdapter(
          operationFence: ref.watch(backupOperationFenceProvider),
          quarantineStore: ref.watch(ownerDeletionQuarantineStoreProvider),
        ),
        secureOperationStore: ref.watch(
          accountDeletionSessionProofStoreProvider,
        ),
        gateway: ref.watch(accountDeletionStartupRecoveryGatewayProvider),
        localFinalizer: ref.watch(
          accountDeletionScopeRecoveryFinalizerProvider,
        ),
        onRetainedFailure: (safeFailureCode) {
          ref
              .read(appLoggerProvider)
              .warning(
                'Account deletion startup recovery retained a quarantined '
                'operation. [code=$safeFailureCode]',
              );
        },
      ),
      name: 'accountDeletionStartupRecoveryCoordinatorProvider',
    );

final accountDeletionStartupRecoveryProvider =
    FutureProvider<AccountDeletionStartupRecoveryReport>((ref) async {
      final report = await ref
          .watch(accountDeletionStartupRecoveryCoordinatorProvider)
          .recoverPending();
      if (report.retained > 0 ||
          report.rejected > 0 ||
          report.authenticatedContinuations.isNotEmpty) {
        ref
            .read(appLoggerProvider)
            .warning(
              'Account deletion startup recovery retained '
              '${report.retained} operation(s) and rejected '
              '${report.rejected} invalid marker(s); '
              '${report.authenticatedContinuations.length} operation(s) '
              'require restricted authenticated continuation.',
            );
      }
      return report;
    }, name: 'accountDeletionStartupRecoveryProvider');

final deletionPreferencesDataSourceProvider =
    Provider<DeletionPreferencesDataSource>(
      (ref) => HiveDeletionPreferencesDataSource(
        Hive.box<dynamic>(HiveBoxNames.settings),
      ),
      name: 'deletionPreferencesDataSourceProvider',
    );

final dataDeletionRepositoryProvider = Provider<DataDeletionRepository>(
  (ref) => DataDeletionRepositoryImpl(
    authDataSource: ref.watch(accountDeletionAuthDataSourceProvider),
    authDeletionDataSource: ref.watch(accountAuthDeletionDataSourceProvider),
    cloudDataSource: ref.watch(cloudUserDataDeletionDataSourceProvider),
    localDataSource: ref.watch(localUserDataDeletionDataSourceProvider),
    preferencesDataSource: ref.watch(deletionPreferencesDataSourceProvider),
    operationStateStore: ref.watch(dataDeletionOperationStateStoreProvider),
    sessionProofStore: ref.watch(accountDeletionSessionProofStoreProvider),
    backupOperationFence: ref.watch(backupOperationFenceProvider),
    executionCoordinator: ref.watch(
      accountDeletionExecutionCoordinatorProvider,
    ),
    logger: ref.watch(appLoggerProvider),
  ),
  name: 'dataDeletionRepositoryProvider',
);

final deleteAllUserDataUseCaseProvider = Provider<DeleteAllUserData>(
  (ref) => DeleteAllUserData(ref.watch(dataDeletionRepositoryProvider)),
  name: 'deleteAllUserDataUseCaseProvider',
);

final accountDeletionAuthenticatedContinuationProvider =
    Provider<AccountDeletionAuthenticatedContinuation>((ref) {
      final authDataSource = ref.watch(accountDeletionAuthDataSourceProvider);
      final nativeAuth = ref.watch(firebaseAuthProvider);
      final authSessionGuard = ref.watch(firebaseAuthSessionEpochGuardProvider);
      return AccountDeletionAuthenticatedContinuation(
        authDataSource: authDataSource,
        deleteAll: (request) async {
          final target = request.expectedRecoveryTarget;
          final lease = request.confirmationLease;
          final user = nativeAuth.currentUser;
          final snapshot = authSessionGuard.currentSnapshot();
          if (target == null ||
              user == null ||
              snapshot == null ||
              snapshot.generation != lease.authSessionGeneration ||
              snapshot.fingerprint.uid != user.uid ||
              snapshot.fingerprint.isAnonymous != user.isAnonymous ||
              snapshot.fingerprint.tenantId != user.tenantId ||
              lease.isAnonymous != user.isAnonymous) {
            return _continuationIdentityFailure();
          }
          late final ConfirmedOwnerScope scope;
          try {
            scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(user.uid);
          } on Object {
            return _continuationIdentityFailure();
          }
          if (scope.id.value != target.ownerScopeValue ||
              lease.ownerScopeValue != target.ownerScopeValue) {
            return _continuationIdentityFailure();
          }
          // Construct deletion-only infrastructure only after native Auth,
          // generation, lease, and opaque startup target all match exact A.
          // No profile-hydrated auth or ordinary owner-session provider is
          // part of this restricted route-free path.
          final database = ref.read(appDatabaseProvider);
          final operationFence = ref.read(backupOperationFenceProvider);
          final authDeletionDataSource = ref.read(
            accountAuthDeletionDataSourceProvider,
          );
          final cloudDataSource = ref.read(
            cloudUserDataDeletionDataSourceProvider,
          );
          final preferencesDataSource = ref.read(
            deletionPreferencesDataSourceProvider,
          );
          final operationStateStore = ref.read(
            dataDeletionOperationStateStoreProvider,
          );
          final sessionProofStore = ref.read(
            accountDeletionSessionProofStoreProvider,
          );
          final executionCoordinator = ref.read(
            accountDeletionExecutionCoordinatorProvider,
          );
          final logger = ref.read(appLoggerProvider);
          final settingsBox = Hive.box<dynamic>(HiveBoxNames.settings);
          final session = ScopedAppDatabaseSession(
            database: database,
            scope: scope,
            operationFence: operationFence,
          );
          final receiptJournal = HiveReceiptFileDeletionJournal(
            settingsBox,
            receiptImageStore: createReceiptImageCleanupPort(
              ownerScopeValue: target.ownerScopeValue,
            ),
          );
          final repository = DataDeletionRepositoryImpl(
            authDataSource: authDataSource,
            authDeletionDataSource: authDeletionDataSource,
            cloudDataSource: cloudDataSource,
            localDataSource: DriftLocalUserDataDeletionDataSource(
              session,
              receiptFileJournal: receiptJournal,
            ),
            preferencesDataSource: preferencesDataSource,
            operationStateStore: operationStateStore,
            sessionProofStore: sessionProofStore,
            backupOperationFence: operationFence,
            executionCoordinator: executionCoordinator,
            logger: logger,
          );
          try {
            return await DeleteAllUserData(repository)(request);
          } finally {
            session.invalidate();
          }
        },
      );
    }, name: 'accountDeletionAuthenticatedContinuationProvider');

AppResult<DataDeletionReport> _continuationIdentityFailure() =>
    const AppResult.failure(
      Failure(
        message: 'The authenticated account does not own this recovery.',
        code: DataDeletionFailureCodes.identityChanged,
      ),
    );

final dataDeletionControllerProvider =
    AsyncNotifierProvider<DataDeletionController, DataDeletionReport?>(
      DataDeletionController.new,
      name: 'dataDeletionControllerProvider',
    );

class DataDeletionController extends AsyncNotifier<DataDeletionReport?> {
  var _operationVersion = 0;
  var _confirmedScopeEpoch = 0;
  var _authExposureEpoch = 0;
  String? _lastConfirmedScopeValue;
  AuthSessionIdentity? _currentObservedAuthSession;

  @override
  FutureOr<DataDeletionReport?> build() {
    _observeConfirmedScope(ref.read(confirmedOwnerScopeSnapshotProvider));
    final initialAuth = ref.read(authStateProvider);
    _currentObservedAuthSession = initialAuth.hasError || initialAuth.isLoading
        ? null
        : initialAuth.value?.sessionIdentity;
    if (initialAuth.hasError) {
      _authExposureEpoch += 1;
    }
    ref.listen(confirmedOwnerScopeSnapshotProvider, (_, next) {
      if (!_observeConfirmedScope(next)) {
        return;
      }
      _operationVersion++;
      if (ref.mounted) {
        state = const AsyncData(null);
      }
    });
    ref.listen(authStateProvider, (_, next) {
      if (next.isLoading) {
        return;
      }
      if (next.hasError) {
        _currentObservedAuthSession = null;
        _authExposureEpoch += 1;
      } else if (!_observeAuthSession(next.value?.sessionIdentity)) {
        return;
      }
      _operationVersion++;
      if (ref.mounted) {
        state = const AsyncData(null);
      }
    });
    ref.onDispose(() {
      _operationVersion++;
    });
    return null;
  }

  Future<Failure?> deleteAll(DataDeletionRequest request) async {
    final keepAlive = ref.keepAlive();
    final operationVersion = ++_operationVersion;
    final ownerSession = ref.read(scopedAppDatabaseSessionProvider);
    final confirmedScopeEpochAtStart = _confirmedScopeEpoch;
    final authExposureEpochAtStart = _authExposureEpoch;
    ConfirmedOwnerScope? capturedOwnerScope;
    try {
      capturedOwnerScope = ownerSession?.confirmedScope;
    } on Object {
      capturedOwnerScope = null;
    }
    state = const AsyncLoading();
    try {
      final result = await ref.read(deleteAllUserDataUseCaseProvider)(request);
      if (!_isCurrentOwnerOperation(operationVersion, ownerSession)) {
        if (result case AppSuccess<DataDeletionReport>(data: final report)
            when ref.read(currentAuthUserProvider) == null &&
                _confirmedScopeEpoch == confirmedScopeEpochAtStart &&
                _authExposureEpoch == authExposureEpochAtStart &&
                _hasCompletionProof(report, capturedOwnerScope)) {
          // Firebase Auth removes the successful deletion session. Suppress
          // stale controller state, but preserve the caller's success signal.
          return null;
        }
        return const Failure(
          message: 'The authenticated account changed during deletion.',
          code: DataDeletionFailureCodes.identityChanged,
        );
      }
      return switch (result) {
        AppSuccess<DataDeletionReport>(data: final report) =>
          _hasCompletionProof(report, capturedOwnerScope)
              ? _success(report)
              : _failure(_identityChangedFailure()),
        AppFailure<DataDeletionReport>(failure: final failure) => _failure(
          failure,
        ),
      };
    } finally {
      keepAlive.close();
    }
  }

  bool _isCurrentOwnerOperation(int version, Object? ownerSession) {
    return ref.mounted &&
        version == _operationVersion &&
        ownerSession != null &&
        identical(ownerSession, ref.read(scopedAppDatabaseSessionProvider));
  }

  bool _observeConfirmedScope(OwnerScopeSnapshot snapshot) {
    final scopeValue = snapshot.status == OwnerScopeStatus.safe
        ? snapshot.scope?.id.value
        : null;
    if (scopeValue != null && scopeValue != _lastConfirmedScopeValue) {
      _lastConfirmedScopeValue = scopeValue;
      _confirmedScopeEpoch += 1;
      return true;
    }
    return false;
  }

  bool _observeAuthSession(AuthSessionIdentity? session) {
    if (session == _currentObservedAuthSession) {
      return false;
    }
    _currentObservedAuthSession = session;
    if (session != null) {
      _authExposureEpoch += 1;
    }
    return true;
  }

  bool _hasCompletionProof(
    DataDeletionReport report,
    ConfirmedOwnerScope? capturedOwnerScope,
  ) {
    if (capturedOwnerScope == null ||
        !report.completionProof.matchesOwnerScope(
          capturedOwnerScope.id.value,
        )) {
      return false;
    }
    final proof = report.completionProof;
    return ref
        .read(completedAccountDeletionOverlayProvider)
        .hasTrustedCompletion(
          operationId: proof.operationId,
          ownerScope: capturedOwnerScope,
          capturedAuthGeneration: proof.authStateGeneration,
        );
  }

  Failure _identityChangedFailure() => const Failure(
    message: 'The authenticated account changed during deletion.',
    code: DataDeletionFailureCodes.identityChanged,
  );

  Failure? _success(DataDeletionReport report) {
    state = AsyncData(report);
    return null;
  }

  Failure _failure(Failure failure) {
    state = AsyncError(failure, StackTrace.current);
    return failure;
  }
}
