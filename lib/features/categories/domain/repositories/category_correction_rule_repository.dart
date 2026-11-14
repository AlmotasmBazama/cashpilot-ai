import '../../../../core/error/result.dart';
import '../entities/category_classification_rule.dart';

abstract interface class CategoryCorrectionRuleRepository {
  Future<AppResult<List<CategoryClassificationRule>>> getRules();

  Future<AppResult<CategoryClassificationRule>> rememberExplicitRule(
    CategoryClassificationRule rule,
  );
}
