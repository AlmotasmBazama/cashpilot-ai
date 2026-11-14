const explicitNonExecutionPatterns = [
  /\b(?:no|never|did not|was not|were not|has not|have not|has not been|have not been)\b[^.!?\n]{0,100}\b(?:executed|saved|added|deleted|removed|updated|created|changed|transferred|paid|recorded|completed|done)\b/giu,
  /(?:لم|لن|ما)\s+(?:يتم|تم|تتم)[^.!?\n]{0,80}(?:تنفيذ|حفظ|إضافة|اضافة|تحديث|إنشاء|انشاء|تحويل|تسجيل|دفع|حذف|إزالة|ازالة)/gu,
] as const;

const unverifiedMutationClaimPatterns = [
  /\b(?:i|we|cash\s*pilot)\s+(?:have\s+)?(?:successfully\s+)?(?:saved|added|deleted|removed|updated|created|changed|transferred|paid|recorded|completed)\b/iu,
  /\b(?:the|your|my|our)?\s*(?:expense|income|transaction|transfer|balance|budget|goal|contribution|payment)\s+(?:has\s+been|have\s+been|was|were|is|are)\s+(?:successfully\s+)?(?:saved|added|deleted|removed|updated|created|changed|transferred|paid|recorded|completed|done)\b/iu,
  /\b(?:successfully\s+)?(?:saved|added|deleted|removed|updated|created|changed|transferred|paid|recorded|completed)\s+(?:the|your|my|our)\s+(?:expense|income|transaction|transfer|balance|budget|goal|contribution|payment)\b/iu,
  /\b(?:all done|everything(?: is|'s)? done|that(?: is|'s) (?:done|taken care of)|taken care of)\b/iu,
  /(?<![\p{L}\p{M}\p{N}_])(?:تم|تمت|قمت|قمنا|كاش\s*بايلوت)(?![\p{L}\p{M}\p{N}_])[^.!?\n]{0,40}(?:تنفيذ|حفظ|إضافة|اضافة|تحديث|إنشاء|انشاء|تحويل|تسجيل|دفع|حذف|إزالة|ازالة)/u,
  /(?<![\p{L}\p{M}\p{N}_])(?:تم|تمت)(?![\p{L}\p{M}\p{N}_])[^.!?\n]{0,60}(?:المصروف|الدخل|المعاملة|التحويل|الرصيد|الميزانية|الهدف|المساهمة|الدفع)/u,
  /(?:خلاص\s*[،,]?\s*تم|درناها(?:\s+وخلاص)?|كملنا(?:ها)?(?:\s+وخلاص)?)/u,
] as const;

function normalizeProviderText(value: string): string {
  return value
    .toLocaleLowerCase("en-US")
    .replaceAll("ـ", "")
    .replace(/[\u064B-\u065F\u0670]/gu, "")
    .replace(/\s+/gu, " ")
    .trim();
}

function removeExplicitNonExecutionClaims(value: string): string {
  return explicitNonExecutionPatterns.reduce(
    (result, pattern) => result.replace(pattern, " "),
    value,
  );
}

/**
 * Returns true when provider prose represents a financial mutation as already
 * complete. Only a verified local durable result is permitted to make such a
 * claim; model text is never execution evidence.
 */
export function hasUnverifiedMutationClaim(text: string): boolean {
  if (text.trim().length === 0) {
    return false;
  }
  const normalized = removeExplicitNonExecutionClaims(
    normalizeProviderText(text),
  );
  return unverifiedMutationClaimPatterns.some((pattern) =>
    pattern.test(normalized),
  );
}
