import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/exchange_rate.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/receipts/application/receipt_review_workflow.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_analysis_draft.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_transaction_draft.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/transaction_split.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/image_retention_choice.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_document_type.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_draft_status.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_payment_status.dart';
import 'package:cashpilot_ai/features/receipts/domain/failures/receipt_failure_codes.dart';
import 'package:cashpilot_ai/features/receipts/domain/repositories/receipt_repository.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/payment_method.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'invalid currency or zero total is rejected before persistence',
    () async {
      final repository = _TrackingReceiptRepository();
      final workflow = _workflow(repository: repository);

      for (final input in <ReceiptReviewDraftInput>[
        _input(currencyText: 'US'),
        _input(totalText: '0'),
      ]) {
        expect(workflow.prepareDraft(input), isA<ReceiptReviewDraftRejected>());
      }

      expect(repository.updateCount, 0);
    },
  );

  test(
    'save preparation preserves fields and repository result identity',
    () async {
      const failure = Failure(
        message: 'aggregate write rejected',
        code: ReceiptFailureCodes.persistenceFailed,
      );
      const repositoryResult = AppResult<ReceiptAnalysisDraft>.failure(failure);
      final repository = _TrackingReceiptRepository(result: repositoryResult);
      final workflow = _workflow(
        repository: repository,
        now: () => DateTime.utc(2026, 8, 17, 12, 30),
      );

      final preparation = workflow.prepareDraft(
        _input(
          merchantNameText: '  Edited merchant  ',
          purchaseDateText: '2026-08-16',
          currencyText: ' usd ',
          subtotalText: '9.25',
          taxText: '0.75',
          discountText: '0.25',
          tipText: '0.25',
          totalText: '10.00',
        ),
      );

      final ready = preparation as ReceiptReviewDraftReady;
      expect(ready.draft.merchantName, 'Edited merchant');
      expect(
        ready.draft.purchaseDate,
        DateTime.tryParse('2026-08-16')!.toUtc(),
      );
      expect(ready.draft.currency, 'USD');
      expect(ready.draft.subtotal, Decimal.parse('9.25'));
      expect(ready.draft.tax, Decimal.parse('0.75'));
      expect(ready.draft.discount, Decimal.parse('0.25'));
      expect(ready.draft.tip, Decimal.parse('0.25'));
      expect(ready.draft.total, Decimal.parse('10.00'));
      expect(ready.draft.status, ReceiptDraftStatus.readyForConfirmation);
      expect(ready.draft.createdAt, DateTime.utc(2026, 1, 1));

      final result = await workflow.saveDraft(ready);

      expect(identical(result, repositoryResult), isTrue);
      expect(repository.updateCount, 1);
      expect(identical(repository.lastUpdated, ready.draft), isTrue);
    },
  );

  test(
    'cross-currency confirmation keeps exact Decimal and rate provenance',
    () async {
      final repository = _TrackingReceiptRepository();
      Money? capturedAmount;
      ExchangeRate? capturedRate;
      bool? capturedWarningsAcknowledged;
      bool? capturedDuplicateAcknowledged;
      bool? capturedConfirmed;
      late ReceiptTransactionDraft built;
      const confirmationFailure = Failure(
        message: 'confirmation stayed pending',
        code: ReceiptFailureCodes.metadataFinalizationPending,
      );
      const confirmationResult = AppResult<ConfirmedReceiptTransaction>.failure(
        confirmationFailure,
      );
      final workflow = ReceiptReviewWorkflow(
        repository: repository,
        buildTransactionDraft:
            ({
              required draft,
              required account,
              required categories,
              required paymentMethod,
              required warningsAcknowledged,
              duplicateAcknowledged = false,
              explicitAccountAmount,
              explicitExchangeRate,
            }) {
              capturedAmount = explicitAccountAmount;
              capturedRate = explicitExchangeRate;
              capturedWarningsAcknowledged = warningsAcknowledged;
              capturedDuplicateAcknowledged = duplicateAcknowledged;
              return built = _transactionDraft(draft, account);
            },
        confirmTransaction: (draft, {required confirmed}) async {
          expect(identical(draft, built), isTrue);
          capturedConfirmed = confirmed;
          return confirmationResult;
        },
      );
      final saved = _draft(currency: 'USD');
      final account = _account(currency: 'LYD');

      final result = await workflow.confirm(
        ReceiptReviewConfirmationInput(
          saved: saved,
          account: account,
          categories: const <Category>[],
          paymentMethod: PaymentMethod.cash,
          warningsAcknowledged: true,
          accountAmountText: '-48.500000001',
          exchangeRateText: '4.8500000001',
        ),
      );

      expect(identical(result, confirmationResult), isTrue);
      expect(capturedAmount?.amount, Decimal.parse('48.500000001'));
      expect(capturedAmount?.currencyCode, 'LYD');
      expect(capturedRate?.fromCurrencyCode, 'USD');
      expect(capturedRate?.toCurrencyCode, 'LYD');
      expect(capturedRate?.rate, Decimal.parse('4.8500000001'));
      expect(capturedRate?.asOf, saved.purchaseDate);
      expect(capturedWarningsAcknowledged, isTrue);
      expect(capturedDuplicateAcknowledged, isTrue);
      expect(capturedConfirmed, isTrue);

      await workflow.confirm(
        ReceiptReviewConfirmationInput(
          saved: saved,
          account: _account(currency: 'USD'),
          categories: const <Category>[],
          paymentMethod: PaymentMethod.cash,
          warningsAcknowledged: false,
          accountAmountText: 'not-a-number',
          exchangeRateText: 'not-a-rate',
        ),
      );
      expect(capturedAmount, isNull);
      expect(capturedRate, isNull);
    },
  );

  test('receipt validation exception crosses the workflow unchanged', () {
    const exception = ReceiptException(
      code: ReceiptFailureCodes.currencyMismatch,
      safeMessage: 'The converted amount and exchange rate must match exactly.',
    );
    var confirmationCalls = 0;
    final workflow = ReceiptReviewWorkflow(
      repository: _TrackingReceiptRepository(),
      buildTransactionDraft:
          ({
            required draft,
            required account,
            required categories,
            required paymentMethod,
            required warningsAcknowledged,
            duplicateAcknowledged = false,
            explicitAccountAmount,
            explicitExchangeRate,
          }) => throw exception,
      confirmTransaction: (draft, {required confirmed}) async {
        confirmationCalls += 1;
        throw StateError('must not confirm');
      },
    );

    expect(
      () => workflow.confirm(
        ReceiptReviewConfirmationInput(
          saved: _draft(currency: 'USD'),
          account: _account(currency: 'LYD'),
          categories: const <Category>[],
          paymentMethod: PaymentMethod.cash,
          warningsAcknowledged: false,
          accountAmountText: '49',
          exchangeRateText: '4.85',
        ),
      ),
      throwsA(same(exception)),
    );
    expect(confirmationCalls, 0);
  });
}

ReceiptReviewWorkflow _workflow({
  required ReceiptRepository repository,
  DateTime Function() now = DateTime.now,
}) {
  return ReceiptReviewWorkflow(
    repository: repository,
    now: now,
    buildTransactionDraft:
        ({
          required draft,
          required account,
          required categories,
          required paymentMethod,
          required warningsAcknowledged,
          duplicateAcknowledged = false,
          explicitAccountAmount,
          explicitExchangeRate,
        }) => throw StateError('unused transaction builder'),
    confirmTransaction: (draft, {required confirmed}) =>
        throw StateError('unused transaction confirmer'),
  );
}

ReceiptReviewDraftInput _input({
  String merchantNameText = 'Merchant',
  String purchaseDateText = '2026-08-01',
  String currencyText = 'USD',
  String subtotalText = '',
  String taxText = '',
  String discountText = '',
  String tipText = '',
  String totalText = '10',
}) {
  return ReceiptReviewDraftInput(
    current: _draft(),
    merchantNameText: merchantNameText,
    purchaseDateText: purchaseDateText,
    currencyText: currencyText,
    subtotalText: subtotalText,
    taxText: taxText,
    discountText: discountText,
    tipText: tipText,
    totalText: totalText,
  );
}

ReceiptAnalysisDraft _draft({String currency = 'USD'}) {
  return ReceiptAnalysisDraft.create(
    id: 'receipt-review',
    documentType: ReceiptDocumentType.purchaseReceipt,
    paymentStatus: ReceiptPaymentStatus.paid,
    merchantName: 'Merchant',
    purchaseDate: DateTime.utc(2026, 8, 1),
    currency: currency,
    total: Decimal.parse('10'),
    imageRetentionChoice: ImageRetentionChoice.keepLocally,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

Account _account({required String currency}) {
  return Account.create(
    id: 'account-$currency',
    name: 'Account $currency',
    type: AccountType.cash,
    currencyCode: currency,
    balance: Decimal.parse('100'),
    icon: 'wallet',
    color: 0xFF000000,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

ReceiptTransactionDraft _transactionDraft(
  ReceiptAnalysisDraft receipt,
  Account account,
) {
  return ReceiptTransactionDraft(
    receipt: receipt,
    transaction: Transaction.create(
      id: 'receipt-transaction',
      accountId: account.id,
      categoryId: 'category',
      amount: Money(amount: Decimal.one, currencyCode: account.currencyCode),
      type: TransactionType.expense,
      transactionDate: DateTime.utc(2026, 8, 1),
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    ),
    splits: const <TransactionSplit>[],
    requiresConfirmation: true,
  );
}

final class _TrackingReceiptRepository implements ReceiptRepository {
  _TrackingReceiptRepository({AppResult<ReceiptAnalysisDraft>? result})
    : result =
          result ??
          AppResult.success(ReceiptAnalysisDraft.create(id: 'default-result'));

  final AppResult<ReceiptAnalysisDraft> result;
  int updateCount = 0;
  ReceiptAnalysisDraft? lastUpdated;

  @override
  Future<AppResult<ReceiptAnalysisDraft>> updateAnalysisDraft(
    ReceiptAnalysisDraft draft,
  ) async {
    updateCount += 1;
    lastUpdated = draft;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
