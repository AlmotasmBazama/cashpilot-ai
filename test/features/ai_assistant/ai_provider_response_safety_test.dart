import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_provider_response_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = AiProviderResponseSafetyPolicy();

  test(
    'unverified mutation claims are rejected across supported languages',
    () {
      for (final claim in <String>[
        'The expense was saved.',
        'The transfer was completed.',
        'I updated your balance.',
        'Your budget has been created.',
        'Income was recorded.',
        'All done.',
        "That's taken care of.",
        'تم حفظ المصروف.',
        'تم تنفيذ التحويل.',
        'تم تحديث الرصيد.',
        'تمت إضافة الميزانية.',
        'تم تسجيل الدخل.',
        'خلاص، تم.',
        'درناها وخلاص.',
      ]) {
        expect(policy.hasUnverifiedMutationClaim(claim), isTrue, reason: claim);
      }
    },
  );

  test('advice, review states, and explicit non-execution remain allowed', () {
    for (final safeText in <String>[
      'No action was executed.',
      'The budget has not been created.',
      'I can help you create a budget for review.',
      'Review the transfer before saving it.',
      'لم يتم تنفيذ أي إجراء مالي.',
      'راجع المصروف قبل حفظه.',
      'Cash flow is income minus expenses.',
    ]) {
      expect(
        policy.hasUnverifiedMutationClaim(safeText),
        isFalse,
        reason: safeText,
      );
    }
  });

  test(
    'provider text cannot prove success before confirmation, after failure, or for another owner',
    () {
      const claimsByScenario = <String, String>{
        'before local confirmation': 'The transaction was saved.',
        'after a local execution failure': 'The transfer was completed.',
        'result associated with another owner': 'تم تحديث الرصيد.',
      };

      for (final scenario in claimsByScenario.entries) {
        expect(
          policy.hasUnverifiedMutationClaim(scenario.value),
          isTrue,
          reason: scenario.key,
        );
      }
    },
  );
}
