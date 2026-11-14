import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/services/ai_action_executor.dart';
import '../../domain/failures/ai_failure_codes.dart';

String localizedAiFailure(AppLocalizations l10n, Failure failure) {
  return switch (failure.code) {
    AiFailureCodes.rateLimited => l10n.aiRateLimitedMessage,
    AiFailureCodes.appCheckBlocked => l10n.aiAppCheckBlockedMessage,
    AiFailureCodes.networkFailure => l10n.aiNetworkFailureMessage,
    AiFailureCodes.providerUnavailable => l10n.aiProviderUnavailableMessage,
    AiFailureCodes.localParserOnly => l10n.aiLocalParserOnlyMessage,
    AiFailureCodes.liveProviderInactive => l10n.aiLiveProviderInactiveMessage,
    AiFailureCodes.invalidResponse ||
    AiFailureCodes.unsupportedSchema => l10n.aiInvalidResponseMessage,
    AiFailureCodes.requestInFlight => l10n.aiRequestInFlightMessage,
    AiFailureCodes.requestTooFast => l10n.aiRequestTooFastMessage,
    AiFailureCodes.duplicatePrompt => l10n.aiDuplicatePromptMessage,
    AiActionFailureCodes.alreadyExecuted => l10n.aiActionAlreadyExecutedMessage,
    AiActionFailureCodes.confirmationRequired ||
    AiActionFailureCodes.invalid ||
    AiActionFailureCodes.destructiveBlocked ||
    AiActionFailureCodes.invalidStatus ||
    AiActionFailureCodes.executionFailed => l10n.aiActionInvalidMessage,
    _ => l10n.aiGenericFailureMessage,
  };
}
