import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../core/owner_scope/domain/owner_scope.dart';
import '../../../core/storage/hive_box_names.dart';
import '../../../core/sync/application/backup_operation_fence.dart';
import '../../accounts/application/providers/accounts_providers.dart';
import '../../accounts/domain/entities/account.dart';
import '../../ai_assistant/application/providers/ai_agent_providers.dart';
import '../../ai_assistant/application/providers/ai_assistant_providers.dart';
import '../../categories/application/providers/categories_providers.dart';
import '../../categories/domain/entities/category.dart';
import '../../payees/application/providers/payees_providers.dart';
import '../../payees/domain/entities/payee.dart';
import '../../transactions/application/providers/transactions_providers.dart';
import '../data/providers/firebase_receipt_analysis_provider.dart';
import '../data/repositories/receipt_repository_impl.dart';
import '../data/services/image_picker_receipt_capture_service.dart';
import '../data/services/isolate_receipt_image_preparation_worker.dart';
import '../data/services/receipt_local_image_store.dart';
import '../data/services/receipt_privacy_consent_store.dart';
import '../domain/config/receipt_analysis_model_config.dart';
import '../domain/config/receipt_feature_config.dart';
import '../domain/entities/receipt_analysis_draft.dart';
import '../domain/entities/prepared_receipt_image.dart';
import '../domain/enums/receipt_draft_status.dart';
import '../domain/enums/receipt_warning.dart';
import '../domain/failures/receipt_failure_codes.dart';
import '../domain/repositories/receipt_analysis_provider.dart';
import '../domain/repositories/receipt_repository.dart';
import '../domain/services/receipt_image_capture_service.dart';
import '../domain/usecases/analyze_receipt_image.dart';
import '../domain/usecases/capture_receipt_image.dart';
import '../domain/usecases/build_receipt_transaction_draft.dart';
import '../domain/usecases/confirm_receipt_transaction.dart';
import '../domain/usecases/import_receipt_image.dart';
import '../domain/usecases/prepare_receipt_image.dart';
import 'receipt_capture_operation_lease.dart';
import 'receipt_capture_state.dart';

final receiptFeatureConfigProvider = Provider<ReceiptFeatureConfig>(
  (_) => ReceiptFeatureConfig.current(),
  name: 'receiptFeatureConfigProvider',
);

final receiptImageStoreProvider = Provider<ReceiptLocalImageStore>(
  (ref) => ReceiptLocalImageStore(
    ownerScopeValue: ref
        .watch(requiredScopedAppDatabaseSessionProvider)
        .ownerScopeValue,
  ),
  name: 'receiptImageStoreProvider',
);

final receiptRepositoryProvider = Provider<ReceiptRepository>(
  (ref) => ReceiptRepositoryImpl(
    session: ref.watch(requiredScopedAppDatabaseSessionProvider),
    imageStore: ref.watch(receiptImageStoreProvider),
  ),
  name: 'receiptRepositoryProvider',
);

final receiptPrivacyConsentStoreProvider = Provider<ReceiptPrivacyConsentStore>(
  (ref) {
    final ownerScope = ref.watch(confirmedOwnerScopeProvider);
    if (ownerScope == null) {
      throw const OwnerScopeException(
        OwnerScopeFailure.scopedSessionUnavailable,
      );
    }
    return ReceiptPrivacyConsentStore(
      box: Hive.box<dynamic>(HiveBoxNames.settings),
      ownerScope: ownerScope,
      operationFence: ref.watch(backupOperationFenceProvider),
    );
  },
  name: 'receiptPrivacyConsentStoreProvider',
);

final receiptCaptureServiceProvider = Provider<ReceiptImageCaptureService>(
  (_) => ImagePickerReceiptImageCaptureService(),
  name: 'receiptCaptureServiceProvider',
);

final receiptPermissionServiceProvider = Provider<ReceiptPermissionService>(
  (_) => const PermissionHandlerReceiptPermissionService(),
  name: 'receiptPermissionServiceProvider',
);

final prepareReceiptImageUseCaseProvider = Provider<PrepareReceiptImageUseCase>(
  (_) => const PrepareReceiptImageUseCase(
    worker: IsolateReceiptImagePreparationWorker(),
  ),
  name: 'prepareReceiptImageUseCaseProvider',
);

final captureReceiptImageUseCaseProvider = Provider<CaptureReceiptImageUseCase>(
  (ref) => CaptureReceiptImageUseCase(
    captureService: ref.watch(receiptCaptureServiceProvider),
    permissionService: ref.watch(receiptPermissionServiceProvider),
    prepareImage: ref.watch(prepareReceiptImageUseCaseProvider),
  ),
  name: 'captureReceiptImageUseCaseProvider',
);

final importReceiptImageUseCaseProvider = Provider<ImportReceiptImageUseCase>(
  (ref) => ImportReceiptImageUseCase(
    captureService: ref.watch(receiptCaptureServiceProvider),
    prepareImage: ref.watch(prepareReceiptImageUseCaseProvider),
  ),
  name: 'importReceiptImageUseCaseProvider',
);

final receiptAnalysisProvider = Provider<ReceiptAnalysisProvider>((ref) {
  if (!ref.watch(aiAssistantCapabilitiesProvider).receiptVisionAvailable) {
    return const _DisabledReceiptAnalysisProvider();
  }
  final fallbackModel = ref.watch(aiModelConfigProvider).modelName;
  return FirebaseReceiptAnalysisProvider(
    config: ReceiptAnalysisModelConfig.current(fallbackModel: fallbackModel),
  );
}, name: 'receiptAnalysisProvider');

class _DisabledReceiptAnalysisProvider implements ReceiptAnalysisProvider {
  const _DisabledReceiptAnalysisProvider();

  @override
  Object get modelConfig => const <String, Object?>{'enabled': false};

  @override
  Future<ReceiptAnalysisDraft> analyzeReceipt({
    required String draftId,
    required PreparedReceiptImage image,
    required ReceiptAnalysisContext context,
    required void Function() assertEgressAllowed,
  }) {
    assertEgressAllowed();
    throw const ReceiptException(
      code: ReceiptFailureCodes.providerUnavailable,
      safeMessage: 'Receipt analysis is disabled.',
    );
  }

  @override
  Future<bool> validateAvailability() async => false;
}

final analyzeReceiptImageUseCaseProvider = Provider<AnalyzeReceiptImageUseCase>(
  (ref) {
    final ownerSnapshot = ref.watch(confirmedOwnerScopeSnapshotProvider);
    final ownerScope = ownerSnapshot.scope;
    final authSessionGeneration = ownerSnapshot.authSessionGeneration;
    if (ownerScope == null || authSessionGeneration == null) {
      throw const OwnerScopeException(
        OwnerScopeFailure.scopedSessionUnavailable,
      );
    }
    return AnalyzeReceiptImageUseCase(
      provider: ref.watch(receiptAnalysisProvider),
      repository: ref.watch(receiptRepositoryProvider),
      operationFence: ref.watch(backupOperationFenceProvider),
      boundOwnerScope: ownerScope.id.value,
      isOwnerScopeCurrent: () => _isCurrentOwnerScope(
        ref,
        ownerScope,
        authSessionGeneration: authSessionGeneration,
      ),
    );
  },
  name: 'analyzeReceiptImageUseCaseProvider',
);

final buildReceiptTransactionDraftUseCaseProvider =
    Provider<BuildReceiptTransactionDraftUseCase>(
      (_) => const BuildReceiptTransactionDraftUseCase(),
      name: 'buildReceiptTransactionDraftUseCaseProvider',
    );

final confirmReceiptTransactionUseCaseProvider =
    Provider<ConfirmReceiptTransactionUseCase>(
      (ref) => ConfirmReceiptTransactionUseCase(
        createTransaction: ref.watch(createTransactionUseCaseProvider),
        getTransaction: ref.watch(getTransactionUseCaseProvider),
        receiptRepository: ref.watch(receiptRepositoryProvider),
      ),
      name: 'confirmReceiptTransactionUseCaseProvider',
    );

final receiptDraftProvider = StreamProvider.autoDispose
    .family<AppResult<ReceiptAnalysisDraft?>, String>(
      (ref, id) => ref.watch(receiptRepositoryProvider).watchDraft(id),
      name: 'receiptDraftProvider',
    );

final receiptCaptureControllerProvider =
    NotifierProvider<ReceiptCaptureController, ReceiptCaptureState>(
      ReceiptCaptureController.new,
      name: 'receiptCaptureControllerProvider',
    );

class ReceiptCaptureController extends Notifier<ReceiptCaptureState> {
  int _captureGeneration = 0;
  ReceiptCaptureOperationLease? _activeCapture;

  @override
  ReceiptCaptureState build() {
    ref.listen<ScopedAppDatabaseSession?>(scopedAppDatabaseSessionProvider, (
      previous,
      next,
    ) {
      if (identical(previous, next)) {
        return;
      }
      _invalidateActiveCapture(clearVisibleState: true);
    });
    ref.onDispose(() {
      _invalidateActiveCapture(clearVisibleState: false);
    });
    return const ReceiptCaptureState();
  }

  Future<ReceiptAnalysisDraft?> start({
    required bool fromGallery,
    required bool analyzeRemotely,
    required Locale locale,
  }) async {
    if (state.isBusy) {
      return null;
    }
    if (!ref.read(receiptFeatureConfigProvider).enabled) {
      state = const ReceiptCaptureState(
        failure: Failure(
          message: 'Receipt scanning is currently disabled.',
          code: ReceiptFailureCodes.providerUnavailable,
        ),
      );
      return null;
    }

    ReceiptCaptureOperationLease? lease;
    try {
      lease = _beginCapture(
        fromGallery: fromGallery,
        analyzeRemotely: analyzeRemotely,
      );
      state = const ReceiptCaptureState(
        isBusy: true,
        stage: ReceiptCaptureStage.selectingAndPreparing,
      );

      if (!_checkpoint(lease)) {
        return null;
      }
      final prepared = await lease.acquireImage(
        cancellationSignal: lease.whenCancelled,
      );
      lease.trackPreparedImage(prepared);
      if (!_checkpoint(lease)) {
        return null;
      }
      if (prepared == null) {
        state = state.copyWith(isBusy: false, clearStage: true);
        return null;
      }

      state = state.copyWith(stage: ReceiptCaptureStage.savingDraft);
      var draft = ReceiptAnalysisDraft.create();
      if (!_checkpoint(lease)) {
        return null;
      }
      final imageResult = await lease.repository.storeLocalImage(
        draft.id,
        prepared.bytes,
      );
      switch (imageResult) {
        case AppSuccess<String>(data: final reference):
          lease.trackLocalImageReference(reference);
          if (!_checkpoint(lease)) {
            return null;
          }
          draft = draft.copyWith(
            localImageReference: reference,
            imageHash: prepared.sha256,
          );
        case AppFailure<String>(:final failure):
          if (_checkpoint(lease)) {
            state = ReceiptCaptureState(failure: failure);
          }
          return null;
      }

      if (!_checkpoint(lease)) {
        return null;
      }
      final created = await lease.repository.createAnalysisDraft(draft);
      if (!_checkpoint(lease)) {
        return null;
      }
      if (created case AppFailure<ReceiptAnalysisDraft>(:final failure)) {
        final reference = lease.detachLocalImageReference();
        await lease.deleteImageReference(reference);
        if (_checkpoint(lease)) {
          state = ReceiptCaptureState(failure: failure);
        }
        return null;
      }

      final analyzeReceipt = lease.analyzeReceipt;
      if (analyzeReceipt == null || !lease.hasCurrentRemoteConsent) {
        return _completeManualReview(lease, draft);
      }

      state = state.copyWith(stage: ReceiptCaptureStage.loadingContext);
      final categories = await _categories(lease);
      if (categories == null) {
        return null;
      }
      final accounts = await _accounts(lease);
      if (accounts == null) {
        return null;
      }
      final payees = await _payees(lease);
      if (payees == null) {
        return null;
      }
      if (!_checkpoint(lease)) {
        return null;
      }
      if (!lease.hasCurrentRemoteConsent) {
        return _completeManualReview(lease, draft);
      }

      state = state.copyWith(stage: ReceiptCaptureStage.analyzing);
      final analyzed = await analyzeReceipt(
        draft: draft,
        image: prepared,
        context: ReceiptAnalysisContext(
          supportedCurrencies: accounts
              .where((account) => !account.isArchived)
              .map((account) => account.currencyCode)
              .toSet()
              .toList(growable: false),
          categoryDescriptions: categories
              .where((category) => !category.isArchived)
              .map((category) => category.name)
              .toList(growable: false),
          locale: locale.toLanguageTag(),
        ),
        categories: categories,
        payees: payees,
        isOperationCurrent: () =>
            _isLeaseCurrent(lease!) && lease.hasCurrentRemoteConsent,
        cancellationSignal: lease.whenCancelled,
      );
      if (!_checkpoint(lease)) {
        return null;
      }
      if (analyzed case AppSuccess<ReceiptAnalysisDraft>(data: final value)) {
        lease.retainLocalImageReference();
        state = ReceiptCaptureState(draft: value);
        return value;
      }
      final failure = (analyzed as AppFailure<ReceiptAnalysisDraft>).failure;
      final manualDraft = draft.copyWith(
        status: ReceiptDraftStatus.reviewRequired,
        warnings: <ReceiptWarning>{
          ...draft.warnings,
          ReceiptWarning.partialExtraction,
        }.toList(growable: false),
      );
      if (!_checkpoint(lease)) {
        return null;
      }
      await lease.repository.updateAnalysisDraft(manualDraft);
      if (!_checkpoint(lease)) {
        return null;
      }
      lease.retainLocalImageReference();
      state = ReceiptCaptureState(draft: manualDraft, failure: failure);
      return manualDraft;
    } on ReceiptAnalysisOperationCancelledException {
      if (lease != null) {
        _cancelLease(lease);
      }
      return null;
    } on ReceiptImagePreparationCancelledException {
      if (lease != null) {
        _cancelLease(lease);
      }
      return null;
    } on ReceiptException catch (error) {
      if (lease == null || _checkpoint(lease)) {
        state = ReceiptCaptureState(
          failure: Failure(message: error.safeMessage, code: error.code),
        );
      }
      return null;
    } on OwnerScopeException {
      if (lease == null || _checkpoint(lease)) {
        state = const ReceiptCaptureState(
          failure: Failure(
            message: 'Receipt capture requires a confirmed account.',
            code: ReceiptFailureCodes.providerUnavailable,
          ),
        );
      }
      return null;
    } on Object {
      if (lease == null || _checkpoint(lease)) {
        state = const ReceiptCaptureState(
          failure: Failure(
            message: 'Receipt capture failed safely.',
            code: ReceiptFailureCodes.invalidImage,
          ),
        );
      }
      return null;
    } finally {
      if (lease != null) {
        lease.purgePreparedBytes();
        if (identical(_activeCapture, lease)) {
          _activeCapture = null;
        }
        try {
          await lease.waitForCleanup();
        } finally {
          lease.releaseWriter();
        }
      }
    }
  }

  ReceiptCaptureOperationLease _beginCapture({
    required bool fromGallery,
    required bool analyzeRemotely,
  }) {
    final ownerSnapshot = ref.read(confirmedOwnerScopeSnapshotProvider);
    final ownerScope = ownerSnapshot.scope;
    final authSessionGeneration = ownerSnapshot.authSessionGeneration;
    final session = ref.read(scopedAppDatabaseSessionProvider);
    if (ownerScope == null ||
        authSessionGeneration == null ||
        session == null) {
      throw const OwnerScopeException(
        OwnerScopeFailure.scopedSessionUnavailable,
      );
    }
    session.assertActive();
    if (session.confirmedScope != ownerScope) {
      throw const OwnerScopeException(OwnerScopeFailure.activeScopeChanged);
    }

    final writer = ref
        .read(backupOperationFenceProvider)
        .tryAcquireWriter(ownerScope.id.value);
    if (writer == null) {
      throw const ReceiptAnalysisOperationCancelledException();
    }
    try {
      writer.assertActive();
      if (!_isCurrentOwnerScope(
        ref,
        ownerScope,
        authSessionGeneration: authSessionGeneration,
      )) {
        throw const ReceiptAnalysisOperationCancelledException();
      }
      final receiptVisionAvailable = ref
          .read(aiAssistantCapabilitiesProvider)
          .receiptVisionAvailable;
      final consentStore = analyzeRemotely && receiptVisionAvailable
          ? ref.read(receiptPrivacyConsentStoreProvider)
          : null;
      final remoteAuthorized = consentStore?.hasAccepted == true;
      final acquireImage = fromGallery
          ? ref.read(importReceiptImageUseCaseProvider).call
          : ref.read(captureReceiptImageUseCaseProvider).call;
      final generation = ++_captureGeneration;
      final repository = ref.read(receiptRepositoryProvider);
      final imageStore = ref.read(receiptImageStoreProvider);
      final lease = ReceiptCaptureOperationLease(
        generation: generation,
        ownerScope: ownerScope,
        authSessionGeneration: authSessionGeneration,
        session: session,
        writer: writer,
        repository: repository,
        acquireImage: acquireImage,
        analyzeReceipt: remoteAuthorized
            ? ref.read(analyzeReceiptImageUseCaseProvider)
            : null,
        hasRemoteConsent: () =>
            ref.read(aiAssistantCapabilitiesProvider).receiptVisionAvailable &&
            consentStore?.hasAccepted == true,
        deleteImageReference: imageStore.deleteReference,
      );
      _activeCapture = lease;
      return lease;
    } on BackupWriterCancelledException {
      writer.release();
      throw const ReceiptAnalysisOperationCancelledException();
    } on Object {
      writer.release();
      rethrow;
    }
  }

  Future<ReceiptAnalysisDraft?> _completeManualReview(
    ReceiptCaptureOperationLease lease,
    ReceiptAnalysisDraft draft,
  ) async {
    final manualDraft = draft.copyWith(
      status: ReceiptDraftStatus.reviewRequired,
    );
    if (!_checkpoint(lease)) {
      return null;
    }
    await lease.repository.updateAnalysisDraft(manualDraft);
    if (!_checkpoint(lease)) {
      return null;
    }
    lease.retainLocalImageReference();
    state = ReceiptCaptureState(draft: manualDraft);
    return manualDraft;
  }

  Future<List<Category>?> _categories(
    ReceiptCaptureOperationLease lease,
  ) async {
    if (!_checkpoint(lease)) {
      return null;
    }
    final result = await ref.read(categoriesProvider.future);
    if (!_checkpoint(lease)) {
      return null;
    }
    return switch (result) {
      AppSuccess<List<Category>>(:final data) => data,
      AppFailure<List<Category>>() => const <Category>[],
    };
  }

  Future<List<Account>?> _accounts(ReceiptCaptureOperationLease lease) async {
    if (!_checkpoint(lease)) {
      return null;
    }
    final result = await ref.read(accountsProvider.future);
    if (!_checkpoint(lease)) {
      return null;
    }
    return switch (result) {
      AppSuccess<List<Account>>(:final data) => data,
      AppFailure<List<Account>>() => const <Account>[],
    };
  }

  Future<List<Payee>?> _payees(ReceiptCaptureOperationLease lease) async {
    if (!_checkpoint(lease)) {
      return null;
    }
    final result = await ref.read(payeesProvider.future);
    if (!_checkpoint(lease)) {
      return null;
    }
    return switch (result) {
      AppSuccess<List<Payee>>(:final data) => data,
      AppFailure<List<Payee>>() => const <Payee>[],
    };
  }

  bool _checkpoint(ReceiptCaptureOperationLease lease) {
    if (_isLeaseCurrent(lease)) {
      return true;
    }
    final wasActive = identical(_activeCapture, lease);
    _cancelLease(lease);
    if (wasActive) {
      _activeCapture = null;
      _captureGeneration += 1;
      if (ref.mounted) {
        state = const ReceiptCaptureState();
      }
    }
    return false;
  }

  bool _isLeaseCurrent(ReceiptCaptureOperationLease lease) {
    if (!ref.mounted ||
        lease.isCancelled ||
        !identical(_activeCapture, lease) ||
        lease.generation != _captureGeneration ||
        lease.isWriterCancelled ||
        !lease.session.isActive) {
      return false;
    }
    final currentSession = ref.read(scopedAppDatabaseSessionProvider);
    return identical(currentSession, lease.session) &&
        _isCurrentOwnerScope(
          ref,
          lease.ownerScope,
          authSessionGeneration: lease.authSessionGeneration,
        );
  }

  void _invalidateActiveCapture({required bool clearVisibleState}) {
    _captureGeneration += 1;
    final lease = _activeCapture;
    _activeCapture = null;
    if (lease != null) {
      _cancelLease(lease);
    }
    if (clearVisibleState && ref.mounted) {
      state = const ReceiptCaptureState();
    }
  }

  void _cancelLease(ReceiptCaptureOperationLease lease) {
    lease.cancel();
  }

  void clear() {
    _invalidateActiveCapture(clearVisibleState: true);
  }

  void cancel() {
    _invalidateActiveCapture(clearVisibleState: true);
  }
}

bool _isCurrentOwnerScope(
  Ref ref,
  ConfirmedOwnerScope expected, {
  int? authSessionGeneration,
}) {
  try {
    final current = ref.read(confirmedOwnerScopeSnapshotProvider);
    return current.scope?.id == expected.id &&
        current.scope?.confirmedAt == expected.confirmedAt &&
        (authSessionGeneration == null ||
            current.authSessionGeneration == authSessionGeneration);
  } on Object {
    return false;
  }
}
