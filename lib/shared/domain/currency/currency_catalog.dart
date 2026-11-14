class CurrencyDefinition {
  const CurrencyDefinition({
    required this.code,
    required this.name,
    this.aliases = const [],
  });

  final String code;
  final String name;
  final List<String> aliases;

  bool matches(String value) {
    final normalized = CurrencyCatalog.normalizeToken(value);
    return normalized == code.toLowerCase() ||
        aliases.any(
          (alias) => CurrencyCatalog.normalizeToken(alias) == normalized,
        );
  }
}

abstract final class CurrencyCatalog {
  static const defaultCurrencyCode = 'LYD';

  static const supported = [
    CurrencyDefinition(
      code: 'LYD',
      name: 'Libyan Dinar',
      aliases: ['دينار', 'دنانير', 'د.ل', 'ل.د', 'lyd'],
    ),
    CurrencyDefinition(
      code: 'USD',
      name: 'US Dollar',
      aliases: ['دولار', 'دولارات', 'usd', 'dollar'],
    ),
    CurrencyDefinition(
      code: 'EUR',
      name: 'Euro',
      aliases: ['يورو', 'eur', 'euro'],
    ),
    CurrencyDefinition(
      code: 'GBP',
      name: 'British Pound',
      aliases: ['جنيه', 'استرليني', 'gbp', 'pound'],
    ),
    CurrencyDefinition(
      code: 'TRY',
      name: 'Turkish Lira',
      aliases: ['ليرة', 'ليره', 'تركي', 'try'],
    ),
    CurrencyDefinition(
      code: 'AED',
      name: 'UAE Dirham',
      aliases: ['درهم', 'aed'],
    ),
    CurrencyDefinition(
      code: 'SAR',
      name: 'Saudi Riyal',
      aliases: ['ريال', 'sar'],
    ),
  ];

  static List<String> get supportedCodes {
    return supported.map((currency) => currency.code).toList(growable: false);
  }

  static String normalizeCode(String? value) {
    final code = value?.trim().toUpperCase();
    if (code == null || code.isEmpty) {
      return defaultCurrencyCode;
    }

    return supported.any((currency) => currency.code == code)
        ? code
        : defaultCurrencyCode;
  }

  static CurrencyDefinition? findByCode(String? code) {
    final normalized = code?.trim().toUpperCase();
    if (normalized == null) {
      return null;
    }

    for (final currency in supported) {
      if (currency.code == normalized) {
        return currency;
      }
    }

    return null;
  }

  static String resolveCurrencyCode(
    String input, {
    String defaultCurrencyCode = CurrencyCatalog.defaultCurrencyCode,
  }) {
    final normalizedInput = normalizeText(input);
    for (final currency in supported) {
      final tokens = [currency.code, ...currency.aliases];
      for (final token in tokens) {
        if (normalizedInput.contains(normalizeToken(token))) {
          return currency.code;
        }
      }
    }

    return normalizeCode(defaultCurrencyCode);
  }

  static String normalizeText(String value) {
    return normalizeArabic(
      value,
    ).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String normalizeToken(String value) {
    return normalizeText(value).replaceAll(' ', '');
  }

  static String normalizeArabic(String value) {
    return value
        .replaceAll(RegExp('[\u064B-\u065F\u0670]'), '')
        .replaceAll('ـ', '')
        .replaceAll(RegExp('[إأآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
  }
}
