abstract final class PayeeNameNormalizer {
  static String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[\u064B-\u065F\u0670]'), '')
        .replaceAll('\u0640', '')
        .replaceAll(RegExp('[\u0622\u0623\u0625\u0671]'), '\u0627')
        .replaceAll('\u0649', '\u064A')
        .replaceAll('\u0629', '\u0647')
        .replaceAll(RegExp('[\u060C\u061B\u061F]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String compact(String value) => normalize(value).replaceAll(' ', '');
}
