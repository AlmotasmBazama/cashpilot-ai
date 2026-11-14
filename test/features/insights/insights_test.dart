import 'dart:convert';

import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/adapters/ai_repository_financial_insight_explanation_adapter.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_message.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_model.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_provider_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_request.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_response.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/repositories/ai_repository.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/insight_evidence.dart';
import 'package:cashpilot_ai/features/insights/domain/enums/insight_severity.dart';
import 'package:cashpilot_ai/features/insights/domain/enums/insight_type.dart';
import 'package:cashpilot_ai/features/insights/domain/usecases/build_ai_insight_summary.dart';
import 'package:cashpilot_ai/features/insights/domain/usecases/calculate_monthly_comparison.dart';
import 'package:cashpilot_ai/features/insights/domain/usecases/detect_cash_flow_trend.dart';
import 'package:cashpilot_ai/features/insights/domain/usecases/detect_missing_exchange_rate_insights.dart';
import 'package:cashpilot_ai/features/insights/domain/usecases/detect_recurring_transactions.dart';
import 'package:cashpilot_ai/features/insights/domain/usecases/detect_top_spending_category.dart';
import 'package:cashpilot_ai/features/insights/domain/usecases/explain_financial_insight.dart';
import 'package:cashpilot_ai/features/insights/domain/usecases/generate_financial_insights.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14);

  test('top category is detected from posted current-month expenses', () async {
    final result = await const DetectTopSpendingCategoryUseCase()(
      transactions: [
        transaction(amount: '80', categoryId: 'food'),
        transaction(amount: '20', categoryId: 'transport'),
        transaction(
          amount: '500',
          categoryId: 'ignored',
          status: TransactionStatus.pending,
        ),
      ],
      baseCurrency: 'LYD',
      now: now,
      convertMoney: sameCurrencyOnly,
    );

    expect(result?.categoryId, 'food');
    expect(result?.amount, Decimal.fromInt(80));
  });

  test('spending increase is detected against previous month', () async {
    final insights = await const GenerateFinancialInsightsUseCase()(
      transactions: [
        transaction(amount: '130'),
        transaction(amount: '100', date: DateTime.utc(2026, 6, 10)),
      ],
      budgets: const [],
      goals: const [],
      baseCurrency: 'LYD',
      now: now,
      convertMoney: sameCurrencyOnly,
    );

    final value = insights.firstWhere(
      (insight) => insight.type == InsightType.spendingIncrease,
    );
    expect(value.evidence.changePercent, Decimal.fromInt(30));
  });

  test('recurring payment pattern is detected locally', () {
    final result = const DetectRecurringTransactionsUseCase()(
      transactions: [
        transaction(
          amount: '25',
          payeeId: 'stream',
          date: DateTime.utc(2026, 4, 1),
        ),
        transaction(
          amount: '25',
          payeeId: 'stream',
          date: DateTime.utc(2026, 5, 1),
        ),
        transaction(
          amount: '25',
          payeeId: 'stream',
          date: DateTime.utc(2026, 6, 1),
        ),
      ],
      now: now,
    );

    expect(result.patternCount, 1);
  });

  test('negative cash-flow trend is detected', () async {
    final result = await const DetectCashFlowTrendUseCase()(
      transactions: [
        transaction(amount: '100', type: TransactionType.income),
        transaction(amount: '150'),
      ],
      baseCurrency: 'LYD',
      now: now,
      convertMoney: sameCurrencyOnly,
    );

    expect(result?.currentNet, Decimal.fromInt(-50));
  });

  test('missing conversion produces an explicit insight', () async {
    final comparison = await const CalculateMonthlyComparisonUseCase()(
      transactions: [transaction(amount: '10', currency: 'USD')],
      baseCurrency: 'LYD',
      now: now,
      convertMoney: (_, _) async =>
          const AppResult.failure(Failure(message: 'Missing rate.')),
    );
    final insights = const DetectMissingExchangeRateInsightsUseCase()(
      pairs: comparison.missingRates,
      periodStart: comparison.currentPeriodStart,
      periodEnd: comparison.currentPeriodEnd,
    );

    expect(insights, hasLength(1));
    expect(insights.single.type, InsightType.missingExchangeRate);
    expect(insights.single.evidence.metricName, 'USD->LYD');
  });

  test('AI insight summary excludes sensitive and identifying fields', () {
    final value = insight(
      metricName: 'private-goal-name',
      relatedCategoryId: 'secret-category-id',
      relatedPayeeId: 'secret-payee-id',
    );
    final encoded = jsonEncode(const BuildAiInsightSummaryUseCase()([value]));

    expect(encoded, isNot(contains(value.id)));
    expect(encoded, isNot(contains('private-goal-name')));
    expect(encoded, isNot(contains('secret-category-id')));
    expect(encoded, isNot(contains('secret-payee-id')));
    expect(encoded, isNot(contains('uid')));
    expect(encoded, isNot(contains('email')));
    expect(encoded, contains('currentValue'));
  });

  test('AI failure falls back to deterministic local text', () async {
    final repository = _InsightAiRepository(fails: true);
    final original = insight(metricName: 'monthly_expense');
    final result = await ExplainFinancialInsightUseCase(
      repository: AiRepositoryFinancialInsightExplanationAdapter(repository),
    )(original);

    expect(result.message, original.message);
    expect(repository.lastRequest, isNotNull);
    final payload = jsonEncode(repository.lastRequest!.context);
    expect(payload, isNot(contains('monthly_expense')));
    expect(
      repository.lastRequest!.messages.single.content,
      isNot(contains(original.message)),
    );
  });
}

Future<AppResult<Money>> sameCurrencyOnly(Money money, String currency) async =>
    AppResult.success(Money(amount: money.amount, currencyCode: currency));

Transaction transaction({
  required String amount,
  String categoryId = 'food',
  String currency = 'LYD',
  String? payeeId,
  TransactionType type = TransactionType.expense,
  TransactionStatus status = TransactionStatus.posted,
  DateTime? date,
}) => Transaction.create(
  accountId: 'cash',
  categoryId: categoryId,
  payeeId: payeeId,
  amount: Money(amount: Decimal.parse(amount), currencyCode: currency),
  type: type,
  status: status,
  transactionDate: date ?? DateTime.utc(2026, 7, 10),
  note: 'raw private note',
);

FinancialInsight insight({
  required String metricName,
  String? relatedCategoryId,
  String? relatedPayeeId,
}) => FinancialInsight.create(
  type: InsightType.spendingIncrease,
  severity: InsightSeverity.warning,
  title: 'Local title',
  message: 'Local deterministic fallback.',
  evidence: InsightEvidence(
    metricName: metricName,
    currentValue: Decimal.fromInt(120),
    previousValue: Decimal.fromInt(100),
    changePercent: Decimal.fromInt(20),
    currency: 'LYD',
    relatedCategoryId: relatedCategoryId,
    relatedPayeeId: relatedPayeeId,
  ),
  periodStart: DateTime.utc(2026, 7, 1),
  periodEnd: DateTime.utc(2026, 8, 1),
);

class _InsightAiRepository implements AiRepository {
  _InsightAiRepository({required this.fails});

  final bool fails;
  AiRequest? lastRequest;

  @override
  Future<AppResult<List<AiModel>>> getAvailableModels() async =>
      AppResult.success([
        AiModel(
          id: 'fake',
          providerType: AiProviderType.mock,
          displayName: 'Fake',
          capabilities: const [AiCapability.chat],
          isDefault: true,
        ),
      ]);

  @override
  Future<AppResult<AiResponse>> sendMessage(AiRequest request) async {
    lastRequest = request;
    if (fails) {
      return const AppResult.failure(Failure(message: 'Offline.'));
    }
    return AppResult.success(
      AiResponse(
        message: AiMessage.assistant(
          conversationId: request.conversationId,
          content: 'A neutral summarized explanation.',
        ),
        providerType: AiProviderType.mock,
        modelId: 'fake',
        finishReason: AiFinishReason.complete,
        tokenUsage: const AiTokenUsage(inputTokens: 0, outputTokens: 0),
      ),
    );
  }
}
