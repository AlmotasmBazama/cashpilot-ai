import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/categories/data/datasources/local/categories_local_data_source.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/balance_calculator.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/finance_validation_service.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transaction_processor.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transfer_processor.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/receipts/data/repositories/receipt_repository_impl.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_local_image_store.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_analysis_draft.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_line_item.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_transaction_draft.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/transaction_split.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/image_retention_choice.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_document_type.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_draft_status.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_payment_status.dart';
import 'package:cashpilot_ai/features/receipts/domain/failures/receipt_failure_codes.dart';
import 'package:cashpilot_ai/features/receipts/domain/repositories/receipt_repository.dart';
import 'package:cashpilot_ai/features/receipts/domain/services/receipt_transaction_identity.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/build_receipt_transaction_draft.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/confirm_receipt_transaction.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_account_balance_repository.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_finance_transaction_manager.dart';
import 'package:cashpilot_ai/features/transactions/data/datasources/local/transactions_local_data_source.dart';
import 'package:cashpilot_ai/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/payment_method.dart';
import 'package:cashpilot_ai/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/get_transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  test(
    'guards-on confirmation links one transaction and replay is balance-idempotent',
    () async {
      final fixture = await _ReceiptConfirmationFixture.create();
      addTearDown(fixture.dispose);

      final draft = fixture.buildTransactionDraft();
      final first = await fixture.useCase()(draft, confirmed: true);

      final completed = _expectSuccess(first);
      final stableTransactionId =
          ReceiptTransactionIdentity.transactionIdForReceipt(
            fixture.receipt.id,
          );
      expect(completed.metadataPersisted, isTrue);
      expect(completed.transaction.id, stableTransactionId);
      await fixture.expectCompleteState(transactionId: stableTransactionId);

      final replay = await fixture.useCase()(draft, confirmed: true);

      expect(_expectSuccess(replay).transaction.id, stableTransactionId);
      await fixture.expectCompleteState(transactionId: stableTransactionId);
    },
  );

  test(
    'metadata finalize failure is typed and a fresh use case completes once',
    () async {
      final fixture = await _ReceiptConfirmationFixture.create();
      addTearDown(fixture.dispose);
      final failingRepository = _FailFinalizeOnceReceiptRepository(
        fixture.receiptRepository,
      );
      final draft = fixture.buildTransactionDraft();

      final first = await fixture.useCase(receiptRepository: failingRepository)(
        draft,
        confirmed: true,
      );

      _expectFailureCode(
        first,
        ReceiptFailureCodes.metadataFinalizationPending,
      );
      expect(await fixture.transactionCount(), 1);
      expect(await fixture.accountBalance(), Decimal.parse('90'));
      final pending = await fixture.loadReceipt();
      expect(pending.status, ReceiptDraftStatus.readyForConfirmation);
      expect(pending.linkedTransactionId, isNull);

      final retry = await fixture.useCase(receiptRepository: failingRepository)(
        draft,
        confirmed: true,
      );

      final transactionId = ReceiptTransactionIdentity.transactionIdForReceipt(
        fixture.receipt.id,
      );
      expect(_expectSuccess(retry).transaction.id, transactionId);
      expect(failingRepository.finalizeAttempts, 2);
      await fixture.expectCompleteState(transactionId: transactionId);
    },
  );

  test(
    'image cleanup failure stays visible and a fresh use case retries cleanup',
    () async {
      final fixture = await _ReceiptConfirmationFixture.create(
        retention: ImageRetentionChoice.deleteAfterExtraction,
        failImageDeleteOnce: true,
      );
      addTearDown(fixture.dispose);
      final reference = await fixture.attachImage();
      final draft = fixture.buildTransactionDraft(receipt: fixture.receipt);

      final first = await fixture.useCase()(draft, confirmed: true);

      _expectFailureCode(first, ReceiptFailureCodes.imageCleanupPending);
      expect(await File(reference).exists(), isTrue);
      final cleanupPending = await fixture.loadReceipt();
      expect(cleanupPending.status, ReceiptDraftStatus.confirmed);
      expect(cleanupPending.localImageReference, reference);
      expect(await fixture.transactionCount(), 1);
      expect(await fixture.accountBalance(), Decimal.parse('90'));

      final retry = await fixture.useCase()(draft, confirmed: true);

      expect(_expectSuccess(retry).metadataPersisted, isTrue);
      expect(await File(reference).exists(), isFalse);
      expect((await fixture.loadReceipt()).localImageReference, isNull);
      expect(fixture.failingImageStore?.deleteAttempts, 2);
      await fixture.expectCompleteState(
        transactionId: ReceiptTransactionIdentity.transactionIdForReceipt(
          fixture.receipt.id,
        ),
      );
    },
  );

  test('mismatched transaction at the receipt identity is rejected', () async {
    final fixture = await _ReceiptConfirmationFixture.create();
    addTearDown(fixture.dispose);
    final draft = fixture.buildTransactionDraft();
    final transactionId = ReceiptTransactionIdentity.transactionIdForReceipt(
      fixture.receipt.id,
    );
    final mismatched = draft.transaction.copyWith(
      id: transactionId,
      amount: Money(amount: Decimal.parse('5'), currencyCode: 'USD'),
    );
    expect(
      await fixture.transactionsRepository.createTransaction(mismatched),
      isA<AppSuccess<Transaction>>(),
    );
    expect(await fixture.accountBalance(), Decimal.parse('95'));

    final result = await fixture.useCase()(draft, confirmed: true);

    _expectFailureCode(
      result,
      ReceiptFailureCodes.transactionReservationConflict,
    );
    expect(await fixture.transactionCount(), 1);
    expect(await fixture.accountBalance(), Decimal.parse('95'));
    final receipt = await fixture.loadReceipt();
    expect(receipt.linkedTransactionId, isNull);
    expect(receipt.status, ReceiptDraftStatus.readyForConfirmation);
  });

  test(
    'create-race failure reconciles an exact committed transaction',
    () async {
      final categories = buildDefaultCategories();
      final receipt = _receipt(_groceriesCategory(categories));
      final draft = const BuildReceiptTransactionDraftUseCase()(
        draft: receipt,
        account: _account(),
        categories: categories,
        paymentMethod: PaymentMethod.cash,
        warningsAcknowledged: true,
      );
      final transactions = _RaceTransactionsRepository();
      final receipts = _InMemoryReceiptRepository(receipt);
      final useCase = ConfirmReceiptTransactionUseCase(
        createTransaction: CreateTransaction(transactions),
        getTransaction: GetTransaction(transactions),
        receiptRepository: receipts,
      );

      final result = await useCase(draft, confirmed: true);

      expect(_expectSuccess(result).metadataPersisted, isTrue);
      expect(transactions.createAttempts, 1);
      expect(transactions.readAttempts, 2);
      expect(receipts.finalizeAttempts, 1);
    },
  );
}

final class _ReceiptConfirmationFixture {
  _ReceiptConfirmationFixture({
    required this.database,
    required this.session,
    required this.directory,
    required this.receiptRepository,
    required this.transactionsRepository,
    required this.receipt,
    required this.account,
    required this.categories,
    this.failingImageStore,
  });

  static Future<_ReceiptConfirmationFixture> create({
    ImageRetentionChoice retention = ImageRetentionChoice.keepLocally,
    bool failImageDeleteOnce = false,
  }) async {
    final database = AppDatabase(
      executor: NativeDatabase.memory(),
      enforceOwnerScopeGuards: true,
      enforceFinancialIntegrityGuards: true,
    );
    final session = scopedTestSession(database);
    final directory = await Directory.systemTemp.createTemp(
      'cashpilot-receipt-confirmation-',
    );
    final failingImageStore = failImageDeleteOnce
        ? _FailOnceReceiptLocalImageStore(
            ownerScopeValue: session.ownerScopeValue,
            baseDirectory: () async => directory,
          )
        : null;
    final imageStore =
        failingImageStore ??
        ReceiptLocalImageStore(
          ownerScopeValue: session.ownerScopeValue,
          baseDirectory: () async => directory,
        );
    final receiptRepository = ReceiptRepositoryImpl(
      session: session,
      imageStore: imageStore,
    );
    await DriftCategoriesLocalDataSource(session).getDefaultCategories();
    final categories = buildDefaultCategories();
    final account = _account();
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion(
            id: Value(account.id),
            ownerScopeId: Value(session.ownerScopeValue),
            name: Value(account.name),
            type: Value(account.type.storageValue),
            currencyCode: Value(account.currencyCode),
            balance: const Value('0'),
            icon: Value(account.icon),
            color: Value(account.color),
            isArchived: Value(account.isArchived),
            createdAt: Value(account.createdAt),
            updatedAt: Value(account.updatedAt),
          ),
        );
    await database.updateAccountBalanceProjection(
      ownerScopeId: session.ownerScopeValue,
      accountId: account.id,
      balance: account.balance.toString(),
      updatedAt: account.updatedAt,
    );
    final transactionManager = DriftFinanceTransactionManager(session);
    final balanceRepository = DriftAccountBalanceRepository(session);
    final transactionsRepository = TransactionsRepositoryImpl(
      localDataSource: DriftTransactionsLocalDataSource(session),
      transactionProcessor: TransactionProcessor(
        accountBalanceRepository: balanceRepository,
        transactionManager: transactionManager,
        balanceCalculator: const BalanceCalculator(),
        validationService: const FinanceValidationService(),
      ),
      transferProcessor: TransferProcessor(
        accountBalanceRepository: balanceRepository,
        transactionManager: transactionManager,
        balanceCalculator: const BalanceCalculator(),
        validationService: const FinanceValidationService(),
        exchangeRateProvider: const SameCurrencyExchangeRateProvider(),
      ),
      logger: AppLogger.instance,
    );
    final receipt = _receipt(
      _groceriesCategory(categories),
      retention: retention,
    );
    final created = await receiptRepository.createAnalysisDraft(receipt);
    if (created is AppFailure<ReceiptAnalysisDraft>) {
      throw TestFailure('Receipt fixture failed: ${created.failure.message}');
    }
    return _ReceiptConfirmationFixture(
      database: database,
      session: session,
      directory: directory,
      receiptRepository: receiptRepository,
      transactionsRepository: transactionsRepository,
      receipt: receipt,
      account: account,
      categories: categories,
      failingImageStore: failingImageStore,
    );
  }

  final AppDatabase database;
  final ScopedAppDatabaseSession session;
  final Directory directory;
  final ReceiptRepositoryImpl receiptRepository;
  final TransactionsRepository transactionsRepository;
  ReceiptAnalysisDraft receipt;
  final Account account;
  final List<Category> categories;
  final _FailOnceReceiptLocalImageStore? failingImageStore;

  ConfirmReceiptTransactionUseCase useCase({
    ReceiptRepository? receiptRepository,
  }) {
    return ConfirmReceiptTransactionUseCase(
      createTransaction: CreateTransaction(transactionsRepository),
      getTransaction: GetTransaction(transactionsRepository),
      receiptRepository: receiptRepository ?? this.receiptRepository,
    );
  }

  ReceiptTransactionDraft buildTransactionDraft({
    ReceiptAnalysisDraft? receipt,
  }) {
    return const BuildReceiptTransactionDraftUseCase()(
      draft: receipt ?? this.receipt,
      account: account,
      categories: categories,
      paymentMethod: PaymentMethod.cash,
      warningsAcknowledged: true,
    );
  }

  Future<String> attachImage() async {
    final stored = await receiptRepository.storeLocalImage(
      receipt.id,
      const <int>[1, 2, 3, 4],
    );
    final reference = _expectSuccess(stored);
    receipt = receipt.copyWith(localImageReference: reference);
    final updated = await receiptRepository.updateAnalysisDraft(receipt);
    _expectSuccess(updated);
    return reference;
  }

  Future<ReceiptAnalysisDraft> loadReceipt() async {
    final result = await receiptRepository.getDraftById(receipt.id);
    final loaded = _expectSuccess(result);
    if (loaded != null) {
      return loaded;
    }
    final counts = await database
        .customSelect(
          '''
      SELECT COUNT(*) AS total,
        SUM(CASE WHEN owner_scope_id = ? THEN 1 ELSE 0 END) AS scoped
      FROM receipts
    ''',
          variables: <Variable<Object>>[
            Variable<String>(session.ownerScopeValue),
          ],
        )
        .getSingle();
    throw TestFailure(
      'Receipt row missing: total=${counts.read<int>('total')}, '
      'scoped=${counts.readNullable<int>('scoped') ?? 0}',
    );
  }

  Future<int> transactionCount() async {
    final count = await database
        .customSelect(
          'SELECT COUNT(*) AS value FROM transactions WHERE owner_scope_id = ?',
          variables: <Variable<Object>>[
            Variable<String>(session.ownerScopeValue),
          ],
        )
        .getSingle();
    return count.read<int>('value');
  }

  Future<Decimal> accountBalance() async {
    final row = await (database.select(
      database.accounts,
    )..where((candidate) => candidate.id.equals(account.id))).getSingle();
    return Decimal.parse(row.balance);
  }

  Future<void> expectCompleteState({required String transactionId}) async {
    expect(await transactionCount(), 1);
    expect(await accountBalance(), Decimal.parse('90'));
    final storedReceipt = await loadReceipt();
    expect(storedReceipt.status, ReceiptDraftStatus.confirmed);
    expect(storedReceipt.linkedTransactionId, transactionId);
    expect(storedReceipt.splits, isNotEmpty);
    expect(
      storedReceipt.splits.every(
        (split) => split.transactionId == transactionId,
      ),
      isTrue,
    );
  }

  Future<void> dispose() async {
    await database.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

final class _FailFinalizeOnceReceiptRepository implements ReceiptRepository {
  _FailFinalizeOnceReceiptRepository(this.delegate);

  final ReceiptRepository delegate;
  bool _shouldFail = true;
  int finalizeAttempts = 0;

  @override
  Future<AppResult<ReceiptAnalysisDraft>> reserveTransactionId(
    String receiptId,
    String transactionId,
  ) {
    return delegate.reserveTransactionId(receiptId, transactionId);
  }

  @override
  Future<AppResult<ReceiptAnalysisDraft>> finalizeReceiptTransaction({
    required String receiptId,
    required String transactionId,
    required List<TransactionSplit> splits,
  }) {
    finalizeAttempts += 1;
    if (_shouldFail) {
      _shouldFail = false;
      return Future.value(
        const AppResult.failure(
          Failure(
            message: 'Injected receipt metadata failure.',
            code: ReceiptFailureCodes.persistenceFailed,
          ),
        ),
      );
    }
    return delegate.finalizeReceiptTransaction(
      receiptId: receiptId,
      transactionId: transactionId,
      splits: splits,
    );
  }

  @override
  Future<AppResult<void>> deleteLocalImage(String receiptId) {
    return delegate.deleteLocalImage(receiptId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FailOnceReceiptLocalImageStore extends ReceiptLocalImageStore {
  _FailOnceReceiptLocalImageStore({
    required super.ownerScopeValue,
    required super.baseDirectory,
  });

  int deleteAttempts = 0;

  @override
  Future<void> deleteReference(String? reference) async {
    deleteAttempts += 1;
    if (deleteAttempts == 1) {
      throw const FileSystemException('Injected locked receipt image.');
    }
    await super.deleteReference(reference);
  }
}

final class _RaceTransactionsRepository implements TransactionsRepository {
  Transaction? stored;
  int createAttempts = 0;
  int readAttempts = 0;

  @override
  Future<AppResult<Transaction>> createTransaction(
    Transaction transaction,
  ) async {
    createAttempts += 1;
    stored = transaction;
    return const AppResult.failure(
      Failure(message: 'Concurrent insert won the transaction race.'),
    );
  }

  @override
  Future<AppResult<Transaction?>> getTransaction(String id) async {
    readAttempts += 1;
    return AppResult.success(stored?.id == id ? stored : null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _InMemoryReceiptRepository implements ReceiptRepository {
  _InMemoryReceiptRepository(this.receipt);

  ReceiptAnalysisDraft receipt;
  int finalizeAttempts = 0;

  @override
  Future<AppResult<ReceiptAnalysisDraft>> reserveTransactionId(
    String receiptId,
    String transactionId,
  ) async {
    return AppResult.success(
      receipt.copyWith(
        linkedTransactionId: receipt.linkedTransactionId ?? transactionId,
      ),
    );
  }

  @override
  Future<AppResult<ReceiptAnalysisDraft>> finalizeReceiptTransaction({
    required String receiptId,
    required String transactionId,
    required List<TransactionSplit> splits,
  }) async {
    finalizeAttempts += 1;
    receipt = receipt.copyWith(
      linkedTransactionId: transactionId,
      status: ReceiptDraftStatus.confirmed,
      splits: splits,
    );
    return AppResult.success(receipt);
  }

  @override
  Future<AppResult<void>> deleteLocalImage(String receiptId) async {
    return const AppResult.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReceiptAnalysisDraft _receipt(
  Category category, {
  ImageRetentionChoice retention = ImageRetentionChoice.keepLocally,
}) {
  const receiptId = '0198a1e6-8d41-7c26-9ed0-c7d1baf4d115';
  return ReceiptAnalysisDraft.create(
    id: receiptId,
    documentType: ReceiptDocumentType.purchaseReceipt,
    paymentStatus: ReceiptPaymentStatus.paid,
    merchantName: 'Confirmation Test Shop',
    purchaseDate: DateTime.utc(2026, 8, 10),
    currency: 'USD',
    total: Decimal.parse('10'),
    imageRetentionChoice: retention,
    status: ReceiptDraftStatus.readyForConfirmation,
    lineItems: <ReceiptLineItem>[
      ReceiptLineItem.create(
        id: '0198a1e6-8d41-7c26-9ed0-c7d1baf4d116',
        receiptId: receiptId,
        description: 'Groceries',
        normalizedDescription: 'groceries',
        totalPrice: Decimal.parse('10'),
        categoryId: category.id,
      ),
    ],
  );
}

Account _account() {
  return Account.create(
    id: '0198a1e6-8d41-7c26-9ed0-c7d1baf4d117',
    name: 'Receipt test cash',
    type: AccountType.cash,
    currencyCode: 'USD',
    balance: Decimal.parse('100'),
    icon: 'wallet',
    color: 0xFF006C67,
    createdAt: DateTime.utc(2026, 8, 10),
    updatedAt: DateTime.utc(2026, 8, 10),
  );
}

Category _groceriesCategory(List<Category> categories) {
  return categories.firstWhere((category) => category.name == 'Groceries');
}

T _expectSuccess<T>(AppResult<T> result) {
  return switch (result) {
    AppSuccess<T>(:final data) => data,
    AppFailure<T>(:final failure) => throw TestFailure(
      'Expected success, got ${failure.code}: ${failure.message}',
    ),
  };
}

void _expectFailureCode<T>(AppResult<T> result, String code) {
  expect(result, isA<AppFailure<T>>());
  expect((result as AppFailure<T>).failure.code, code);
}
