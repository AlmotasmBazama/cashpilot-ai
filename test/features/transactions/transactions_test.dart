import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/features/exchange_rates/data/adapters/stored_exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_transaction_mutation_executor.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_mutation_command.dart';
import 'package:cashpilot_ai/features/exchange_rates/data/datasources/local/exchange_rates_local_data_source.dart';
import 'package:cashpilot_ai/features/exchange_rates/data/repositories/exchange_rate_repository_impl.dart';
import 'package:cashpilot_ai/features/exchange_rates/domain/entities/stored_exchange_rate.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/account_balance_repository.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/finance_transaction_manager.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/exceptions/finance_exception.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/balance_calculator.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/finance_validation_service.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transaction_processor.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transfer_processor.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_account_balance_repository.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_finance_transaction_manager.dart';
import 'package:cashpilot_ai/features/transactions/data/datasources/local/transactions_local_data_source.dart';
import 'package:cashpilot_ai/features/transactions/data/mappers/transaction_mapper.dart';
import 'package:cashpilot_ai/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:cashpilot_ai/features/transactions/transactions.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;
  late TransactionsRepository repository;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    await seedAccount(database, id: 'cash', balance: '100');
    repository = buildRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'creates posted expense and debits account via finance engine',
    () async {
      final transaction = transactionEntity(
        id: 'tx-expense',
        amount: '25.25',
        type: TransactionType.expense,
        status: TransactionStatus.posted,
        note: 'Lunch with team',
      );

      final created = (await repository.createTransaction(
        transaction,
      )).expectSuccess();

      expect(created.id, transaction.id);
      expect(await accountBalance(database, 'cash'), decimal('74.75'));
      expect(
        (await repository.getTransaction('tx-expense')).expectSuccess(),
        isNotNull,
      );
    },
  );

  test('creates pending transaction without changing balance', () async {
    final pending = transactionEntity(
      id: 'tx-pending',
      amount: '40',
      type: TransactionType.expense,
      status: TransactionStatus.pending,
    );

    await repository.createTransaction(pending);

    expect(await accountBalance(database, 'cash'), decimal('100'));
  });

  test('rejects invalid pending amounts before persistence', () async {
    for (final amount in ['0', '-1']) {
      final result = await repository.createTransaction(
        transactionEntity(
          id: 'invalid-pending-$amount',
          amount: amount,
          type: TransactionType.expense,
          status: TransactionStatus.pending,
        ),
      );
      expect(result.expectFailureCode(), FinanceFailureCodes.invalidAmount);
    }
    expect((await repository.getTransactions()).expectSuccess(), isEmpty);
    expect(await accountBalance(database, 'cash'), decimal('100'));
  });

  test('rejects pending currency mismatch without reserving funds', () async {
    final pending = transactionEntity(
      id: 'pending-currency',
      amount: '150',
      type: TransactionType.expense,
      status: TransactionStatus.pending,
    );
    final invalid = await repository.createTransaction(
      pending.copyWith(amount: money('150', 'LYD')),
    );
    expect(invalid.expectFailureCode(), FinanceFailureCodes.currencyMismatch);
    expect((await repository.getTransactions()).expectSuccess(), isEmpty);

    // A valid pending expense may exceed today's balance. Only posting it
    // requires sufficient funds.
    (await repository.createTransaction(pending)).expectSuccess();
    expect(await accountBalance(database, 'cash'), decimal('100'));
  });

  test('invalid pending edit preserves stored content and balances', () async {
    final original = (await repository.createTransaction(
      transactionEntity(
        id: 'pending-invalid-edit',
        amount: '25',
        type: TransactionType.expense,
        status: TransactionStatus.pending,
      ),
    )).expectSuccess();
    final storedBefore = (await repository.getTransaction(
      original.id,
    )).expectSuccess();
    for (final (amount, code) in [
      (money('-1'), FinanceFailureCodes.invalidAmount),
      (money('25', 'LYD'), FinanceFailureCodes.currencyMismatch),
    ]) {
      final result = await repository.updateTransaction(
        original.copyWith(amount: amount),
      );
      expect(result.expectFailureCode(), code);
      expect(
        (await repository.getTransaction(original.id)).expectSuccess(),
        storedBefore,
      );
    }
    expect(await accountBalance(database, 'cash'), decimal('100'));
  });

  test(
    'stale expected snapshot blocks update before any balance change',
    () async {
      final original = transactionEntity(
        id: 'stale-update',
        amount: '30',
        type: TransactionType.expense,
        status: TransactionStatus.posted,
      );
      await repository.createTransaction(original);
      final independentlyEdited = original.copyWith(
        amount: money('40'),
        updatedAt: DateTime.utc(2026, 2, 2),
      );
      await repository.updateTransaction(independentlyEdited);

      final staleAttempt = await repository.updateTransaction(
        original.copyWith(
          amount: money('50'),
          updatedAt: DateTime.utc(2026, 2, 3),
        ),
        expectedCurrent: original,
      );

      expect(
        staleAttempt.expectFailureCode(),
        TransactionFailureCodes.staleMutationTarget,
      );
      expect(await accountBalance(database, 'cash'), decimal('60'));
      expect(
        (await repository.getTransaction(
          original.id,
        )).expectSuccess()!.amount.amount,
        decimal('40'),
      );
    },
  );

  test('stale expected snapshot blocks delete and reversal', () async {
    final original = transactionEntity(
      id: 'stale-delete',
      amount: '30',
      type: TransactionType.expense,
      status: TransactionStatus.posted,
    );
    await repository.createTransaction(original);
    final independentlyEdited = original.copyWith(
      note: 'manual edit after preview',
      updatedAt: DateTime.utc(2026, 2, 2),
    );
    await repository.updateTransaction(independentlyEdited);

    final staleAttempt = await repository.deleteTransaction(
      original.id,
      expectedCurrent: <Transaction>[original],
    );

    expect(
      staleAttempt.expectFailureCode(),
      TransactionFailureCodes.staleMutationTarget,
    );
    expect(await accountBalance(database, 'cash'), decimal('70'));
    expect(await repository.getTransaction(original.id), isA<AppSuccess>());
    expect(
      (await repository.getTransaction(original.id)).expectSuccess(),
      isNotNull,
    );
  });

  test(
    'typed AI update delete and undo use shared finance use cases exactly once',
    () async {
      final created = (await repository.createTransaction(
        transactionEntity(
          id: 'typed-ai-mutation',
          amount: '30',
          type: TransactionType.expense,
          status: TransactionStatus.posted,
          note: 'coffee',
        ),
      )).expectSuccess();
      final original = (await repository.getTransaction(
        created.id,
      )).expectSuccess()!;
      final executor = AiTransactionMutationExecutor(
        updateTransaction: UpdateTransaction(repository),
        deleteTransaction: DeleteTransaction(repository),
        updateTransactionStatus: UpdateTransactionStatus(repository),
        createTransaction: CreateTransaction(repository),
        getTransaction: GetTransaction(repository),
      );
      final before = AiTransactionTargetSnapshot(
        transaction: original,
        accountName: 'Cash',
        categoryName: 'Coffee',
      );
      final updatedTransaction = original.copyWith(
        amount: money('50'),
        updatedAt: DateTime.utc(2026, 3, 1),
      );
      final after = AiTransactionTargetSnapshot(
        transaction: updatedTransaction,
        accountName: 'Cash',
        categoryName: 'Coffee',
      );
      final updateCommand = UpdateTransactionCommand(
        commandId: 'update-command',
        original: before,
        updated: after,
        operationRevision: 0,
        previewFingerprint: 'preview-update',
        createdAt: DateTime.utc(2026, 3, 1),
        expiresAt: DateTime.utc(2026, 3, 1, 0, 15),
      );

      expect(
        (await executor.execute(
          UpdateTransactionDraft(command: updateCommand),
        )).expectSuccess().undoAvailable,
        isTrue,
      );
      expect(await accountBalance(database, 'cash'), decimal('50'));
      expect(
        await executor.execute(UpdateTransactionDraft(command: updateCommand)),
        isA<AppFailure>(),
      );
      expect(await accountBalance(database, 'cash'), decimal('50'));

      final undoUpdate = UndoAiActionCommand(
        commandId: 'undo-update',
        sourceCommandId: 'update-command',
        sourceToolId: 'updateTransactionDraft',
        operationType: AiUndoOperationType.undoUpdateTransaction,
        before: <AiTransactionTargetSnapshot>[before],
        after: <AiTransactionTargetSnapshot>[after],
        sourceOperationRevision: 1,
        operationRevision: 0,
        previewFingerprint: 'preview-undo-update',
        createdAt: DateTime.utc(2026, 3, 1, 0, 1),
        expiresAt: DateTime.utc(2026, 3, 1, 0, 16),
      );
      await executor.execute(UndoAiActionDraft(command: undoUpdate));
      expect(await accountBalance(database, 'cash'), decimal('70'));
      expect(
        await executor.execute(UndoAiActionDraft(command: undoUpdate)),
        isA<AppFailure>(),
      );
      expect(await accountBalance(database, 'cash'), decimal('70'));

      final deleteCommand = DeleteTransactionCommand(
        commandId: 'delete-command',
        targets: <AiTransactionTargetSnapshot>[before],
        mode: AiTransactionDeleteMode.reverseAndDeletePosted,
        operationRevision: 0,
        previewFingerprint: 'preview-delete',
        createdAt: DateTime.utc(2026, 3, 1, 0, 2),
        expiresAt: DateTime.utc(2026, 3, 1, 0, 17),
      );
      await executor.execute(DeleteTransactionDraft(command: deleteCommand));
      expect(await accountBalance(database, 'cash'), decimal('100'));
      expect(
        await executor.execute(DeleteTransactionDraft(command: deleteCommand)),
        isA<AppFailure>(),
      );
      expect(await accountBalance(database, 'cash'), decimal('100'));

      final undoDelete = UndoAiActionCommand(
        commandId: 'undo-delete',
        sourceCommandId: 'delete-command',
        sourceToolId: 'deleteTransactionDraft',
        operationType: AiUndoOperationType.undoDeleteTransaction,
        before: <AiTransactionTargetSnapshot>[before],
        after: const <AiTransactionTargetSnapshot>[],
        sourceOperationRevision: 1,
        operationRevision: 0,
        previewFingerprint: 'preview-undo-delete',
        createdAt: DateTime.utc(2026, 3, 1, 0, 3),
        expiresAt: DateTime.utc(2026, 3, 1, 0, 18),
      );
      await executor.execute(UndoAiActionDraft(command: undoDelete));
      expect(await accountBalance(database, 'cash'), decimal('70'));
      expect(
        await executor.execute(UndoAiActionDraft(command: undoDelete)),
        isA<AppFailure>(),
      );
      expect(await accountBalance(database, 'cash'), decimal('70'));

      final undoCreate = UndoAiActionCommand(
        commandId: 'undo-create',
        sourceCommandId: 'create-command',
        sourceToolId: 'createExpenseDraft',
        operationType: AiUndoOperationType.undoCreateTransaction,
        before: const <AiTransactionTargetSnapshot>[],
        after: <AiTransactionTargetSnapshot>[before],
        sourceOperationRevision: 1,
        operationRevision: 0,
        previewFingerprint: 'preview-undo-create',
        createdAt: DateTime.utc(2026, 3, 1, 0, 4),
        expiresAt: DateTime.utc(2026, 3, 1, 0, 19),
      );
      await executor.execute(UndoAiActionDraft(command: undoCreate));
      expect(await accountBalance(database, 'cash'), decimal('100'));
      expect(
        await executor.execute(UndoAiActionDraft(command: undoCreate)),
        isA<AppFailure>(),
      );
      expect(await accountBalance(database, 'cash'), decimal('100'));
    },
  );

  test('rejects terminal status on initial transaction creation', () async {
    final result = await repository.createTransaction(
      transactionEntity(
        id: 'invalid-initial-status',
        amount: '10',
        type: TransactionType.expense,
        status: TransactionStatus.cancelled,
      ),
    );

    expect(
      result.expectFailureCode(),
      TransactionFailureCodes.invalidInitialStatus,
    );
    expect(await accountBalance(database, 'cash'), decimal('100'));
  });

  test(
    'editing pending fields preserves identity and remains balance neutral',
    () async {
      await seedAccount(database, id: 'savings', balance: '50');
      final pending = transactionEntity(
        id: 'pending-edit',
        amount: '10',
        type: TransactionType.expense,
        status: TransactionStatus.pending,
      );
      await repository.createTransaction(pending);
      final editedDate = DateTime.utc(2026, 2, 3);

      final edited = (await repository.updateTransaction(
        pending.copyWith(
          accountId: 'savings',
          categoryId: 'category-edited',
          amount: money('25'),
          note: 'Edited pending note',
          transactionDate: editedDate,
          updatedAt: DateTime.utc(2026, 2, 4),
        ),
      )).expectSuccess();

      expect(edited.id, pending.id);
      expect(edited.createdAt, pending.createdAt);
      expect(edited.accountId, 'savings');
      expect(edited.categoryId, 'category-edited');
      expect(edited.amount.amount, decimal('25'));
      expect(edited.note, 'Edited pending note');
      expect(edited.transactionDate, editedDate);
      expect(edited.status, TransactionStatus.pending);
      expect(await accountBalance(database, 'cash'), decimal('100'));
      expect(await accountBalance(database, 'savings'), decimal('50'));
    },
  );

  test(
    'pending edit cannot cross the owner-scoped repository boundary',
    () async {
      const otherOwner = 'cashpilot-other-owner';
      await seedAccount(
        database,
        id: 'other-cash',
        balance: '80',
        syntheticFirebaseUid: otherOwner,
      );
      final otherRepository = buildRepository(
        database,
        syntheticFirebaseUid: otherOwner,
      );
      final otherPending = transactionEntity(
        id: 'other-pending-edit',
        accountId: 'other-cash',
        amount: '12',
        type: TransactionType.expense,
        status: TransactionStatus.pending,
      );
      await otherRepository.createTransaction(otherPending);

      final crossOwnerEdit = await repository.updateTransaction(
        otherPending.copyWith(amount: money('99')),
      );

      expect(crossOwnerEdit, isA<AppFailure<Transaction>>());
      final persisted = (await otherRepository.getTransaction(
        otherPending.id,
      )).expectSuccess();
      expect(persisted?.amount.amount, decimal('12'));
      expect(await accountBalance(database, 'other-cash'), decimal('80'));
    },
  );

  test(
    'updates pending transaction to posted and applies balance once',
    () async {
      final pending = transactionEntity(
        id: 'tx-update-status',
        amount: '10',
        type: TransactionType.expense,
        status: TransactionStatus.pending,
      );
      await repository.createTransaction(pending);

      await repository.updateTransactionStatus(
        pending.id,
        TransactionStatus.posted,
      );
      await repository.updateTransactionStatus(
        pending.id,
        TransactionStatus.posted,
      );

      expect(await accountBalance(database, 'cash'), decimal('90'));
    },
  );

  test(
    'editing pending to posted applies the edited amount exactly once',
    () async {
      final pending = transactionEntity(
        id: 'pending-edit-post',
        amount: '10',
        type: TransactionType.expense,
        status: TransactionStatus.pending,
      );
      await repository.createTransaction(pending);
      final postedEdit = pending.copyWith(
        amount: money('25'),
        status: TransactionStatus.posted,
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      await repository.updateTransaction(postedEdit);
      await repository.updateTransaction(postedEdit);

      expect(await accountBalance(database, 'cash'), decimal('75'));
    },
  );

  test(
    'updates posted transaction by reversing old balance effect first',
    () async {
      final original = transactionEntity(
        id: 'tx-update-amount',
        amount: '20',
        type: TransactionType.expense,
        status: TransactionStatus.posted,
      );
      await repository.createTransaction(original);

      final updated = original.copyWith(
        amount: money('35'),
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      await repository.updateTransaction(updated);

      expect(await accountBalance(database, 'cash'), decimal('65'));
    },
  );

  test('deletes posted transaction and reverses balance effect', () async {
    final transaction = transactionEntity(
      id: 'tx-delete',
      amount: '30',
      type: TransactionType.expense,
      status: TransactionStatus.posted,
    );
    await repository.createTransaction(transaction);

    await repository.deleteTransaction(transaction.id);

    expect(await accountBalance(database, 'cash'), decimal('100'));
    expect(
      (await repository.getTransaction(transaction.id)).expectSuccess(),
      isNull,
    );
  });

  test('creates posted income and credits account', () async {
    final income = transactionEntity(
      id: 'tx-income',
      amount: '75.50',
      type: TransactionType.income,
      status: TransactionStatus.posted,
    );

    await repository.createTransaction(income);

    expect(await accountBalance(database, 'cash'), decimal('175.50'));
  });

  test('fails insufficient balance atomically', () async {
    final transaction = transactionEntity(
      id: 'tx-too-large',
      amount: '200',
      type: TransactionType.expense,
      status: TransactionStatus.posted,
    );

    final result = await repository.createTransaction(transaction);

    expect(result, isA<AppFailure<Transaction>>());
    expect(await accountBalance(database, 'cash'), decimal('100'));
    expect(
      (await repository.getTransaction(transaction.id)).expectSuccess(),
      isNull,
    );
  });

  test('searches transactions by note and location', () async {
    await repository.createTransaction(
      transactionEntity(
        id: 'tx-search-1',
        amount: '5',
        type: TransactionType.expense,
        status: TransactionStatus.pending,
        note: 'Coffee meeting',
      ),
    );
    await repository.createTransaction(
      transactionEntity(
        id: 'tx-search-2',
        amount: '8',
        type: TransactionType.expense,
        status: TransactionStatus.pending,
        location: 'Tripoli Mall',
      ),
    );

    final noteResults = (await repository.searchTransactions(
      'coffee',
    )).expectSuccess();
    final locationResults = (await repository.searchTransactions(
      'mall',
    )).expectSuccess();

    expect(
      noteResults.map((transaction) => transaction.id),
      contains('tx-search-1'),
    );
    expect(
      locationResults.map((transaction) => transaction.id),
      contains('tx-search-2'),
    );
  });

  test(
    'search treats wildcard text literally and applies a database limit',
    () async {
      for (var index = 0; index < 4; index++) {
        await repository.createTransaction(
          transactionEntity(
            id: 'tx-search-limit-$index',
            amount: '1',
            type: TransactionType.expense,
            status: TransactionStatus.pending,
            note: index == 0 ? 'Save 100 percent' : 'Save 100% now',
          ).copyWith(
            transactionDate: DateTime.utc(2026, 1, index + 1),
            createdAt: DateTime.utc(2026, 1, index + 1),
            updatedAt: DateTime.utc(2026, 1, index + 1),
          ),
        );
      }

      final results = (await repository.searchTransactions(
        '%',
        limit: 2,
      )).expectSuccess();

      expect(results.map((transaction) => transaction.id), <String>[
        'tx-search-limit-3',
        'tx-search-limit-2',
      ]);
    },
  );

  test(
    'search keeps payee hits and applies type and status before the limit',
    () async {
      final target = transactionEntity(
        id: 'tx-filter-target',
        amount: '1',
        type: TransactionType.income,
        status: TransactionStatus.pending,
        payeeId: 'merchant-reference',
        note: 'needle',
      );
      await repository.createTransaction(target);
      for (var index = 0; index < 2; index++) {
        await repository.createTransaction(
          transactionEntity(
            id: 'tx-filter-newer-$index',
            amount: '1',
            type: TransactionType.expense,
            status: TransactionStatus.posted,
            note: 'needle',
          ).copyWith(
            transactionDate: DateTime.utc(2026, 1, index + 2),
            createdAt: DateTime.utc(2026, 1, index + 2),
            updatedAt: DateTime.utc(2026, 1, index + 2),
          ),
        );
      }

      final payeeResults = (await repository.searchTransactions(
        'merchant-reference',
        limit: 1,
      )).expectSuccess();
      final typeResults = (await repository.searchTransactions(
        'needle',
        limit: 1,
        transactionTypes: const <TransactionType>{TransactionType.income},
      )).expectSuccess();
      final statusResults = (await repository.searchTransactions(
        'needle',
        limit: 1,
        status: TransactionStatus.pending,
      )).expectSuccess();

      expect(payeeResults.single.id, target.id);
      expect(typeResults.single.id, target.id);
      expect(statusResults.single.id, target.id);
    },
  );

  test('creates successful same-currency transfer atomically', () async {
    await seedAccount(database, id: 'savings', balance: '20');

    final created = (await repository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'cash',
        targetAccountId: 'savings',
        sourceAmount: money('30'),
        occurredAt: DateTime.utc(2026, 1, 3),
      ),
    )).expectSuccess();

    expect(created.outgoingTransaction.type, TransactionType.transferOut);
    expect(created.incomingTransaction.type, TransactionType.transferIn);
    expect(created.transferGroupId, isNotEmpty);
    expect(
      created.outgoingTransaction.transferGroupId,
      created.transferGroupId,
    );
    expect(
      created.incomingTransaction.transferGroupId,
      created.transferGroupId,
    );
    expect(await accountBalance(database, 'cash'), decimal('70'));
    expect(await accountBalance(database, 'savings'), decimal('50'));
    expect((await repository.getTransactions()).expectSuccess(), hasLength(2));
    expect(
      (await repository.getTransactions(
        transferGroupId: created.transferGroupId,
      )).expectSuccess(),
      hasLength(2),
    );
  });

  test(
    'failed second transfer insert rolls back records and balances',
    () async {
      await seedAccount(database, id: 'savings', balance: '20');
      await database.customStatement('''
      CREATE TRIGGER fail_incoming_transfer
      BEFORE INSERT ON transactions
      WHEN NEW.type = 'transferIn'
      BEGIN
        SELECT RAISE(ABORT, 'injected incoming insert failure');
      END;
    ''');

      final result = await repository.createTransfer(
        CreateTransferCommand(
          sourceAccountId: 'cash',
          targetAccountId: 'savings',
          sourceAmount: money('30'),
        ),
      );

      expect(result, isA<AppFailure<CreatedTransfer>>());
      expect(await accountBalance(database, 'cash'), decimal('100'));
      expect(await accountBalance(database, 'savings'), decimal('20'));
      expect((await repository.getTransactions()).expectSuccess(), isEmpty);
    },
  );

  test('fails transfer due to insufficient balance', () async {
    await seedAccount(database, id: 'savings', balance: '20');

    final result = await repository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'cash',
        targetAccountId: 'savings',
        sourceAmount: money('130'),
      ),
    );

    expect(result, isA<AppFailure<CreatedTransfer>>());
    expect(await accountBalance(database, 'cash'), decimal('100'));
    expect(await accountBalance(database, 'savings'), decimal('20'));
    expect((await repository.getTransactions()).expectSuccess(), isEmpty);
  });

  test('fails transfer when source and destination are the same', () async {
    final result = await repository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'cash',
        targetAccountId: 'cash',
        sourceAmount: money('10'),
      ),
    );

    expect(result, isA<AppFailure<CreatedTransfer>>());
    expect(await accountBalance(database, 'cash'), decimal('100'));
    expect((await repository.getTransactions()).expectSuccess(), isEmpty);
  });

  test('failed transfer does not partially update balances', () async {
    await seedAccount(database, id: 'savings', balance: '20');

    final result = await repository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'missing',
        targetAccountId: 'savings',
        sourceAmount: money('10'),
      ),
    );

    expect(result, isA<AppFailure<CreatedTransfer>>());
    expect(await accountBalance(database, 'cash'), decimal('100'));
    expect(await accountBalance(database, 'savings'), decimal('20'));
    expect((await repository.getTransactions()).expectSuccess(), isEmpty);
  });

  test(
    'multi-currency transfer requires destination amount or exchange rate',
    () async {
      await seedAccount(database, id: 'eur', balance: '0', currencyCode: 'EUR');

      final result = await repository.createTransfer(
        CreateTransferCommand(
          sourceAccountId: 'cash',
          targetAccountId: 'eur',
          sourceAmount: money('10'),
        ),
      );

      expect(result, isA<AppFailure<CreatedTransfer>>());
      expect(
        result.expectFailureCode(),
        FinanceFailureCodes.exchangeRateUnavailable,
      );
      expect(await accountBalance(database, 'cash'), decimal('100'));
      expect(await accountBalance(database, 'eur'), decimal('0'));
      expect((await repository.getTransactions()).expectSuccess(), isEmpty);
    },
  );

  test('multi-currency transfer uses a stored manual rate', () async {
    await seedAccount(database, id: 'eur', balance: '0', currencyCode: 'EUR');
    final exchangeRepository = ExchangeRateRepositoryImpl(
      localDataSource: DriftExchangeRatesLocalDataSource(
        scopedTestSession(database),
      ),
      logger: AppLogger.instance,
    );
    await exchangeRepository.upsertRate(
      StoredExchangeRate.create(
        baseCurrency: 'USD',
        quoteCurrency: 'EUR',
        rate: decimal('0.9'),
        fetchedAt: DateTime.utc(2026, 1, 2),
      ),
    );
    final rateAwareRepository = buildRepository(
      database,
      exchangeRateProvider: StoredExchangeRateProvider(exchangeRepository),
    );

    final created = (await rateAwareRepository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'cash',
        targetAccountId: 'eur',
        sourceAmount: money('10'),
        occurredAt: DateTime.utc(2026, 1, 3),
      ),
    )).expectSuccess();

    expect(created.incomingTransaction.amount, money('9.0', 'EUR'));
    expect(created.transfer.exchangeRate.rate, decimal('0.9'));
    expect(created.transfer.exchangeRate.asOf, DateTime.utc(2026, 1, 2));
    expect(await accountBalance(database, 'cash'), decimal('90'));
    expect(await accountBalance(database, 'eur'), decimal('9.0'));
  });

  test('posted multi-currency transfer updates balances correctly', () async {
    await seedAccount(database, id: 'eur', balance: '0', currencyCode: 'EUR');

    final created = (await repository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'cash',
        targetAccountId: 'eur',
        sourceAmount: money('10'),
        targetAmount: money('9', 'EUR'),
        occurredAt: DateTime.utc(2026, 1, 3),
      ),
    )).expectSuccess();

    expect(created.transfer.exchangeRate.rate, decimal('0.9'));
    expect(created.incomingTransaction.amount.amount, decimal('9'));
    final stored = (await repository.getTransactions(
      transferGroupId: created.transferGroupId,
    )).expectSuccess();
    final storedOutgoing = stored.singleWhere(
      (transaction) => transaction.type == TransactionType.transferOut,
    );
    final storedIncoming = stored.singleWhere(
      (transaction) => transaction.type == TransactionType.transferIn,
    );
    expect(storedOutgoing.amount, money('10'));
    expect(storedIncoming.amount, money('9', 'EUR'));
    expect(storedIncoming.exchangeRate?.rate, decimal('0.9'));
    expect(
      storedIncoming.exchangeRate?.asOf?.toUtc(),
      DateTime.utc(2026, 1, 3),
    );
    expect(await accountBalance(database, 'cash'), decimal('90'));
    expect(await accountBalance(database, 'eur'), decimal('9'));
  });

  test(
    'OF-004 inconsistent explicit FX terms create no balances or rows',
    () async {
      await seedAccount(database, id: 'eur', balance: '0', currencyCode: 'EUR');

      final result = await repository.createTransfer(
        CreateTransferCommand(
          sourceAccountId: 'cash',
          targetAccountId: 'eur',
          sourceAmount: money('100'),
          targetAmount: money('999', 'EUR'),
          exchangeRate: ExchangeRate(
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'EUR',
            rate: decimal('2'),
          ),
          occurredAt: DateTime.utc(2026, 1, 3),
        ),
      );

      expect(await accountBalance(database, 'cash'), decimal('100'));
      expect(await accountBalance(database, 'eur'), Decimal.zero);
      expect((await repository.getTransactions()).expectSuccess(), isEmpty);
      expect(
        result.expectFailureCode(),
        FinanceFailureCodes.inconsistentTransferAmount,
      );
    },
  );

  test(
    'OF-004 pending transfer also rejects inconsistent FX before row writes',
    () async {
      await seedAccount(database, id: 'eur', balance: '0', currencyCode: 'EUR');

      final result = await repository.createTransfer(
        CreateTransferCommand(
          sourceAccountId: 'cash',
          targetAccountId: 'eur',
          sourceAmount: money('100'),
          targetAmount: money('999', 'EUR'),
          exchangeRate: ExchangeRate(
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'EUR',
            rate: decimal('2'),
          ),
          status: TransactionStatus.pending,
        ),
      );

      expect(await accountBalance(database, 'cash'), decimal('100'));
      expect(await accountBalance(database, 'eur'), Decimal.zero);
      expect((await repository.getTransactions()).expectSuccess(), isEmpty);
      expect(
        result.expectFailureCode(),
        FinanceFailureCodes.inconsistentTransferAmount,
      );
    },
  );

  test(
    'OF-004 target-only repeating ratio posts then reverses exact balances',
    () async {
      await seedAccount(database, id: 'eur', balance: '0', currencyCode: 'EUR');

      final created = (await repository.createTransfer(
        CreateTransferCommand(
          sourceAccountId: 'cash',
          targetAccountId: 'eur',
          sourceAmount: money('3'),
          targetAmount: money('1', 'EUR'),
        ),
      )).expectSuccess();
      final cancelled = (await repository.updateTransactionStatus(
        created.incomingTransaction.id,
        TransactionStatus.cancelled,
      )).expectSuccess();

      expect(
        cancelled.every((item) => item.status == TransactionStatus.cancelled),
        isTrue,
      );
      expect(await accountBalance(database, 'cash'), decimal('100'));
      expect(await accountBalance(database, 'eur'), Decimal.zero);
      expect(
        (await repository.getTransactions(
          transferGroupId: created.transferGroupId,
        )).expectSuccess(),
        hasLength(2),
      );
    },
  );

  test('provided exchange rate is stored with transfer timestamp', () async {
    await seedAccount(database, id: 'eur', balance: '0', currencyCode: 'EUR');
    final occurredAt = DateTime.utc(2026, 2, 3);

    final created = (await repository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'cash',
        targetAccountId: 'eur',
        sourceAmount: money('10'),
        exchangeRate: ExchangeRate(
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'EUR',
          rate: decimal('0.8'),
        ),
        occurredAt: occurredAt,
      ),
    )).expectSuccess();

    final stored = (await repository.getTransactions(
      transferGroupId: created.transferGroupId,
    )).expectSuccess();
    expect(stored, hasLength(2));
    expect(
      stored.every(
        (transaction) =>
            transaction.exchangeRate?.rate == decimal('0.8') &&
            transaction.exchangeRate?.asOf?.toUtc() == occurredAt,
      ),
      isTrue,
    );
    expect(created.incomingTransaction.amount, money('8.0', 'EUR'));
  });

  test('pending transfer creates records without changing balances', () async {
    await seedAccount(database, id: 'savings', balance: '20');

    final created = (await repository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'cash',
        targetAccountId: 'savings',
        sourceAmount: money('25'),
        status: TransactionStatus.pending,
      ),
    )).expectSuccess();

    expect(created.outgoingTransaction.status, TransactionStatus.pending);
    expect(created.incomingTransaction.status, TransactionStatus.pending);
    expect(await accountBalance(database, 'cash'), decimal('100'));
    expect(await accountBalance(database, 'savings'), decimal('20'));
    expect((await repository.getTransactions()).expectSuccess(), hasLength(2));
  });

  test('pending transfer posts both sides exactly once', () async {
    await seedAccount(database, id: 'savings', balance: '20');
    final created = (await repository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'cash',
        targetAccountId: 'savings',
        sourceAmount: money('25'),
        status: TransactionStatus.pending,
      ),
    )).expectSuccess();

    final first = (await repository.updateTransactionStatus(
      created.outgoingTransaction.id,
      TransactionStatus.posted,
    )).expectSuccess();
    final repeated = (await repository.updateTransactionStatus(
      created.incomingTransaction.id,
      TransactionStatus.posted,
    )).expectSuccess();

    expect(first, hasLength(2));
    expect(repeated, hasLength(2));
    expect(
      first.every((item) => item.status == TransactionStatus.posted),
      isTrue,
    );
    expect(await accountBalance(database, 'cash'), decimal('75'));
    expect(await accountBalance(database, 'savings'), decimal('45'));
  });

  test('pending transfer cancellation changes neither balance', () async {
    await seedAccount(database, id: 'savings', balance: '20');
    final created = (await repository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'cash',
        targetAccountId: 'savings',
        sourceAmount: money('25'),
        status: TransactionStatus.pending,
      ),
    )).expectSuccess();

    final cancelled = (await repository.updateTransactionStatus(
      created.outgoingTransaction.id,
      TransactionStatus.cancelled,
    )).expectSuccess();

    expect(cancelled, hasLength(2));
    expect(
      cancelled.every((item) => item.status == TransactionStatus.cancelled),
      isTrue,
    );
    expect(await accountBalance(database, 'cash'), decimal('100'));
    expect(await accountBalance(database, 'savings'), decimal('20'));
  });

  test('posted transfer cancellation reverses both balances once', () async {
    await seedAccount(database, id: 'savings', balance: '20');
    final created = (await repository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'cash',
        targetAccountId: 'savings',
        sourceAmount: money('30'),
      ),
    )).expectSuccess();

    final cancelled = (await repository.updateTransactionStatus(
      created.incomingTransaction.id,
      TransactionStatus.cancelled,
    )).expectSuccess();
    final repeated = (await repository.updateTransactionStatus(
      created.outgoingTransaction.id,
      TransactionStatus.cancelled,
    )).expectSuccess();

    expect(cancelled, hasLength(2));
    expect(repeated, hasLength(2));
    expect(await accountBalance(database, 'cash'), decimal('100'));
    expect(await accountBalance(database, 'savings'), decimal('20'));
  });

  test(
    'failed transfer cancellation rolls back statuses and balances',
    () async {
      await seedAccount(database, id: 'savings', balance: '0');
      final created = (await repository.createTransfer(
        CreateTransferCommand(
          sourceAccountId: 'cash',
          targetAccountId: 'savings',
          sourceAmount: money('30'),
        ),
      )).expectSuccess();
      await repository.createTransaction(
        transactionEntity(
          id: 'spend-transfer-proceeds',
          accountId: 'savings',
          amount: '30',
          type: TransactionType.expense,
          status: TransactionStatus.posted,
        ),
      );

      final result = await repository.updateTransactionStatus(
        created.outgoingTransaction.id,
        TransactionStatus.cancelled,
      );

      expect(result, isA<AppFailure<List<Transaction>>>());
      expect(await accountBalance(database, 'cash'), decimal('70'));
      expect(await accountBalance(database, 'savings'), decimal('0'));
      final group = (await repository.getTransactions(
        transferGroupId: created.transferGroupId,
      )).expectSuccess();
      expect(
        group.every((item) => item.status == TransactionStatus.posted),
        isTrue,
      );
    },
  );

  test(
    'posted to pending reverses the posted balance effect exactly once',
    () async {
      final transaction = transactionEntity(
        id: 'posted-transition',
        amount: '10',
        type: TransactionType.expense,
        status: TransactionStatus.posted,
      );
      await repository.createTransaction(transaction);

      final pendingEdit = transaction.copyWith(
        status: TransactionStatus.pending,
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      final first = await repository.updateTransaction(pendingEdit);
      final repeated = await repository.updateTransaction(pendingEdit);

      expect(first.expectSuccess().status, TransactionStatus.pending);
      expect(repeated.expectSuccess().status, TransactionStatus.pending);
      expect(await accountBalance(database, 'cash'), decimal('100'));
    },
  );

  test('posted transfer cannot be edited or hard-deleted', () async {
    await seedAccount(database, id: 'savings', balance: '20');
    final created = (await repository.createTransfer(
      CreateTransferCommand(
        sourceAccountId: 'cash',
        targetAccountId: 'savings',
        sourceAmount: money('30'),
      ),
    )).expectSuccess();

    final editResult = await repository.updateTransaction(
      created.outgoingTransaction.copyWith(note: 'unsafe edit'),
    );
    final deleteResult = await repository.deleteTransaction(
      created.outgoingTransaction.id,
    );

    expect(
      editResult.expectFailureCode(),
      TransactionFailureCodes.transferDirectEditNotAllowed,
    );
    expect(
      deleteResult.expectFailureCode(),
      TransactionFailureCodes.transferHardDeleteNotAllowed,
    );
    expect((await repository.getTransactions()).expectSuccess(), hasLength(2));
    expect(await accountBalance(database, 'cash'), decimal('70'));
    expect(await accountBalance(database, 'savings'), decimal('50'));
  });

  test(
    'deleting either pending transfer side removes the whole pair',
    () async {
      await seedAccount(database, id: 'savings', balance: '20');
      final created = (await repository.createTransfer(
        CreateTransferCommand(
          sourceAccountId: 'cash',
          targetAccountId: 'savings',
          sourceAmount: money('30'),
          status: TransactionStatus.pending,
        ),
      )).expectSuccess();

      await repository.deleteTransaction(created.incomingTransaction.id);

      expect((await repository.getTransactions()).expectSuccess(), isEmpty);
      expect(await accountBalance(database, 'cash'), decimal('100'));
      expect(await accountBalance(database, 'savings'), decimal('20'));
    },
  );

  test('direct creation of one transfer side is rejected', () async {
    final result = await repository.createTransaction(
      transactionEntity(
        id: 'orphan-transfer',
        amount: '10',
        type: TransactionType.transferOut,
        status: TransactionStatus.pending,
      ),
    );

    expect(
      result.expectFailureCode(),
      TransactionFailureCodes.transferCreationRequiresPair,
    );
    expect((await repository.getTransactions()).expectSuccess(), isEmpty);
  });

  test('legacy and malformed transfer groups reject mutation', () async {
    final localDataSource = DriftTransactionsLocalDataSource(
      scopedTestSession(database),
    );
    final legacy = transactionEntity(
      id: 'legacy-transfer',
      amount: '10',
      type: TransactionType.transferOut,
      status: TransactionStatus.pending,
    );
    await localDataSource.createTransaction(legacy.toDto());

    final legacyDelete = await repository.deleteTransaction(legacy.id);
    expect(
      legacyDelete.expectFailureCode(),
      TransactionFailureCodes.transferGroupMissing,
    );

    final malformed = legacy.copyWith(
      id: 'malformed-transfer',
      transferGroupId: 'malformed-group',
      exchangeRate: ExchangeRate.identity(currencyCode: 'USD'),
    );
    await localDataSource.createTransaction(malformed.toDto());
    final malformedDelete = await repository.deleteTransaction(malformed.id);
    expect(
      malformedDelete.expectFailureCode(),
      TransactionFailureCodes.transferGroupMalformed,
    );
  });
}

TransactionsRepository buildRepository(
  AppDatabase database, {
  ExchangeRateProvider exchangeRateProvider =
      const SameCurrencyExchangeRateProvider(),
  String syntheticFirebaseUid = 'cashpilot-test-owner',
}) {
  final session = scopedTestSession(
    database,
    syntheticFirebaseUid: syntheticFirebaseUid,
  );
  final accountBalanceRepository = DriftAccountBalanceRepository(session);
  final transactionManager = DriftFinanceTransactionManager(session);

  return TransactionsRepositoryImpl(
    localDataSource: DriftTransactionsLocalDataSource(session),
    transactionProcessor: buildTransactionProcessor(
      accountBalanceRepository: accountBalanceRepository,
      transactionManager: transactionManager,
    ),
    transferProcessor: TransferProcessor(
      accountBalanceRepository: accountBalanceRepository,
      transactionManager: transactionManager,
      balanceCalculator: const BalanceCalculator(),
      validationService: const FinanceValidationService(),
      exchangeRateProvider: exchangeRateProvider,
    ),
    logger: AppLogger.instance,
  );
}

TransactionProcessor buildTransactionProcessor({
  required AccountBalanceRepository accountBalanceRepository,
  required FinanceTransactionManager transactionManager,
}) {
  return TransactionProcessor(
    accountBalanceRepository: accountBalanceRepository,
    transactionManager: transactionManager,
    balanceCalculator: const BalanceCalculator(),
    validationService: const FinanceValidationService(),
  );
}

Transaction transactionEntity({
  required String id,
  required String amount,
  required TransactionType type,
  required TransactionStatus status,
  String accountId = 'cash',
  String? payeeId,
  String? note,
  String? location,
}) {
  return Transaction.create(
    id: id,
    accountId: accountId,
    categoryId: 'category-food',
    payeeId: payeeId,
    amount: money(amount),
    type: type,
    paymentMethod: PaymentMethod.cash,
    source: TransactionSource.manual,
    status: status,
    note: note,
    location: location,
    transactionDate: DateTime.utc(2026, 1, 1),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

Money money(String amount, [String currencyCode = 'USD']) {
  return Money(amount: decimal(amount), currencyCode: currencyCode);
}

Decimal decimal(String value) => Decimal.parse(value);

Future<void> seedAccount(
  AppDatabase database, {
  required String id,
  required String balance,
  String name = 'Cash',
  String currencyCode = 'USD',
  String syntheticFirebaseUid = 'cashpilot-test-owner',
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion(
          id: Value(id),
          ownerScopeId: Value(
            scopedTestSession(
              database,
              syntheticFirebaseUid: syntheticFirebaseUid,
            ).ownerScopeValue,
          ),
          name: Value(name),
          type: const Value('cash'),
          currencyCode: Value(currencyCode),
          balance: Value(balance),
          icon: const Value('wallet'),
          color: const Value(0xFF006C67),
          isArchived: const Value(false),
          createdAt: Value(DateTime.utc(2026, 1, 1)),
          updatedAt: Value(DateTime.utc(2026, 1, 1)),
        ),
      );
}

Future<Decimal> accountBalance(AppDatabase database, String accountId) async {
  final account = await (database.select(
    database.accounts,
  )..where((row) => row.id.equals(accountId))).getSingle();

  return decimal(account.balance);
}

extension AppResultTestX<T> on AppResult<T> {
  T expectSuccess() {
    return switch (this) {
      AppSuccess<T>(:final data) => data,
      AppFailure<T>(:final failure) => throw TestFailure(
        'Expected success but got failure: ${failure.message}',
      ),
    };
  }

  String? expectFailureCode() {
    return switch (this) {
      AppFailure<T>(:final failure) => failure.code,
      AppSuccess<T>() => throw TestFailure('Expected failure but got success.'),
    };
  }
}
