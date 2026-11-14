import '../entities/payee.dart';
import '../entities/payee_resolution.dart';
import 'payee_name_normalizer.dart';

class PayeeResolver {
  const PayeeResolver();

  PayeeResolution resolve(
    String query,
    List<Payee> payees, {
    bool includeArchived = false,
  }) {
    final normalized = PayeeNameNormalizer.normalize(query);
    final compact = PayeeNameNormalizer.compact(query);
    if (compact.isEmpty) {
      return PayeeNotFound(query: query);
    }

    final matches = payees
        .where((payee) {
          if (payee.isArchived && !includeArchived) {
            return false;
          }
          return _keys(payee).any(
            (key) => key == normalized || key.replaceAll(' ', '') == compact,
          );
        })
        .toList(growable: false);
    return _result(query, matches);
  }

  PayeeResolution resolveFromText(
    String text,
    List<Payee> payees, {
    bool includeArchived = false,
  }) {
    final normalizedText = PayeeNameNormalizer.normalize(text);
    final compactText = normalizedText.replaceAll(' ', '');
    if (compactText.isEmpty) {
      return PayeeNotFound(query: text);
    }

    final candidates = <_PayeeTextMatch>[];
    for (final payee in payees) {
      if (payee.isArchived && !includeArchived) {
        continue;
      }
      final match = _bestTextMatch(payee, normalizedText, compactText);
      if (match != null) {
        candidates.add(match);
      }
    }
    if (candidates.isEmpty) {
      return PayeeNotFound(query: text);
    }

    var strongest = candidates.first;
    for (final candidate in candidates.skip(1)) {
      if (candidate.isStrongerThan(strongest)) {
        strongest = candidate;
      }
    }
    final matches = candidates
        .where((candidate) => candidate.hasSameRankAs(strongest))
        .map((candidate) => candidate.payee)
        .toList(growable: false);
    return _result(text, matches);
  }

  _PayeeTextMatch? _bestTextMatch(
    Payee payee,
    String normalizedText,
    String compactText,
  ) {
    _PayeeTextMatch? best;
    for (final key in _keys(payee)) {
      final compactKey = key.replaceAll(' ', '');
      if (compactKey.length < 2) {
        continue;
      }
      final normalizedMatch = normalizedText.contains(key);
      final compactMatch = compactText.contains(compactKey);
      if (!normalizedMatch && !compactMatch) {
        continue;
      }

      final candidate = _PayeeTextMatch(
        payee: payee,
        isExact: normalizedText == key || compactText == compactKey,
        keyLength: compactKey.length,
        preservesSpacing: normalizedMatch,
      );
      if (best == null || candidate.isStrongerThan(best)) {
        best = candidate;
      }
    }
    return best;
  }

  PayeeResolution _result(String query, List<Payee> matches) {
    if (matches.isEmpty) {
      return PayeeNotFound(query: query);
    }
    if (matches.length > 1) {
      return PayeeAmbiguous(query: query, matches: List.unmodifiable(matches));
    }
    return PayeeResolved(payee: matches.single, matchedText: query);
  }

  Iterable<String> _keys(Payee payee) sync* {
    yield payee.normalizedName;
    for (final alias in payee.aliases) {
      yield PayeeNameNormalizer.normalize(alias);
    }
  }
}

class _PayeeTextMatch {
  const _PayeeTextMatch({
    required this.payee,
    required this.isExact,
    required this.keyLength,
    required this.preservesSpacing,
  });

  final Payee payee;
  final bool isExact;
  final int keyLength;
  final bool preservesSpacing;

  bool isStrongerThan(_PayeeTextMatch other) {
    if (isExact != other.isExact) {
      return isExact;
    }
    if (keyLength != other.keyLength) {
      return keyLength > other.keyLength;
    }
    return preservesSpacing && !other.preservesSpacing;
  }

  bool hasSameRankAs(_PayeeTextMatch other) {
    return isExact == other.isExact &&
        keyLength == other.keyLength &&
        preservesSpacing == other.preservesSpacing;
  }
}
