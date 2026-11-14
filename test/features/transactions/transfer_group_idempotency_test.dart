import 'dart:async';
import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_health_service.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/sync_mutation_queue.dart';
import 'package:cashpilot_ai/core/sync/domain/sync_types.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/exceptions/finance_exception.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/entities/transfer_command.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/balance_calculator.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/finance_validation_service.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transaction_processor.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transfer_processor.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_account_balance_repository.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_finance_transaction_manager.dart';
import 'package:cashpilot_ai/features/transactions/data/datasources/local/transactions_local_data_source.dart';
import 'package:cashpilot_ai/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:cashpilot_ai/features/transactions/data/dtos/transaction_dto.dart';
import 'package:cashpilot_ai/features/transactions/transactions.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    await _seedAccount(database, id: 'source', balance: '100');
    await _seedAccount(database, id: 'target', balance: '20');
  });

  tearDown(() => database.close());

  test('OF-005 exact posted retry returns the persisted pair once', () async {
    final repository = _buildRepository(database);
    final command = _command(group: 'posted-retry');

    final first = (await repository.createTransfer(command)).expectSuccess();
    final replay = (await repository.createTransfer(command)).expectSuccess();

    expect(replay.transferGroupId, first.transferGroupId);
    expect(replay.outgoingTransaction.id, first.outgoingTransaction.id);
    expect(replay.incomingTransaction.id, first.incomingTransaction.id);
    expect(await _groupRows(database, command.transferGroupId), hasLength(2));
    expect(await _balance(database, 'source'), Decimal.parse('90'));
    expect(await _balance(database, 'target'), Decimal.parse('30'));
  });

  test('OF-005 rebuilt repository replays a pending transfer safely', () async {
    final command = _command(
      group: 'pending-restart',
      status: TransactionStatus.pending,
    );
    final first = (await _buildRepository(
      database,
    ).createTransfer(command)).expectSuccess();

    final replay = (await _buildRepository(
      database,
    ).createTransfer(command)).expectSuccess();

    expect(replay.outgoingTransaction.id, first.outgoingTransaction.id);
    expect(replay.incomingTransaction.id, first.incomingTransaction.id);
    expect(await _groupRows(database, command.transferGroupId), hasLength(2));
    expect(await _balance(database, 'source'), Decimal.parse('100'));
    expect(await _balance(database, 'target'), Decimal.parse('20'));
  });

  test(
    'OF-005 concurrent exact confirmations both reconcile to one pair',
    () async {
      final command = _command(group: 'concurrent-retry');
      final firstRepository = _buildRepository(database);
      final rebuiltRepository = _buildRepository(database);

      final results = await Future.wait([
        firstRepository.createTransfer(command),
        rebuiltRepository.createTransfer(command),
      ]);
      final created = results.map((result) => result.expectSuccess()).toList();

      expect(created.map((item) => item.outgoingTransaction.id).toSet(), {
        command.outgoingTransactionId,
      });
      expect(created.map((item) => item.incomingTransaction.id).toSet(), {
        command.incomingTransactionId,
      });
      expect(await _groupRows(database, command.transferGroupId), hasLength(2));
      expect(await _balance(database, 'source'), Decimal.parse('90'));
      expect(await _balance(database, 'target'), Decimal.parse('30'));
    },
  );

  test(
    'OF-005 conflicting payload reuse fails before balance mutation',
    () async {
      final repository = _buildRepository(database);
      final original = _command(group: 'conflicting-reuse');
      await repository.createTransfer(original);

      final conflict = await repository.createTransfer(
        _command(
          group: 'conflicting-reuse',
          amount: '7',
          outgoingId: 'different-out',
          incomingId: 'different-in',
        ),
      );

      expect(conflict.expectFailureCode(), 'transfer_group_conflict');
      expect(
        await _groupRows(database, original.transferGroupId),
        hasLength(2),
      );
      expect(await _balance(database, 'source'), Decimal.parse('90'));
      expect(await _balance(database, 'target'), Decimal.parse('30'));
    },
  );

  test('OF-005 malformed one-leg group fails before Finance Engine', () async {
    final command = _command(group: 'legacy-one-leg');
    await _seedRawTransferLeg(
      database,
      id: 'legacy-only-out',
      group: command.transferGroupId,
      type: TransactionType.transferOut,
    );

    final result = await _buildRepository(database).createTransfer(command);

    expect(result.expectFailureCode(), 'transfer_group_malformed');
    expect(await _groupRows(database, command.transferGroupId), hasLength(1));
    expect(await _balance(database, 'source'), Decimal.parse('100'));
    expect(await _balance(database, 'target'), Decimal.parse('20'));
  });

  test('OF-005 extra and duplicate-role legacy group fails closed', () async {
    final command = _command(group: 'legacy-extra-leg');
    await _seedRawTransferLeg(
      database,
      id: 'legacy-out-1',
      group: command.transferGroupId,
      type: TransactionType.transferOut,
    );
    await _seedRawTransferLeg(
      database,
      id: 'legacy-out-2',
      group: command.transferGroupId,
      type: TransactionType.transferOut,
    );
    await _seedRawTransferLeg(
      database,
      id: 'legacy-in',
      group: command.transferGroupId,
      type: TransactionType.transferIn,
      accountId: 'target',
    );

    final result = await _buildRepository(database).createTransfer(command);

    expect(result.expectFailureCode(), 'transfer_group_malformed');
    expect(await _groupRows(database, command.transferGroupId), hasLength(3));
    expect(await _balance(database, 'source'), Decimal.parse('100'));
    expect(await _balance(database, 'target'), Decimal.parse('20'));
  });

  test('OF-005 database rejects raw one-leg insert and shape update', () async {
    await database.close();
    database = AppDatabase(
      executor: NativeDatabase.memory(),
      enforceOwnerScopeGuards: true,
      enforceFinancialIntegrityGuards: true,
    );
    await _seedGuardedAccount(database, id: 'source');
    await _seedGuardedAccount(database, id: 'target');
    await _seedGuardedCategory(database);

    await expectLater(
      _seedRawTransferLeg(
        database,
        id: 'raw-one-leg',
        group: 'raw-group',
        type: TransactionType.transferOut,
      ),
      throwsA(anything),
    );

    await database
        .into(database.transactions)
        .insert(
          _transactionCompanion(
            database,
            id: 'ordinary',
            group: null,
            type: TransactionType.expense,
          ),
        );
    await expectLater(
      database.customStatement(
        "UPDATE transactions SET type = 'transferOut', "
        "transfer_group_id = 'raw-group' WHERE id = 'ordinary'",
      ),
      throwsA(anything),
    );
  });

  test(
    'OF-005 command allocates identity once and replay queues nothing',
    () async {
      final queue = _RecordingSyncQueue();
      final repository = _buildRepository(database, syncQueue: queue);
      final command = CreateTransferCommand(
        sourceAccountId: 'source',
        targetAccountId: 'target',
        sourceAmount: Money(amount: Decimal.parse('10'), currencyCode: 'USD'),
        targetAmount: Money(amount: Decimal.parse('10'), currencyCode: 'USD'),
        occurredAt: DateTime.utc(2026, 2, 2),
      );

      final first = (await repository.createTransfer(command)).expectSuccess();
      final replay = (await repository.createTransfer(command)).expectSuccess();

      expect(command.transferGroupId, first.transferGroupId);
      expect(replay.replayed, isTrue);
      expect(
        replay.transfer.sourcePreviousBalance,
        replay.transfer.sourceNewBalance,
      );
      expect(
        replay.transfer.targetPreviousBalance,
        replay.transfer.targetNewBalance,
      );
      expect(queue.upserts, hasLength(2));
      expect(queue.upserts.map((item) => item.$2).toSet(), {
        first.outgoingTransaction.id,
        first.incomingTransaction.id,
      });
    },
  );

  test('OF-005 transfer identifiers reject partial or noncanonical input', () {
    CreateTransferCommand build({
      String? group = 'valid-group',
      String? outgoing,
      String? incoming,
    }) => CreateTransferCommand(
      sourceAccountId: 'source',
      targetAccountId: 'target',
      sourceAmount: Money(amount: Decimal.one, currencyCode: 'USD'),
      transferGroupId: group,
      outgoingTransactionId: outgoing,
      incomingTransactionId: incoming,
    );

    expect(() => build(outgoing: 'only-out'), throwsArgumentError);
    expect(
      () => build(outgoing: 'same', incoming: 'same'),
      throwsArgumentError,
    );
    for (final group in <String>[
      '',
      ' leading',
      'bad\u0000group',
      'bad\ngroup',
      List<String>.filled(129, 'x').join(),
    ]) {
      expect(() => build(group: group), throwsArgumentError, reason: group);
    }
  });

  test(
    'OF-005 every canonical payload field rejects conflicting reuse',
    () async {
      final repository = _buildRepository(database);
      final original = _command(group: 'field-conflicts');
      await repository.createTransfer(original);
      final conflicts = <CreateTransferCommand>[
        _command(group: 'field-conflicts', sourceAccountId: 'other-source'),
        _command(group: 'field-conflicts', targetAccountId: 'other-target'),
        _command(group: 'field-conflicts', amount: '11'),
        _command(group: 'field-conflicts', sourceCurrency: 'EUR'),
        _command(group: 'field-conflicts', targetAmount: '9'),
        _command(group: 'field-conflicts', targetCurrency: 'EUR'),
        _command(
          group: 'field-conflicts',
          explicitRate: ExchangeRate(
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'USD',
            rate: Decimal.parse('2'),
            asOf: DateTime.utc(2026, 2, 1),
          ),
        ),
        _command(group: 'field-conflicts', rateAsOf: DateTime.utc(2026, 2, 3)),
        _command(group: 'field-conflicts', status: TransactionStatus.pending),
        _command(group: 'field-conflicts', categoryId: 'another-category'),
        _command(group: 'field-conflicts', source: TransactionSource.imported),
        _command(group: 'field-conflicts', note: 'another note'),
        _command(
          group: 'field-conflicts',
          occurredAt: DateTime.utc(2026, 2, 4),
        ),
        _command(group: 'field-conflicts', includeTarget: false),
        _command(group: 'field-conflicts', includeRate: false),
      ];

      for (final conflict in conflicts) {
        final result = await repository.createTransfer(conflict);
        expect(
          result.expectFailureCode(),
          TransactionFailureCodes.transferGroupConflict,
        );
      }
      expect(
        await _groupRows(database, original.transferGroupId),
        hasLength(2),
      );
      expect(await _balance(database, 'source'), Decimal.parse('90'));
      expect(await _balance(database, 'target'), Decimal.parse('30'));
    },
  );

  test(
    'OF-005 target rate and provider provenance replay without provider use',
    () async {
      await _seedAccount(
        database,
        id: 'eur',
        balance: '0',
        currencyCode: 'EUR',
      );
      final provider = _MutableExchangeRateProvider(Decimal.parse('0.9'));
      final repository = _buildRepository(
        database,
        exchangeRateProvider: provider,
      );

      final targetOnly = _command(
        group: 'target-only',
        targetAccountId: 'eur',
        targetAmount: '9',
        targetCurrency: 'EUR',
        includeRate: false,
      );
      await repository.createTransfer(targetOnly);
      expect(
        (await repository.createTransfer(targetOnly)).expectSuccess().replayed,
        isTrue,
      );

      final rateOnly = _command(
        group: 'rate-only',
        targetAccountId: 'eur',
        targetCurrency: 'EUR',
        includeTarget: false,
        explicitRate: ExchangeRate(
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'EUR',
          rate: Decimal.parse('0.9'),
          asOf: DateTime.utc(2026, 2, 1),
        ),
      );
      await repository.createTransfer(rateOnly);
      expect(
        (await repository.createTransfer(rateOnly)).expectSuccess().replayed,
        isTrue,
      );

      final providerDerived = _command(
        group: 'provider-derived',
        targetAccountId: 'eur',
        targetCurrency: 'EUR',
        includeTarget: false,
        includeRate: false,
      );
      await repository.createTransfer(providerDerived);
      provider.fail = true;
      expect(
        (await repository.createTransfer(
          providerDerived,
        )).expectSuccess().replayed,
        isTrue,
      );
      expect(provider.calls, 1);

      final provenanceConflict = _command(
        group: targetOnly.transferGroupId,
        targetAccountId: 'eur',
        targetCurrency: 'EUR',
        includeTarget: false,
        explicitRate: ExchangeRate(
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'EUR',
          rate: Decimal.parse('0.9'),
          asOf: DateTime.utc(2026, 2, 1),
        ),
      );
      expect(
        (await repository.createTransfer(
          provenanceConflict,
        )).expectFailureCode(),
        TransactionFailureCodes.transferGroupConflict,
      );
    },
  );

  test(
    'OF-005 archived account after preview cannot execute a transfer',
    () async {
      await database.close();
      database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await _seedGuardedAccount(database, id: 'source', balance: '100');
      await _seedGuardedAccount(database, id: 'archive-target');
      await _seedGuardedCategory(database);
      final command = _command(
        group: 'archived-after-preview',
        targetAccountId: 'archive-target',
      );
      await _buildTransferProcessor(database).preview(
        TransferCommand(
          sourceAccountId: command.sourceAccountId,
          targetAccountId: command.targetAccountId,
          sourceAmount: command.sourceAmount,
          targetAmount: command.targetAmount,
          exchangeRate: command.exchangeRate,
          occurredAt: command.occurredAt,
        ),
      );
      final scope = scopedTestSession(database).ownerScopeValue;
      await (database.update(database.accounts)..where(
            (account) =>
                account.ownerScopeId.equals(scope) &
                account.id.equals('archive-target'),
          ))
          .write(
            AccountsCompanion(
              isArchived: const Value(true),
              updatedAt: Value(DateTime.utc(2026, 2, 2)),
            ),
          );

      final result = await _buildRepository(database).createTransfer(command);

      expect(result.expectFailureCode(), FinanceFailureCodes.accountNotFound);
      expect(await _groupRows(database, command.transferGroupId), isEmpty);
      expect(await _balance(database, 'source'), Decimal.parse('100'));
      expect(await _balance(database, 'archive-target'), Decimal.zero);
    },
  );

  test(
    'OF-005 prebuilt command cannot cross an owner-scope transition',
    () async {
      final command = _command(group: 'scope-changed-after-preview');
      await _buildTransferProcessor(database).preview(
        TransferCommand(
          sourceAccountId: command.sourceAccountId,
          targetAccountId: command.targetAccountId,
          sourceAmount: command.sourceAmount,
          targetAmount: command.targetAmount,
          exchangeRate: command.exchangeRate,
          occurredAt: command.occurredAt,
        ),
      );

      final result = await _buildRepository(
        database,
        syntheticFirebaseUid: 'different-confirmed-owner',
      ).createTransfer(command);

      expect(result.expectFailureCode(), FinanceFailureCodes.accountNotFound);
      expect(await _groupRows(database, command.transferGroupId), isEmpty);
      expect(await _balance(database, 'source'), Decimal.parse('100'));
      expect(await _balance(database, 'target'), Decimal.parse('20'));
    },
  );

  test(
    'OF-005 preview-bound explicit rate stays authoritative if provider changes',
    () async {
      await _seedAccount(
        database,
        id: 'eur-preview',
        balance: '20',
        currencyCode: 'EUR',
      );
      final provider = _MutableExchangeRateProvider(Decimal.parse('0.9'));
      final explicitRate = ExchangeRate(
        fromCurrencyCode: 'USD',
        toCurrencyCode: 'EUR',
        rate: Decimal.parse('0.9'),
        asOf: DateTime.utc(2026, 2, 1),
      );
      final command = _command(
        group: 'rate-changed-after-preview',
        targetAccountId: 'eur-preview',
        targetCurrency: 'EUR',
        targetAmount: '9',
        explicitRate: explicitRate,
      );
      final preview =
          await _buildTransferProcessor(
            database,
            exchangeRateProvider: provider,
          ).preview(
            TransferCommand(
              sourceAccountId: command.sourceAccountId,
              targetAccountId: command.targetAccountId,
              sourceAmount: command.sourceAmount,
              targetAmount: command.targetAmount,
              exchangeRate: command.exchangeRate,
              occurredAt: command.occurredAt,
            ),
          );
      expect(preview.exchangeRate.rate, Decimal.parse('0.9'));
      provider.rate = Decimal.parse('1.5');

      final created = (await _buildRepository(
        database,
        exchangeRateProvider: provider,
      ).createTransfer(command)).expectSuccess();

      expect(provider.calls, 0);
      expect(created.transfer.exchangeRate.rate, Decimal.parse('0.9'));
      expect(created.transfer.targetAmount.amount, Decimal.parse('9'));
      expect(await _balance(database, 'source'), Decimal.parse('90'));
      expect(await _balance(database, 'eur-preview'), Decimal.parse('29'));
    },
  );

  test(
    'OF-005 guards-on create status cancel and pending delete use pair permits',
    () async {
      await database.close();
      database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await _seedGuardedAccount(database, id: 'source', balance: '100');
      await _seedGuardedAccount(database, id: 'target', balance: '20');
      await _seedGuardedCategory(database);
      final repository = _buildRepository(database);
      final pending = (await repository.createTransfer(
        _command(group: 'guarded-post', status: TransactionStatus.pending),
      )).expectSuccess();
      await repository.updateTransactionStatus(
        pending.outgoingTransaction.id,
        TransactionStatus.posted,
      );
      await repository.updateTransactionStatus(
        pending.incomingTransaction.id,
        TransactionStatus.cancelled,
      );
      expect(await _balance(database, 'source'), Decimal.parse('100'));
      expect(await _balance(database, 'target'), Decimal.parse('20'));

      final deletable = (await repository.createTransfer(
        _command(group: 'guarded-delete', status: TransactionStatus.pending),
      )).expectSuccess();
      await repository.deleteTransaction(deletable.outgoingTransaction.id);
      expect(await _groupRows(database, deletable.transferGroupId), isEmpty);
    },
  );

  test(
    'OF-005 original command replays after legal pair status descendants',
    () async {
      final repository = _buildRepository(database);
      final pendingCommand = _command(
        group: 'replay-after-status',
        status: TransactionStatus.pending,
      );
      final pending = (await repository.createTransfer(
        pendingCommand,
      )).expectSuccess();

      (await repository.updateTransactionStatus(
        pending.outgoingTransaction.id,
        TransactionStatus.posted,
      )).expectSuccess();
      final postedReplay = (await repository.createTransfer(
        pendingCommand,
      )).expectSuccess();
      expect(postedReplay.replayed, isTrue);
      expect(postedReplay.outgoingTransaction.status, TransactionStatus.posted);
      expect(postedReplay.incomingTransaction.status, TransactionStatus.posted);
      expect(await _balance(database, 'source'), Decimal.parse('90'));
      expect(await _balance(database, 'target'), Decimal.parse('30'));

      expect(
        (await repository.createTransfer(
          _command(
            group: pendingCommand.transferGroupId,
            status: TransactionStatus.posted,
          ),
        )).expectFailureCode(),
        TransactionFailureCodes.transferGroupConflict,
      );

      (await repository.updateTransactionStatus(
        pending.incomingTransaction.id,
        TransactionStatus.cancelled,
      )).expectSuccess();
      final cancelledReplay = (await repository.createTransfer(
        pendingCommand,
      )).expectSuccess();
      expect(cancelledReplay.replayed, isTrue);
      expect(
        cancelledReplay.outgoingTransaction.status,
        TransactionStatus.cancelled,
      );
      expect(
        cancelledReplay.incomingTransaction.status,
        TransactionStatus.cancelled,
      );
      expect(await _balance(database, 'source'), Decimal.parse('100'));
      expect(await _balance(database, 'target'), Decimal.parse('20'));

      final directCancelCommand = _command(
        group: 'replay-direct-cancel',
        status: TransactionStatus.pending,
      );
      final directPending = (await repository.createTransfer(
        directCancelCommand,
      )).expectSuccess();
      (await repository.updateTransactionStatus(
        directPending.outgoingTransaction.id,
        TransactionStatus.cancelled,
      )).expectSuccess();
      final directCancelledReplay = (await repository.createTransfer(
        directCancelCommand,
      )).expectSuccess();
      expect(directCancelledReplay.replayed, isTrue);
      expect(
        directCancelledReplay.outgoingTransaction.status,
        TransactionStatus.cancelled,
      );

      final postedCommand = _command(group: 'replay-posted-cancelled');
      final initiallyPosted = (await repository.createTransfer(
        postedCommand,
      )).expectSuccess();
      (await repository.updateTransactionStatus(
        initiallyPosted.outgoingTransaction.id,
        TransactionStatus.cancelled,
      )).expectSuccess();
      final postedCancelledReplay = (await repository.createTransfer(
        postedCommand,
      )).expectSuccess();
      expect(postedCancelledReplay.replayed, isTrue);
      expect(
        postedCancelledReplay.outgoingTransaction.status,
        TransactionStatus.cancelled,
      );
      expect(await _balance(database, 'source'), Decimal.parse('100'));
      expect(await _balance(database, 'target'), Decimal.parse('20'));
    },
  );

  test(
    'OF-005 raw insert update delete matrix cannot corrupt a valid pair',
    () async {
      await database.close();
      database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await _seedGuardedAccount(database, id: 'source', balance: '100');
      await _seedGuardedAccount(database, id: 'target');
      await _seedGuardedCategory(database);
      final created = (await _buildRepository(database).createTransfer(
        _command(group: 'guarded-shape', status: TransactionStatus.pending),
      )).expectSuccess();

      final rawWrites = <Future<Object?> Function()>[
        () => _seedRawTransferLeg(
          database,
          id: 'null-group',
          group: null,
          type: TransactionType.transferOut,
        ),
        () => _seedRawTransferLeg(
          database,
          id: 'blank-group',
          group: '',
          type: TransactionType.transferOut,
        ),
        () => database
            .into(database.transactions)
            .insert(
              _transactionCompanion(
                database,
                id: 'grouped-expense',
                group: created.transferGroupId,
                type: TransactionType.expense,
              ),
            ),
        () => _seedRawTransferLeg(
          database,
          id: 'duplicate-out',
          group: created.transferGroupId,
          type: TransactionType.transferOut,
        ),
        () => _seedRawTransferLeg(
          database,
          id: 'third-in',
          group: created.transferGroupId,
          type: TransactionType.transferIn,
          accountId: 'target',
        ),
        () => database.customStatement(
          "UPDATE transactions SET transfer_group_id = 'changed' "
          'WHERE id = ?',
          <Object?>[created.outgoingTransaction.id],
        ),
        () => database.customStatement(
          "UPDATE transactions SET type = 'transferIn' WHERE id = ?",
          <Object?>[created.outgoingTransaction.id],
        ),
        () => database.customStatement(
          'DELETE FROM transactions WHERE id = ?',
          <Object?>[created.outgoingTransaction.id],
        ),
      ];
      for (final write in rawWrites) {
        await expectLater(write(), throwsA(anything));
      }
      expect(await _groupRows(database, created.transferGroupId), hasLength(2));
    },
  );

  test(
    'OF-005 failed pair insert cleans permit and permits exact retry',
    () async {
      await database.close();
      database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await _seedGuardedAccount(database, id: 'source', balance: '100');
      await _seedGuardedAccount(database, id: 'target', balance: '20');
      await _seedGuardedCategory(database);
      await database.customStatement('''
      CREATE TEMP TRIGGER injected_pair_failure
      BEFORE INSERT ON transactions WHEN NEW.type = 'transferIn'
      BEGIN SELECT RAISE(ABORT, 'injected'); END
    ''');
      final command = _command(group: 'permit-cleanup');
      expect(
        await _buildRepository(database).createTransfer(command),
        isA<AppFailure<CreatedTransfer>>(),
      );
      await database.customStatement('DROP TRIGGER injected_pair_failure');

      final created = (await _buildRepository(
        database,
      ).createTransfer(command)).expectSuccess();
      expect(created.replayed, isFalse);
      expect(await _groupRows(database, command.transferGroupId), hasLength(2));
      expect(await _balance(database, 'source'), Decimal.parse('90'));
    },
  );

  test(
    'OF-005 timeout at incoming-leg attempt rolls back pair and balances',
    () async {
      await database.close();
      var timeoutInvocations = 0;
      database = AppDatabase(
        executor: NativeDatabase.memory(
          setup: (rawDatabase) {
            rawDatabase.createFunction(
              functionName: 'of005_transfer_timeout',
              directOnly: false,
              function: (_) {
                timeoutInvocations += 1;
                throw TimeoutException('injected between transfer legs');
              },
            );
          },
        ),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await _seedGuardedAccount(database, id: 'source', balance: '100');
      await _seedGuardedAccount(database, id: 'target', balance: '20');
      await _seedGuardedCategory(database);
      await database.customStatement('''
        CREATE TEMP TRIGGER injected_transfer_timeout
        BEFORE INSERT ON transactions WHEN NEW.type = 'transferIn'
        BEGIN SELECT of005_transfer_timeout(); END
      ''');
      final command = _command(group: 'timeout-between-legs');

      expect(
        await _buildRepository(database).createTransfer(command),
        isA<AppFailure<CreatedTransfer>>(),
      );
      expect(timeoutInvocations, 1);
      expect(await _groupRows(database, command.transferGroupId), isEmpty);
      expect(await _balance(database, 'source'), Decimal.parse('100'));
      expect(await _balance(database, 'target'), Decimal.parse('20'));

      await database.customStatement('DROP TRIGGER injected_transfer_timeout');
      final retry = (await _buildRepository(
        database,
      ).createTransfer(command)).expectSuccess();
      expect(retry.replayed, isFalse);
      expect(await _groupRows(database, command.transferGroupId), hasLength(2));
      expect(await _balance(database, 'source'), Decimal.parse('90'));
      expect(await _balance(database, 'target'), Decimal.parse('30'));
    },
  );

  test(
    'OF-005 uncertain post-commit result reconciles and survives restart',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp(
        'of005-uncertain-commit-',
      );
      final file = File('${directory.path}${Platform.pathSeparator}db.sqlite');
      database = AppDatabase(
        executor: NativeDatabase(file),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await _seedGuardedAccount(database, id: 'source', balance: '100');
      await _seedGuardedAccount(
        database,
        id: 'eur',
        balance: '20',
        currencyCode: 'EUR',
      );
      await _seedGuardedCategory(database);
      final session = scopedTestSession(database);
      final dataSource = _ThrowOnceAfterCommitDataSource(
        DriftTransactionsLocalDataSource(session),
      );
      final provider = _MutableExchangeRateProvider(Decimal.parse('0.9'));
      final command = _command(
        group: 'uncertain-after-commit',
        targetAccountId: 'eur',
        targetCurrency: 'EUR',
        includeTarget: false,
        includeRate: false,
      );

      final result = (await _buildRepository(
        database,
        localDataSource: dataSource,
        exchangeRateProvider: provider,
      ).createTransfer(command)).expectSuccess();

      expect(result.replayed, isTrue);
      expect(dataSource.transactionCalls, 2);
      expect(provider.calls, 1);
      expect(await _groupRows(database, command.transferGroupId), hasLength(2));
      expect(await _balance(database, 'source'), Decimal.parse('90'));
      expect(await _balance(database, 'eur'), Decimal.parse('29'));

      await database.close();
      database = AppDatabase(
        executor: NativeDatabase(file),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      provider.fail = true;
      final restartedReplay = (await _buildRepository(
        database,
        exchangeRateProvider: provider,
      ).createTransfer(command)).expectSuccess();
      expect(restartedReplay.replayed, isTrue);
      expect(provider.calls, 1);
      expect(await _groupRows(database, command.transferGroupId), hasLength(2));
      expect(await _balance(database, 'source'), Decimal.parse('90'));
      expect(await _balance(database, 'eur'), Decimal.parse('29'));

      await database.close();
      database = AppDatabase(executor: NativeDatabase.memory());
      await directory.delete(recursive: true);
    },
  );

  test(
    'OF-005 v16 duplicate group stays unchanged and quarantines its owner',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp(
        'of005-v16-quarantine-',
      );
      final file = File('${directory.path}${Platform.pathSeparator}db.sqlite');
      database = AppDatabase(executor: NativeDatabase(file));
      await _seedAccount(database, id: 'source', balance: '80');
      await _seedAccount(database, id: 'target', balance: '40');
      await _seedGuardedCategory(database);
      const malformedGroup = 'v16-duplicated-transfer';
      for (final id in const <String>['duplicate-out-1', 'duplicate-out-2']) {
        await database
            .into(database.transactions)
            .insert(
              _transactionCompanion(
                database,
                id: id,
                group: malformedGroup,
                type: TransactionType.transferOut,
                status: 'posted',
              ),
            );
      }
      for (final id in const <String>['duplicate-in-1', 'duplicate-in-2']) {
        await database
            .into(database.transactions)
            .insert(
              _transactionCompanion(
                database,
                id: id,
                group: malformedGroup,
                type: TransactionType.transferIn,
                accountId: 'target',
                status: 'posted',
              ),
            );
      }
      for (final pair
          in const <
            ({
              String group,
              String status,
              String outgoingId,
              String incomingId,
            })
          >[
            (
              group: 'healthy-pending-before-quarantine',
              status: 'pending',
              outgoingId: 'healthy-pending-out',
              incomingId: 'healthy-pending-in',
            ),
            (
              group: 'healthy-posted-before-quarantine',
              status: 'posted',
              outgoingId: 'healthy-posted-out',
              incomingId: 'healthy-posted-in',
            ),
          ]) {
        await database
            .into(database.transactions)
            .insert(
              _transactionCompanion(
                database,
                id: pair.outgoingId,
                group: pair.group,
                type: TransactionType.transferOut,
                status: pair.status,
              ),
            );
        await database
            .into(database.transactions)
            .insert(
              _transactionCompanion(
                database,
                id: pair.incomingId,
                group: pair.group,
                type: TransactionType.transferIn,
                accountId: 'target',
                status: pair.status,
              ),
            );
      }
      await database.close();

      database = AppDatabase(
        executor: NativeDatabase(
          file,
          setup: (rawDatabase) {
            rawDatabase.execute(
              'ALTER TABLE transactions '
              'DROP COLUMN transfer_payload_fingerprint',
            );
            rawDatabase.execute('PRAGMA user_version = 16');
          },
        ),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await database.customSelect('SELECT 1').get();
      final session = scopedTestSession(database);
      final health = await OwnerScopeHealthService(database).evaluate(
        snapshot: OwnerScopeSnapshot(
          status: OwnerScopeStatus.safe,
          scope: session.confirmedScope,
        ),
        session: session,
      );

      expect(health.isSafe, isFalse);
      expect(health.status, OwnerScopeStatus.corrupted);
      expect(health.failure, OwnerScopeFailure.integrityCheckFailed);
      expect(await _groupRows(database, malformedGroup), hasLength(4));
      expect(
        (await _groupRows(
          database,
          malformedGroup,
        )).every((row) => row.transferPayloadFingerprint == null),
        isTrue,
      );
      expect(await _balance(database, 'source'), Decimal.parse('80'));
      expect(await _balance(database, 'target'), Decimal.parse('40'));

      const newGroup = 'blocked-by-transfer-quarantine';
      final blocked = await _buildRepository(
        database,
      ).createTransfer(_command(group: newGroup));
      expect(
        blocked.expectFailureCode(),
        TransactionFailureCodes.transferScopeIntegrityQuarantined,
      );
      final repository = _buildRepository(database);
      final ordinary = await repository.createTransaction(
        Transaction.create(
          id: 'blocked-ordinary-expense',
          accountId: 'source',
          categoryId: defaultTransferCategoryId,
          amount: Money(amount: Decimal.parse('5'), currencyCode: 'USD'),
          type: TransactionType.expense,
          transactionDate: DateTime.utc(2026, 2, 3),
        ),
      );
      expect(
        ordinary.expectFailureCode(),
        TransactionFailureCodes.transferScopeIntegrityQuarantined,
      );
      final posting = await repository.updateTransactionStatus(
        'healthy-pending-out',
        TransactionStatus.posted,
      );
      expect(
        posting.expectFailureCode(),
        TransactionFailureCodes.transferScopeIntegrityQuarantined,
      );
      final reversal = await repository.updateTransactionStatus(
        'healthy-posted-out',
        TransactionStatus.cancelled,
      );
      expect(
        reversal.expectFailureCode(),
        TransactionFailureCodes.transferScopeIntegrityQuarantined,
      );
      expect(await _groupRows(database, newGroup), isEmpty);
      expect(await _groupRows(database, malformedGroup), hasLength(4));
      expect(
        (await _groupRows(
          database,
          'healthy-pending-before-quarantine',
        )).every((row) => row.status == 'pending'),
        isTrue,
      );
      expect(
        (await _groupRows(
          database,
          'healthy-posted-before-quarantine',
        )).every((row) => row.status == 'posted'),
        isTrue,
      );
      expect(await _balance(database, 'source'), Decimal.parse('80'));
      expect(await _balance(database, 'target'), Decimal.parse('40'));

      final deletedTransactions = await database
          .deleteTransactionsForOwnerDataDeletion(
            ownerScopeId: session.ownerScopeValue,
            operationId: 'privacy-quarantine-cleanup',
          );
      expect(deletedTransactions, 8);
      final deletedAccounts = await database.deleteAccountsForOwnerDataDeletion(
        ownerScopeId: session.ownerScopeValue,
        operationId: 'privacy-quarantine-cleanup',
      );
      expect(deletedAccounts, 2);

      await database.close();
      database = AppDatabase(executor: NativeDatabase.memory());
      await directory.delete(recursive: true);
    },
  );

  test(
    'OF-005 repository rejects null-fingerprint contradictory terms before Finance',
    () async {
      const group = 'legacy-contradictory-terms';
      await database
          .into(database.transactions)
          .insert(
            _transactionCompanion(
              database,
              id: 'legacy-contradictory-out',
              group: group,
              type: TransactionType.transferOut,
              amount: '10',
            ),
          );
      await database
          .into(database.transactions)
          .insert(
            _transactionCompanion(
              database,
              id: 'legacy-contradictory-in',
              group: group,
              type: TransactionType.transferIn,
              accountId: 'target',
              amount: '11',
            ),
          );

      final result = await _buildRepository(database).updateTransactionStatus(
        'legacy-contradictory-out',
        TransactionStatus.posted,
      );

      expect(
        result.expectFailureCode(),
        TransactionFailureCodes.transferGroupMalformed,
      );
      expect(
        (await _groupRows(
          database,
          group,
        )).every((row) => row.status == 'pending'),
        isTrue,
      );
      expect(await _balance(database, 'source'), Decimal.parse('100'));
      expect(await _balance(database, 'target'), Decimal.parse('20'));
    },
  );

  test(
    'OF-005 repository rejects fingerprinted same-currency non-unit terms',
    () async {
      const group = 'fingerprinted-same-currency-contradiction';
      final fingerprint = List<String>.filled(64, 'c').join();
      await database
          .into(database.transactions)
          .insert(
            _transactionCompanion(
              database,
              id: 'fingerprinted-same-currency-out',
              group: group,
              type: TransactionType.transferOut,
              amount: '10',
              exchangeRate: '2',
              fingerprint: fingerprint,
            ),
          );
      await database
          .into(database.transactions)
          .insert(
            _transactionCompanion(
              database,
              id: 'fingerprinted-same-currency-in',
              group: group,
              type: TransactionType.transferIn,
              accountId: 'target',
              amount: '20',
              exchangeRate: '2',
              fingerprint: fingerprint,
            ),
          );

      final result = await _buildRepository(database).updateTransactionStatus(
        'fingerprinted-same-currency-out',
        TransactionStatus.posted,
      );

      expect(
        result.expectFailureCode(),
        TransactionFailureCodes.transferGroupMalformed,
      );
      expect(
        (await _groupRows(
          database,
          group,
        )).every((row) => row.status == 'pending'),
        isTrue,
      );
      expect(await _balance(database, 'source'), Decimal.parse('100'));
      expect(await _balance(database, 'target'), Decimal.parse('20'));
    },
  );

  test(
    'OF-005 global cross-owner group collision fails before mutation',
    () async {
      await _seedAccount(
        database,
        id: 'owner-b-source',
        balance: '100',
        syntheticFirebaseUid: 'owner-b',
      );
      await _seedRawTransferLeg(
        database,
        id: 'owner-b-leg',
        group: 'global-collision',
        type: TransactionType.transferOut,
        accountId: 'owner-b-source',
        syntheticFirebaseUid: 'owner-b',
      );

      final result = await _buildRepository(
        database,
      ).createTransfer(_command(group: 'global-collision'));

      expect(
        result.expectFailureCode(),
        TransactionFailureCodes.transferGroupConflict,
      );
      expect(await _balance(database, 'source'), Decimal.parse('100'));
      expect(await _balance(database, 'target'), Decimal.parse('20'));
    },
  );

  test(
    'OF-005 real file restart and two connections replay committed pair',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp('of005-restart-');
      final file = File('${directory.path}${Platform.pathSeparator}db.sqlite');
      database = AppDatabase(
        executor: NativeDatabase(file),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await _seedGuardedAccount(database, id: 'source', balance: '100');
      await _seedGuardedAccount(database, id: 'target', balance: '20');
      await _seedGuardedCategory(database);
      final command = _command(group: 'file-restart');
      final first = (await _buildRepository(
        database,
      ).createTransfer(command)).expectSuccess();
      await database.close();

      database = AppDatabase(
        executor: NativeDatabase(file),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      final secondConnection = AppDatabase(
        executor: NativeDatabase(file),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      final results = await Future.wait([
        _buildRepository(database).createTransfer(command),
        _buildRepository(secondConnection).createTransfer(command),
      ]);
      expect(
        results.every((result) => result is AppSuccess<CreatedTransfer>),
        isTrue,
      );
      expect(
        results
            .map((result) => result.expectSuccess().outgoingTransaction.id)
            .toSet(),
        {first.outgoingTransaction.id},
      );
      expect(await _groupRows(database, command.transferGroupId), hasLength(2));
      expect(await _balance(database, 'source'), Decimal.parse('90'));
      expect(await _balance(database, 'target'), Decimal.parse('30'));
      await secondConnection.close();
      await database.close();
      database = AppDatabase(executor: NativeDatabase.memory());
      await directory.delete(recursive: true);
    },
  );

  test(
    'OF-005 two file connections concurrently create one absent pair',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp(
        'of005-concurrent-create-',
      );
      final file = File('${directory.path}${Platform.pathSeparator}db.sqlite');
      database = AppDatabase(
        executor: NativeDatabase(file),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await _seedGuardedAccount(database, id: 'source', balance: '100');
      await _seedGuardedAccount(
        database,
        id: 'target',
        balance: '20',
        currencyCode: 'EUR',
      );
      await _seedGuardedCategory(database);
      final secondConnection = AppDatabase(
        executor: NativeDatabase(file),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await secondConnection.customSelect('SELECT 1').get();
      final provider = _BlockingExchangeRateProvider(Decimal.parse('2'));
      final command = _command(
        group: 'file-concurrent-absent',
        sourceCurrency: 'USD',
        targetCurrency: 'EUR',
        includeTarget: false,
        includeRate: false,
      );

      var firstCompleted = false;
      var secondCompleted = false;
      final first = _buildRepository(
        database,
        exchangeRateProvider: provider,
      ).createTransfer(command).whenComplete(() => firstCompleted = true);
      await provider.entered.future;
      final second = _buildRepository(
        secondConnection,
        exchangeRateProvider: provider,
      ).createTransfer(command).whenComplete(() => secondCompleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(provider.calls, 1);
      expect(firstCompleted, isFalse);
      expect(secondCompleted, isFalse);

      provider.release.complete();
      final results = await Future.wait([first, second]);
      final created = results.map((result) => result.expectSuccess()).toList();

      expect(provider.calls, 1);
      expect(created.where((item) => item.replayed), hasLength(1));
      expect(created.map((item) => item.outgoingTransaction.id).toSet(), {
        command.outgoingTransactionId,
      });
      expect(await _groupRows(database, command.transferGroupId), hasLength(2));
      expect(await _balance(database, 'source'), Decimal.parse('90'));
      expect(await _balance(database, 'target'), Decimal.parse('40'));
      await secondConnection.close();
      await database.close();
      database = AppDatabase(executor: NativeDatabase.memory());
      await directory.delete(recursive: true);
    },
  );

  test(
    'OF-005 two live file connections leave one pair on DB collision',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp(
        'of005-db-collision-',
      );
      final file = File('${directory.path}${Platform.pathSeparator}db.sqlite');
      database = AppDatabase(
        executor: NativeDatabase(file),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await _seedGuardedAccount(database, id: 'source', balance: '100');
      await _seedGuardedAccount(database, id: 'target', balance: '20');
      await _seedGuardedCategory(database);
      final secondConnection = AppDatabase(
        executor: NativeDatabase(file),
        enforceOwnerScopeGuards: true,
        enforceFinancialIntegrityGuards: true,
      );
      await secondConnection.customSelect('SELECT 1').get();
      final ownerScope = scopedTestSession(database).ownerScopeValue;
      const group = 'low-level-db-collision';
      final start = Completer<void>();

      Future<bool> attempt(AppDatabase connection) async {
        await start.future;
        try {
          await connection.insertTransferPair(
            ownerScopeId: ownerScope,
            payloadFingerprint: List<String>.filled(64, 'a').join(),
            outgoing: _transactionCompanion(
              connection,
              id: 'collision-out',
              group: group,
              type: TransactionType.transferOut,
            ),
            incoming: _transactionCompanion(
              connection,
              id: 'collision-in',
              group: group,
              type: TransactionType.transferIn,
              accountId: 'target',
            ),
          );
          return true;
        } on Object {
          return false;
        }
      }

      final attempts = <Future<bool>>[
        attempt(database),
        attempt(secondConnection),
      ];
      start.complete();
      final results = await Future.wait(attempts);

      expect(results.where((succeeded) => succeeded), hasLength(1));
      expect(await _groupRows(database, group), hasLength(2));
      expect(await _balance(database, 'source'), Decimal.parse('100'));
      expect(await _balance(database, 'target'), Decimal.parse('20'));

      final losingConnection = results.first ? secondConnection : database;
      await losingConnection.insertTransferPair(
        ownerScopeId: ownerScope,
        payloadFingerprint: List<String>.filled(64, 'b').join(),
        outgoing: _transactionCompanion(
          losingConnection,
          id: 'permit-clean-out',
          group: 'permit-clean-after-collision',
          type: TransactionType.transferOut,
        ),
        incoming: _transactionCompanion(
          losingConnection,
          id: 'permit-clean-in',
          group: 'permit-clean-after-collision',
          type: TransactionType.transferIn,
          accountId: 'target',
        ),
      );
      expect(
        await _groupRows(database, 'permit-clean-after-collision'),
        hasLength(2),
      );

      await secondConnection.close();
      await database.close();
      database = AppDatabase(executor: NativeDatabase.memory());
      await directory.delete(recursive: true);
    },
  );

  test(
    'OF-005 corrupt raw payload is rejected before mapper or Finance',
    () async {
      final corruptions = <String, String>{
        'bad-status': "status = 'mystery'",
        'bad-source': "source = 'mystery'",
        'bad-amount': "amount = 'not-decimal'",
        'bad-rate': "exchange_rate = '-1'",
        'bad-currency': "currency_code = 'EUR'",
      };
      for (final entry in corruptions.entries) {
        await database.close();
        database = AppDatabase(executor: NativeDatabase.memory());
        await _seedAccount(database, id: 'source', balance: '100');
        await _seedAccount(database, id: 'target', balance: '20');
        final repository = _buildRepository(database);
        final command = _command(
          group: entry.key,
          status: TransactionStatus.pending,
        );
        await repository.createTransfer(command);
        await database.customStatement(
          'UPDATE transactions SET ${entry.value} WHERE id = ?',
          <Object?>[command.outgoingTransactionId],
        );
        final result = await repository.createTransfer(command);
        expect(
          result.expectFailureCode(),
          TransactionFailureCodes.transferGroupMalformed,
          reason: entry.key,
        );
        expect(
          await _balance(database, 'source'),
          Decimal.parse('100'),
          reason: entry.key,
        );
        expect(
          await _balance(database, 'target'),
          Decimal.parse('20'),
          reason: entry.key,
        );
      }
    },
  );
}

CreateTransferCommand _command({
  required String group,
  String amount = '10',
  String targetAmount = '10',
  String sourceAccountId = 'source',
  String targetAccountId = 'target',
  String sourceCurrency = 'USD',
  String targetCurrency = 'USD',
  TransactionStatus status = TransactionStatus.posted,
  TransactionSource source = TransactionSource.manual,
  String categoryId = defaultTransferCategoryId,
  String? note = 'canonical transfer',
  DateTime? occurredAt,
  DateTime? rateAsOf,
  bool includeOccurredAt = true,
  bool includeRateAsOf = true,
  bool includeTarget = true,
  bool includeRate = true,
  ExchangeRate? explicitRate,
  String? outgoingId,
  String? incomingId,
}) {
  final resolvedOccurredAt = includeOccurredAt
      ? occurredAt ?? DateTime.utc(2026, 2, 1)
      : null;
  return CreateTransferCommand(
    sourceAccountId: sourceAccountId,
    targetAccountId: targetAccountId,
    sourceAmount: Money(
      amount: Decimal.parse(amount),
      currencyCode: sourceCurrency,
    ),
    targetAmount: includeTarget
        ? Money(
            amount: Decimal.parse(targetAmount),
            currencyCode: targetCurrency,
          )
        : null,
    exchangeRate: includeRate
        ? explicitRate ??
              ExchangeRate(
                fromCurrencyCode: sourceCurrency,
                toCurrencyCode: targetCurrency,
                rate: Decimal.one,
                asOf: includeRateAsOf
                    ? rateAsOf ?? DateTime.utc(2026, 2, 1)
                    : null,
              )
        : null,
    status: status,
    source: source,
    categoryId: categoryId,
    note: note,
    occurredAt: resolvedOccurredAt,
    transferGroupId: group,
    outgoingTransactionId: outgoingId ?? '$group-out',
    incomingTransactionId: incomingId ?? '$group-in',
  );
}

TransactionsRepository _buildRepository(
  AppDatabase database, {
  String syntheticFirebaseUid = 'cashpilot-test-owner',
  ExchangeRateProvider exchangeRateProvider =
      const _UnusedExchangeRateProvider(),
  SyncMutationQueue? syncQueue,
  TransactionsLocalDataSource? localDataSource,
}) {
  final session = scopedTestSession(
    database,
    syntheticFirebaseUid: syntheticFirebaseUid,
  );
  final balances = DriftAccountBalanceRepository(session);
  final manager = DriftFinanceTransactionManager(session);
  return TransactionsRepositoryImpl(
    localDataSource:
        localDataSource ?? DriftTransactionsLocalDataSource(session),
    transactionProcessor: TransactionProcessor(
      accountBalanceRepository: balances,
      transactionManager: manager,
      balanceCalculator: const BalanceCalculator(),
      validationService: const FinanceValidationService(),
    ),
    transferProcessor: TransferProcessor(
      accountBalanceRepository: balances,
      transactionManager: manager,
      balanceCalculator: const BalanceCalculator(),
      validationService: const FinanceValidationService(),
      exchangeRateProvider: exchangeRateProvider,
    ),
    logger: AppLogger.instance,
    syncQueue: syncQueue,
  );
}

TransferProcessor _buildTransferProcessor(
  AppDatabase database, {
  String syntheticFirebaseUid = 'cashpilot-test-owner',
  ExchangeRateProvider exchangeRateProvider =
      const _UnusedExchangeRateProvider(),
}) {
  final session = scopedTestSession(
    database,
    syntheticFirebaseUid: syntheticFirebaseUid,
  );
  return TransferProcessor(
    accountBalanceRepository: DriftAccountBalanceRepository(session),
    transactionManager: DriftFinanceTransactionManager(session),
    balanceCalculator: const BalanceCalculator(),
    validationService: const FinanceValidationService(),
    exchangeRateProvider: exchangeRateProvider,
  );
}

Future<void> _seedAccount(
  AppDatabase database, {
  required String id,
  required String balance,
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
          name: Value(id),
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

Future<void> _seedGuardedAccount(
  AppDatabase database, {
  required String id,
  String balance = '0',
  String currencyCode = 'USD',
  String syntheticFirebaseUid = 'cashpilot-test-owner',
}) async {
  await _seedAccount(
    database,
    id: id,
    balance: '0',
    currencyCode: currencyCode,
    syntheticFirebaseUid: syntheticFirebaseUid,
  );
  if (balance != '0') {
    final scope = scopedTestSession(
      database,
      syntheticFirebaseUid: syntheticFirebaseUid,
    ).ownerScopeValue;
    await database.updateAccountBalanceProjection(
      ownerScopeId: scope,
      accountId: id,
      balance: balance,
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }
}

Future<void> _seedGuardedCategory(
  AppDatabase database, {
  String syntheticFirebaseUid = 'cashpilot-test-owner',
}) {
  return database
      .into(database.categories)
      .insert(
        CategoriesCompanion(
          id: const Value(defaultTransferCategoryId),
          ownerScopeId: Value(
            scopedTestSession(
              database,
              syntheticFirebaseUid: syntheticFirebaseUid,
            ).ownerScopeValue,
          ),
          name: const Value('Transfer'),
          type: const Value('expense'),
          icon: const Value('swap'),
          color: const Value(0xFF006C67),
          isDefault: const Value(false),
          isArchived: const Value(false),
          sortOrder: const Value(0),
          createdAt: Value(DateTime.utc(2026, 1, 1)),
          updatedAt: Value(DateTime.utc(2026, 1, 1)),
        ),
      );
}

Future<void> _seedRawTransferLeg(
  AppDatabase database, {
  required String id,
  required String? group,
  required TransactionType type,
  String accountId = 'source',
  String syntheticFirebaseUid = 'cashpilot-test-owner',
}) {
  return database
      .into(database.transactions)
      .insert(
        _transactionCompanion(
          database,
          id: id,
          group: group,
          type: type,
          accountId: accountId,
          syntheticFirebaseUid: syntheticFirebaseUid,
        ),
      );
}

TransactionsCompanion _transactionCompanion(
  AppDatabase database, {
  required String id,
  required String? group,
  required TransactionType type,
  String accountId = 'source',
  String syntheticFirebaseUid = 'cashpilot-test-owner',
  String status = 'pending',
  String amount = '10',
  String currencyCode = 'USD',
  String exchangeRateFromCurrencyCode = 'USD',
  String exchangeRateToCurrencyCode = 'USD',
  String exchangeRate = '1',
  String? fingerprint,
}) {
  return TransactionsCompanion(
    id: Value(id),
    ownerScopeId: Value(
      scopedTestSession(
        database,
        syntheticFirebaseUid: syntheticFirebaseUid,
      ).ownerScopeValue,
    ),
    accountId: Value(accountId),
    categoryId: const Value(defaultTransferCategoryId),
    amount: Value(amount),
    currencyCode: Value(currencyCode),
    type: Value(type.storageValue),
    paymentMethod: const Value('bankTransfer'),
    source: const Value('manual'),
    status: Value(status),
    transferGroupId: Value(group),
    transferPayloadFingerprint: Value(fingerprint),
    exchangeRateFromCurrencyCode: Value(exchangeRateFromCurrencyCode),
    exchangeRateToCurrencyCode: Value(exchangeRateToCurrencyCode),
    exchangeRate: Value(exchangeRate),
    exchangeRateAsOf: Value(DateTime.utc(2026, 2, 1)),
    note: const Value('canonical transfer'),
    transactionDate: Value(DateTime.utc(2026, 2, 1)),
    attachmentCount: const Value(0),
    needsReview: const Value(false),
    createdAt: Value(DateTime.utc(2026, 2, 1)),
    updatedAt: Value(DateTime.utc(2026, 2, 1)),
  );
}

Future<List<TransactionRow>> _groupRows(AppDatabase database, String group) {
  return (database.select(
    database.transactions,
  )..where((row) => row.transferGroupId.equals(group))).get();
}

Future<Decimal> _balance(AppDatabase database, String accountId) async {
  final row = await (database.select(
    database.accounts,
  )..where((account) => account.id.equals(accountId))).getSingle();
  return Decimal.parse(row.balance);
}

final class _UnusedExchangeRateProvider implements ExchangeRateProvider {
  const _UnusedExchangeRateProvider();

  @override
  Future<ExchangeRate> getExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    DateTime? at,
  }) {
    throw StateError('The explicit exchange rate must be used.');
  }
}

final class _MutableExchangeRateProvider implements ExchangeRateProvider {
  _MutableExchangeRateProvider(this.rate);

  Decimal rate;
  int calls = 0;
  bool fail = false;

  @override
  Future<ExchangeRate> getExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    DateTime? at,
  }) async {
    calls += 1;
    if (fail) {
      throw StateError('provider unavailable');
    }
    return ExchangeRate(
      fromCurrencyCode: fromCurrencyCode,
      toCurrencyCode: toCurrencyCode,
      rate: rate,
      asOf: at,
    );
  }
}

final class _BlockingExchangeRateProvider implements ExchangeRateProvider {
  _BlockingExchangeRateProvider(this.rate);

  final Decimal rate;
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();
  int calls = 0;

  @override
  Future<ExchangeRate> getExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    DateTime? at,
  }) async {
    calls += 1;
    if (!entered.isCompleted) {
      entered.complete();
    }
    await release.future;
    return ExchangeRate(
      fromCurrencyCode: fromCurrencyCode,
      toCurrencyCode: toCurrencyCode,
      rate: rate,
      asOf: at,
    );
  }
}

final class _ThrowOnceAfterCommitDataSource
    implements TransactionsLocalDataSource {
  _ThrowOnceAfterCommitDataSource(this._delegate);

  final TransactionsLocalDataSource _delegate;
  int transactionCalls = 0;
  bool _shouldThrow = true;

  @override
  String get ownerScopeValue => _delegate.ownerScopeValue;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() operation) async {
    transactionCalls += 1;
    final result = await _delegate.runInTransaction(operation);
    if (_shouldThrow) {
      _shouldThrow = false;
      throw StateError('injected_result_delivery_interruption');
    }
    return result;
  }

  @override
  Future<TransferPairDtos> createTransferPair({
    required TransactionDto outgoing,
    required TransactionDto incoming,
    required String payloadFingerprint,
  }) {
    return _delegate.createTransferPair(
      outgoing: outgoing,
      incoming: incoming,
      payloadFingerprint: payloadFingerprint,
    );
  }

  @override
  Future<TransferGroupIntegrity> inspectTransferGroup(String transferGroupId) {
    return _delegate.inspectTransferGroup(transferGroupId);
  }

  @override
  Future<List<StoredTransferRecord>> getStoredTransferGroup(
    String transferGroupId,
  ) {
    return _delegate.getStoredTransferGroup(transferGroupId);
  }

  @override
  Future<ScopedAccountBalanceSnapshot?> getAccountBalanceSnapshot(String id) {
    return _delegate.getAccountBalanceSnapshot(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingSyncQueue implements SyncMutationQueue {
  final List<(SyncEntityType, String)> upserts = <(SyncEntityType, String)>[];
  final List<(SyncEntityType, String)> deletes = <(SyncEntityType, String)>[];

  @override
  Future<void> enqueueDelete(SyncEntityType entityType, String entityId) async {
    deletes.add((entityType, entityId));
  }

  @override
  Future<void> enqueueUpsert(
    SyncEntityType entityType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    upserts.add((entityType, entityId));
  }
}

extension _ResultAssertions<T> on AppResult<T> {
  T expectSuccess() => switch (this) {
    AppSuccess<T>(:final data) => data,
    AppFailure<T>(:final failure) => throw TestFailure(
      'Expected success, got ${failure.code}: ${failure.message}',
    ),
  };

  String? expectFailureCode() => switch (this) {
    AppFailure<T>(:final failure) => failure.code,
    AppSuccess<T>() => throw TestFailure('Expected failure, got success.'),
  };
}
