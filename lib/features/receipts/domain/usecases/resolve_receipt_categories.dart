import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/entities/category_classification_rule.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/domain/services/category_suggestion_resolver.dart';
import '../entities/receipt_analysis_draft.dart';

class ResolveReceiptCategoriesUseCase {
  const ResolveReceiptCategoriesUseCase({
    CategorySuggestionResolver resolver = const CategorySuggestionResolver(),
  }) : _resolver = resolver;

  final CategorySuggestionResolver _resolver;

  ReceiptAnalysisDraft call({
    required ReceiptAnalysisDraft draft,
    required List<Category> categories,
    List<CategoryClassificationRule> userRules =
        const <CategoryClassificationRule>[],
    String? merchantDefaultCategoryId,
  }) {
    final items = draft.lineItems
        .map((item) {
          final suggestion = _resolver.resolve(
            input: item.description,
            categories: categories,
            payeeDefaultCategoryId: merchantDefaultCategoryId,
            aiCategoryHint: item.categoryHint,
            aiConfidence: item.categoryConfidence,
            aiAlternativeHints: item.categoryAlternatives,
            userRules: userRules,
            categoryType: CategoryType.expense,
          );
          return item.copyWith(
            categoryId: suggestion.categoryId,
            categoryHint: suggestion.categoryHint,
            categoryConfidence: suggestion.confidence,
            categorySuggestionSource: suggestion.source,
            categoryAlternatives: suggestion.alternativeCategoryIds,
          );
        })
        .toList(growable: false);
    return draft.copyWith(lineItems: items);
  }
}
