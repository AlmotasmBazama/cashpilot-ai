/// Rejects provider-authored text that represents a financial mutation as
/// already completed. Provider prose is never execution evidence; only the
/// local durable execution result may render success.
final class AiProviderResponseSafetyPolicy {
  const AiProviderResponseSafetyPolicy();

  bool hasUnverifiedMutationClaim(String text) {
    if (text.trim().isEmpty) return false;
    final normalized = _withoutExplicitNonExecution(_normalize(text));
    return _claimPatterns.any((pattern) => pattern.hasMatch(normalized));
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('\u0640', '')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _withoutExplicitNonExecution(String value) {
    var result = value;
    for (final pattern in _explicitNonExecutionPatterns) {
      result = result.replaceAll(pattern, ' ');
    }
    return result;
  }
}

final _explicitNonExecutionPatterns = <RegExp>[
  RegExp(
    r'\b(?:no|never|did not|was not|were not|has not|have not|has not been|have not been)\b[^.!?\n]{0,100}\b(?:executed|saved|added|deleted|removed|updated|created|changed|transferred|paid|recorded|completed|done)\b',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:لم|لن|ما)\s+(?:يتم|تم|تتم)[^.!?\n]{0,80}(?:تنفيذ|حفظ|إضافة|اضافة|تحديث|إنشاء|انشاء|تحويل|تسجيل|دفع|حذف|إزالة|ازالة)',
    unicode: true,
  ),
];

final _claimPatterns = <RegExp>[
  RegExp(
    r'\b(?:i|we|cash\s*pilot)\s+(?:have\s+)?(?:successfully\s+)?(?:saved|added|deleted|removed|updated|created|changed|transferred|paid|recorded|completed)\b',
    caseSensitive: false,
  ),
  RegExp(
    r'\b(?:the|your|my|our)?\s*(?:expense|income|transaction|transfer|balance|budget|goal|contribution|payment)\s+(?:has\s+been|have\s+been|was|were|is|are)\s+(?:successfully\s+)?(?:saved|added|deleted|removed|updated|created|changed|transferred|paid|recorded|completed|done)\b',
    caseSensitive: false,
  ),
  RegExp(
    r'\b(?:successfully\s+)?(?:saved|added|deleted|removed|updated|created|changed|transferred|paid|recorded|completed)\s+(?:the|your|my|our)\s+(?:expense|income|transaction|transfer|balance|budget|goal|contribution|payment)\b',
    caseSensitive: false,
  ),
  RegExp(
    r"\b(?:all done|everything(?: is|'s)? done|that(?: is|'s) (?:done|taken care of)|taken care of)\b",
    caseSensitive: false,
  ),
  RegExp(
    r'(?:تم|تمت|قمت|قمنا|كاش\s*بايلوت)[^.!?\n]{0,40}(?:تنفيذ|حفظ|إضافة|اضافة|تحديث|إنشاء|انشاء|تحويل|تسجيل|دفع|حذف|إزالة|ازالة)',
    unicode: true,
  ),
  RegExp(
    r'(?:تم|تمت)[^.!?\n]{0,60}(?:المصروف|الدخل|المعاملة|التحويل|الرصيد|الميزانية|الهدف|المساهمة|الدفع)',
    unicode: true,
  ),
  RegExp(
    r'(?:خلاص\s*[،,]?\s*تم|درناها(?:\s+وخلاص)?|كملنا(?:ها)?(?:\s+وخلاص)?)',
    unicode: true,
  ),
];
