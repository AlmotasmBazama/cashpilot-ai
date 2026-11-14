import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/receipts/data/repositories/receipt_repository_impl.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_local_image_store.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_analysis_draft.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_line_item.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;
  late Directory directory;
  late _FailOnceImageStore imageStore;
  late ReceiptRepositoryImpl repository;

  setUp(() async {
    database = AppDatabase(
      executor: NativeDatabase.memory(),
      enforceOwnerScopeGuards: false,
      enforceFinancialIntegrityGuards: false,
    );
    final session = scopedTestSession(database);
    directory = await Directory.systemTemp.createTemp(
      'cashpilot-receipt-aggregate-',
    );
    imageStore = _FailOnceImageStore(
      ownerScopeValue: session.ownerScopeValue,
      baseDirectory: () async => directory,
    );
    repository = ReceiptRepositoryImpl(
      session: session,
      imageStore: imageStore,
    );
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  group('OF-015 receipt aggregate persistence', () {
    test('duplicate line IDs roll back the parent and every child', () async {
      final draft = _draft(
        lineItems: [
          _line('line-duplicate', description: 'First'),
          _line('line-duplicate', description: 'Second'),
        ],
      );

      expect(
        await repository.createAnalysisDraft(draft),
        isA<AppFailure<ReceiptAnalysisDraft>>(),
      );
      await _expectCounts(database, receipts: 0, lines: 0, splits: 0);
    });

    test('duplicate split IDs roll back the parent and every child', () async {
      final draft = _draft(
        splits: [
          _split('split-duplicate', categoryId: 'category-a'),
          _split('split-duplicate', categoryId: 'category-b'),
        ],
      );

      expect(
        await repository.createAnalysisDraft(draft),
        isA<AppFailure<ReceiptAnalysisDraft>>(),
      );
      await _expectCounts(database, receipts: 0, lines: 0, splits: 0);
    });

    test(
      'duplicate parent insert leaves its existing aggregate intact',
      () async {
        final original = _draft();
        expect(
          await repository.createAnalysisDraft(original),
          isA<AppSuccess<ReceiptAnalysisDraft>>(),
        );

        final conflicting = _draft(
          merchantName: 'Replacement merchant',
          lineItems: [_line('line-new')],
          splits: [_split('split-new')],
        );
        expect(
          await repository.createAnalysisDraft(conflicting),
          isA<AppFailure<ReceiptAnalysisDraft>>(),
        );

        final stored = await _load(repository);
        expect(stored.merchantName, original.merchantName);
        expect(stored.lineItems.map((item) => item.id), ['line-original']);
        expect(stored.splits.map((split) => split.id), ['split-original']);
        await _expectCounts(database, receipts: 1, lines: 1, splits: 1);
      },
    );

    test('line replacement failure rolls back parent and children', () async {
      final original = _draft();
      expect(
        await repository.createAnalysisDraft(original),
        isA<AppSuccess<ReceiptAnalysisDraft>>(),
      );
      final invalid = original.copyWith(
        merchantName: 'Must roll back',
        lineItems: [
          _line('line-duplicate', description: 'First'),
          _line('line-duplicate', description: 'Second'),
        ],
        splits: [_split('split-new')],
      );

      expect(
        await repository.updateAnalysisDraft(invalid),
        isA<AppFailure<ReceiptAnalysisDraft>>(),
      );
      await _expectOriginalAggregate(repository);
    });

    test('split replacement failure rolls back parent and children', () async {
      final original = _draft();
      expect(
        await repository.createAnalysisDraft(original),
        isA<AppSuccess<ReceiptAnalysisDraft>>(),
      );
      final invalid = original.copyWith(
        merchantName: 'Must roll back',
        lineItems: [_line('line-new')],
        splits: [
          _split('split-duplicate', categoryId: 'category-a'),
          _split('split-duplicate', categoryId: 'category-b'),
        ],
      );

      expect(
        await repository.updateAnalysisDraft(invalid),
        isA<AppFailure<ReceiptAnalysisDraft>>(),
      );
      await _expectOriginalAggregate(repository);
    });

    test('successful update replaces the exact aggregate', () async {
      final original = _draft();
      expect(
        await repository.createAnalysisDraft(original),
        isA<AppSuccess<ReceiptAnalysisDraft>>(),
      );
      final replacement = original.copyWith(
        merchantName: 'Updated merchant',
        lineItems: [_line('line-new-a'), _line('line-new-b')],
        splits: [_split('split-new')],
      );

      expect(
        await repository.updateAnalysisDraft(replacement),
        isA<AppSuccess<ReceiptAnalysisDraft>>(),
      );

      final stored = await _load(repository);
      expect(stored.merchantName, 'Updated merchant');
      expect(stored.lineItems.map((item) => item.id), [
        'line-new-a',
        'line-new-b',
      ]);
      expect(stored.splits.map((split) => split.id), ['split-new']);
      await _expectCounts(database, receipts: 1, lines: 2, splits: 1);
    });
  });

  test(
    'OF-018 failed image deletion preserves a retryable aggregate',
    () async {
      final original = _draft();
      expect(
        await repository.createAnalysisDraft(original),
        isA<AppSuccess<ReceiptAnalysisDraft>>(),
      );
      final storedImage = await repository.storeLocalImage(
        original.id,
        const <int>[1, 2, 3, 4],
      );
      final reference = (storedImage as AppSuccess<String>).data;
      final withImage = original.copyWith(localImageReference: reference);
      expect(
        await repository.updateAnalysisDraft(withImage),
        isA<AppSuccess<ReceiptAnalysisDraft>>(),
      );
      imageStore.failNextDeletion = true;

      expect(
        await repository.deleteDraft(original.id),
        isA<AppFailure<void>>(),
      );
      expect(await File(reference).exists(), isTrue);
      final preserved = await _load(repository);
      expect(preserved.localImageReference, reference);
      await _expectCounts(database, receipts: 1, lines: 1, splits: 1);

      expect(
        await repository.deleteDraft(original.id),
        isA<AppSuccess<void>>(),
      );
      expect(await File(reference).exists(), isFalse);
      expect(
        (await repository.getDraftById(original.id)
                as AppSuccess<ReceiptAnalysisDraft?>)
            .data,
        isNull,
      );
      await _expectCounts(database, receipts: 0, lines: 0, splits: 0);
    },
  );
}

ReceiptAnalysisDraft _draft({
  String merchantName = 'Original merchant',
  List<ReceiptLineItem>? lineItems,
  List<TransactionSplit>? splits,
}) {
  return ReceiptAnalysisDraft.create(
    id: 'receipt-aggregate',
    merchantName: merchantName,
    currency: 'USD',
    total: Decimal.parse('12.34'),
    lineItems: lineItems ?? [_line('line-original')],
    splits: splits ?? [_split('split-original')],
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 1),
  );
}

ReceiptLineItem _line(String id, {String description = 'Item'}) {
  return ReceiptLineItem.create(
    id: id,
    receiptId: 'receipt-aggregate',
    description: description,
    normalizedDescription: description.toLowerCase(),
    totalPrice: Decimal.parse('12.34'),
  );
}

TransactionSplit _split(String id, {String categoryId = 'category-original'}) {
  return TransactionSplit.create(
    id: id,
    draftId: 'receipt-aggregate',
    categoryId: categoryId,
    amount: Decimal.parse('12.34'),
    sourceReceiptItemIds: const <String>[],
  );
}

Future<ReceiptAnalysisDraft> _load(ReceiptRepositoryImpl repository) async {
  final result = await repository.getDraftById('receipt-aggregate');
  expect(result, isA<AppSuccess<ReceiptAnalysisDraft?>>());
  final stored = (result as AppSuccess<ReceiptAnalysisDraft?>).data;
  expect(stored, isNotNull);
  return stored!;
}

Future<void> _expectOriginalAggregate(ReceiptRepositoryImpl repository) async {
  final stored = await _load(repository);
  expect(stored.merchantName, 'Original merchant');
  expect(stored.lineItems.map((item) => item.id), ['line-original']);
  expect(stored.splits.map((split) => split.id), ['split-original']);
}

Future<void> _expectCounts(
  AppDatabase database, {
  required int receipts,
  required int lines,
  required int splits,
}) async {
  Future<int> count(String table) async {
    final row = await database
        .customSelect('SELECT COUNT(*) AS value FROM $table')
        .getSingle();
    return row.read<int>('value');
  }

  expect(await count('receipts'), receipts);
  expect(await count('receipt_line_items'), lines);
  expect(await count('transaction_splits'), splits);
}

final class _FailOnceImageStore extends ReceiptLocalImageStore {
  _FailOnceImageStore({
    required super.ownerScopeValue,
    required super.baseDirectory,
  });

  bool failNextDeletion = false;

  @override
  Future<void> deleteReference(String? reference) async {
    if (failNextDeletion && reference != null) {
      failNextDeletion = false;
      throw const FileSystemException('Injected receipt image lock.');
    }
    await super.deleteReference(reference);
  }
}
