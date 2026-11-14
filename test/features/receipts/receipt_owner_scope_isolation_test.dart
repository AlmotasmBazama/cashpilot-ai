import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/accounts/application/providers/accounts_providers.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/payees/application/providers/payees_providers.dart';
import 'package:cashpilot_ai/features/payees/domain/entities/payee.dart';
import 'package:cashpilot_ai/features/receipts/application/receipt_capture_state.dart';
import 'package:cashpilot_ai/features/receipts/application/receipt_providers.dart';
import 'package:cashpilot_ai/features/receipts/data/services/isolate_receipt_image_preparation_worker.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_local_image_store.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_privacy_consent_store.dart';
import 'package:cashpilot_ai/features/receipts/domain/config/receipt_image_config.dart';
import 'package:cashpilot_ai/features/receipts/domain/config/receipt_feature_config.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/prepared_receipt_image.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_analysis_draft.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_duplicate_result.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_line_item.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/duplicate_match_strength.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_image_source.dart';
import 'package:cashpilot_ai/features/receipts/domain/repositories/receipt_analysis_provider.dart';
import 'package:cashpilot_ai/features/receipts/domain/repositories/receipt_repository.dart';
import 'package:cashpilot_ai/features/receipts/domain/services/receipt_image_capture_service.dart';
import 'package:cashpilot_ai/features/receipts/domain/services/receipt_image_preparation_worker.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/analyze_receipt_image.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/import_receipt_image.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/prepare_receipt_image.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as image;

final _testOwnerScopeProvider = StateProvider<ConfirmedOwnerScope>(
  (_) => _ownerA,
);
final _ownerA = OwnerScopeDerivation.fromConfirmedFirebaseUid(
  'synthetic-owner-a',
  confirmedAt: DateTime.utc(2026),
);
final _ownerB = OwnerScopeDerivation.fromConfirmedFirebaseUid(
  'synthetic-owner-b',
  confirmedAt: DateTime.utc(2026),
);

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> settingsBox;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'receipt-owner-scope-test-',
    );
    Hive.init(hiveDirectory.path);
    settingsBox = await Hive.openBox<dynamic>('receipt-owner-settings');
  });

  setUp(() => settingsBox.clear());

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'receipt privacy consent is isolated between owner A and owner B',
    () async {
      final ownerAStore = ReceiptPrivacyConsentStore(
        box: settingsBox,
        ownerScope: _ownerA,
        operationFence: BackupOperationFence(),
      );
      final ownerBStore = ReceiptPrivacyConsentStore(
        box: settingsBox,
        ownerScope: _ownerB,
        operationFence: BackupOperationFence(),
      );

      await settingsBox.put('receipt_ai_privacy_consent_v1', true);
      expect(ownerAStore.hasAccepted, isFalse);
      expect(ownerBStore.hasAccepted, isFalse);

      await ownerAStore.accept();

      expect(ownerAStore.hasAccepted, isTrue);
      expect(ownerBStore.hasAccepted, isFalse);
      final scopedKeys = settingsBox.keys
          .whereType<String>()
          .where((key) => key.startsWith('receipt_ai_privacy_consent_v2_'))
          .toList(growable: false);
      expect(scopedKeys, hasLength(1));
      expect(
        scopedKeys.single,
        matches(RegExp(r'^receipt_ai_privacy_consent_v2_[a-f0-9]{64}$')),
      );
      expect(scopedKeys.single, isNot(contains('synthetic-owner-a')));
      expect(scopedKeys.single, isNot(contains('synthetic-owner-b')));
    },
  );

  test(
    'receipt consent cannot commit after owner deletion is fenced',
    () async {
      final fence = BackupOperationFence();
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      final store = ReceiptPrivacyConsentStore(
        box: settingsBox,
        ownerScope: _ownerA,
        operationFence: fence,
        beforeWrite: () async {
          writeStarted.complete();
          await releaseWrite.future;
        },
      );

      final accepting = store.accept();
      final acceptingExpectation = expectLater(
        accepting,
        throwsA(isA<BackupWriterCancelledException>()),
      );
      await writeStarted.future;
      var deletionDrained = false;
      final deletion = fence
          .fenceAndDrain(
            ownerScopeValue: _ownerA.id.value,
            operationId: 'delete-receipt-consent-owner',
          )
          .then((lease) {
            deletionDrained = true;
            return lease;
          });
      await pumpEventQueue();
      expect(deletionDrained, isFalse);

      releaseWrite.complete();
      await acceptingExpectation;
      final deletionLease = await deletion;
      expect(store.hasAccepted, isFalse);
      deletionLease.release();
    },
  );

  test(
    'A to B switch while image import awaits performs no repository or provider work',
    () async {
      final capture = _ControlledCaptureService();
      final prepare = _TrackingPrepareReceiptImage();
      final repositoryA = _ControlledReceiptRepository();
      final repositoryB = _ControlledReceiptRepository();
      final provider = _TrackingReceiptAnalysisProvider();
      final imageStore = _TrackingImageStore();
      final harness = _Harness(
        settingsBox: settingsBox,
        capture: capture,
        prepare: prepare,
        repositoryA: repositoryA,
        repositoryB: repositoryB,
        provider: provider,
        imageStore: imageStore,
        providerMode: AiProviderMode.firebaseGemini,
      );
      addTearDown(harness.dispose);

      final resultFuture = harness.container
          .read(receiptCaptureControllerProvider.notifier)
          .start(
            fromGallery: true,
            analyzeRemotely: true,
            locale: const Locale('en'),
          );
      await capture.pickStarted.future;

      harness.switchToOwnerB();
      await Future<void>.delayed(Duration.zero);
      capture.completePick(_readableImage());
      final result = await resultFuture;

      expect(result, isNull);
      expect(repositoryA.totalCalls, 0);
      expect(repositoryB.totalCalls, 0);
      expect(provider.callCount, 0);
      expect(prepare.lastPrepared, isNull);
      expect(
        harness.container.read(receiptCaptureControllerProvider).draft,
        isNull,
      );
    },
  );

  test(
    'A to B switch during image preparation detaches and purges the late result',
    () async {
      final worker = _ControlledPreparationWorker();
      final prepare = _TrackingPrepareReceiptImage(worker: worker);
      final repositoryA = _ControlledReceiptRepository();
      final repositoryB = _ControlledReceiptRepository();
      final provider = _TrackingReceiptAnalysisProvider();
      final harness = _Harness(
        settingsBox: settingsBox,
        capture: _ControlledCaptureService(immediateImage: _readableImage()),
        prepare: prepare,
        repositoryA: repositoryA,
        repositoryB: repositoryB,
        provider: provider,
        imageStore: _TrackingImageStore(),
        providerMode: AiProviderMode.firebaseGemini,
      );
      addTearDown(harness.dispose);

      final resultFuture = harness.container
          .read(receiptCaptureControllerProvider.notifier)
          .start(
            fromGallery: true,
            analyzeRemotely: true,
            locale: const Locale('en'),
          );
      await worker.started.future.timeout(const Duration(seconds: 1));

      harness.switchToOwnerB();
      final result = await resultFuture.timeout(const Duration(seconds: 1));

      expect(result, isNull);
      expect(repositoryA.totalCalls, 0);
      expect(repositoryB.totalCalls, 0);
      expect(provider.callCount, 0);

      final lateBytes = Uint8List.fromList(<int>[5, 4, 3]);
      worker.complete(
        PreparedReceiptImage(
          bytes: lateBytes,
          mimeType: 'image/jpeg',
          width: 800,
          height: 1000,
          sha256: 'late-hash',
        ),
      );
      await pumpEventQueue();
      expect(lateBytes, everyElement(0));
      expect(prepare.lastPrepared, isNull);
    },
  );

  test(
    'user cancellation during image preparation detaches and purges late output',
    () async {
      final worker = _ControlledPreparationWorker();
      final prepare = _TrackingPrepareReceiptImage(worker: worker);
      final repositoryA = _ControlledReceiptRepository();
      final repositoryB = _ControlledReceiptRepository();
      final provider = _TrackingReceiptAnalysisProvider();
      final harness = _Harness(
        settingsBox: settingsBox,
        capture: _ControlledCaptureService(immediateImage: _readableImage()),
        prepare: prepare,
        repositoryA: repositoryA,
        repositoryB: repositoryB,
        provider: provider,
        imageStore: _TrackingImageStore(),
        providerMode: AiProviderMode.firebaseGemini,
      );
      addTearDown(harness.dispose);

      final controller = harness.container.read(
        receiptCaptureControllerProvider.notifier,
      );
      final resultFuture = controller.start(
        fromGallery: true,
        analyzeRemotely: true,
        locale: const Locale('en'),
      );
      await worker.started.future.timeout(const Duration(seconds: 1));
      expect(
        harness.container.read(receiptCaptureControllerProvider).stage,
        ReceiptCaptureStage.selectingAndPreparing,
      );

      controller.cancel();
      final result = await resultFuture.timeout(const Duration(seconds: 1));

      expect(result, isNull);
      expect(
        harness.container.read(receiptCaptureControllerProvider).isBusy,
        isFalse,
      );
      expect(repositoryA.totalCalls, 0);
      expect(repositoryB.totalCalls, 0);
      expect(provider.callCount, 0);

      final lateBytes = Uint8List.fromList(<int>[9, 8, 7]);
      worker.complete(
        PreparedReceiptImage(
          bytes: lateBytes,
          mimeType: 'image/jpeg',
          width: 800,
          height: 1000,
          sha256: 'cancelled-late-hash',
        ),
      );
      await pumpEventQueue();
      expect(lateBytes, everyElement(0));
      expect(prepare.lastPrepared, isNull);
    },
  );

  test(
    'A to B switch while local image storage awaits purges bytes and stops the pipeline',
    () async {
      final capture = _ControlledCaptureService(
        immediateImage: _readableImage(),
      );
      final prepare = _TrackingPrepareReceiptImage();
      final repositoryA = _ControlledReceiptRepository(blockImageStore: true);
      final repositoryB = _ControlledReceiptRepository();
      final provider = _TrackingReceiptAnalysisProvider();
      final imageStore = _TrackingImageStore();
      final harness = _Harness(
        settingsBox: settingsBox,
        capture: capture,
        prepare: prepare,
        repositoryA: repositoryA,
        repositoryB: repositoryB,
        provider: provider,
        imageStore: imageStore,
        providerMode: AiProviderMode.firebaseGemini,
      );
      addTearDown(harness.dispose);

      final resultFuture = harness.container
          .read(receiptCaptureControllerProvider.notifier)
          .start(
            fromGallery: true,
            analyzeRemotely: true,
            locale: const Locale('en'),
          );
      await repositoryA.imageStoreStarted.future;

      harness.switchToOwnerB();
      await Future<void>.delayed(Duration.zero);
      repositoryA.completeImageStore('synthetic-local-reference');
      final result = await resultFuture;

      expect(result, isNull);
      expect(repositoryA.storeImageCount, 1);
      expect(repositoryA.createCount, 0);
      expect(repositoryA.updateCount, 0);
      expect(repositoryB.totalCalls, 0);
      expect(provider.callCount, 0);
      expect(prepare.lastPrepared?.bytes, everyElement(0));
      expect(imageStore.deletedReferences, ['synthetic-local-reference']);
    },
  );

  test('stale A consent cannot authorize provider bytes for owner B', () async {
    final ownerAStore = ReceiptPrivacyConsentStore(
      box: settingsBox,
      ownerScope: _ownerA,
      operationFence: BackupOperationFence(),
    );
    final ownerBStore = ReceiptPrivacyConsentStore(
      box: settingsBox,
      ownerScope: _ownerB,
      operationFence: BackupOperationFence(),
    );
    await ownerAStore.accept();
    expect(ownerBStore.hasAccepted, isFalse);

    final provider = _TrackingReceiptAnalysisProvider();
    final repositoryA = _ControlledReceiptRepository();
    final repositoryB = _ControlledReceiptRepository();
    final harness = _Harness(
      settingsBox: settingsBox,
      capture: _ControlledCaptureService(immediateImage: _readableImage()),
      prepare: _TrackingPrepareReceiptImage(),
      repositoryA: repositoryA,
      repositoryB: repositoryB,
      provider: provider,
      imageStore: _TrackingImageStore(),
      providerMode: AiProviderMode.firebaseGemini,
    );
    addTearDown(harness.dispose);
    harness.switchToOwnerB();

    await harness.container
        .read(receiptCaptureControllerProvider.notifier)
        .start(
          fromGallery: true,
          // Simulates a stale UI decision captured for owner A.
          analyzeRemotely: true,
          locale: const Locale('en'),
        );

    expect(provider.callCount, 0);
    expect(provider.receivedByteCount, 0);
  });

  test(
    'default auto chat mode still authorizes independent receipt vision',
    () async {
      final runtime = AiRuntimeConfig.resolve();
      expect(runtime.providerMode, AiProviderMode.localParserOnly);
      expect(
        runtime.resolvedConversationProviderPreference,
        AiConversationProviderPreference.auto,
      );
      final capture = _ControlledCaptureService(
        immediateImage: _readableImage(),
      );
      final repositoryA = _ControlledReceiptRepository();
      final repositoryB = _ControlledReceiptRepository();
      final provider = _TrackingReceiptAnalysisProvider(blockAnalysis: true);
      final harness = _Harness(
        settingsBox: settingsBox,
        capture: capture,
        prepare: _TrackingPrepareReceiptImage(),
        repositoryA: repositoryA,
        repositoryB: repositoryB,
        provider: provider,
        imageStore: _TrackingImageStore(),
        providerMode: runtime.providerMode,
        receiptVisionAvailable: true,
      );
      addTearDown(harness.dispose);
      await harness.container
          .read(receiptPrivacyConsentStoreProvider)
          .accept()
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw TestFailure(
              'Timed out accepting owner-scoped receipt consent.',
            ),
          );

      final resultFuture = harness.container
          .read(receiptCaptureControllerProvider.notifier)
          .start(
            fromGallery: true,
            analyzeRemotely: true,
            locale: const Locale('en'),
          );
      final providerGate =
          await Future.any<String>(<Future<String>>[
            provider.analysisStarted.future.then((_) => 'provider-started'),
            resultFuture.then((result) => 'capture-completed:$result'),
          ]).timeout(
            const Duration(seconds: 2),
            onTimeout: () => 'pipeline-stalled',
          );
      expect(
        providerGate,
        'provider-started',
        reason:
            'Remote receipt pipeline did not reach the provider. '
            'captureStarted=${capture.pickStarted.isCompleted}, '
            'stored=${repositoryA.storeImageCount}, '
            'created=${repositoryA.createCount}, '
            'updated=${repositoryA.updateCount}, '
            'providerCalls=${provider.callCount}, '
            'state=${harness.container.read(receiptCaptureControllerProvider)}',
      );

      expect(provider.callCount, 1);
      expect(provider.receivedByteCount, greaterThan(0));
      final analyzedDraftId = provider.lastDraftId!;
      provider.completeAnalysis(
        ReceiptAnalysisDraft.create(id: analyzedDraftId),
      );
      final result = await resultFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TestFailure(
          'Timed out completing an independently authorized receipt analysis.',
        ),
      );
      expect(result, isNotNull);
      expect(result?.id, analyzedDraftId);
    },
  );

  test(
    'noncooperative receipt provider detaches and drains after owner switch',
    () async {
      final provider = _TrackingReceiptAnalysisProvider(blockAnalysis: true);
      final harness = _Harness(
        settingsBox: settingsBox,
        capture: _ControlledCaptureService(immediateImage: _readableImage()),
        prepare: _TrackingPrepareReceiptImage(),
        repositoryA: _ControlledReceiptRepository(),
        repositoryB: _ControlledReceiptRepository(),
        provider: provider,
        imageStore: _TrackingImageStore(),
        providerMode: AiProviderMode.firebaseGemini,
      );
      addTearDown(harness.dispose);
      await harness.container.read(receiptPrivacyConsentStoreProvider).accept();

      final resultFuture = harness.container
          .read(receiptCaptureControllerProvider.notifier)
          .start(
            fromGallery: true,
            analyzeRemotely: true,
            locale: const Locale('en'),
          );
      await provider.analysisStarted.future.timeout(const Duration(seconds: 2));
      expect(provider.callCount, 1);
      expect(provider.receivedByteCount, greaterThan(0));

      harness.switchToOwnerB();
      final result = await resultFuture.timeout(const Duration(seconds: 2));
      expect(result, isNull);

      final deletionLease = await harness.container
          .read(backupOperationFenceProvider)
          .fenceAndDrain(
            ownerScopeValue: _ownerA.id.value,
            operationId: 'noncooperative-receipt-owner-switch',
          )
          .timeout(const Duration(seconds: 2));
      deletionLease.release();
    },
  );

  test(
    'analysis rechecks owner after repository await before provider upload',
    () async {
      var currentOwner = _ownerA;
      final repository = _ControlledReceiptRepository(blockFirstUpdate: true);
      final provider = _TrackingReceiptAnalysisProvider();
      final useCase = AnalyzeReceiptImageUseCase(
        provider: provider,
        repository: repository,
        operationFence: BackupOperationFence(),
        boundOwnerScope: _ownerA.id.value,
        isOwnerScopeCurrent: () => currentOwner == _ownerA,
      );
      final operation = useCase(
        draft: ReceiptAnalysisDraft.create(id: 'synthetic-draft'),
        image: PreparedReceiptImage(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mimeType: 'image/jpeg',
          width: 1,
          height: 1,
          sha256:
              '0000000000000000000000000000000000000000000000000000000000000000',
        ),
        context: const ReceiptAnalysisContext(
          supportedCurrencies: <String>[],
          categoryDescriptions: <String>[],
          locale: 'en',
        ),
        categories: const <Category>[],
        isOperationCurrent: () => currentOwner == _ownerA,
      );
      await repository.updateStarted.future;

      currentOwner = _ownerB;
      repository.completeFirstUpdate();

      await expectLater(
        operation,
        throwsA(isA<ReceiptAnalysisOperationCancelledException>()),
      );
      expect(repository.updateCount, 1);
      expect(repository.duplicateCount, 0);
      expect(provider.callCount, 0);
      expect(provider.receivedByteCount, 0);
    },
  );

  test(
    'receipt response arriving after A to B is discarded and never persisted',
    () async {
      var currentOwner = _ownerA;
      final repository = _ControlledReceiptRepository();
      final provider = _TrackingReceiptAnalysisProvider(blockAnalysis: true);
      final useCase = AnalyzeReceiptImageUseCase(
        provider: provider,
        repository: repository,
        operationFence: BackupOperationFence(),
        boundOwnerScope: _ownerA.id.value,
        isOwnerScopeCurrent: () => currentOwner == _ownerA,
      );
      final operation = useCase(
        draft: ReceiptAnalysisDraft.create(id: 'owner-switch-race-draft'),
        image: PreparedReceiptImage(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mimeType: 'image/jpeg',
          width: 1,
          height: 1,
          sha256:
              '2222222222222222222222222222222222222222222222222222222222222222',
        ),
        context: const ReceiptAnalysisContext(
          supportedCurrencies: <String>[],
          categoryDescriptions: <String>[],
          locale: 'en',
        ),
        categories: const <Category>[],
      );
      await provider.analysisStarted.future;
      expect(provider.receivedByteCount, greaterThan(0));

      currentOwner = _ownerB;
      provider.completeAnalysis(
        ReceiptAnalysisDraft.create(id: 'owner-switch-race-draft'),
      );

      await expectLater(
        operation,
        throwsA(isA<ReceiptAnalysisOperationCancelledException>()),
      );
      expect(repository.updateCount, 1);
      expect(repository.duplicateCount, 0);
      expect(repository.saveLineItemsCount, 0);
    },
  );

  test('receipt extraction returning during deletion cannot persist', () async {
    final fence = BackupOperationFence();
    final repository = _ControlledReceiptRepository();
    final provider = _TrackingReceiptAnalysisProvider(blockAnalysis: true);
    final useCase = AnalyzeReceiptImageUseCase(
      provider: provider,
      repository: repository,
      operationFence: fence,
      boundOwnerScope: _ownerA.id.value,
      isOwnerScopeCurrent: () => true,
    );
    final operation = useCase(
      draft: ReceiptAnalysisDraft.create(id: 'deletion-race-draft'),
      image: PreparedReceiptImage(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sha256:
            '1111111111111111111111111111111111111111111111111111111111111111',
      ),
      context: const ReceiptAnalysisContext(
        supportedCurrencies: <String>[],
        categoryDescriptions: <String>[],
        locale: 'en',
      ),
      categories: const <Category>[],
    );
    await provider.analysisStarted.future;

    final deletionFuture = fence.fenceAndDrain(
      ownerScopeValue: _ownerA.id.value,
      operationId: 'receipt-delete-race',
    );
    provider.completeAnalysis(
      ReceiptAnalysisDraft.create(id: 'deletion-race-draft'),
    );

    await expectLater(
      operation,
      throwsA(isA<ReceiptAnalysisOperationCancelledException>()),
    );
    final deletionLease = await deletionFuture;
    deletionLease.release();

    expect(repository.updateCount, 1);
    expect(repository.duplicateCount, 0);
    expect(repository.saveLineItemsCount, 0);
  });

  test('new receipt capture while fenced performs zero work', () async {
    final capture = _ControlledCaptureService(immediateImage: _readableImage());
    final repositoryA = _ControlledReceiptRepository();
    final repositoryB = _ControlledReceiptRepository();
    final provider = _TrackingReceiptAnalysisProvider();
    final harness = _Harness(
      settingsBox: settingsBox,
      capture: capture,
      prepare: _TrackingPrepareReceiptImage(),
      repositoryA: repositoryA,
      repositoryB: repositoryB,
      provider: provider,
      imageStore: _TrackingImageStore(),
      providerMode: AiProviderMode.firebaseGemini,
    );
    addTearDown(harness.dispose);
    final deletionLease = await harness.container
        .read(backupOperationFenceProvider)
        .fenceAndDrain(
          ownerScopeValue: _ownerA.id.value,
          operationId: 'receipt-delete-active',
        );
    addTearDown(deletionLease.release);

    final result = await harness.container
        .read(receiptCaptureControllerProvider.notifier)
        .start(
          fromGallery: true,
          analyzeRemotely: true,
          locale: const Locale('en'),
        );

    expect(result, isNull);
    expect(capture.pickStarted.isCompleted, isFalse);
    expect(repositoryA.totalCalls, 0);
    expect(repositoryB.totalCalls, 0);
    expect(provider.callCount, 0);
  });
}

class _Harness {
  _Harness({
    required Box<dynamic> settingsBox,
    required _ControlledCaptureService capture,
    required _TrackingPrepareReceiptImage prepare,
    required _ControlledReceiptRepository repositoryA,
    required _ControlledReceiptRepository repositoryB,
    required _TrackingReceiptAnalysisProvider provider,
    required _TrackingImageStore imageStore,
    required AiProviderMode providerMode,
    bool? receiptVisionAvailable,
  }) {
    database = AppDatabase(executor: NativeDatabase.memory());
    final sessionA = ScopedAppDatabaseSession(
      database: database,
      scope: _ownerA,
    );
    final sessionB = ScopedAppDatabaseSession(
      database: database,
      scope: _ownerB,
    );
    final operationFence = BackupOperationFence();
    container = ProviderContainer(
      overrides: [
        confirmedOwnerScopeSnapshotProvider.overrideWith(
          _TestConfirmedOwnerScopeController.new,
        ),
        scopedAppDatabaseSessionProvider.overrideWith(
          (ref) => ref.watch(_testOwnerScopeProvider) == _ownerA
              ? sessionA
              : sessionB,
        ),
        receiptFeatureConfigProvider.overrideWithValue(
          const ReceiptFeatureConfig(enabled: true),
        ),
        backupOperationFenceProvider.overrideWithValue(operationFence),
        importReceiptImageUseCaseProvider.overrideWithValue(
          ImportReceiptImageUseCase(
            captureService: capture,
            prepareImage: prepare,
          ),
        ),
        receiptRepositoryProvider.overrideWith(
          (ref) => ref.watch(_testOwnerScopeProvider) == _ownerA
              ? repositoryA
              : repositoryB,
        ),
        receiptPrivacyConsentStoreProvider.overrideWith(
          (ref) => ReceiptPrivacyConsentStore(
            box: settingsBox,
            ownerScope: ref.watch(_testOwnerScopeProvider),
            operationFence: ref.watch(backupOperationFenceProvider),
          ),
        ),
        receiptAnalysisProvider.overrideWithValue(provider),
        receiptImageStoreProvider.overrideWithValue(imageStore),
        aiAssistantCapabilitiesProvider.overrideWithValue(
          _receiptCapabilities(
            receiptVisionAvailable:
                receiptVisionAvailable ??
                providerMode == AiProviderMode.firebaseGemini,
          ),
        ),
        categoriesProvider.overrideWithValue(
          const AsyncValue<AppResult<List<Category>>>.data(
            AppResult<List<Category>>.success(<Category>[]),
          ),
        ),
        accountsProvider.overrideWithValue(
          const AsyncValue<AppResult<List<Account>>>.data(
            AppResult<List<Account>>.success(<Account>[]),
          ),
        ),
        payeesProvider.overrideWithValue(
          const AsyncValue<AppResult<List<Payee>>>.data(
            AppResult<List<Payee>>.success(<Payee>[]),
          ),
        ),
      ],
    );
    subscription = container.listen(
      receiptCaptureControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
  }

  late final AppDatabase database;
  late final ProviderContainer container;
  late final ProviderSubscription<ReceiptCaptureState> subscription;

  void switchToOwnerB() {
    container.read(_testOwnerScopeProvider.notifier).state = _ownerB;
  }

  Future<void> dispose() async {
    subscription.close();
    container.dispose();
    await database.close();
  }
}

AiAssistantCapabilities _receiptCapabilities({
  required bool receiptVisionAvailable,
}) => AiAssistantCapabilities(
  directConversationAvailable: true,
  generalConversationAvailable: true,
  currentKnowledgeAvailable: false,
  personalFinancialAnalysisAvailable: false,
  financialDraftsAvailable: false,
  confirmedExecutionAvailable: false,
  receiptVisionAvailable: receiptVisionAvailable,
  navigationAvailable: false,
  activeProvider: AiActiveProvider.firebase,
  unavailableReason: null,
  retryable: false,
  platformSupported: true,
);

final class _TestConfirmedOwnerScopeController
    extends ConfirmedOwnerScopeController {
  @override
  OwnerScopeSnapshot build() {
    final scope = ref.watch(_testOwnerScopeProvider);
    return OwnerScopeSnapshot(
      status: OwnerScopeStatus.safe,
      scope: scope,
      authSessionGeneration: scope == _ownerA ? 1 : 2,
    );
  }
}

class _ControlledCaptureService implements ReceiptImageCaptureService {
  _ControlledCaptureService({this.immediateImage});

  final CapturedReceiptImage? immediateImage;
  final Completer<void> pickStarted = Completer<void>();
  final Completer<CapturedReceiptImage?> _picked =
      Completer<CapturedReceiptImage?>();

  void completePick(CapturedReceiptImage? value) {
    if (!_picked.isCompleted) {
      _picked.complete(value);
    }
  }

  @override
  Future<ReceiptCaptureAvailability> checkAvailability(
    ReceiptImageSource source,
  ) async => ReceiptCaptureAvailability.available;

  @override
  Future<CapturedReceiptImage?> pickFromGallery() async {
    if (!pickStarted.isCompleted) {
      pickStarted.complete();
    }
    return immediateImage ?? _picked.future;
  }

  @override
  Future<CapturedReceiptImage?> captureFromCamera() async => null;

  @override
  Future<CapturedReceiptImage?> scanDocument() async => null;
}

class _TrackingPrepareReceiptImage extends PrepareReceiptImageUseCase {
  _TrackingPrepareReceiptImage({
    super.worker = const IsolateReceiptImagePreparationWorker(),
  });

  PreparedReceiptImage? lastPrepared;

  @override
  Future<PreparedReceiptImage> call(
    CapturedReceiptImage captured, {
    Future<void>? cancellationSignal,
  }) async {
    return lastPrepared = await super.call(
      captured,
      cancellationSignal: cancellationSignal,
    );
  }
}

final class _ControlledPreparationWorker
    implements ReceiptImagePreparationWorker {
  final Completer<void> started = Completer<void>();
  final Completer<PreparedReceiptImage> _result =
      Completer<PreparedReceiptImage>();

  void complete(PreparedReceiptImage result) {
    _result.complete(result);
  }

  @override
  Future<PreparedReceiptImage> prepare({
    required CapturedReceiptImage captured,
    required ReceiptImageConfig config,
  }) {
    if (!started.isCompleted) {
      started.complete();
    }
    return _result.future;
  }
}

class _ControlledReceiptRepository implements ReceiptRepository {
  _ControlledReceiptRepository({
    this.blockImageStore = false,
    this.blockFirstUpdate = false,
  });

  final bool blockImageStore;
  final bool blockFirstUpdate;
  final Completer<void> imageStoreStarted = Completer<void>();
  final Completer<String> _imageStoreResult = Completer<String>();
  final Completer<void> updateStarted = Completer<void>();
  final Completer<void> _firstUpdateResult = Completer<void>();
  int storeImageCount = 0;
  int createCount = 0;
  int updateCount = 0;
  int duplicateCount = 0;
  int saveLineItemsCount = 0;

  int get totalCalls =>
      storeImageCount +
      createCount +
      updateCount +
      duplicateCount +
      saveLineItemsCount;

  void completeImageStore(String reference) {
    if (!_imageStoreResult.isCompleted) {
      _imageStoreResult.complete(reference);
    }
  }

  void completeFirstUpdate() {
    if (!_firstUpdateResult.isCompleted) {
      _firstUpdateResult.complete();
    }
  }

  @override
  Future<AppResult<String>> storeLocalImage(
    String receiptId,
    List<int> bytes,
  ) async {
    storeImageCount += 1;
    if (!imageStoreStarted.isCompleted) {
      imageStoreStarted.complete();
    }
    if (blockImageStore) {
      return AppResult.success(await _imageStoreResult.future);
    }
    return const AppResult.success('synthetic-local-reference');
  }

  @override
  Future<AppResult<ReceiptAnalysisDraft>> createAnalysisDraft(
    ReceiptAnalysisDraft draft,
  ) async {
    createCount += 1;
    return AppResult.success(draft);
  }

  @override
  Future<AppResult<ReceiptAnalysisDraft>> updateAnalysisDraft(
    ReceiptAnalysisDraft draft,
  ) async {
    updateCount += 1;
    if (!updateStarted.isCompleted) {
      updateStarted.complete();
    }
    if (blockFirstUpdate && updateCount == 1) {
      await _firstUpdateResult.future;
    }
    return AppResult.success(draft);
  }

  @override
  Future<AppResult<ReceiptDuplicateResult>> findDuplicateCandidates(
    ReceiptAnalysisDraft draft,
  ) async {
    duplicateCount += 1;
    return const AppResult.success(
      ReceiptDuplicateResult(
        strength: DuplicateMatchStrength.noMatch,
        candidateIds: <String>[],
      ),
    );
  }

  @override
  Future<AppResult<void>> saveLineItems(
    String receiptId,
    List<ReceiptLineItem> items,
  ) async {
    saveLineItemsCount += 1;
    return const AppResult.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TrackingReceiptAnalysisProvider implements ReceiptAnalysisProvider {
  _TrackingReceiptAnalysisProvider({this.blockAnalysis = false});

  final bool blockAnalysis;
  final Completer<void> analysisStarted = Completer<void>();
  final Completer<ReceiptAnalysisDraft> _analysisResult =
      Completer<ReceiptAnalysisDraft>();
  int callCount = 0;
  int receivedByteCount = 0;
  String? lastDraftId;

  void completeAnalysis(ReceiptAnalysisDraft draft) {
    if (!_analysisResult.isCompleted) {
      _analysisResult.complete(draft);
    }
  }

  @override
  Future<ReceiptAnalysisDraft> analyzeReceipt({
    required String draftId,
    required PreparedReceiptImage image,
    required ReceiptAnalysisContext context,
    required void Function() assertEgressAllowed,
  }) async {
    assertEgressAllowed();
    callCount += 1;
    receivedByteCount += image.bytes.length;
    lastDraftId = draftId;
    if (!analysisStarted.isCompleted) {
      analysisStarted.complete();
    }
    if (blockAnalysis) {
      return _analysisResult.future;
    }
    return ReceiptAnalysisDraft.create(id: draftId);
  }

  @override
  Object get modelConfig => const <String, Object?>{};

  @override
  Future<bool> validateAvailability() async => true;
}

class _TrackingImageStore extends ReceiptLocalImageStore {
  _TrackingImageStore()
    : super(
        ownerScopeValue:
            '0000000000000000000000000000000000000000000000000000000000000000',
      );

  final List<String> deletedReferences = <String>[];

  @override
  Future<void> deleteReference(String? reference) async {
    if (reference != null) {
      deletedReferences.add(reference);
    }
  }
}

CapturedReceiptImage _readableImage() {
  final source = image.Image(width: 800, height: 1000);
  image.fill(source, color: image.ColorRgb8(255, 255, 255));
  return CapturedReceiptImage(
    bytes: Uint8List.fromList(image.encodePng(source)),
    suggestedMimeType: 'image/png',
  );
}
