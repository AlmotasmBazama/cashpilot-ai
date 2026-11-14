import 'package:cashpilot_ai/features/ai_assistant/application/agent/general_assistant_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_intent.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeneralAssistantPolicy locale selection', () {
    const cases = <(String, String)>[
      ('en', 'en'),
      ('ar', 'ar'),
      ('en-US', 'en'),
      ('ar_LY', 'ar'),
      ('unsupported', 'en'),
    ];

    for (final entry in cases) {
      test('normalizes ${entry.$1} to ${entry.$2}', () {
        final expected = _l10n(entry.$2);

        expect(
          GeneralAssistantPolicy.localGreeting(locale: entry.$1),
          expected.aiLocalGreeting,
        );
        expect(
          GeneralAssistantPolicy.localSmallTalk(locale: entry.$1),
          expected.aiLocalSmallTalk,
        );
        expect(
          GeneralAssistantPolicy.unavailable(locale: entry.$1),
          expected.aiGeneralUnavailable,
        );
      });
    }
  });

  group('GeneralAssistantPolicy unavailable reason selection', () {
    for (final languageCode in <String>['en', 'ar']) {
      final l10n = _l10n(languageCode);

      for (final reason in AiUnavailableReason.values) {
        test('${reason.name} uses the $languageCode localization', () {
          expect(
            GeneralAssistantPolicy.unavailableForReason(
              reason,
              locale: languageCode,
            ),
            _unavailableMessageForReason(l10n, reason),
          );
        });
      }
    }
  });

  group('GeneralAssistantPolicy capability selection and order', () {
    final l10n = _l10n('en');

    test('null capabilities retain local help and disabled finance notice', () {
      expect(
        GeneralAssistantPolicy.localCapabilities(locale: 'en'),
        <String>[
          l10n.aiCapabilityLocal,
          l10n.aiCapabilityFinancialDisabled,
          l10n.aiCapabilityConfirmationRequired,
        ].join(' '),
      );
    });

    test('all available capabilities retain their current order', () {
      expect(
        GeneralAssistantPolicy.localCapabilities(
          locale: 'en',
          capabilities: const AiAssistantCapabilities.testDefaults(),
        ),
        <String>[
          l10n.aiCapabilityLocal,
          l10n.aiCapabilityGeneralChat,
          l10n.aiCapabilityCurrentKnowledge,
          l10n.aiCapabilityPersonalFinance,
          l10n.aiCapabilityFinancialDrafts,
          l10n.aiCapabilityReceiptVision,
          l10n.aiCapabilityNavigation,
          l10n.aiCapabilityConfirmationRequired,
        ].join(' '),
      );
    });

    test('disabled financial capabilities retain their current placement', () {
      expect(
        GeneralAssistantPolicy.localCapabilities(
          locale: 'en',
          capabilities: _capabilities(
            personalFinancialAnalysisAvailable: false,
            financialDraftsAvailable: false,
          ),
        ),
        <String>[
          l10n.aiCapabilityLocal,
          l10n.aiCapabilityGeneralChat,
          l10n.aiCapabilityCurrentKnowledge,
          l10n.aiCapabilityReceiptVision,
          l10n.aiCapabilityNavigation,
          l10n.aiCapabilityFinancialDisabled,
          l10n.aiCapabilityConfirmationRequired,
        ].join(' '),
      );
    });
  });

  group('GeneralAssistantPolicy direct reply selection', () {
    final l10n = _l10n('en');
    const capabilities = AiAssistantCapabilities.testDefaults();
    final capabilityReply = <String>[
      l10n.aiCapabilityLocal,
      l10n.aiCapabilityGeneralChat,
      l10n.aiCapabilityCurrentKnowledge,
      l10n.aiCapabilityPersonalFinance,
      l10n.aiCapabilityFinancialDrafts,
      l10n.aiCapabilityReceiptVision,
      l10n.aiCapabilityNavigation,
      l10n.aiCapabilityConfirmationRequired,
    ].join(' ');

    for (final intent in AiIntent.values) {
      test('${intent.name} retains its direct reply variant', () {
        final expected = switch (intent) {
          AiIntent.greeting => l10n.aiLocalGreeting,
          AiIntent.smallTalk => l10n.aiLocalSmallTalk,
          AiIntent.help || AiIntent.supportedCapabilities => capabilityReply,
          _ => l10n.aiLocalGreeting,
        };

        expect(
          GeneralAssistantPolicy.localDirectReply(
            intent: intent,
            locale: 'en',
            capabilities: capabilities,
          ),
          expected,
        );
      });
    }
  });

  group('GeneralAssistantPolicy specialized unavailable replies', () {
    for (final languageCode in <String>['en', 'ar']) {
      final l10n = _l10n(languageCode);

      test('financial availability branches in $languageCode', () {
        expect(
          GeneralAssistantPolicy.financialAnalysisUnavailable(
            locale: languageCode,
            generalConversationAvailable: true,
          ),
          l10n.aiFinancialAnalysisUnavailableWithGeneral,
        );
        expect(
          GeneralAssistantPolicy.financialAnalysisUnavailable(
            locale: languageCode,
            generalConversationAvailable: false,
          ),
          l10n.aiFinancialAnalysisUnavailable,
        );
      });

      test('receipt and navigation replies in $languageCode', () {
        expect(
          GeneralAssistantPolicy.receiptVisionUnavailable(locale: languageCode),
          l10n.aiUnavailableReceiptVision,
        );
        expect(
          GeneralAssistantPolicy.navigationUnavailable(locale: languageCode),
          l10n.aiNavigationUnavailable,
        );
      });
    }
  });

  group('GeneralAssistantPolicy offline answers', () {
    final english = _l10n('en');
    final arabic = _l10n('ar');

    test('answers the supported inflation variants', () {
      expect(
        GeneralAssistantPolicy.supportedOfflineAnswer(
          'WHAT IS INFLATION?',
          locale: 'en',
        ),
        english.aiOfflineInflationAnswer,
      );
      expect(
        GeneralAssistantPolicy.supportedOfflineAnswer(
          'ما هو التضخم؟',
          locale: 'ar',
        ),
        arabic.aiOfflineInflationAnswer,
      );
    });

    test('answers the supported Tunisia capital variants', () {
      expect(
        GeneralAssistantPolicy.supportedOfflineAnswer(
          'What is the capital of Tunisia?',
          locale: 'en',
        ),
        english.aiOfflineTunisiaCapitalAnswer,
      );
      expect(
        GeneralAssistantPolicy.supportedOfflineAnswer(
          'ما هي عاصمة تونس؟',
          locale: 'ar',
        ),
        arabic.aiOfflineTunisiaCapitalAnswer,
      );
    });

    test('does not answer a Tunisia query with the Arabic current marker', () {
      expect(
        GeneralAssistantPolicy.supportedOfflineAnswer(
          'ما هي عاصمة تونس حالياً؟',
          locale: 'ar',
        ),
        isNull,
      );
    });

    test('returns null for an unmatched question', () {
      expect(
        GeneralAssistantPolicy.supportedOfflineAnswer(
          'How do eclipses happen?',
          locale: 'en',
        ),
        isNull,
      );
    });
  });

  group('GroundedKnowledgePolicy', () {
    test('retains its English and Arabic unavailable replies', () {
      expect(
        GroundedKnowledgePolicy.unavailable(isArabic: false),
        'Current information could not be verified right now. '
        'I will not present unverified memory as current.',
      );
      expect(
        GroundedKnowledgePolicy.unavailable(isArabic: true),
        'تعذّر التحقق من معلومات حديثة الآن. ما نقدرش نقدّم بيانات حالية من '
        'الذاكرة على إنها مؤكدة.',
      );
    });

    test('retains a nonempty grounding prompt', () {
      expect(GroundedKnowledgePolicy.systemInstruction.trim(), isNotEmpty);
    });
  });
}

AppLocalizations _l10n(String languageCode) =>
    lookupAppLocalizations(Locale(languageCode));

String _unavailableMessageForReason(
  AppLocalizations l10n,
  AiUnavailableReason reason,
) {
  return switch (reason) {
    AiUnavailableReason.platformNotConfigured =>
      l10n.aiUnavailablePlatformNotConfigured,
    AiUnavailableReason.firebaseNotInitialized =>
      l10n.aiUnavailableFirebaseNotInitialized,
    AiUnavailableReason.firebaseAiUnavailable => l10n.aiUnavailableFirebaseAi,
    AiUnavailableReason.appCheckUnavailable => l10n.aiUnavailableAppCheck,
    AiUnavailableReason.appCheckTimedOut => l10n.aiUnavailableAppCheckTimedOut,
    AiUnavailableReason.appCheckRejected => l10n.aiUnavailableAppCheckRejected,
    AiUnavailableReason.authenticationNotReady =>
      l10n.aiUnavailableAuthenticationNotReady,
    AiUnavailableReason.authenticationRequired =>
      l10n.aiUnavailableAuthentication,
    AiUnavailableReason.gatewayDisabled => l10n.aiUnavailableGatewayDisabled,
    AiUnavailableReason.gatewayUrlMissing =>
      l10n.aiUnavailableGatewayUrlMissing,
    AiUnavailableReason.gatewayUnreachable =>
      l10n.aiUnavailableGatewayUnreachable,
    AiUnavailableReason.providerTimedOut => l10n.aiUnavailableProviderTimedOut,
    AiUnavailableReason.providerRejectedRequest =>
      l10n.aiUnavailableProviderRejected,
    AiUnavailableReason.rateLimited => l10n.aiRateLimitedMessage,
    AiUnavailableReason.modelUnavailable => l10n.aiUnavailableFirebaseAi,
    AiUnavailableReason.offline => l10n.aiUnavailableOffline,
    AiUnavailableReason.financialAccessDisabled =>
      l10n.aiUnavailableFinancialAccess,
    AiUnavailableReason.ownerScopeNotReady => l10n.aiUnavailableOwnerScope,
    AiUnavailableReason.legacyDataUnresolved => l10n.aiUnavailableLegacyData,
    AiUnavailableReason.receiptVisionUnavailable =>
      l10n.aiUnavailableReceiptVision,
    AiUnavailableReason.unknownTemporaryFailure => l10n.aiUnavailableTemporary,
  };
}

AiAssistantCapabilities _capabilities({
  bool personalFinancialAnalysisAvailable = true,
  bool financialDraftsAvailable = true,
}) {
  return AiAssistantCapabilities(
    directConversationAvailable: true,
    generalConversationAvailable: true,
    currentKnowledgeAvailable: true,
    personalFinancialAnalysisAvailable: personalFinancialAnalysisAvailable,
    financialDraftsAvailable: financialDraftsAvailable,
    confirmedExecutionAvailable: false,
    receiptVisionAvailable: true,
    navigationAvailable: true,
    activeProvider: AiActiveProvider.firebase,
    unavailableReason: null,
    retryable: false,
    platformSupported: true,
  );
}
