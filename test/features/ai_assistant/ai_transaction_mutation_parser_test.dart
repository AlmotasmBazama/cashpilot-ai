import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_intent.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_transaction_mutation_parser.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/transaction_target_resolver.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/categories/domain/enums/category_type.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_color.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_icon.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/payment_methods/payment_methods.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_source.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final accounts = <Account>[
    _account('cash', 'الكاش'),
    _account('bank', 'البنك', type: AccountType.bank),
    _account('main', 'Main Bank', type: AccountType.bank),
  ];
  final categories = <Category>[
    _category('restaurants', 'مطاعم'),
    _category('groceries', 'مواد غذائية'),
  ];
  const parser = AiTransactionMutationParser();
  final now = DateTime.utc(2026, 8, 19, 10);

  group('deterministic transaction mutation parser', () {
    final intentCases = <(String, AiIntent)>[
      ('عدل آخر عملية وخليها 50 بدل 30', AiIntent.updateTransaction),
      ('بدل مصروف القهوة اليوم إلى 25', AiIntent.updateTransaction),
      ('غير تصنيف آخر مصروف إلى مواد غذائية', AiIntent.updateTransaction),
      ('غير حساب عملية البارح من الكاش للبنك', AiIntent.updateTransaction),
      ('خلي آخر عملية معلقة منشورة', AiIntent.updateTransaction),
      ('رجع آخر عملية منشورة لمعلقة', AiIntent.updateTransaction),
      ('احذف آخر عملية', AiIntent.deleteTransaction),
      ('احذف مصروف القهوة اليوم', AiIntent.deleteTransaction),
      ('الغي العملية المعلقة الأخيرة', AiIntent.deleteTransaction),
      ('الغي آخر تحويل', AiIntent.deleteTransaction),
      ('تراجع', AiIntent.undoAction),
      ('الغي آخر تعديل', AiIntent.undoAction),
      ('رجع العملية اللي حذفتها', AiIntent.undoAction),
      ('Edit my last expense to 50 LYD', AiIntent.updateTransaction),
      ('Delete today’s coffee expense', AiIntent.deleteTransaction),
      ('Undo the last transaction change', AiIntent.undoAction),
    ];

    for (final (input, intent) in intentCases) {
      test('routes "$input" to ${intent.name}', () {
        expect(
          parser
              .parse(
                input: input,
                accounts: accounts,
                categories: categories,
                payees: const [],
                nowUtc: now,
              )
              ?.intent,
          intent,
        );
      });
    }

    test(
      'normalizes Arabic-Indic and three-decimal LYD amount replacement',
      () {
        final parsed = parser.parse(
          input: 'عدل آخر عملية وخليها ٥٠٫١٢٥ بدل ٣٠',
          accounts: accounts,
          categories: categories,
          payees: const [],
          nowUtc: now,
        )!;

        expect(parsed.query.previousAmount, Decimal.parse('30'));
        expect(parsed.changes.amount, Decimal.parse('50.125'));
      },
    );

    test('extracts account and category changes without accepting IDs', () {
      final accountChange = parser.parse(
        input: 'غير حساب عملية البارح من الكاش للبنك',
        accounts: accounts,
        categories: categories,
        payees: const [],
        nowUtc: now,
      )!;
      final categoryChange = parser.parse(
        input: 'بدل تصنيف آخر مصروف من مطاعم إلى مواد غذائية',
        accounts: accounts,
        categories: categories,
        payees: const [],
        nowUtc: now,
      )!;

      expect(accountChange.query.accountId, 'cash');
      expect(accountChange.changes.accountId, 'bank');
      expect(accountChange.query.day, DateTime.utc(2026, 8, 17, 22));
      expect(categoryChange.query.categoryId, 'restaurants');
      expect(categoryChange.changes.categoryId, 'groceries');
    });

    test('extracts both legal status directions', () {
      final post = parser.parse(
        input: 'خلي آخر عملية معلقة منشورة',
        accounts: accounts,
        categories: categories,
        payees: const [],
        nowUtc: now,
      )!;
      final pend = parser.parse(
        input: 'رجع آخر عملية منشورة لمعلقة',
        accounts: accounts,
        categories: categories,
        payees: const [],
        nowUtc: now,
      )!;

      expect(post.query.status, TransactionStatus.pending);
      expect(post.changes.status, TransactionStatus.posted);
      expect(pend.query.status, TransactionStatus.posted);
      expect(pend.changes.status, TransactionStatus.pending);
    });

    test('marks the unsupported transfer-cancellation undo explicitly', () {
      final parsed = parser.parse(
        input: 'تراجع عن إلغاء التحويل',
        accounts: accounts,
        categories: categories,
        payees: const [],
        nowUtc: now,
      )!;

      expect(parsed.intent, AiIntent.undoAction);
      expect(parsed.undoTransferCancellationRequested, isTrue);
    });

    test('relative day honors an explicit IANA user timezone', () {
      final parsed = parser.parse(
        input: 'احذف مصروف القهوة اليوم',
        accounts: accounts,
        categories: categories,
        payees: const [],
        nowUtc: DateTime.utc(2026, 8, 19, 2),
        timeZoneName: 'America/New_York',
      )!;

      expect(parsed.query.day, DateTime.utc(2026, 8, 18, 4));
    });
  });

  group('transaction target resolver', () {
    const resolver = TransactionTargetResolver(maxChoices: 3);
    final newest = _transaction(
      'newest',
      note: 'قهوة',
      amount: '25',
      date: DateTime.utc(2026, 8, 19, 8),
    );
    final older = _transaction(
      'older',
      note: 'قهوة',
      amount: '20',
      date: DateTime.utc(2026, 8, 18, 8),
    );

    test('resolves exactly one matching owner-scoped candidate', () {
      final result = resolver.resolve(
        query: AiTransactionTargetQuery(
          previousAmount: Decimal.parse('25'),
          subjectHints: const <String>['قهوه'],
        ),
        ownerScopedCandidates: <Transaction>[older, newest],
        accounts: accounts,
        categories: categories,
        payees: const [],
        usesArabic: true,
      );

      expect(result, isA<TransactionTargetResolved>());
      expect(
        (result as TransactionTargetResolved).snapshot.transaction.id,
        'newest',
      );
    });

    test('matches Arabic coffee wording to an English transaction note', () {
      final englishCoffee = _transaction(
        'english-coffee',
        note: 'Coffee',
        amount: '30',
        date: DateTime.utc(2026, 8, 19, 8),
      );
      final result = resolver.resolve(
        query: AiTransactionTargetQuery(
          previousAmount: Decimal.parse('30'),
          subjectHints: const <String>['قهوه'],
        ),
        ownerScopedCandidates: <Transaction>[englishCoffee],
        accounts: accounts,
        categories: categories,
        payees: const [],
        usesArabic: true,
      );

      expect(result, isA<TransactionTargetResolved>());
      expect(
        (result as TransactionTargetResolved).snapshot.transaction.id,
        'english-coffee',
      );
    });

    test('matches Arabic transport wording to an English transaction note', () {
      final englishTransport = _transaction(
        'english-transport',
        note: 'Transport',
        amount: '20',
        date: DateTime.utc(2026, 8, 19, 8),
      );
      final result = resolver.resolve(
        query: const AiTransactionTargetQuery(
          subjectHints: <String>['مواصلات'],
        ),
        ownerScopedCandidates: <Transaction>[englishTransport],
        accounts: accounts,
        categories: categories,
        payees: const [],
        usesArabic: true,
      );

      expect(result, isA<TransactionTargetResolved>());
      expect(
        (result as TransactionTargetResolved).snapshot.transaction.id,
        'english-transport',
      );
    });

    test('returns no match without selecting another transaction', () {
      final result = resolver.resolve(
        query: AiTransactionTargetQuery(previousAmount: Decimal.parse('99')),
        ownerScopedCandidates: <Transaction>[older, newest],
        accounts: accounts,
        categories: categories,
        payees: const [],
        usesArabic: true,
      );

      expect(result, isA<TransactionTargetNotFound>());
    });

    test('returns bounded display-safe ambiguity choices', () {
      final candidates = List<Transaction>.generate(
        8,
        (index) => _transaction(
          'candidate-$index',
          note: 'قهوة',
          amount: '${20 + index}',
          date: DateTime.utc(2026, 8, 19, 8 - index),
        ),
      );
      final result =
          resolver.resolve(
                query: const AiTransactionTargetQuery(
                  subjectHints: <String>['قهوه'],
                ),
                ownerScopedCandidates: candidates,
                accounts: accounts,
                categories: categories,
                payees: const [],
                usesArabic: true,
              )
              as TransactionTargetAmbiguous;

      expect(result.choices, hasLength(3));
      expect(result.message, contains('أي وحدة تقصد؟'));
      expect(result.message, isNot(contains('candidate-')));
    });

    test('latest uses stable date, creation, then ID ordering', () {
      final sameDateA = _transaction(
        'a',
        note: 'قهوة',
        amount: '20',
        date: DateTime.utc(2026, 8, 19, 8),
        createdAt: DateTime.utc(2026, 8, 19, 9),
      );
      final sameDateB = _transaction(
        'b',
        note: 'قهوة',
        amount: '20',
        date: DateTime.utc(2026, 8, 19, 8),
        createdAt: DateTime.utc(2026, 8, 19, 9),
      );
      final result =
          resolver.resolve(
                query: const AiTransactionTargetQuery(latest: true),
                ownerScopedCandidates: <Transaction>[sameDateB, sameDateA],
                accounts: accounts,
                categories: categories,
                payees: const [],
                usesArabic: false,
              )
              as TransactionTargetResolved;

      expect(result.snapshot.transaction.id, 'a');
    });

    test('collapses a transfer pair into one logical target', () {
      final outgoing = _transaction(
        'out',
        note: 'تحويل',
        amount: '100',
        date: DateTime.utc(2026, 8, 19, 8),
        type: TransactionType.transferOut,
        transferGroupId: 'pair',
      );
      final incoming = _transaction(
        'in',
        note: 'تحويل',
        amount: '100',
        date: DateTime.utc(2026, 8, 19, 8),
        type: TransactionType.transferIn,
        transferGroupId: 'pair',
      );
      final result =
          resolver.resolve(
                query: const AiTransactionTargetQuery(transferRequested: true),
                ownerScopedCandidates: <Transaction>[incoming, outgoing],
                accounts: accounts,
                categories: categories,
                payees: const [],
                usesArabic: true,
              )
              as TransactionTargetResolved;

      expect(result.snapshot.transaction.id, 'out');
    });
  });
}

Account _account(
  String id,
  String name, {
  AccountType type = AccountType.cash,
}) {
  return Account.create(
    id: id,
    name: name,
    type: type,
    currencyCode: 'LYD',
    balance: Decimal.parse('1000'),
    icon: 'wallet',
    color: 0xff000000,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

Category _category(String id, String name) {
  return Category.create(
    id: id,
    name: name,
    type: CategoryType.expense,
    icon: const CategoryIcon(key: 'food'),
    color: const CategoryColor(argb: 0xff000000),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

Transaction _transaction(
  String id, {
  required String note,
  required String amount,
  required DateTime date,
  DateTime? createdAt,
  TransactionType type = TransactionType.expense,
  String? transferGroupId,
}) {
  return Transaction.create(
    id: id,
    accountId: 'cash',
    categoryId: 'restaurants',
    amount: Money(amount: Decimal.parse(amount), currencyCode: 'LYD'),
    type: type,
    paymentMethod: PaymentMethod.cash,
    source: TransactionSource.manual,
    status: TransactionStatus.posted,
    transferGroupId: transferGroupId,
    note: note,
    transactionDate: date,
    createdAt: createdAt ?? date,
    updatedAt: createdAt ?? date,
  );
}
