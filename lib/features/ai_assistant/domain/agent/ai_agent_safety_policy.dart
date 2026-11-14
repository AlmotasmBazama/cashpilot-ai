class AiAgentSafetyPolicy {
  const AiAgentSafetyPolicy();

  static const Set<String> _blockedTerms = <String>{
    'app check token',
    'debug token',
    'firebase token',
    'api key',
    'secret key',
    'service account',
    'raw database',
    'drift database',
    'firestore dump',
    'disable app check',
    'bypass app check',
    'disable enforcement',
    'system prompt',
    'developer message',
    'upload all data',
    'export all data',
    'access token',
    'refresh token',
  };

  static const Set<String> _blockedArabicTerms = <String>{
    'رمز التحقق',
    'رمز سري',
    'مفتاح سري',
    'قاعدة البيانات الخام',
    'تعطيل التحقق',
    'عطل التحقق',
    'تجاوز التحقق',
    'ارفع كل البيانات',
    'صدر كل البيانات',
  };

  bool isBlocked(String message) {
    final normalized = message.toLowerCase();
    return _blockedTerms.any(normalized.contains) ||
        _blockedArabicTerms.any(normalized.contains);
  }

  String refusal({required bool isArabic}) => isArabic
      ? 'لا أستطيع الوصول إلى الأسرار أو البيانات الخام أو تغيير إعدادات الأمان. يمكنني استخدام أدوات CashPilot المسموح بها فقط لتقديم تحليل مالي محدود.'
      : 'I cannot access secrets or raw data, or change security settings. I can only use CashPilot’s allowlisted, bounded tools for financial analysis.';
}
