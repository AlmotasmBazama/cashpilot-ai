import 'package:cashpilot_ai/features/ai_assistant/application/agent/general_assistant_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases =
      <
        ({
          String safeCode,
          AiUnavailableReason reason,
          bool retryable,
          String english,
          String arabic,
        })
      >[
        (
          safeCode: 'appCheckUnavailable',
          reason: AiUnavailableReason.appCheckUnavailable,
          retryable: true,
          english:
              'Device verification is getting ready. Try again in a moment.',
          arabic: 'جاري تجهيز التحقق من الجهاز. حاول مرة أخرى بعد لحظات.',
        ),
        (
          safeCode: 'appCheckTimedOut',
          reason: AiUnavailableReason.appCheckTimedOut,
          retryable: true,
          english:
              'Device verification took too long. Check your connection and try again.',
          arabic:
              'استغرق التحقق من الجهاز وقتًا أطول من المتوقع. تحقق من الاتصال وحاول مرة أخرى.',
        ),
        (
          safeCode: 'appCheckRejected',
          reason: AiUnavailableReason.appCheckRejected,
          retryable: true,
          english:
              "This development build could not be verified on this device. Check the emulator's App Check registration.",
          arabic:
              'تعذر التحقق من نسخة التطوير على هذا الجهاز. تحقق من تسجيل App Check للمحاكي.',
        ),
        (
          safeCode: 'authenticationNotReady',
          reason: AiUnavailableReason.authenticationNotReady,
          retryable: true,
          english:
              'Your sign-in is still getting ready. Try again in a moment.',
          arabic: 'جاري تجهيز تسجيل الدخول. حاول مرة أخرى بعد لحظات.',
        ),
        (
          safeCode: 'network_failure',
          reason: AiUnavailableReason.offline,
          retryable: true,
          english:
              'You appear to be offline. Check your internet connection and try again.',
          arabic:
              'يبدو أن الجهاز غير متصل بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.',
        ),
      ];

  for (final value in cases) {
    test('${value.safeCode} has distinct safe localized presentation', () {
      expect(aiUnavailableReasonForSafeCode(value.safeCode), value.reason);
      expect(isAiRequestFailureRetryable(value.reason), value.retryable);

      final english = GeneralAssistantPolicy.unavailableForReason(
        value.reason,
        locale: 'en',
      );
      final arabic = GeneralAssistantPolicy.unavailableForReason(
        value.reason,
        locale: 'ar',
      );

      expect(english, value.english);
      expect(arabic, value.arabic);
      expect(english.toLowerCase(), isNot(contains('provider unavailable')));
      expect(arabic, isNot(english));
    });
  }

  test('legacy and transport-safe codes preserve the typed distinction', () {
    expect(
      aiUnavailableReasonForSafeCode('gatewayAppCheckRequired'),
      AiUnavailableReason.appCheckUnavailable,
    );
    expect(
      aiUnavailableReasonForSafeCode('app_check_blocked'),
      AiUnavailableReason.appCheckRejected,
    );
    expect(
      aiUnavailableReasonForSafeCode('gatewayAuthenticationRequired'),
      AiUnavailableReason.authenticationNotReady,
    );
  });
}
