import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/build_ai_insight_summary.dart';
import '../../domain/usecases/generate_financial_insights.dart';

final generateFinancialInsightsUseCaseProvider =
    Provider<GenerateFinancialInsightsUseCase>(
      (_) => const GenerateFinancialInsightsUseCase(),
      name: 'generateFinancialInsightsUseCaseProvider',
    );

final buildAiInsightSummaryUseCaseProvider =
    Provider<BuildAiInsightSummaryUseCase>(
      (_) => const BuildAiInsightSummaryUseCase(),
      name: 'buildAiInsightSummaryUseCaseProvider',
    );
