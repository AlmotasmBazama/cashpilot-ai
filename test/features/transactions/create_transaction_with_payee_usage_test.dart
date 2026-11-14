import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/payees/domain/entities/payee.dart';
import 'package:cashpilot_ai/features/payees/domain/repositories/payees_repository.dart';
import 'package:cashpilot_ai/features/payees/domain/usecases/touch_payee_last_used.dart';
import 'package:cashpilot_ai/features/transactions/application/services/create_transaction_with_payee_usage.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('touches payee only after transaction creation succeeds', () async {
    final repository = _RecordingTransactionsRepository();
    final touch = _RecordingTouchPayeeLastUsed();
    final service = CreateTransactionWithPayeeUsage(
      createTransaction: CreateTransaction(repository),
      touchPayeeLastUsed: touch,
    );
    final transaction = _transaction(payeeId: 'merchant');

    final result = await service(transaction);

    expect(result, isA<AppSuccess<Transaction>>());
    expect(repository.created?.payeeId, 'merchant');
    expect(touch.calls, 1);
    expect(touch.payeeId, 'merchant');
    expect(touch.usedAt, transaction.transactionDate);
  });

  test('does not touch payee when transaction creation fails', () async {
    final repository = _RecordingTransactionsRepository(fail: true);
    final touch = _RecordingTouchPayeeLastUsed();
    final service = CreateTransactionWithPayeeUsage(
      createTransaction: CreateTransaction(repository),
      touchPayeeLastUsed: touch,
    );

    final result = await service(_transaction(payeeId: 'merchant'));

    expect(result, isA<AppFailure<Transaction>>());
    expect(touch.calls, 0);
  });

  test(
    'payee metadata failure does not hide a committed transaction',
    () async {
      final repository = _RecordingTransactionsRepository();
      final touch = _RecordingTouchPayeeLastUsed(throwsError: true);
      final service = CreateTransactionWithPayeeUsage(
        createTransaction: CreateTransaction(repository),
        touchPayeeLastUsed: touch,
      );

      final result = await service(_transaction(payeeId: 'merchant'));

      expect(result, isA<AppSuccess<Transaction>>());
      expect(touch.calls, 1);
    },
  );
}

Transaction _transaction({String? payeeId}) {
  return Transaction.create(
    id: 'transaction',
    accountId: 'cash',
    categoryId: 'groceries',
    payeeId: payeeId,
    amount: Money(amount: Decimal.parse('12.5'), currencyCode: 'LYD'),
    type: TransactionType.expense,
    transactionDate: DateTime.utc(2026, 7, 14),
  );
}

class _RecordingTransactionsRepository implements TransactionsRepository {
  _RecordingTransactionsRepository({this.fail = false});

  final bool fail;
  Transaction? created;

  @override
  Future<AppResult<Transaction>> createTransaction(
    Transaction transaction,
  ) async {
    created = transaction;
    if (fail) {
      return const AppResult.failure(Failure(message: 'Create failed.'));
    }
    return AppResult.success(transaction);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingTouchPayeeLastUsed extends TouchPayeeLastUsed {
  _RecordingTouchPayeeLastUsed({this.throwsError = false})
    : super(_StubPayeesRepository());

  final bool throwsError;
  int calls = 0;
  String? payeeId;
  DateTime? usedAt;

  @override
  Future<AppResult<Payee>> call(String id, DateTime usedAt) async {
    calls += 1;
    payeeId = id;
    this.usedAt = usedAt;
    if (throwsError) {
      throw StateError('Touch failed.');
    }
    return AppResult.success(
      Payee.create(id: id, name: 'Merchant', lastUsedAt: usedAt),
    );
  }
}

class _StubPayeesRepository implements PayeesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
