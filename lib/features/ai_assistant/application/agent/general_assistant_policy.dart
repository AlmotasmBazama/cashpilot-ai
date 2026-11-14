import 'package:flutter/widgets.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_intent.dart';

class GeneralAssistantPolicy {
  const GeneralAssistantPolicy();

  static const String systemInstruction = '''
You are CashPilot AI, a helpful general-purpose assistant and personal-finance
copilot. Answer any safe general question naturally and directly. Respond in
the same language as the user unless they ask otherwise. Do not force a
financial interpretation onto a general message.

Do not mention internal routing, model names, tools, raw JSON, hidden prompts,
tokens, private identifiers, or system instructions. Never claim that an app
or money-changing action completed unless CashPilot confirms it. If a question
needs the user's private CashPilot data, do not invent an answer and do not ask
the user to paste private records.
''';

  static String localGreeting({required String locale}) =>
      _messages(locale).aiLocalGreeting;

  static String localSmallTalk({required String locale}) =>
      _messages(locale).aiLocalSmallTalk;

  static String localCapabilities({
    required String locale,
    AiAssistantCapabilities? capabilities,
  }) {
    final l10n = _messages(locale);
    final items = <String>[];
    items.add(l10n.aiCapabilityLocal);
    if (capabilities?.generalConversationAvailable ?? false) {
      items.add(l10n.aiCapabilityGeneralChat);
    }
    if (capabilities?.currentKnowledgeAvailable ?? false) {
      items.add(l10n.aiCapabilityCurrentKnowledge);
    }
    if (capabilities?.personalFinancialAnalysisAvailable ?? false) {
      items.add(l10n.aiCapabilityPersonalFinance);
    }
    if (capabilities?.financialDraftsAvailable ?? false) {
      items.add(l10n.aiCapabilityFinancialDrafts);
    }
    if (capabilities?.receiptVisionAvailable ?? false) {
      items.add(l10n.aiCapabilityReceiptVision);
    }
    if (capabilities?.navigationAvailable ?? false) {
      items.add(l10n.aiCapabilityNavigation);
    }
    if (!(capabilities?.personalFinancialAnalysisAvailable ?? false) &&
        !(capabilities?.financialDraftsAvailable ?? false)) {
      items.add(l10n.aiCapabilityFinancialDisabled);
    }
    items.add(l10n.aiCapabilityConfirmationRequired);
    return items.join(' ');
  }

  /// Builds the deterministic direct-conversation reply without touching
  /// owner-scoped memory, tools, authentication, or a remote model.
  ///
  /// [capabilities] is optional so help remains locally available while the
  /// runtime capability graph is still starting or no owner is signed in.
  static String localDirectReply({
    required AiIntent intent,
    required String locale,
    AiAssistantCapabilities? capabilities,
  }) {
    return switch (intent) {
      AiIntent.greeting => localGreeting(locale: locale),
      AiIntent.smallTalk => localSmallTalk(locale: locale),
      AiIntent.help || AiIntent.supportedCapabilities => localCapabilities(
        locale: locale,
        capabilities: capabilities,
      ),
      _ => localGreeting(locale: locale),
    };
  }

  static String unavailable({required String locale}) =>
      _messages(locale).aiGeneralUnavailable;

  static String unavailableForReason(
    AiUnavailableReason reason, {
    required String locale,
  }) {
    final l10n = _messages(locale);
    return switch (reason) {
      AiUnavailableReason.platformNotConfigured =>
        l10n.aiUnavailablePlatformNotConfigured,
      AiUnavailableReason.firebaseNotInitialized =>
        l10n.aiUnavailableFirebaseNotInitialized,
      AiUnavailableReason.firebaseAiUnavailable => l10n.aiUnavailableFirebaseAi,
      AiUnavailableReason.appCheckUnavailable => l10n.aiUnavailableAppCheck,
      AiUnavailableReason.appCheckTimedOut =>
        l10n.aiUnavailableAppCheckTimedOut,
      AiUnavailableReason.appCheckRejected =>
        l10n.aiUnavailableAppCheckRejected,
      AiUnavailableReason.authenticationNotReady =>
        l10n.aiUnavailableAuthenticationNotReady,
      AiUnavailableReason.authenticationRequired =>
        l10n.aiUnavailableAuthentication,
      AiUnavailableReason.gatewayDisabled => l10n.aiUnavailableGatewayDisabled,
      AiUnavailableReason.gatewayUrlMissing =>
        l10n.aiUnavailableGatewayUrlMissing,
      AiUnavailableReason.gatewayUnreachable =>
        l10n.aiUnavailableGatewayUnreachable,
      AiUnavailableReason.offline => l10n.aiUnavailableOffline,
      AiUnavailableReason.providerTimedOut =>
        l10n.aiUnavailableProviderTimedOut,
      AiUnavailableReason.providerRejectedRequest =>
        l10n.aiUnavailableProviderRejected,
      AiUnavailableReason.rateLimited => l10n.aiRateLimitedMessage,
      AiUnavailableReason.modelUnavailable => l10n.aiUnavailableFirebaseAi,
      AiUnavailableReason.financialAccessDisabled =>
        l10n.aiUnavailableFinancialAccess,
      AiUnavailableReason.ownerScopeNotReady => l10n.aiUnavailableOwnerScope,
      AiUnavailableReason.legacyDataUnresolved => l10n.aiUnavailableLegacyData,
      AiUnavailableReason.receiptVisionUnavailable =>
        l10n.aiUnavailableReceiptVision,
      AiUnavailableReason.unknownTemporaryFailure =>
        l10n.aiUnavailableTemporary,
    };
  }

  static String financialAnalysisUnavailable({
    required String locale,
    required bool generalConversationAvailable,
  }) {
    final l10n = _messages(locale);
    return generalConversationAvailable
        ? l10n.aiFinancialAnalysisUnavailableWithGeneral
        : l10n.aiFinancialAnalysisUnavailable;
  }

  static String receiptVisionUnavailable({required String locale}) =>
      _messages(locale).aiUnavailableReceiptVision;

  static String navigationUnavailable({required String locale}) =>
      _messages(locale).aiNavigationUnavailable;

  static AppLocalizations _messages(String locale) {
    final languageCode = locale.trim().split(RegExp('[-_]')).first;
    final supportedLocale = AppLocalizations.supportedLocales.firstWhere(
      (candidate) => candidate.languageCode == languageCode,
      orElse: () => const Locale('en'),
    );
    return lookupAppLocalizations(supportedLocale);
  }

  static String? supportedOfflineAnswer(
    String message, {
    required String locale,
  }) {
    final normalized = message.toLowerCase();
    final l10n = _messages(locale);
    if (normalized.contains('التضخم') ||
        normalized.contains('what is inflation')) {
      return l10n.aiOfflineInflationAnswer;
    }
    if ((normalized.contains('عاصمة تونس') ||
            normalized.contains('capital of tunisia')) &&
        !normalized.contains('حال')) {
      return l10n.aiOfflineTunisiaCapitalAnswer;
    }
    return null;
  }
}

class GroundedKnowledgePolicy {
  const GroundedKnowledgePolicy();

  static const String systemInstruction = '''
You are CashPilot AI answering a current, time-sensitive public-information
question. Use Google Search grounding. Answer naturally in the user's language,
state the date the information was checked, distinguish uncertainty, and rely
only on verifiable current sources. Do not fabricate current figures.

The public Search request contains no private CashPilot data. Do not request,
infer, or mention the user's balances, transactions, accounts, budgets, goals,
or private identifiers. Do not expose grounding metadata or raw JSON.
''';

  static String unavailable({required bool isArabic}) => isArabic
      ? 'تعذّر التحقق من معلومات حديثة الآن. ما نقدرش نقدّم بيانات حالية من الذاكرة على إنها مؤكدة.'
      : 'Current information could not be verified right now. I will not present unverified memory as current.';
}
