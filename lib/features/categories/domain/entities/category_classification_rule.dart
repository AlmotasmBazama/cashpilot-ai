class CategoryClassificationRule {
  const CategoryClassificationRule({
    required this.normalizedPhrase,
    required this.categoryId,
    required this.confirmedCount,
    required this.lastUsedAt,
    this.isExplicit = false,
  });

  final String normalizedPhrase;
  final String categoryId;
  final int confirmedCount;
  final DateTime lastUsedAt;
  final bool isExplicit;

  bool get isTrusted => isExplicit || confirmedCount >= 2;
}
