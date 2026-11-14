import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/receipts/data/repositories/receipt_repository_impl.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_local_image_store.dart';
import 'package:cashpilot_ai/features/receipts/data/services/isolate_receipt_image_preparation_worker.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_analysis_draft.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_line_item.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/transaction_split.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/image_retention_choice.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_document_type.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_draft_status.dart';
import 'package:cashpilot_ai/features/receipts/domain/enums/receipt_payment_status.dart';
import 'package:cashpilot_ai/features/receipts/domain/failures/receipt_failure_codes.dart';
import 'package:cashpilot_ai/features/receipts/domain/services/receipt_image_capture_service.dart';
import 'package:cashpilot_ai/features/receipts/domain/usecases/prepare_receipt_image.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  test(
    'receipt repository round-trips decimals, items, splits, and links',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-receipt-test-',
      );
      addTearDown(() async {
        await database.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final session = scopedTestSession(database);
      final imageStore = ReceiptLocalImageStore(
        ownerScopeValue: session.ownerScopeValue,
        baseDirectory: () async => directory,
      );
      final repository = ReceiptRepositoryImpl(
        session: session,
        imageStore: imageStore,
      );
      final draft = _draft();

      expect(
        await repository.createAnalysisDraft(draft),
        isA<AppSuccess<ReceiptAnalysisDraft>>(),
      );
      final imageResult = await repository.storeLocalImage(
        draft.id,
        const <int>[1, 2, 3, 4],
      );
      final reference = (imageResult as AppSuccess<String>).data;
      final withImage = draft.copyWith(
        localImageReference: reference,
        imageHash: 'image-hash',
      );
      await repository.updateAnalysisDraft(withImage);

      final loadedResult = await repository.getDraftById(draft.id);
      final loaded = (loadedResult as AppSuccess<ReceiptAnalysisDraft?>).data!;
      expect(loaded.total, Decimal.parse('10.01'));
      expect(loaded.lineItems.single.totalPrice, Decimal.parse('10.01'));
      expect(loaded.localImageReference, reference);
      expect(await File(reference).exists(), isTrue);

      final reserved = await repository.reserveTransactionId(
        draft.id,
        'transaction-1',
      );
      expect(
        (reserved as AppSuccess<ReceiptAnalysisDraft>).data.linkedTransactionId,
        'transaction-1',
      );
      final transactionTimestamp = DateTime.utc(2026, 7, 20);
      await database
          .into(database.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 'transaction-1',
              ownerScopeId: Value(session.ownerScopeValue),
              accountId: 'account-1',
              categoryId: 'category-1',
              amount: '10.01',
              currencyCode: 'USD',
              type: 'expense',
              paymentMethod: 'cash',
              source: 'aiGenerated',
              status: 'posted',
              transactionDate: transactionTimestamp,
              createdAt: transactionTimestamp,
              updatedAt: transactionTimestamp,
            ),
          );
      final split = TransactionSplit.create(
        id: 'split-1',
        transactionId: 'transaction-1',
        draftId: draft.id,
        categoryId: 'category-1',
        amount: Decimal.parse('10.01'),
        sourceReceiptItemIds: const ['line-1'],
      );
      final finalized = await repository.finalizeReceiptTransaction(
        receiptId: draft.id,
        transactionId: 'transaction-1',
        splits: [split],
      );
      final confirmed = (finalized as AppSuccess<ReceiptAnalysisDraft>).data;
      expect(confirmed.status, ReceiptDraftStatus.confirmed);
      expect(confirmed.splits.single.amount, Decimal.parse('10.01'));

      await repository.deleteLocalImage(draft.id);
      expect(await File(reference).exists(), isFalse);
      final withoutImage =
          (await repository.getDraftById(draft.id)
                  as AppSuccess<ReceiptAnalysisDraft?>)
              .data!;
      expect(withoutImage.localImageReference, isNull);
    },
  );

  test(
    'image preparation resizes, re-encodes, hashes, and bounds output',
    () async {
      final source = image.Image(width: 2400, height: 1200);
      image.fill(source, color: image.ColorRgb8(248, 248, 248));
      final encoded = image.encodePng(source);

      final prepared = await const PrepareReceiptImageUseCase(
        worker: IsolateReceiptImagePreparationWorker(),
      )(CapturedReceiptImage(bytes: encoded, suggestedMimeType: 'image/png'));

      expect(prepared.mimeType, 'image/jpeg');
      expect(prepared.width, lessThanOrEqualTo(2048));
      expect(prepared.height, lessThanOrEqualTo(2048));
      expect(prepared.bytes.length, lessThan(8 * 1024 * 1024));
      expect(prepared.sha256, hasLength(64));
      expect(image.decodeJpg(prepared.bytes), isNotNull);
    },
  );

  test(
    'image preparation rejects an explicitly unsupported MIME type',
    () async {
      final source = image.Image(width: 800, height: 800);
      final encoded = image.encodePng(source);

      await expectLater(
        const PrepareReceiptImageUseCase(
          worker: IsolateReceiptImagePreparationWorker(),
        )(CapturedReceiptImage(bytes: encoded, suggestedMimeType: 'image/gif')),
        throwsA(
          isA<ReceiptException>().having(
            (error) => error.code,
            'code',
            ReceiptFailureCodes.unsupportedImage,
          ),
        ),
      );
    },
  );

  test(
    'image store refuses deletion outside its private receipt directory',
    () async {
      final base = await Directory.systemTemp.createTemp(
        'cashpilot-image-root-',
      );
      final outside = await Directory.systemTemp.createTemp(
        'cashpilot-image-outside-',
      );
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
        if (await outside.exists()) {
          await outside.delete(recursive: true);
        }
      });
      final outsideFile = File(
        '${outside.path}${Platform.pathSeparator}keep.jpg',
      );
      await outsideFile.writeAsBytes(const [1, 2, 3]);
      final store = ReceiptLocalImageStore(
        ownerScopeValue:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        baseDirectory: () async => base,
      );

      await store.deleteReference(outsideFile.path);

      expect(await outsideFile.exists(), isTrue);
    },
  );
}

ReceiptAnalysisDraft _draft() {
  return ReceiptAnalysisDraft.create(
    id: 'receipt-1',
    documentType: ReceiptDocumentType.purchaseReceipt,
    paymentStatus: ReceiptPaymentStatus.paid,
    merchantName: 'Test Shop',
    purchaseDate: DateTime.utc(2026, 7, 20),
    currency: 'USD',
    subtotal: Decimal.parse('10'),
    tax: Decimal.parse('0.01'),
    total: Decimal.parse('10.01'),
    imageRetentionChoice: ImageRetentionChoice.keepLocally,
    status: ReceiptDraftStatus.readyForConfirmation,
    lineItems: [
      ReceiptLineItem.create(
        id: 'line-1',
        receiptId: 'receipt-1',
        description: 'Milk',
        normalizedDescription: 'milk',
        totalPrice: Decimal.parse('10.01'),
        categoryId: 'category-1',
      ),
    ],
  );
}
