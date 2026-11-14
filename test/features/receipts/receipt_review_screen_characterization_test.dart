import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/accounts/application/providers/accounts_providers.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/receipts/application/receipt_providers.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_analysis_draft.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_duplicate_result.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_line_item.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/transaction_split.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/duplicate_match_strength.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/image_retention_choice.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_document_type.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_payment_status.dart';
import 'package:cashpilot_ai/features/receipts/domain/repositories/receipt_repository.dart';
import 'package:cashpilot_ai/features/receipts/presentation/pages/receipt_review_screen.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'invalid review input stays local and performs no repository write',
    (tester) async {
      final repository = _TrackingReceiptRepository();
      final draft = _draft();
      await _pumpReview(tester, draft: draft, repository: repository);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReceiptReviewScreen)),
      );

      await tester.enterText(find.byType(TextFormField).at(2), 'US');
      await _scrollTo(tester, find.text(l10n.receiptSaveDraft));
      await tester.tap(find.text(l10n.receiptSaveDraft));
      await tester.pump();

      expect(find.text(l10n.receiptNoItems), findsWidgets);
      expect(repository.updateCount, 0);
    },
  );

  testWidgets('confirmation saves first, then requires a retention choice', (
    tester,
  ) async {
    final repository = _TrackingReceiptRepository();
    final draft = _draft();
    final account = _account();
    await _pumpReview(
      tester,
      draft: draft,
      repository: repository,
      accounts: <Account>[account],
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReceiptReviewScreen)),
    );

    await _scrollTo(tester, find.text(l10n.accountName));
    await tester.tap(find.text(l10n.accountName));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('${account.name} (${account.currencyCode})').last,
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text(l10n.receiptConfirmTransaction));
    await tester.tap(find.text(l10n.receiptConfirmTransaction));
    await tester.pump();

    expect(repository.updateCount, 1);
    expect(find.text(l10n.receiptSavedMessage), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text(l10n.receiptRetentionRequired), findsWidgets);
  });
}

Future<void> _pumpReview(
  WidgetTester tester, {
  required ReceiptAnalysisDraft draft,
  required _TrackingReceiptRepository repository,
  List<Account> accounts = const <Account>[],
  List<Category> categories = const <Category>[],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        receiptRepositoryProvider.overrideWithValue(repository),
        receiptDraftProvider(
          draft.id,
        ).overrideWith((_) => Stream.value(AppResult.success(draft))),
        accountsProvider.overrideWith((_) async => AppResult.success(accounts)),
        categoriesProvider.overrideWith(
          (_) async => AppResult.success(categories),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReceiptReviewScreen(receiptId: draft.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    360,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

ReceiptAnalysisDraft _draft() {
  return ReceiptAnalysisDraft.create(
    id: 'review-receipt',
    documentType: ReceiptDocumentType.purchaseReceipt,
    paymentStatus: ReceiptPaymentStatus.paid,
    merchantName: 'Corner shop',
    purchaseDate: DateTime.utc(2026, 8, 1),
    currency: 'USD',
    total: Decimal.parse('10'),
    imageRetentionChoice: ImageRetentionChoice.undecided,
  );
}

Account _account() {
  return Account.create(
    id: 'cash-account',
    name: 'Cash',
    type: AccountType.cash,
    currencyCode: 'USD',
    balance: Decimal.parse('100'),
    icon: 'wallet',
    color: 0xFF000000,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

final class _TrackingReceiptRepository implements ReceiptRepository {
  int updateCount = 0;

  @override
  Future<AppResult<ReceiptAnalysisDraft>> updateAnalysisDraft(
    ReceiptAnalysisDraft draft,
  ) async {
    updateCount += 1;
    return AppResult.success(draft);
  }

  @override
  Stream<AppResult<ReceiptAnalysisDraft?>> watchDraft(String id) =>
      const Stream<AppResult<ReceiptAnalysisDraft?>>.empty();

  @override
  Future<AppResult<ReceiptAnalysisDraft>> createAnalysisDraft(
    ReceiptAnalysisDraft draft,
  ) async => AppResult.success(draft);

  @override
  Future<AppResult<void>> deleteDraft(String id) async =>
      const AppResult.success(null);

  @override
  Future<AppResult<void>> deleteLocalImage(String receiptId) async =>
      const AppResult.success(null);

  @override
  Future<AppResult<ReceiptDuplicateResult>> findDuplicateCandidates(
    ReceiptAnalysisDraft draft,
  ) async => const AppResult.success(
    ReceiptDuplicateResult(
      strength: DuplicateMatchStrength.noMatch,
      candidateIds: <String>[],
    ),
  );

  @override
  Future<AppResult<ReceiptAnalysisDraft>> finalizeReceiptTransaction({
    required String receiptId,
    required String transactionId,
    required List<TransactionSplit> splits,
  }) async => throw UnimplementedError();

  @override
  Future<AppResult<ReceiptAnalysisDraft?>> getDraftById(String id) async =>
      const AppResult.success(null);

  @override
  Future<AppResult<ReceiptAnalysisDraft>> reserveTransactionId(
    String receiptId,
    String transactionId,
  ) async => throw UnimplementedError();

  @override
  Future<AppResult<void>> saveLineItems(
    String receiptId,
    List<ReceiptLineItem> items,
  ) async => const AppResult.success(null);

  @override
  Future<AppResult<void>> saveSplits(
    String receiptId,
    List<TransactionSplit> splits,
  ) async => const AppResult.success(null);

  @override
  Future<AppResult<String>> storeLocalImage(
    String receiptId,
    List<int> bytes,
  ) async => const AppResult.failure(Failure(message: 'unused'));
}
