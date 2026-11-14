import '../../../categories/domain/catalog/category_taxonomy.dart';
import '../entities/receipt_analysis_draft.dart';
import '../entities/receipt_duplicate_result.dart';
import '../enums/duplicate_match_strength.dart';

class ReceiptDuplicateDetector {
  const ReceiptDuplicateDetector();

  ReceiptDuplicateResult detect({
    required ReceiptAnalysisDraft target,
    required List<ReceiptAnalysisDraft> candidates,
  }) {
    final possible = <String>[];
    final strong = <String>[];
    for (final candidate in candidates) {
      if (candidate.id == target.id) {
        continue;
      }
      if (_strongMatch(target, candidate)) {
        strong.add(candidate.id);
      } else if (_possibleMatch(target, candidate)) {
        possible.add(candidate.id);
      }
    }
    if (strong.isNotEmpty) {
      return ReceiptDuplicateResult(
        strength: DuplicateMatchStrength.strongDuplicate,
        candidateIds: List.unmodifiable(strong),
      );
    }
    if (possible.isNotEmpty) {
      return ReceiptDuplicateResult(
        strength: DuplicateMatchStrength.possibleDuplicate,
        candidateIds: List.unmodifiable(possible),
      );
    }
    return const ReceiptDuplicateResult(
      strength: DuplicateMatchStrength.noMatch,
    );
  }

  bool _strongMatch(ReceiptAnalysisDraft left, ReceiptAnalysisDraft right) {
    final sameNumber =
        _sameNonEmpty(left.receiptNumber, right.receiptNumber) ||
        _sameNonEmpty(left.invoiceNumber, right.invoiceNumber);
    final sameHash = _sameNonEmpty(left.imageHash, right.imageHash);
    return sameHash ||
        sameNumber &&
            _sameMerchant(left, right) &&
            left.currency == right.currency;
  }

  bool _possibleMatch(ReceiptAnalysisDraft left, ReceiptAnalysisDraft right) {
    return _sameMerchant(left, right) &&
        _sameDay(left.purchaseDate, right.purchaseDate) &&
        left.currency == right.currency &&
        left.total != null &&
        left.total == right.total;
  }

  bool _sameMerchant(ReceiptAnalysisDraft left, ReceiptAnalysisDraft right) {
    final leftName = CategoryTaxonomy.normalize(left.merchantName ?? '');
    final rightName = CategoryTaxonomy.normalize(right.merchantName ?? '');
    return leftName.isNotEmpty && leftName == rightName;
  }

  bool _sameNonEmpty(String? left, String? right) {
    final normalizedLeft = left?.trim().toLowerCase();
    final normalizedRight = right?.trim().toLowerCase();
    return normalizedLeft?.isNotEmpty == true &&
        normalizedLeft == normalizedRight;
  }

  bool _sameDay(DateTime? left, DateTime? right) {
    if (left == null || right == null) {
      return false;
    }
    final a = left.toUtc();
    final b = right.toUtc();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
