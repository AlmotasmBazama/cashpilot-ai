enum CategorySuggestionSource {
  explicitUserInput,
  userRule,
  payeeDefault,
  exactAlias,
  aiSemantic,
  localKeyword,
  fallback,
}

enum CategoryConfidenceLevel { high, medium, low }

class CategorySuggestion {
  const CategorySuggestion({
    required this.categoryId,
    required this.categoryHint,
    required this.confidence,
    required this.source,
    this.alternativeCategoryIds = const <String>[],
    this.matchedPhrase,
    this.needsClarification = false,
  });

  const CategorySuggestion.unresolved({
    this.categoryHint,
    this.alternativeCategoryIds = const <String>[],
    this.matchedPhrase,
  }) : categoryId = null,
       confidence = 0,
       source = CategorySuggestionSource.fallback,
       needsClarification = true;

  final String? categoryId;
  final String? categoryHint;
  final int confidence;
  final CategorySuggestionSource source;
  final List<String> alternativeCategoryIds;
  final String? matchedPhrase;
  final bool needsClarification;

  CategoryConfidenceLevel get confidenceLevel {
    if (confidence >= 80 && !needsClarification) {
      return CategoryConfidenceLevel.high;
    }
    if (confidence >= 55 && !needsClarification) {
      return CategoryConfidenceLevel.medium;
    }
    return CategoryConfidenceLevel.low;
  }
}
