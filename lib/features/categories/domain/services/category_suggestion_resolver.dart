import '../catalog/category_taxonomy.dart';
import '../entities/category.dart';
import '../entities/category_classification_rule.dart';
import '../entities/category_suggestion.dart';
import '../enums/category_type.dart';

class CategorySuggestionResolver {
  const CategorySuggestionResolver();

  CategorySuggestion resolve({
    required String input,
    required List<Category> categories,
    String? payeeDefaultCategoryId,
    String? aiCategoryHint,
    int? aiConfidence,
    List<String> aiAlternativeHints = const <String>[],
    List<CategoryClassificationRule> userRules =
        const <CategoryClassificationRule>[],
    CategoryType? categoryType,
  }) {
    final activeCategories = categories
        .where(
          (category) =>
              !category.isArchived &&
              (categoryType == null || category.type == categoryType),
        )
        .toList(growable: false);
    if (activeCategories.isEmpty) {
      return const CategorySuggestion.unresolved();
    }

    final normalizedInput = CategoryTaxonomy.normalize(input);
    final explicit = _explicitCategory(normalizedInput, activeCategories);
    if (explicit != null) {
      return _suggestion(
        explicit,
        source: CategorySuggestionSource.explicitUserInput,
        confidence: 100,
        matchedPhrase: explicit.name,
      );
    }

    final rule = _trustedRule(normalizedInput, userRules, activeCategories);
    if (rule != null) {
      final category = _categoryById(activeCategories, rule.categoryId)!;
      return _suggestion(
        category,
        source: CategorySuggestionSource.userRule,
        confidence: rule.isExplicit ? 100 : 95,
        matchedPhrase: rule.normalizedPhrase,
      );
    }

    final payeeCategory = _categoryById(
      activeCategories,
      payeeDefaultCategoryId,
    );
    if (payeeCategory != null) {
      return _suggestion(
        payeeCategory,
        source: CategorySuggestionSource.payeeDefault,
        confidence: 90,
      );
    }

    final exactAlias = _taxonomyMatch(
      normalizedInput,
      activeCategories,
      exact: true,
    );
    if (exactAlias != null) {
      return _suggestion(
        exactAlias.category,
        source: CategorySuggestionSource.exactAlias,
        confidence: 96,
        matchedPhrase: exactAlias.alias,
      );
    }

    final semanticCategory = _categoryForHint(aiCategoryHint, activeCategories);
    if (semanticCategory != null) {
      final confidence = (aiConfidence ?? 70).clamp(0, 100);
      final alternatives = _alternativeIds(
        aiAlternativeHints,
        activeCategories,
        excluding: semanticCategory.id,
      );
      if (confidence < 55) {
        return CategorySuggestion.unresolved(
          categoryHint: semanticCategory.name,
          alternativeCategoryIds: <String>[
            semanticCategory.id,
            ...alternatives,
          ],
        );
      }
      return _suggestion(
        semanticCategory,
        source: CategorySuggestionSource.aiSemantic,
        confidence: confidence,
        alternativeCategoryIds: alternatives,
      );
    }

    final keyword = _taxonomyMatch(
      normalizedInput,
      activeCategories,
      exact: false,
    );
    if (keyword != null) {
      return _suggestion(
        keyword.category,
        source: CategorySuggestionSource.localKeyword,
        confidence: 72,
        matchedPhrase: keyword.alias,
      );
    }

    return CategorySuggestion.unresolved(
      categoryHint: aiCategoryHint,
      alternativeCategoryIds: _alternativeIds(
        aiAlternativeHints,
        activeCategories,
      ),
    );
  }

  Category? _explicitCategory(String input, List<Category> categories) {
    for (final category in categories) {
      final name = CategoryTaxonomy.normalize(category.name);
      if (name.isEmpty) {
        continue;
      }
      final explicitPatterns = <String>[
        'category $name',
        'under $name',
        'as $name',
        'تصنيف $name',
        'فئه $name',
        'ضمن $name',
        'في $name',
        'حطه في $name',
        'سجله في $name',
      ];
      if (input == name ||
          explicitPatterns.any((pattern) => _containsPhrase(input, pattern))) {
        return category;
      }
    }
    return null;
  }

  CategoryClassificationRule? _trustedRule(
    String input,
    List<CategoryClassificationRule> rules,
    List<Category> categories,
  ) {
    final matches =
        rules
            .where(
              (rule) =>
                  rule.isTrusted &&
                  _categoryById(categories, rule.categoryId) != null &&
                  _containsPhrase(input, rule.normalizedPhrase),
            )
            .toList(growable: false)
          ..sort(
            (left, right) => right.normalizedPhrase.length.compareTo(
              left.normalizedPhrase.length,
            ),
          );
    return matches.firstOrNull;
  }

  _TaxonomyMatch? _taxonomyMatch(
    String input,
    List<Category> categories, {
    required bool exact,
  }) {
    final matches = <_TaxonomyMatch>[];
    for (final entry in CategoryTaxonomy.entries) {
      final category = _categoryByName(categories, entry.categoryName);
      if (category == null) {
        continue;
      }
      for (final rawAlias in entry.aliases) {
        final alias = CategoryTaxonomy.normalize(rawAlias);
        final matched = exact
            ? _containsPhrase(input, alias)
            : input.replaceAll(' ', '').contains(alias.replaceAll(' ', ''));
        if (matched) {
          matches.add(_TaxonomyMatch(category: category, alias: rawAlias));
        }
      }
    }
    if (matches.isEmpty) {
      return null;
    }
    matches.sort(
      (left, right) => right.alias.length.compareTo(left.alias.length),
    );
    return matches.first;
  }

  bool _containsPhrase(String input, String phrase) {
    final normalizedPhrase = CategoryTaxonomy.normalize(phrase);
    return ' $input '.contains(' $normalizedPhrase ');
  }

  Category? _categoryForHint(String? hint, List<Category> categories) {
    if (hint == null || hint.trim().isEmpty) {
      return null;
    }
    final direct = _categoryByName(categories, hint);
    if (direct != null) {
      return direct;
    }
    final taxonomy = CategoryTaxonomy.forHint(hint);
    return taxonomy == null
        ? null
        : _categoryByName(categories, taxonomy.categoryName);
  }

  List<String> _alternativeIds(
    List<String> hints,
    List<Category> categories, {
    String? excluding,
  }) {
    final ids = <String>{};
    for (final hint in hints) {
      final category = _categoryForHint(hint, categories);
      if (category != null && category.id != excluding) {
        ids.add(category.id);
      }
    }
    return ids.take(3).toList(growable: false);
  }

  Category? _categoryById(List<Category> categories, String? id) {
    if (id == null) {
      return null;
    }
    return categories.where((category) => category.id == id).firstOrNull;
  }

  Category? _categoryByName(List<Category> categories, String name) {
    final normalizedName = CategoryTaxonomy.normalize(name);
    return categories
        .where(
          (category) =>
              CategoryTaxonomy.normalize(category.name) == normalizedName,
        )
        .firstOrNull;
  }

  CategorySuggestion _suggestion(
    Category category, {
    required CategorySuggestionSource source,
    required int confidence,
    String? matchedPhrase,
    List<String> alternativeCategoryIds = const <String>[],
  }) {
    return CategorySuggestion(
      categoryId: category.id,
      categoryHint: category.name,
      confidence: confidence,
      source: source,
      matchedPhrase: matchedPhrase,
      alternativeCategoryIds: alternativeCategoryIds,
    );
  }
}

class _TaxonomyMatch {
  const _TaxonomyMatch({required this.category, required this.alias});

  final Category category;
  final String alias;
}
