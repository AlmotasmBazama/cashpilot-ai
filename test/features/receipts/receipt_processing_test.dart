import 'dart:convert';
import 'dart:math';

import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/exchange_rate.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/receipts/data/dtos/receipt_analysis_transport.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_analysis_draft.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_line_item.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/transaction_split.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/duplicate_match_strength.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/image_retention_choice.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_document_type.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_draft_status.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_payment_status.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_warning.dart';
import 'package:cashpilot_ai/features/receipts/domain/failures/receipt_failure_codes.dart';
import 'package:cashpilot_ai/features/receipts/domain/repositories/receipt_repository.dart';
import 'package:cashpilot_ai/features/receipts/domain/services/receipt_arithmetic_validator.dart';
import 'package:cashpilot_ai/features/receipts/domain/services/receipt_duplicate_detector.dart';
import 'package:cashpilot_ai/features/receipts/domain/services/receipt_split_allocator.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/build_receipt_transaction_draft.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/confirm_receipt_transaction.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/resolve_receipt_categories.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/payment_method.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/get_transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('strict receipt transport', () {
    test('parses supported JSON and keeps all money as Decimal', () {
      final draft = ReceiptAnalysisTransport.parse(
        draftId: 'receipt-1',
        content: jsonEncode(_validPayload()),
      );

      expect(draft.documentType, ReceiptDocumentType.purchaseReceipt);
      expect(draft.total, Decimal.parse('12.34'));
      expect(draft.tax, Decimal.parse('0.34'));
      expect(draft.lineItems.single.totalPrice, Decimal.parse('12.00'));
      expect(draft.purchaseDate, DateTime.utc(2026, 7, 20));
    });

    for (final invalid in <Object>['1e3', '1,000', 'NaN', 12.34]) {
      test('rejects unsupported money representation $invalid', () {
        final payload = _validPayload()..['total'] = invalid;
        expect(
          () => ReceiptAnalysisTransport.parse(
            draftId: 'receipt-1',
            content: jsonEncode(payload),
          ),
          throwsA(
            isA<ReceiptException>().having(
              (error) => error.code,
              'code',
              ReceiptFailureCodes.unsupportedSchema,
            ),
          ),
        );
      });
    }

    test('rejects calendar dates that DateTime would normalize', () {
      final payload = _validPayload()..['purchaseDate'] = '2026-02-30';
      expect(
        () => ReceiptAnalysisTransport.parse(
          draftId: 'receipt-1',
          content: jsonEncode(payload),
        ),
        throwsA(isA<ReceiptException>()),
      );
    });

    test('adds payment clarification warning for an unclear invoice', () {
      final payload = _validPayload()
        ..['documentType'] = 'invoice'
        ..['paymentStatus'] = 'unclear';
      final draft = ReceiptAnalysisTransport.parse(
        draftId: 'invoice-1',
        content: jsonEncode(payload),
      );

      expect(draft.status, ReceiptDraftStatus.reviewRequired);
      expect(draft.warnings, contains(ReceiptWarning.paymentStatusUnclear));
    });

    test('accepts negative credit note values without changing them', () {
      final payload = _validPayload()
        ..['documentType'] = 'credit_note'
        ..['total'] = '-12.34'
        ..['lineItems'] = [
          {
            'description': 'Returned item',
            'totalPrice': '-12.34',
            'categoryHint': 'Shopping',
            'categoryConfidence': 0.9,
            'warnings': <String>[],
          },
        ];
      final draft = ReceiptAnalysisTransport.parse(
        draftId: 'credit-1',
        content: jsonEncode(payload),
      );

      expect(draft.total, Decimal.parse('-12.34'));
      expect(draft.lineItems.single.totalPrice, Decimal.parse('-12.34'));
    });

    test('preserves Arabic receipt text without inventing local choices', () {
      final payload = _validPayload()
        ..['merchantName'] = 'متجر تجريبي'
        ..['lineItems'] = [
          {
            'description': 'حليب',
            'totalPrice': '12.00',
            'categoryHint': null,
            'categoryConfidence': 0.0,
            'warnings': <String>[],
          },
        ];
      final draft = ReceiptAnalysisTransport.parse(
        draftId: 'arabic-1',
        content: jsonEncode(payload),
      );

      expect(draft.merchantName, 'متجر تجريبي');
      expect(draft.lineItems.single.description, 'حليب');
      expect(draft.lineItems.single.categoryId, isNull);
      expect(draft.merchantPayeeId, isNull);
    });
  });

  group('receipt arithmetic and category resolution', () {
    test('warns without silently rewriting extracted totals', () {
      final draft = _draft(
        total: '10.00',
        subtotal: '9.00',
        tax: '2.00',
        itemAmounts: const ['4.00', '5.00'],
      );
      final result = const ReceiptArithmeticValidator().validate(draft);

      expect(result.expectedTotal, Decimal.parse('11.00'));
      expect(result.draft.total, Decimal.parse('10.00'));
      expect(
        result.draft.warnings,
        contains(ReceiptWarning.arithmeticMismatch),
      );
    });

    test('routes mixed receipt items independently', () {
      final categories = buildDefaultCategories();
      final draft = ReceiptAnalysisDraft.create(
        documentType: ReceiptDocumentType.purchaseReceipt,
        paymentStatus: ReceiptPaymentStatus.paid,
        currency: 'USD',
        total: Decimal.parse('15'),
        lineItems: [
          _item(id: 'milk', description: 'Fresh milk', amount: '5'),
          _item(id: 'soap', description: 'Laundry detergent', amount: '5'),
          _item(id: 'shampoo', description: 'Shampoo', amount: '5'),
        ],
      );
      final resolved = const ResolveReceiptCategoriesUseCase()(
        draft: draft,
        categories: categories,
      );
      String categoryName(ReceiptLineItem item) => categories
          .firstWhere((category) => category.id == item.categoryId)
          .name;

      expect(categoryName(resolved.lineItems[0]), 'Groceries');
      expect(categoryName(resolved.lineItems[1]), 'Home');
      expect(categoryName(resolved.lineItems[2]), 'Beauty');
    });

    test('allocates fees proportionally with an exact final remainder', () {
      final draft = _draft(
        total: '10.01',
        itemAmounts: const ['5.00', '5.00'],
        categoryIds: const ['category-b', 'category-a'],
      );
      final splits = const ReceiptSplitAllocator().allocate(draft);

      expect(splits.map((split) => split.amount), [
        Decimal.parse('5.01'),
        Decimal.parse('5.00'),
      ]);
      expect(
        splits.fold<Decimal>(Decimal.zero, (sum, split) => sum + split.amount),
        Decimal.parse('10.01'),
      );
    });

    test(
      'tiny totals across many categories never create a negative split',
      () {
        final draft = _draft(
          total: '0.02',
          itemAmounts: const ['1', '1', '1', '1'],
          categoryIds: const [
            'category-d',
            'category-c',
            'category-b',
            'category-a',
          ],
        );

        final splits = const ReceiptSplitAllocator().allocate(draft);

        expect(splits.map((split) => split.categoryId), const [
          'category-a',
          'category-b',
          'category-c',
          'category-d',
        ]);
        expect(splits.map((split) => split.amount), <Decimal>[
          Decimal.parse('0.01'),
          Decimal.parse('0.01'),
          Decimal.zero,
          Decimal.zero,
        ]);
        expect(splits.every((split) => split.amount >= Decimal.zero), isTrue);
        expect(
          splits.fold<Decimal>(
            Decimal.zero,
            (sum, split) => sum + split.amount,
          ),
          Decimal.parse('0.02'),
        );
      },
    );

    for (final scaleCase in <(int, String)>[
      (0, '2'),
      (2, '0.02'),
      (3, '0.002'),
    ]) {
      test('largest-remainder allocation is exact and deterministic at scale '
          '${scaleCase.$1}', () {
        final draft = _draft(
          total: scaleCase.$2,
          itemAmounts: const ['7', '7', '7'],
          categoryIds: const ['category-c', 'category-a', 'category-b'],
        );
        final allocator = ReceiptSplitAllocator(currencyScale: scaleCase.$1);

        final first = allocator.allocate(draft);
        final second = allocator.allocate(draft);

        expect(
          first.map((split) => (split.categoryId, split.amount)),
          second.map((split) => (split.categoryId, split.amount)),
        );
        expect(first.every((split) => split.amount >= Decimal.zero), isTrue);
        expect(
          first.fold<Decimal>(Decimal.zero, (sum, split) => sum + split.amount),
          Decimal.parse(scaleCase.$2),
        );
      });
    }

    test(
      'largest-remainder invariants hold across bounded weight matrices',
      () {
        final random = Random(20260810);
        for (final scale in const [0, 2, 3]) {
          final factor = Decimal.fromInt(pow(10, scale).toInt());
          for (var sample = 0; sample < 30; sample++) {
            final categoryCount = 1 + random.nextInt(12);
            final totalMinorUnits = 1 + random.nextInt(10000);
            final weights = List<int>.generate(
              categoryCount,
              (_) => 1 + random.nextInt(1000),
            );
            final total = (Decimal.fromInt(totalMinorUnits) / factor)
                .toDecimal();
            final draft = _draft(
              total: total.toString(),
              itemAmounts: weights.map((weight) => '$weight').toList(),
              categoryIds: List<String?>.generate(
                categoryCount,
                (index) => 'category-${index.toString().padLeft(2, '0')}',
              ),
            );
            final allocator = ReceiptSplitAllocator(currencyScale: scale);

            final splits = allocator.allocate(draft);

            expect(
              splits.every((split) => split.amount >= Decimal.zero),
              isTrue,
            );
            expect(
              splits.fold<Decimal>(
                Decimal.zero,
                (sum, split) => sum + split.amount,
              ),
              total,
            );
            final totalWeight = Decimal.fromInt(
              weights.fold<int>(0, (sum, weight) => sum + weight),
            );
            for (var index = 0; index < splits.length; index++) {
              final splitMinorUnits = splits[index].amount * factor;
              expect(splitMinorUnits.isInteger, isTrue);
              final idealNumerator =
                  Decimal.fromInt(totalMinorUnits) *
                  Decimal.fromInt(weights[index]);
              final allocatedNumerator = splitMinorUnits * totalWeight;
              expect(
                (allocatedNumerator - idealNumerator).abs() <= totalWeight,
                isTrue,
                reason: 'scale=$scale sample=$sample category=$index',
              );
            }
          }
        }
      },
    );

    test('rejects a total that is not representable at the currency scale', () {
      final draft = _draft(
        total: '0.001',
        itemAmounts: const ['1'],
        categoryIds: const ['category-a'],
      );

      expect(
        () => const ReceiptSplitAllocator().allocate(draft),
        throwsA(
          isA<ReceiptException>().having(
            (error) => error.code,
            'code',
            ReceiptFailureCodes.invalidDraft,
          ),
        ),
      );
    });

    test(
      'TransactionSplit rejects negative construction at the entity edge',
      () {
        expect(
          () => TransactionSplit.create(
            categoryId: 'category-a',
            amount: Decimal.parse('-0.01'),
            sourceReceiptItemIds: const ['item-a'],
          ),
          throwsArgumentError,
        );
      },
    );

    test('requires a category and total for every item', () {
      final draft = _draft(
        total: '10',
        itemAmounts: const ['10'],
        categoryIds: const [null],
      );
      expect(
        () => const ReceiptSplitAllocator().allocate(draft),
        throwsA(isA<ReceiptException>()),
      );
    });
  });

  group('duplicate detection', () {
    const detector = ReceiptDuplicateDetector();

    test('image hash or receipt number creates a strong duplicate', () {
      final target = _draft(total: '10').copyWith(imageHash: 'same-hash');
      final candidate = _draft(
        id: 'candidate',
        total: '99',
      ).copyWith(imageHash: 'same-hash');
      final result = detector.detect(target: target, candidates: [candidate]);

      expect(result.strength, DuplicateMatchStrength.strongDuplicate);
      expect(result.candidateIds, ['candidate']);
    });

    test('merchant, day, total, and currency create possible duplicate', () {
      final target = _draft(
        total: '10',
        merchantName: 'Corner Shop',
        purchaseDate: DateTime.utc(2026, 7, 20, 8),
      );
      final candidate = _draft(
        id: 'candidate',
        total: '10',
        merchantName: 'corner shop',
        purchaseDate: DateTime.utc(2026, 7, 20, 18),
      );
      final result = detector.detect(target: target, candidates: [candidate]);

      expect(result.strength, DuplicateMatchStrength.possibleDuplicate);
    });
  });

  group('receipt transaction construction', () {
    final categories = buildDefaultCategories();
    final groceries = categories.firstWhere(
      (category) => category.name == 'Groceries',
    );
    final account = _account(currency: 'USD');
    const builder = BuildReceiptTransactionDraftUseCase();

    test('purchase receipt creates a posted expense draft', () {
      final result = builder(
        draft: _draft(
          total: '10',
          categoryIds: [groceries.id],
          itemAmounts: const ['10'],
        ),
        account: account,
        categories: categories,
        paymentMethod: PaymentMethod.cash,
        warningsAcknowledged: true,
      );

      expect(result.transaction.type, TransactionType.expense);
      expect(result.transaction.status, TransactionStatus.posted);
      expect(result.transaction.amount.amount, Decimal.parse('10'));
      expect(result.requiresConfirmation, isTrue);
    });

    test('unpaid invoice creates pending expense; unclear invoice blocks', () {
      final unpaid = builder(
        draft: _draft(
          total: '10',
          documentType: ReceiptDocumentType.invoice,
          paymentStatus: ReceiptPaymentStatus.unpaid,
          categoryIds: [groceries.id],
          itemAmounts: const ['10'],
        ),
        account: account,
        categories: categories,
        paymentMethod: PaymentMethod.bankTransfer,
        warningsAcknowledged: true,
      );
      expect(unpaid.transaction.status, TransactionStatus.pending);

      expect(
        () => builder(
          draft: _draft(
            total: '10',
            documentType: ReceiptDocumentType.invoice,
            paymentStatus: ReceiptPaymentStatus.unclear,
            categoryIds: [groceries.id],
            itemAmounts: const ['10'],
          ),
          account: account,
          categories: categories,
          paymentMethod: PaymentMethod.other,
          warningsAcknowledged: true,
        ),
        throwsA(isA<ReceiptException>()),
      );
    });

    test('negative credit note becomes positive refund income', () {
      final result = builder(
        draft: _draft(
          total: '-10',
          documentType: ReceiptDocumentType.creditNote,
          categoryIds: [groceries.id],
          itemAmounts: const ['-10'],
        ),
        account: account,
        categories: categories,
        paymentMethod: PaymentMethod.creditCard,
        warningsAcknowledged: true,
      );

      expect(result.transaction.type, TransactionType.income);
      expect(result.transaction.amount.amount, Decimal.parse('10'));
      expect(result.splits.single.amount, Decimal.parse('10'));
    });

    test('negative regular purchase is blocked instead of normalized', () {
      expect(
        () => builder(
          draft: _draft(
            total: '-10',
            categoryIds: [groceries.id],
            itemAmounts: const ['-10'],
          ),
          account: account,
          categories: categories,
          paymentMethod: PaymentMethod.cash,
          warningsAcknowledged: true,
        ),
        throwsA(isA<ReceiptException>()),
      );
    });

    test('cross-currency receipt requires explicit amount and rate', () {
      final lydAccount = _account(currency: 'LYD');
      final draft = _draft(
        total: '10',
        categoryIds: [groceries.id],
        itemAmounts: const ['10'],
      );
      expect(
        () => builder(
          draft: draft,
          account: lydAccount,
          categories: categories,
          paymentMethod: PaymentMethod.cash,
          warningsAcknowledged: true,
        ),
        throwsA(isA<ReceiptException>()),
      );

      final result = builder(
        draft: draft,
        account: lydAccount,
        categories: categories,
        paymentMethod: PaymentMethod.cash,
        warningsAcknowledged: true,
        explicitAccountAmount: Money(
          amount: Decimal.parse('48.5'),
          currencyCode: 'LYD',
        ),
        explicitExchangeRate: ExchangeRate(
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'LYD',
          rate: Decimal.parse('4.85'),
        ),
      );
      expect(result.transaction.amount.amount, Decimal.parse('48.5'));
      expect(result.transaction.exchangeRate?.rate, Decimal.parse('4.85'));
    });

    test(
      'cross-currency amount and rate must have exact direction and product',
      () {
        final lydAccount = _account(currency: 'LYD');
        final draft = _draft(
          total: '10',
          categoryIds: [groceries.id],
          itemAmounts: const ['10'],
        );
        final invalidPairs = <(Money, ExchangeRate)>[
          (
            Money(amount: Decimal.parse('48.5'), currencyCode: 'LYD'),
            ExchangeRate(
              fromCurrencyCode: 'LYD',
              toCurrencyCode: 'USD',
              rate: Decimal.parse('4.85'),
            ),
          ),
          (
            Money(amount: Decimal.parse('48.5'), currencyCode: 'LYD'),
            ExchangeRate(
              fromCurrencyCode: 'USD',
              toCurrencyCode: 'LYD',
              rate: Decimal.zero,
            ),
          ),
          (
            Money(amount: Decimal.parse('48.5'), currencyCode: 'LYD'),
            ExchangeRate(
              fromCurrencyCode: 'USD',
              toCurrencyCode: 'LYD',
              rate: Decimal.parse('-4.85'),
            ),
          ),
          (
            Money(amount: Decimal.parse('49'), currencyCode: 'LYD'),
            ExchangeRate(
              fromCurrencyCode: 'USD',
              toCurrencyCode: 'LYD',
              rate: Decimal.parse('4.85'),
            ),
          ),
        ];

        for (final invalidPair in invalidPairs) {
          expect(
            () => builder(
              draft: draft,
              account: lydAccount,
              categories: categories,
              paymentMethod: PaymentMethod.cash,
              warningsAcknowledged: true,
              explicitAccountAmount: invalidPair.$1,
              explicitExchangeRate: invalidPair.$2,
            ),
            throwsA(
              isA<ReceiptException>().having(
                (error) => error.code,
                'code',
                ReceiptFailureCodes.currencyMismatch,
              ),
            ),
          );
        }
      },
    );

    test('high-precision receipt FX remains exact Decimal arithmetic', () {
      final result = builder(
        draft: _draft(
          total: '10.00',
          categoryIds: [groceries.id],
          itemAmounts: const ['10.00'],
        ),
        account: _account(currency: 'LYD'),
        categories: categories,
        paymentMethod: PaymentMethod.cash,
        warningsAcknowledged: true,
        explicitAccountAmount: Money(
          amount: Decimal.parse('48.500000001'),
          currencyCode: 'LYD',
        ),
        explicitExchangeRate: ExchangeRate(
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'LYD',
          rate: Decimal.parse('4.8500000001'),
        ),
      );

      expect(result.transaction.amount.amount, Decimal.parse('48.500000001'));
    });

    test('possible duplicate requires separate acknowledgement', () {
      final draft = _draft(
        total: '10',
        categoryIds: [groceries.id],
        itemAmounts: const ['10'],
      ).copyWith(duplicateCandidateIds: const ['existing']);
      expect(
        () => builder(
          draft: draft,
          account: account,
          categories: categories,
          paymentMethod: PaymentMethod.cash,
          warningsAcknowledged: true,
        ),
        throwsA(isA<ReceiptException>()),
      );

      final acknowledged = builder(
        draft: draft,
        account: account,
        categories: categories,
        paymentMethod: PaymentMethod.cash,
        warningsAcknowledged: true,
        duplicateAcknowledged: true,
      );
      expect(acknowledged.requiresConfirmation, isTrue);
    });
  });

  test(
    'confirmation retries metadata safely without a second transaction',
    () async {
      final categories = buildDefaultCategories();
      final groceries = categories.firstWhere(
        (category) => category.name == 'Groceries',
      );
      final receipt = _draft(
        total: '10',
        categoryIds: [groceries.id],
        itemAmounts: const ['10'],
        retention: ImageRetentionChoice.keepLocally,
      );
      final transactionDraft = const BuildReceiptTransactionDraftUseCase()(
        draft: receipt,
        account: _account(currency: 'USD'),
        categories: categories,
        paymentMethod: PaymentMethod.cash,
        warningsAcknowledged: true,
      );
      final transactionRepository = _FakeTransactionsRepository();
      final receiptRepository = _FakeReceiptRepository(
        receipt,
        failFinalizeOnce: true,
      );
      final useCase = ConfirmReceiptTransactionUseCase(
        createTransaction: CreateTransaction(transactionRepository),
        getTransaction: GetTransaction(transactionRepository),
        receiptRepository: receiptRepository,
      );

      final first = await useCase(transactionDraft, confirmed: true);
      final second = await useCase(transactionDraft, confirmed: true);

      expect(
        (first as AppFailure).failure.code,
        ReceiptFailureCodes.metadataFinalizationPending,
      );
      expect((second as AppSuccess).data.metadataPersisted, isTrue);
      expect(transactionRepository.createCount, 1);
      expect(receiptRepository.finalizeCount, 2);
    },
  );

  test(
    'deletes a requested local image only after metadata finalizes',
    () async {
      final categories = buildDefaultCategories();
      final groceries = categories.firstWhere(
        (category) => category.name == 'Groceries',
      );
      final receipt = _draft(
        id: 'delete-receipt',
        total: '10',
        categoryIds: [groceries.id],
        itemAmounts: const ['10'],
        retention: ImageRetentionChoice.deleteAfterExtraction,
      );
      final transactionDraft = const BuildReceiptTransactionDraftUseCase()(
        draft: receipt,
        account: _account(currency: 'USD'),
        categories: categories,
        paymentMethod: PaymentMethod.cash,
        warningsAcknowledged: true,
      );
      final transactionRepository = _FakeTransactionsRepository();
      final receiptRepository = _FakeReceiptRepository(
        receipt,
        failFinalizeOnce: true,
      );
      final useCase = ConfirmReceiptTransactionUseCase(
        createTransaction: CreateTransaction(transactionRepository),
        getTransaction: GetTransaction(transactionRepository),
        receiptRepository: receiptRepository,
      );

      final first = await useCase(transactionDraft, confirmed: true);
      expect(
        (first as AppFailure).failure.code,
        ReceiptFailureCodes.metadataFinalizationPending,
      );
      expect(receiptRepository.deleteImageCount, 0);

      final second = await useCase(transactionDraft, confirmed: true);
      expect((second as AppSuccess).data.metadataPersisted, isTrue);
      expect(receiptRepository.deleteImageCount, 1);
    },
  );
}

Map<String, Object?> _validPayload() => <String, Object?>{
  'documentType': 'purchase_receipt',
  'paymentStatus': 'paid',
  'merchantName': 'Test Shop',
  'purchaseDate': '2026-07-20',
  'currency': 'USD',
  'subtotal': '12.00',
  'tax': '0.34',
  'discount': '0',
  'serviceCharge': '0',
  'tip': '0',
  'otherFees': '0',
  'total': '12.34',
  'confidence': 0.95,
  'warnings': <String>[],
  'lineItems': <Object?>[
    <String, Object?>{
      'description': 'Milk',
      'quantity': '1',
      'unitPrice': '12.00',
      'totalPrice': '12.00',
      'categoryHint': 'Groceries',
      'categoryConfidence': 0.9,
      'categoryAlternatives': <String>['Food'],
      'warnings': <String>[],
    },
  ],
};

ReceiptAnalysisDraft _draft({
  String id = 'receipt-1',
  String total = '10',
  String? subtotal,
  String? tax,
  List<String> itemAmounts = const ['10'],
  List<String?> categoryIds = const ['category-1'],
  ReceiptDocumentType documentType = ReceiptDocumentType.purchaseReceipt,
  ReceiptPaymentStatus paymentStatus = ReceiptPaymentStatus.paid,
  String? merchantName,
  DateTime? purchaseDate,
  ImageRetentionChoice retention = ImageRetentionChoice.keepLocally,
}) {
  return ReceiptAnalysisDraft.create(
    id: id,
    documentType: documentType,
    paymentStatus: paymentStatus,
    merchantName: merchantName,
    purchaseDate: purchaseDate ?? DateTime.utc(2026, 7, 20),
    currency: 'USD',
    subtotal: subtotal == null ? null : Decimal.parse(subtotal),
    tax: tax == null ? null : Decimal.parse(tax),
    total: Decimal.parse(total),
    imageRetentionChoice: retention,
    lineItems: List.generate(
      itemAmounts.length,
      (index) => _item(
        id: 'item-$index',
        description: 'Item $index',
        amount: itemAmounts[index],
        categoryId: index < categoryIds.length ? categoryIds[index] : null,
      ),
    ),
  );
}

ReceiptLineItem _item({
  required String id,
  required String description,
  required String amount,
  String? categoryId,
}) {
  return ReceiptLineItem.create(
    id: id,
    receiptId: 'receipt-1',
    description: description,
    normalizedDescription: description.toLowerCase(),
    totalPrice: Decimal.parse(amount),
    categoryId: categoryId,
  );
}

Account _account({required String currency}) {
  return Account.create(
    id: 'account-$currency',
    name: 'Cash $currency',
    type: AccountType.cash,
    currencyCode: currency,
    balance: Decimal.parse('100'),
    icon: 'wallet',
    color: 0xff000000,
  );
}

class _FakeTransactionsRepository implements TransactionsRepository {
  final Map<String, Transaction> transactions = <String, Transaction>{};
  int createCount = 0;

  @override
  Future<AppResult<Transaction>> createTransaction(
    Transaction transaction,
  ) async {
    createCount += 1;
    transactions[transaction.id] = transaction;
    return AppResult.success(transaction);
  }

  @override
  Future<AppResult<Transaction?>> getTransaction(String id) async {
    return AppResult.success(transactions[id]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReceiptRepository implements ReceiptRepository {
  _FakeReceiptRepository(this.draft, {required this.failFinalizeOnce});

  ReceiptAnalysisDraft draft;
  bool failFinalizeOnce;
  int finalizeCount = 0;
  int deleteImageCount = 0;

  @override
  Future<AppResult<ReceiptAnalysisDraft>> reserveTransactionId(
    String receiptId,
    String transactionId,
  ) async {
    draft = draft.copyWith(
      linkedTransactionId: draft.linkedTransactionId ?? transactionId,
    );
    return AppResult.success(draft);
  }

  @override
  Future<AppResult<ReceiptAnalysisDraft>> finalizeReceiptTransaction({
    required String receiptId,
    required String transactionId,
    required List<TransactionSplit> splits,
  }) async {
    finalizeCount += 1;
    if (failFinalizeOnce) {
      failFinalizeOnce = false;
      return const AppResult.failure(
        Failure(
          message: 'Metadata unavailable.',
          code: ReceiptFailureCodes.persistenceFailed,
        ),
      );
    }

    draft = draft.copyWith(
      linkedTransactionId: transactionId,
      splits: splits,
      status: ReceiptDraftStatus.confirmed,
    );
    return AppResult.success(draft);
  }

  @override
  Future<AppResult<void>> deleteLocalImage(String receiptId) async {
    deleteImageCount += 1;
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<ReceiptAnalysisDraft?>> getDraftById(String id) async {
    return AppResult.success(draft);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
