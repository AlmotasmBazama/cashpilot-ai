import '../../../../core/error/result.dart';
import '../entities/financial_insight.dart';
import '../services/financial_insight_explanation_port.dart';
import 'build_ai_insight_summary.dart';

class ExplainFinancialInsightUseCase {
  const ExplainFinancialInsightUseCase({
    required FinancialInsightExplanationPort repository,
    BuildAiInsightSummaryUseCase summaryBuilder =
        const BuildAiInsightSummaryUseCase(),
  }) : _repository = repository,
       _summaryBuilder = summaryBuilder;

  final FinancialInsightExplanationPort _repository;
  final BuildAiInsightSummaryUseCase _summaryBuilder;

  Future<FinancialInsight> call(FinancialInsight insight) async {
    final conversationId = 'local-insight-${insight.id}';
    final result = await _repository.explain(
      FinancialInsightExplanationRequest(
        conversationId: conversationId,
        systemPrompt: _prompt,
        userPrompt: 'Phrase the summarized metric in one neutral sentence.',
        context: _summaryBuilder(<FinancialInsight>[insight]),
        metadata: const <String, Object?>{
          'source': 'ExplainFinancialInsightUseCase',
          'dataClass': 'aggregated_metrics_only',
        },
      ),
    );
    final message = switch (result) {
      AppSuccess(:final data) => data.trim(),
      AppFailure() => '',
    };
    return _isSafe(message) ? insight.copyWith(message: message) : insight;
  }

  bool _isSafe(String value) {
    if (value.isEmpty || value.length > 300) {
      return false;
    }
    final normalized = value.toLowerCase();
    return !<String>[
      'you must',
      'guaranteed',
      'guarantee',
      'investment advice',
      'invest in',
      'ashamed',
      'failure',
      'يجب عليك',
      'مضمون',
    ].any(normalized.contains);
  }
}

const _prompt = '''
Rewrite one summarized personal-finance metric in a concise, neutral tone.
Use only the aggregated values provided in context.
Do not request or infer raw transactions, identity, notes, balances, health, or emotions.
Do not give investment advice, guarantees, commands, shame, or blame.
Return one sentence only.
''';
