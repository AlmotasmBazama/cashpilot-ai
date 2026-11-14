import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/catalog/category_taxonomy.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../payment_methods/domain/defaults/libyan_payment_method_catalog.dart';
import '../../../payment_methods/domain/entities/payment_method_definition.dart';

class AiActionContextBuilder {
  const AiActionContextBuilder();

  Map<String, Object?> build({
    required String locale,
    required List<Account> accounts,
    required List<Category> categories,
  }) {
    final accountAliases = accounts
        .map((account) => account.name.trim())
        .where(_isSafeAlias)
        .toSet()
        .toList(growable: false);
    final paymentMethodAliases = accounts
        .expand((account) => account.paymentMethodIds)
        .map(LibyanPaymentMethodCatalog.findById)
        .whereType<PaymentMethodDefinition>()
        .expand<String>(
          (method) => <String>[method.displayName, ...method.aliases],
        )
        .map((alias) => alias.trim())
        .where(_isSafeAlias)
        .toSet()
        .toList(growable: false);
    final categoryNames = categories
        .map((category) => category.name.trim())
        .where(_isSafeAlias)
        .toSet()
        .toList(growable: false);
    final categorySemantics = CategoryTaxonomy.safeSemanticDescriptions(
      categoryNames,
    );
    return Map<String, Object?>.unmodifiable(<String, Object?>{
      'locale': locale.trim(),
      'supportedCurrencies': List<String>.unmodifiable(
        CurrencyCatalog.supportedCodes,
      ),
      'accountAliases': List<String>.unmodifiable(accountAliases),
      'paymentMethodAliases': List<String>.unmodifiable(paymentMethodAliases),
      'categoryNames': List<String>.unmodifiable(categoryNames),
      'categorySemantics': List<String>.unmodifiable(categorySemantics),
    });
  }
}

bool _isSafeAlias(String value) {
  if (value.isEmpty ||
      _emailPattern.hasMatch(value) ||
      _firestorePathPattern.hasMatch(value) ||
      _tokenLikePattern.hasMatch(value)) {
    return false;
  }
  return _phoneDigitPattern.allMatches(value).length < 7;
}

final _emailPattern = RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]+');
final _phoneDigitPattern = RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]');
final _firestorePathPattern = RegExp(
  r'(?:^|\s)(?:users|projects)/|/documents/',
  caseSensitive: false,
);
final _tokenLikePattern = RegExp(
  r'(?:token|secret|bearer|auth)[\s_:=.-]+[A-Za-z0-9_-]{12,}'
  r'|AIza[0-9A-Za-z_-]{20,}|eyJ[A-Za-z0-9_-]{10,}\.',
  caseSensitive: false,
);
