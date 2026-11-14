import 'package:cashpilot_ai/features/finance_engine/finance_engine.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BalanceCalculator', () {
    test('uses Decimal arithmetic for balance changes', () {
      const calculator = BalanceCalculator();
      final occurredAt = DateTime.utc(2026, 1, 1);
      final account = accountState(balance: '10.10');

      final credited = calculator.credit(
        account,
        money('0.20'),
        occurredAt: occurredAt,
      );
      final debited = calculator.debit(
        credited,
        money('0.30'),
        occurredAt: occurredAt,
      );

      expect(credited.balance, decimal('10.30'));
      expect(debited.balance, decimal('10.00'));
      expect(debited.updatedAt, occurredAt);
    });

    test('rejects currency mismatch', () {
      const calculator = BalanceCalculator();

      expect(
        () => calculator.add(money('1', 'USD'), money('1', 'EUR')),
        throwsA(isA<FinanceException>()),
      );
    });
  });

  group('FinanceValidationService', () {
    const validation = FinanceValidationService();

    test('rejects insufficient balance for regular accounts', () {
      final account = accountState(balance: '50');

      expect(
        () => validation.validateDebit(account, money('50.01')),
        throwsA(
          isA<FinanceException>().having(
            (error) => error.code,
            'code',
            FinanceFailureCodes.insufficientBalance,
          ),
        ),
      );
    });

    test('supports accounts that allow negative balances', () {
      final account = accountState(balance: '0', allowsNegativeBalance: true);

      expect(
        () => validation.validateDebit(account, money('1000')),
        returnsNormally,
      );
    });

    test('supports credit limits', () {
      final account = accountState(balance: '0', creditLimit: '500');

      expect(
        () => validation.validateDebit(account, money('499.99')),
        returnsNormally,
      );
      expect(
        () => validation.validateDebit(account, money('500.01')),
        throwsA(
          isA<FinanceException>().having(
            (error) => error.code,
            'code',
            FinanceFailureCodes.insufficientBalance,
          ),
        ),
      );
    });

    test('positive credit can repair a legacy balance below policy', () {
      final account = accountState(balance: '-100');

      expect(
        () => validation.validateCredit(account, money('25')),
        returnsNormally,
      );
      expect(
        () => validation.validateDebit(account, money('1')),
        throwsA(
          isA<FinanceException>().having(
            (error) => error.code,
            'code',
            FinanceFailureCodes.insufficientBalance,
          ),
        ),
      );
    });
  });

  group('TransactionProcessor', () {
    test('processes debits transactionally', () async {
      final transactionManager = RecordingFinanceTransactionManager();
      final repository = InMemoryAccountBalanceRepository(
        transactionManager: transactionManager,
        accounts: [accountState(accountId: 'cash', balance: '100')],
      );
      final processor = TransactionProcessor(
        accountBalanceRepository: repository,
        transactionManager: transactionManager,
        balanceCalculator: const BalanceCalculator(),
        validationService: const FinanceValidationService(),
      );

      final result = await processor.process(
        TransactionCommand(
          accountId: 'cash',
          amount: money('25.25'),
          direction: FinanceTransactionDirection.debit,
          occurredAt: DateTime.utc(2026, 1, 1),
        ),
      );

      expect(result.previousBalance.amount, decimal('100'));
      expect(result.newBalance.amount, decimal('74.75'));
      expect(repository.accounts['cash']?.balance, decimal('74.75'));
      expect(transactionManager.transactionCount, 1);
      expect(repository.savedInsideTransaction, isTrue);
    });
  });

  group('TransferProcessor', () {
    test('transfers across currencies using exchange-rate contract', () async {
      final transactionManager = RecordingFinanceTransactionManager();
      final repository = InMemoryAccountBalanceRepository(
        transactionManager: transactionManager,
        accounts: [
          accountState(accountId: 'usd', currencyCode: 'USD', balance: '100'),
          accountState(accountId: 'eur', currencyCode: 'EUR', balance: '0'),
        ],
      );
      final processor = TransferProcessor(
        accountBalanceRepository: repository,
        transactionManager: transactionManager,
        balanceCalculator: const BalanceCalculator(),
        validationService: const FinanceValidationService(),
        exchangeRateProvider: FixedExchangeRateProvider(
          rate: ExchangeRate(
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'EUR',
            rate: decimal('0.90'),
            asOf: DateTime.utc(2026, 1, 1),
          ),
        ),
      );

      final result = await processor.process(
        TransferCommand(
          sourceAccountId: 'usd',
          targetAccountId: 'eur',
          sourceAmount: money('10', 'USD'),
          occurredAt: DateTime.utc(2026, 1, 1),
        ),
      );

      expect(result.sourceNewBalance.amount, decimal('90'));
      expect(result.targetAmount.amount, decimal('9.00'));
      expect(result.targetAmount.currencyCode, 'EUR');
      expect(repository.accounts['usd']?.balance, decimal('90'));
      expect(repository.accounts['eur']?.balance, decimal('9.00'));
      expect(transactionManager.transactionCount, 1);
      expect(repository.saveCount, 2);
      expect(repository.savedInsideTransaction, isTrue);
    });

    test('OF-004 rejects inconsistent explicit cross-currency terms before '
        'process mutation', () async {
      final fixture = transferFixture();
      FinanceException? failure;

      try {
        await fixture.processor.process(
          TransferCommand(
            sourceAccountId: 'usd',
            targetAccountId: 'eur',
            sourceAmount: money('100', 'USD'),
            targetAmount: money('999', 'EUR'),
            exchangeRate: ExchangeRate(
              fromCurrencyCode: 'USD',
              toCurrencyCode: 'EUR',
              rate: decimal('2'),
            ),
            occurredAt: DateTime.utc(2026, 1, 1),
          ),
        );
      } on FinanceException catch (error) {
        failure = error;
      }

      expect(fixture.repository.accounts['usd']?.balance, decimal('100'));
      expect(fixture.repository.accounts['eur']?.balance, Decimal.zero);
      expect(fixture.repository.saveCount, 0);
      expect(failure?.code, FinanceFailureCodes.inconsistentTransferAmount);
    });

    test(
      'OF-004 preview and reverse reject inconsistent explicit terms without '
      'mutation',
      () async {
        final fixture = transferFixture(
          sourceBalance: '100',
          targetBalance: '999',
        );
        final inconsistent = TransferCommand(
          sourceAccountId: 'usd',
          targetAccountId: 'eur',
          sourceAmount: money('100', 'USD'),
          targetAmount: money('999', 'EUR'),
          exchangeRate: ExchangeRate(
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'EUR',
            rate: decimal('2'),
          ),
          occurredAt: DateTime.utc(2026, 1, 1),
        );

        await expectLater(
          fixture.processor.preview(inconsistent),
          throwsA(
            isA<FinanceException>().having(
              (error) => error.code,
              'code',
              FinanceFailureCodes.inconsistentTransferAmount,
            ),
          ),
        );
        await expectLater(
          fixture.processor.reverse(inconsistent),
          throwsA(
            isA<FinanceException>().having(
              (error) => error.code,
              'code',
              FinanceFailureCodes.inconsistentTransferAmount,
            ),
          ),
        );

        expect(fixture.repository.accounts['usd']?.balance, decimal('100'));
        expect(fixture.repository.accounts['eur']?.balance, decimal('999'));
        expect(fixture.repository.saveCount, 0);
      },
    );

    test('OF-004 uses exact Decimal products at high precision', () async {
      final fixture = transferFixture();
      final source = decimal('0.123456789012345678');
      final rate = decimal('1.234567890123456789');
      final exactTarget = source * rate;

      final prepared = await fixture.processor.preview(
        TransferCommand(
          sourceAccountId: 'usd',
          targetAccountId: 'eur',
          sourceAmount: Money(amount: source, currencyCode: 'USD'),
          targetAmount: Money(amount: exactTarget, currencyCode: 'EUR'),
          exchangeRate: ExchangeRate(
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'EUR',
            rate: rate,
          ),
        ),
      );

      expect(prepared.targetAmount.amount, exactTarget);
      expect(fixture.repository.saveCount, 0);
    });

    test('OF-004 rejects rounded approximation when no currency quantization '
        'policy is configured', () async {
      final fixture = transferFixture();

      await expectLater(
        fixture.processor.preview(
          TransferCommand(
            sourceAccountId: 'usd',
            targetAccountId: 'eur',
            sourceAmount: money('3', 'USD'),
            targetAmount: money('1', 'EUR'),
            exchangeRate: ExchangeRate(
              fromCurrencyCode: 'USD',
              toCurrencyCode: 'EUR',
              rate: decimal('0.333333333333'),
            ),
          ),
        ),
        throwsA(
          isA<FinanceException>().having(
            (error) => error.code,
            'code',
            FinanceFailureCodes.inconsistentTransferAmount,
          ),
        ),
      );
    });

    test('OF-004 rejects zero and negative explicit rates', () async {
      for (final invalidRate in <String>['0', '-0.01']) {
        final fixture = transferFixture();

        await expectLater(
          fixture.processor.process(
            TransferCommand(
              sourceAccountId: 'usd',
              targetAccountId: 'eur',
              sourceAmount: money('10', 'USD'),
              targetAmount: money('10', 'EUR'),
              exchangeRate: ExchangeRate(
                fromCurrencyCode: 'USD',
                toCurrencyCode: 'EUR',
                rate: decimal(invalidRate),
              ),
            ),
          ),
          throwsA(
            isA<FinanceException>().having(
              (error) => error.code,
              'code',
              FinanceFailureCodes.invalidExchangeRate,
            ),
          ),
        );
        expect(fixture.repository.accounts['usd']?.balance, decimal('100'));
        expect(fixture.repository.accounts['eur']?.balance, Decimal.zero);
        expect(fixture.repository.saveCount, 0);
      }
    });

    test('OF-004 target-only repeating ratio remains reversible from persisted '
        'terms', () async {
      final fixture = transferFixture();
      final command = TransferCommand(
        sourceAccountId: 'usd',
        targetAccountId: 'eur',
        sourceAmount: money('3', 'USD'),
        targetAmount: money('1', 'EUR'),
        occurredAt: DateTime.utc(2026, 1, 1),
      );

      final processed = await fixture.processor.process(command);
      expect(processed.exchangeRate.rate, decimal('0.333333333333'));
      await fixture.processor.reverse(command);

      expect(fixture.repository.accounts['usd']?.balance, decimal('100'));
      expect(fixture.repository.accounts['eur']?.balance, Decimal.zero);
      expect(fixture.repository.saveCount, 4);
    });

    test(
      'OF-004 rejects reversed exchange-rate direction before mutation',
      () async {
        final fixture = transferFixture();

        await expectLater(
          fixture.processor.process(
            TransferCommand(
              sourceAccountId: 'usd',
              targetAccountId: 'eur',
              sourceAmount: money('10', 'USD'),
              targetAmount: money('20', 'EUR'),
              exchangeRate: ExchangeRate(
                fromCurrencyCode: 'EUR',
                toCurrencyCode: 'USD',
                rate: decimal('2'),
              ),
            ),
          ),
          throwsA(
            isA<FinanceException>().having(
              (error) => error.code,
              'code',
              FinanceFailureCodes.currencyMismatch,
            ),
          ),
        );

        expect(fixture.repository.accounts['usd']?.balance, decimal('100'));
        expect(fixture.repository.accounts['eur']?.balance, Decimal.zero);
        expect(fixture.repository.saveCount, 0);
      },
    );
  });

  group('AccountBalanceService', () {
    test('applies credit limits transactionally', () async {
      final transactionManager = RecordingFinanceTransactionManager();
      final repository = InMemoryAccountBalanceRepository(
        transactionManager: transactionManager,
        accounts: [
          accountState(accountId: 'credit', balance: '0', creditLimit: '500'),
        ],
      );
      final service = AccountBalanceService(
        accountBalanceRepository: repository,
        transactionManager: transactionManager,
        balanceCalculator: const BalanceCalculator(),
        validationService: const FinanceValidationService(),
      );

      final updated = await service.debit('credit', money('450'));

      expect(updated.balance, decimal('-450'));
      expect(repository.savedInsideTransaction, isTrue);
      expect(
        () => service.debit('credit', money('51')),
        throwsA(
          isA<FinanceException>().having(
            (error) => error.code,
            'code',
            FinanceFailureCodes.insufficientBalance,
          ),
        ),
      );
      expect(transactionManager.transactionCount, 2);
    });
  });
}

Decimal decimal(String value) => Decimal.parse(value);

Money money(String amount, [String currencyCode = 'USD']) {
  return Money(amount: decimal(amount), currencyCode: currencyCode);
}

AccountBalanceState accountState({
  String accountId = 'account',
  String currencyCode = 'USD',
  String balance = '0',
  bool allowsNegativeBalance = false,
  String? creditLimit,
}) {
  return AccountBalanceState(
    accountId: accountId,
    currencyCode: currencyCode,
    balance: decimal(balance),
    allowsNegativeBalance: allowsNegativeBalance,
    creditLimit: creditLimit == null ? null : decimal(creditLimit),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

class InMemoryAccountBalanceRepository implements AccountBalanceRepository {
  InMemoryAccountBalanceRepository({
    required RecordingFinanceTransactionManager transactionManager,
    required List<AccountBalanceState> accounts,
  }) : _transactionManager = transactionManager,
       accounts = {for (final account in accounts) account.accountId: account};

  final RecordingFinanceTransactionManager _transactionManager;
  final Map<String, AccountBalanceState> accounts;
  bool savedInsideTransaction = false;
  int saveCount = 0;

  @override
  Future<AccountBalanceState?> getById(String accountId) async {
    return accounts[accountId];
  }

  @override
  Future<void> save(AccountBalanceState account) async {
    savedInsideTransaction =
        savedInsideTransaction || _transactionManager.isActive;
    saveCount += 1;
    accounts[account.accountId] = account;
  }
}

class RecordingFinanceTransactionManager implements FinanceTransactionManager {
  int transactionCount = 0;
  bool isActive = false;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() operation) async {
    transactionCount += 1;
    isActive = true;

    try {
      return await operation();
    } finally {
      isActive = false;
    }
  }
}

class FixedExchangeRateProvider implements ExchangeRateProvider {
  const FixedExchangeRateProvider({required this.rate});

  final ExchangeRate rate;

  @override
  Future<ExchangeRate> getExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    DateTime? at,
  }) async {
    return rate;
  }
}

TransferFixture transferFixture({
  String sourceBalance = '100',
  String targetBalance = '0',
}) {
  final transactionManager = RecordingFinanceTransactionManager();
  final repository = InMemoryAccountBalanceRepository(
    transactionManager: transactionManager,
    accounts: [
      accountState(
        accountId: 'usd',
        currencyCode: 'USD',
        balance: sourceBalance,
      ),
      accountState(
        accountId: 'eur',
        currencyCode: 'EUR',
        balance: targetBalance,
      ),
    ],
  );
  return TransferFixture(
    repository: repository,
    processor: TransferProcessor(
      accountBalanceRepository: repository,
      transactionManager: transactionManager,
      balanceCalculator: const BalanceCalculator(),
      validationService: const FinanceValidationService(),
      exchangeRateProvider: FixedExchangeRateProvider(
        rate: ExchangeRate(
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'EUR',
          rate: Decimal.one,
        ),
      ),
    ),
  );
}

class TransferFixture {
  const TransferFixture({required this.repository, required this.processor});

  final InMemoryAccountBalanceRepository repository;
  final TransferProcessor processor;
}
