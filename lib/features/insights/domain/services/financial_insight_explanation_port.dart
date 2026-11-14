import '../../../../core/error/result.dart';

/// The complete, aggregated-only request Insights permits an explanation
/// adapter to send. It deliberately exposes no AI-provider-specific types.
final class FinancialInsightExplanationRequest {
  FinancialInsightExplanationRequest({
    required this.conversationId,
    required this.systemPrompt,
    required this.userPrompt,
    Map<String, Object?> context = const <String, Object?>{},
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : context = Map<String, Object?>.unmodifiable(context),
       metadata = Map<String, Object?>.unmodifiable(metadata);

  final String conversationId;
  final String systemPrompt;
  final String userPrompt;
  final Map<String, Object?> context;
  final Map<String, Object?> metadata;
}

/// Insights-owned output port for optional remote wording.
///
/// Implementations translate this neutral request at a feature boundary and
/// return only the candidate sentence. Insights retains all safety decisions.
abstract interface class FinancialInsightExplanationPort {
  Future<AppResult<String>> explain(FinancialInsightExplanationRequest request);
}
