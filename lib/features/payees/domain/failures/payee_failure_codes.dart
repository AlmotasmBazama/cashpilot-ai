abstract final class PayeeFailureCodes {
  static const emptyName = 'payee_empty_name';
  static const duplicateName = 'payee_duplicate_name';
  static const duplicateAlias = 'payee_duplicate_alias';
  static const defaultCategoryNotFound = 'payee_default_category_not_found';
  static const defaultAccountNotFound = 'payee_default_account_not_found';
  static const notFound = 'payee_not_found';
}

class PayeeValidationException implements Exception {
  const PayeeValidationException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'PayeeValidationException: [$code] $message';
}
