import '../../../../core/error/result.dart';
import '../../../insights/insight_explanation.dart';
import '../../domain/entities/ai_message.dart';
import '../../domain/entities/ai_request.dart';
import '../../domain/repositories/ai_repository.dart';

/// Translates the Insights-owned explanation port to the assistant repository
/// without leaking assistant request/response types into Insights.
final class AiRepositoryFinancialInsightExplanationAdapter
    implements FinancialInsightExplanationPort {
  const AiRepositoryFinancialInsightExplanationAdapter(this._repository);

  final AiRepository _repository;

  @override
  Future<AppResult<String>> explain(
    FinancialInsightExplanationRequest request,
  ) async {
    final result = await _repository.sendMessage(
      AiRequest(
        conversationId: request.conversationId,
        systemPrompt: request.systemPrompt,
        messages: <AiMessage>[
          AiMessage.user(
            conversationId: request.conversationId,
            content: request.userPrompt,
          ),
        ],
        context: request.context,
        metadata: request.metadata,
      ),
    );
    return switch (result) {
      AppSuccess(:final data) => AppResult<String>.success(
        data.message.content,
      ),
      AppFailure(:final failure) => AppResult<String>.failure(failure),
    };
  }
}
