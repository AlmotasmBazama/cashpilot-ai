import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/failures/ai_failure_codes.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/support/ai_failure_localizer.dart';
import 'package:cashpilot_ai/l10n/app_localizations_ar.dart';
import 'package:cashpilot_ai/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final code in <String>[
    AiFailureCodes.rateLimited,
    AiFailureCodes.appCheckBlocked,
    AiFailureCodes.networkFailure,
    AiFailureCodes.providerUnavailable,
    AiFailureCodes.localParserOnly,
    AiFailureCodes.liveProviderInactive,
    AiFailureCodes.invalidResponse,
    AiFailureCodes.unsupportedSchema,
    AiFailureCodes.requestInFlight,
    AiFailureCodes.requestTooFast,
    AiFailureCodes.duplicatePrompt,
  ]) {
    test('$code maps to English and Arabic presentation copy', () {
      const backendMessage = 'raw backend details must not be shown';
      const failure = Failure(message: backendMessage);
      final codedFailure = failure.copyWith(code: code);

      final english = localizedAiFailure(AppLocalizationsEn(), codedFailure);
      final arabic = localizedAiFailure(AppLocalizationsAr(), codedFailure);

      expect(english, isNotEmpty);
      expect(arabic, isNotEmpty);
      expect(english, isNot(backendMessage));
      expect(arabic, isNot(backendMessage));
      expect(arabic, isNot(english));
    });
  }

  test('unknown backend errors use generic localized copy', () {
    const failure = Failure(message: 'sensitive server response');

    expect(
      localizedAiFailure(AppLocalizationsEn(), failure),
      AppLocalizationsEn().aiGenericFailureMessage,
    );
  });
}
