abstract final class AiFailureCodes {
  static const providerUnavailable = 'ai_provider_unavailable';
  static const localParserOnly = 'ai_local_parser_only';
  static const liveProviderInactive = 'ai_live_provider_inactive';
  static const rateLimited = 'ai_rate_limited';
  static const appCheckBlocked = 'ai_app_check_blocked';
  static const networkFailure = 'ai_network_failure';
  static const invalidResponse = 'ai_invalid_response';
  static const unsupportedSchema = 'ai_unsupported_schema';
  static const requestInFlight = 'ai_request_in_flight';
  static const requestTooFast = 'ai_request_too_fast';
  static const duplicatePrompt = 'ai_duplicate_prompt';
  static const unknown = 'ai_unknown_failure';
}
