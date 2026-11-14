import 'package:decimal/decimal.dart';

import '../entities/receipt_analysis_draft.dart';
import '../entities/transaction_split.dart';
import '../enums/receipt_document_type.dart';
import '../failures/receipt_failure_codes.dart';

class ReceiptSplitAllocator {
  const ReceiptSplitAllocator({this.currencyScale = 2});

  final int currencyScale;

  List<TransactionSplit> allocate(ReceiptAnalysisDraft draft) {
    if (currencyScale < 0) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidDraft,
        safeMessage: 'Receipt currency scale must not be negative.',
      );
    }
    final extractedTotal = draft.total;
    if (extractedTotal == null || extractedTotal == Decimal.zero) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.missingTotal,
        safeMessage: 'A reviewed receipt total is required.',
      );
    }
    if (extractedTotal < Decimal.zero &&
        !draft.documentType.permitsNegativeValues) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidDraft,
        safeMessage: 'Negative receipt totals require a refund document.',
      );
    }
    final total = extractedTotal.abs();
    final grouped = <String, _SplitAccumulator>{};
    for (final item in draft.lineItems) {
      final categoryId = item.categoryId;
      final extractedAmount = item.totalPrice;
      if (categoryId == null || extractedAmount == null) {
        throw const ReceiptException(
          code: ReceiptFailureCodes.invalidDraft,
          safeMessage: 'Choose a category and total for every receipt item.',
        );
      }
      if (extractedAmount < Decimal.zero &&
          !draft.documentType.permitsNegativeValues) {
        throw const ReceiptException(
          code: ReceiptFailureCodes.invalidDraft,
          safeMessage: 'Negative line items require a refund document.',
        );
      }
      final amount = extractedAmount.abs();
      grouped.update(
        categoryId,
        (current) => current.add(amount, item.id),
        ifAbsent: () => _SplitAccumulator(amount, <String>[item.id]),
      );
    }
    if (grouped.isEmpty) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidDraft,
        safeMessage: 'Choose a category for each receipt item.',
      );
    }
    final itemTotal = grouped.values.fold<Decimal>(
      Decimal.zero,
      (sum, value) => sum + value.amount,
    );
    if (itemTotal <= Decimal.zero) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidDraft,
        safeMessage: 'Receipt item totals must be greater than zero.',
      );
    }

    final entries = grouped.entries.toList(growable: false)
      ..sort((left, right) => left.key.compareTo(right.key));
    final scaleFactor = Decimal.fromBigInt(BigInt.from(10).pow(currencyScale));
    final scaledTotal = total * scaleFactor;
    if (!scaledTotal.isInteger) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidDraft,
        safeMessage: 'Receipt total exceeds the supported currency precision.',
      );
    }
    final totalMinorUnits = scaledTotal.toBigInt();
    final allocations = entries
        .map((entry) {
          final numerator =
              Decimal.fromBigInt(totalMinorUnits) * entry.value.amount;
          final baseMinorUnits = numerator ~/ itemTotal;
          final remainder =
              numerator - Decimal.fromBigInt(baseMinorUnits) * itemTotal;
          return _MinorUnitAllocation(
            entry: entry,
            baseMinorUnits: baseMinorUnits,
            remainder: remainder,
          );
        })
        .toList(growable: false);
    final baseTotal = allocations.fold<BigInt>(
      BigInt.zero,
      (sum, allocation) => sum + allocation.baseMinorUnits,
    );
    final remainingMinorUnits = totalMinorUnits - baseTotal;
    if (remainingMinorUnits < BigInt.zero ||
        remainingMinorUnits > BigInt.from(allocations.length)) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidDraft,
        safeMessage: 'Receipt category allocation is invalid.',
      );
    }
    final ranked = allocations.toList(growable: false)
      ..sort((left, right) {
        final byRemainder = right.remainder.compareTo(left.remainder);
        return byRemainder != 0
            ? byRemainder
            : left.entry.key.compareTo(right.entry.key);
      });
    final receivesRemainder = ranked
        .take(remainingMinorUnits.toInt())
        .map((allocation) => allocation.entry.key)
        .toSet();
    final splits = <TransactionSplit>[];
    for (final allocation in allocations) {
      final entry = allocation.entry;
      final minorUnits =
          allocation.baseMinorUnits +
          (receivesRemainder.contains(entry.key) ? BigInt.one : BigInt.zero);
      final amount = (Decimal.fromBigInt(minorUnits) / scaleFactor).toDecimal();
      splits.add(
        TransactionSplit.create(
          draftId: draft.id,
          categoryId: entry.key,
          amount: amount,
          sourceReceiptItemIds: entry.value.itemIds,
        ),
      );
    }
    final splitTotal = splits.fold<Decimal>(
      Decimal.zero,
      (sum, split) => sum + split.amount,
    );
    if (splitTotal != total) {
      throw const ReceiptException(
        code: ReceiptFailureCodes.invalidDraft,
        safeMessage: 'Receipt category splits do not equal the total.',
      );
    }
    return splits;
  }
}

class _MinorUnitAllocation {
  const _MinorUnitAllocation({
    required this.entry,
    required this.baseMinorUnits,
    required this.remainder,
  });

  final MapEntry<String, _SplitAccumulator> entry;
  final BigInt baseMinorUnits;
  final Decimal remainder;
}

class _SplitAccumulator {
  const _SplitAccumulator(this.amount, this.itemIds);

  final Decimal amount;
  final List<String> itemIds;

  _SplitAccumulator add(Decimal value, String itemId) {
    return _SplitAccumulator(amount + value, <String>[...itemIds, itemId]);
  }
}
