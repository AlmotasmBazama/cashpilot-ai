import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/adapters/ai_repository_financial_insight_explanation_adapter.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_message.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_model.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_provider_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_request.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_response.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/repositories/ai_repository.dart';
import 'package:cashpilot_ai/features/budgets/application/providers/budgets_providers.dart';
import 'package:cashpilot_ai/features/budgets/domain/entities/budget_progress.dart';
import 'package:cashpilot_ai/features/dashboard/application/dashboard_providers.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/providers/exchange_rates_providers.dart';
import 'package:cashpilot_ai/features/exchange_rates/domain/entities/stored_exchange_rate.dart';
import 'package:cashpilot_ai/features/exchange_rates/domain/repositories/exchange_rate_repository.dart';
import 'package:cashpilot_ai/features/exchange_rates/domain/usecases/convert_money.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/exchange_rate.dart'
    as finance;
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/goals/application/providers/goals_providers.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal_progress.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart'
    as legacy;
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/insight_analysis_result.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/insight_evidence.dart';
import 'package:cashpilot_ai/features/insights/domain/enums/insight_severity.dart';
import 'package:cashpilot_ai/features/insights/domain/enums/insight_type.dart';
import 'package:cashpilot_ai/features/insights/domain/services/insight_conversion_service.dart';
import 'package:cashpilot_ai/features/insights/domain/usecases/explain_financial_insight.dart';
import 'package:cashpilot_ai/features/insights/domain/usecases/generate_financial_insights.dart';
import 'package:cashpilot_ai/features/insights/insights.dart' as public;
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy and public facades expose the exact provider objects', () {
    expect(
      identical(
        legacy.generateFinancialInsightsUseCaseProvider,
        public.generateFinancialInsightsUseCaseProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        legacy.buildAiInsightSummaryUseCaseProvider,
        public.buildAiInsightSummaryUseCaseProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        legacy.financialInsightsProvider,
        public.financialInsightsProvider,
      ),
      isTrue,
    );
    expect(legacy.financialInsightsProvider.name, 'financialInsightsProvider');
    expect(dashboardSnapshotProvider.name, 'dashboardSnapshotProvider');
  });

  test(
    'financial insights provider preserves dashboard input and output',
    () async {
      final snapshot = _emptySnapshot(
        missingExchangeRatePairs: const <MissingExchangeRatePair>[
          MissingExchangeRatePair('usd', 'lyd'),
        ],
      );
      const budgets = <BudgetProgress>[];
      const goals = <GoalProgress>[];
      final expected = <FinancialInsight>[_insight()];
      final generator = _RecordingInsightsGenerator(expected);
      final container = ProviderContainer(
        overrides: [
          dashboardSnapshotProvider.overrideWith(
            (_) async => AppResult<DashboardSnapshot>.success(snapshot),
          ),
          budgetProgressProvider.overrideWith(
            (_) async => const AppResult<List<BudgetProgress>>.success(budgets),
          ),
          allGoalProgressProvider.overrideWith(
            (_) async => const AppResult<List<GoalProgress>>.success(goals),
          ),
          convertMoneyUseCaseProvider.overrideWithValue(
            ConvertMoney(_PassThroughExchangeRateRepository()),
          ),
          legacy.generateFinancialInsightsUseCaseProvider.overrideWithValue(
            generator,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        legacy.financialInsightsProvider.future,
      );

      expect(result, isA<AppSuccess<List<FinancialInsight>>>());
      expect(
        (result as AppSuccess<List<FinancialInsight>>).data,
        same(expected),
      );
      expect(generator.transactions, same(snapshot.transactions));
      expect(generator.budgets, same(budgets));
      expect(generator.goals, same(goals));
      expect(generator.baseCurrency, 'LYD');
      expect(generator.now?.isUtc, isTrue);
      expect(generator.missingRates, hasLength(1));
      expect(generator.missingRates.single.fromCurrency, 'usd');
      expect(generator.missingRates.single.toCurrency, 'lyd');
    },
  );

  test(
    'financial insights provider preserves dashboard failure identity',
    () async {
      const failure = Failure(
        message: 'snapshot unavailable',
        code: 'snapshot',
      );
      final container = ProviderContainer(
        overrides: [
          dashboardSnapshotProvider.overrideWith(
            (_) async => const AppResult<DashboardSnapshot>.failure(failure),
          ),
          budgetProgressProvider.overrideWith(
            (_) async => const AppResult<List<BudgetProgress>>.success(
              <BudgetProgress>[],
            ),
          ),
          allGoalProgressProvider.overrideWith(
            (_) async =>
                const AppResult<List<GoalProgress>>.success(<GoalProgress>[]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        legacy.financialInsightsProvider.future,
      );

      expect(result, isA<AppFailure<List<FinancialInsight>>>());
      expect(
        (result as AppFailure<List<FinancialInsight>>).failure,
        same(failure),
      );
    },
  );

  test(
    'explanation preserves request envelope and trimmed safe output',
    () async {
      final repository = _RecordingAiRepository();
      final original = _insight();

      final result = await ExplainFinancialInsightUseCase(
        repository: AiRepositoryFinancialInsightExplanationAdapter(repository),
      )(original);

      expect(result.message, 'A neutral summarized explanation.');
      final request = repository.lastRequest;
      expect(request, isNotNull);
      expect(request!.conversationId, 'local-insight-${original.id}');
      expect(request.modelId, isNull);
      expect(request.systemPrompt, _expectedPrompt);
      expect(request.messages, hasLength(1));
      expect(request.messages.single.role, AiMessageRole.user);
      expect(request.messages.single.conversationId, request.conversationId);
      expect(
        request.messages.single.content,
        'Phrase the summarized metric in one neutral sentence.',
      );
      expect(request.context, <String, Object?>{
        'insights': <Map<String, Object?>>[
          <String, Object?>{
            'type': 'spending_increase',
            'severity': 'warning',
            'currentValue': '120',
            'previousValue': '100',
            'changePercent': '20',
            'currency': 'LYD',
            'periodStart': '2026-07-01T00:00:00.000Z',
            'periodEnd': '2026-08-01T00:00:00.000Z',
          },
        ],
      });
      expect(request.metadata, const <String, Object?>{
        'source': 'ExplainFinancialInsightUseCase',
        'dataClass': 'aggregated_metrics_only',
      });
    },
  );
}

const _expectedPrompt = '''
Rewrite one summarized personal-finance metric in a concise, neutral tone.
Use only the aggregated values provided in context.
Do not request or infer raw transactions, identity, notes, balances, health, or emotions.
Do not give investment advice, guarantees, commands, shame, or blame.
Return one sentence only.
''';

DashboardSnapshot _emptySnapshot({
  List<MissingExchangeRatePair> missingExchangeRatePairs =
      const <MissingExchangeRatePair>[],
}) {
  final zero = CurrencyTotal(currencyCode: 'LYD', amount: Decimal.zero);
  return DashboardSnapshot(
    accounts: const [],
    transactions: const [],
    categories: const [],
    baseCurrencyCode: 'LYD',
    netWorthInBaseCurrency: zero,
    unconvertedNetWorthByCurrency: const [],
    netWorthByCurrency: <CurrencyTotal>[zero],
    monthlyIncomeByCurrency: <CurrencyTotal>[zero],
    monthlyExpenseByCurrency: <CurrencyTotal>[zero],
    monthlySavingsByCurrency: <CurrencyTotal>[zero],
    yearlyIncomeByCurrency: <CurrencyTotal>[zero],
    yearlyExpenseByCurrency: <CurrencyTotal>[zero],
    yearlySavingsByCurrency: <CurrencyTotal>[zero],
    recentTransactions: const [],
    spendingByCategory: const [],
    monthlyExpenseTrend: List<Decimal>.filled(6, Decimal.zero),
    missingExchangeRatePairs: missingExchangeRatePairs,
  );
}

FinancialInsight _insight() => FinancialInsight.create(
  id: 'insight-contract-id',
  type: InsightType.spendingIncrease,
  severity: InsightSeverity.warning,
  title: 'Local title',
  message: 'Local deterministic fallback.',
  evidence: InsightEvidence(
    metricName: 'private_metric_name',
    currentValue: Decimal.fromInt(120),
    previousValue: Decimal.fromInt(100),
    changePercent: Decimal.fromInt(20),
    currency: 'LYD',
  ),
  periodStart: DateTime.utc(2026, 7),
  periodEnd: DateTime.utc(2026, 8),
);

final class _RecordingInsightsGenerator
    extends GenerateFinancialInsightsUseCase {
  _RecordingInsightsGenerator(this.output);

  final List<FinancialInsight> output;
  List<Transaction>? transactions;
  List<BudgetProgress>? budgets;
  List<GoalProgress>? goals;
  String? baseCurrency;
  DateTime? now;
  List<InsightMissingRatePair> missingRates = const <InsightMissingRatePair>[];

  @override
  Future<List<FinancialInsight>> call({
    required List<Transaction> transactions,
    required List<BudgetProgress> budgets,
    required List<GoalProgress> goals,
    required String baseCurrency,
    required DateTime now,
    required InsightMoneyConverter convertMoney,
    List<InsightMissingRatePair> knownMissingRates =
        const <InsightMissingRatePair>[],
  }) async {
    this.transactions = transactions;
    this.budgets = budgets;
    this.goals = goals;
    this.baseCurrency = baseCurrency;
    this.now = now;
    missingRates = knownMissingRates;
    return output;
  }
}

final class _RecordingAiRepository implements AiRepository {
  AiRequest? lastRequest;

  @override
  Future<AppResult<List<AiModel>>> getAvailableModels() async =>
      const AppResult<List<AiModel>>.success(<AiModel>[]);

  @override
  Future<AppResult<AiResponse>> sendMessage(AiRequest request) async {
    lastRequest = request;
    return AppResult<AiResponse>.success(
      AiResponse(
        message: AiMessage.assistant(
          conversationId: request.conversationId,
          content: '  A neutral summarized explanation.  ',
        ),
        providerType: AiProviderType.mock,
        modelId: 'contract-model',
        finishReason: AiFinishReason.complete,
        tokenUsage: const AiTokenUsage(inputTokens: 1, outputTokens: 2),
      ),
    );
  }
}

final class _PassThroughExchangeRateRepository
    implements ExchangeRateRepository {
  @override
  Future<AppResult<Money>> convert(Money money, String toCurrencyCode) async =>
      AppResult<Money>.success(
        Money(amount: money.amount, currencyCode: toCurrencyCode),
      );

  @override
  Future<AppResult<StoredExchangeRate>> archiveRate(String id) =>
      throw UnimplementedError();

  @override
  Future<AppResult<finance.ExchangeRate?>> getLatestRate(
    String fromCurrency,
    String toCurrency,
  ) => throw UnimplementedError();

  @override
  Future<AppResult<StoredExchangeRate?>> getRate(
    String baseCurrency,
    String quoteCurrency,
  ) => throw UnimplementedError();

  @override
  Future<AppResult<List<StoredExchangeRate>>> getRatesForBaseCurrency(
    String baseCurrency,
  ) => throw UnimplementedError();

  @override
  Future<AppResult<StoredExchangeRate>> upsertRate(StoredExchangeRate rate) =>
      throw UnimplementedError();

  @override
  Stream<AppResult<List<StoredExchangeRate>>> watchRates({
    bool includeArchived = false,
  }) => throw UnimplementedError();
}
