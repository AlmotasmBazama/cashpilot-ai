import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/services/ai_intent_router.dart';
import 'ai_provider_response_safety.dart';
import 'financial_response_grounding.dart';

class DefaultAiAgentModelRouter implements AiAgentModelRouter {
  const DefaultAiAgentModelRouter();

  @override
  ModelTask classify(
    String message, {
    required bool allowComplexPlanning,
    AiIntentRoute? route,
  }) {
    if (route != null) {
      return switch (route.target) {
        AssistantRouteTarget.directConversation ||
        AssistantRouteTarget.financialRecordOffer ||
        AssistantRouteTarget.appNavigation ||
        AssistantRouteTarget.blocked => ModelTask.localConversation,
        AssistantRouteTarget.generalConversation =>
          ModelTask.generalConversation,
        AssistantRouteTarget.groundedCurrentKnowledge =>
          ModelTask.groundedCurrentKnowledge,
        AssistantRouteTarget.personalFinancialAnalysis =>
          ModelTask.personalFinancialAnalysis,
        AssistantRouteTarget.financialAction =>
          ModelTask.financialCommandExtraction,
        AssistantRouteTarget.receiptAction => ModelTask.receiptAnalysis,
      };
    }
    final normalized = message.toLowerCase();
    if (_containsAny(normalized, const <String>[
      'create ',
      'add ',
      'transfer ',
      'set a budget',
      'أنشئ',
      'أضف',
      'حول',
    ])) {
      return ModelTask.financialCommandExtraction;
    }
    if (_containsAny(normalized, const <String>[
      'plan',
      'scenario',
      'forecast',
      'what if',
      'خطة',
      'سيناريو',
      'توقع',
    ])) {
      return allowComplexPlanning
          ? ModelTask.complexFinancialPlanning
          : ModelTask.personalFinancialAnalysis;
    }
    if (_containsAny(normalized, const <String>[
      'spend',
      'income',
      'saving',
      'budget',
      'goal',
      'cash flow',
      'net worth',
      'transaction',
      'expense',
      'أنفق',
      'دخل',
      'ادخار',
      'ميزانية',
      'هدف',
      'مصروف',
    ])) {
      return ModelTask.personalFinancialAnalysis;
    }
    return ModelTask.generalConversation;
  }

  bool _containsAny(String value, List<String> terms) =>
      terms.any(value.contains);
}

class DefaultAiAgentContextSanitizer implements AiAgentContextSanitizer {
  const DefaultAiAgentContextSanitizer();

  @override
  String buildMemoryContext(AiAgentSessionMemory memory) {
    final parts = <String>[
      if (memory.activeTopic case final value?) 'Active topic: $value',
      if (memory.activePeriod case final value?) 'Active period: $value',
    ];
    return parts.join('\n');
  }
}

class DefaultAiAgentResponseComposer implements AiAgentResponseComposer {
  const DefaultAiAgentResponseComposer({
    FinancialResponseGroundingValidator groundingValidator =
        const FinancialResponseGroundingValidator(),
    AiProviderResponseSafetyPolicy responseSafetyPolicy =
        const AiProviderResponseSafetyPolicy(),
  }) : _groundingValidator = groundingValidator,
       _responseSafetyPolicy = responseSafetyPolicy;

  final FinancialResponseGroundingValidator _groundingValidator;
  final AiProviderResponseSafetyPolicy _responseSafetyPolicy;

  @override
  AiAgentResponse compose({
    required String? modelText,
    required List<AiToolResult> results,
    required String locale,
  }) {
    final isArabic = locale.toLowerCase().startsWith('ar');
    final evidence = results
        .map(
          (result) => AiAgentEvidence(
            toolName: result.toolName,
            summary: _summaryFor(result, isArabic: isArabic),
            period: result.period,
            isPartial: result.isPartial,
          ),
        )
        .toList(growable: false);
    final navigationPath = results
        .map((result) => result.navigationPath)
        .whereType<String>()
        .firstOrNull;
    final actionDraft = results
        .map((result) => result.actionDraft)
        .whereType<Map<String, Object?>>()
        .firstOrNull;
    final fallback = results.isEmpty
        ? (isArabic
              ? 'تعذّر الوصول إلى بياناتك المالية الآن. لم يتم تنفيذ أي إجراء.'
              : 'Your financial data is temporarily unavailable. No action was executed.')
        : results
              .map((result) => _answerFor(result, isArabic: isArabic))
              .where((value) => value.trim().isNotEmpty)
              .join('\n\n');
    final trimmedModelText = modelText?.trim();
    String? safeModelText;
    if (trimmedModelText case final text? when text.isNotEmpty) {
      if (!_responseSafetyPolicy.hasUnverifiedMutationClaim(text) &&
          _groundingValidator.supports(text: text, results: results)) {
        safeModelText = text;
      }
    }
    return AiAgentResponse(
      kind: actionDraft != null
          ? AiAgentResponseKind.actionDraft
          : navigationPath != null
          ? AiAgentResponseKind.navigation
          : AiAgentResponseKind.answer,
      message: safeModelText ?? fallback,
      evidence: evidence,
      executedToolNames: results
          .map((result) => result.toolName)
          .toList(growable: false),
      navigationPath: navigationPath,
      actionDraft: actionDraft,
      isPartial: results.any((result) => result.isPartial),
      followUpPrompts: isArabic
          ? const <String>['قارن بالشهر الماضي', 'شن أكثر فئة صرفت عليها؟']
          : const <String>[
              'Compare this with last month',
              'What was my top spending category?',
            ],
    );
  }

  String _answerFor(AiToolResult result, {required bool isArabic}) {
    final data = result.data;
    return switch (result.toolName) {
      'get_dashboard_summary' =>
        isArabic
            ? 'راجعت ملخص هذا الشهر: الدخل ${_value(data, 'monthlyIncome')} ${_value(data, 'currency')}، والمصروفات ${_value(data, 'monthlyExpense')} ${_value(data, 'currency')}، وصافي الادخار ${_value(data, 'monthlySavings')} ${_value(data, 'currency')}.'
            : 'This month, income is ${_value(data, 'monthlyIncome')} ${_value(data, 'currency')}, expenses are ${_value(data, 'monthlyExpense')} ${_value(data, 'currency')}, and net savings are ${_value(data, 'monthlySavings')} ${_value(data, 'currency')}.',
      'get_monthly_comparison' =>
        isArabic
            ? 'مصروفاتك هذا الشهر ${_value(data, 'currentExpense')} ${_value(data, 'currency')}، مقابل ${_value(data, 'previousExpense')} ${_value(data, 'currency')} الشهر الماضي${_change(data, isArabic: true)}.'
            : 'Spending is ${_value(data, 'currentExpense')} ${_value(data, 'currency')} this month versus ${_value(data, 'previousExpense')} ${_value(data, 'currency')} last month${_change(data, isArabic: false)}.',
      'get_top_spending_categories' ||
      'get_category_spending' => _categoryAnswer(data, isArabic: isArabic),
      'get_budget_summary' =>
        isArabic
            ? 'عندك ${_value(data, 'activeCount')} ميزانية نشطة؛ ${_value(data, 'warningCount')} تحتاج متابعة و${_value(data, 'exceededCount')} متجاوزة.'
            : 'You have ${_value(data, 'activeCount')} active budgets; ${_value(data, 'warningCount')} need attention and ${_value(data, 'exceededCount')} are exceeded.',
      'get_goal_summary' =>
        isArabic
            ? 'عندك ${_value(data, 'activeCount')} هدف نشط و${_value(data, 'completedCount')} هدف مكتمل.'
            : 'You have ${_value(data, 'activeCount')} active goals and ${_value(data, 'completedCount')} completed goals.',
      'get_cash_flow_trend' =>
        isArabic
            ? 'صافي التدفق النقدي الحالي ${_value(data, 'currentNet')} ${_value(data, 'currency')}، مقابل ${_value(data, 'previousNet')} ${_value(data, 'currency')} الشهر الماضي.'
            : 'Current net cash flow is ${_value(data, 'currentNet')} ${_value(data, 'currency')}, versus ${_value(data, 'previousNet')} ${_value(data, 'currency')} last month.',
      'get_net_worth' =>
        isArabic
            ? 'صافي ثروتك المسجّل في CashPilot هو ${_value(data, 'netWorth')} ${_value(data, 'currency')}.'
            : 'Your recorded CashPilot net worth is ${_value(data, 'netWorth')} ${_value(data, 'currency')}.',
      _ =>
        isArabic
            ? 'راجعت البيانات المرتبطة بسؤالك، لكن التفاصيل المتاحة لا تكفي لإجابة أدق.'
            : 'I reviewed the data relevant to your question, but the available details are not sufficient for a more precise answer.',
    };
  }

  String _summaryFor(AiToolResult result, {required bool isArabic}) {
    return switch (result.toolName) {
      'get_monthly_comparison' =>
        isArabic
            ? 'مقارنة هذا الشهر بالشهر الماضي'
            : 'This month compared with last month',
      'get_top_spending_categories' || 'get_category_spending' =>
        isArabic ? 'توزيع المصروفات حسب الفئة' : 'Spending by category',
      'get_dashboard_summary' =>
        isArabic ? 'ملخص بيانات هذا الشهر' : 'Current-month summary',
      'get_budget_summary' || 'get_budget_progress' =>
        isArabic ? 'بيانات الميزانيات النشطة' : 'Active budget data',
      'get_goal_summary' ||
      'get_goal_progress' => isArabic ? 'بيانات الأهداف' : 'Goal data',
      _ => isArabic ? 'بيانات CashPilot ذات الصلة' : 'Relevant CashPilot data',
    };
  }

  String _categoryAnswer(Map<String, Object?> data, {required bool isArabic}) {
    final categories = data['categories'];
    if (categories is! List || categories.isEmpty) {
      return isArabic
          ? 'ما لقيناش مصروفات منشورة للفترة المطلوبة.'
          : 'No posted spending was found for the requested period.';
    }
    final labels = categories
        .take(3)
        .whereType<Map>()
        .map((item) {
          final category = item['category'] ?? '';
          final amount = item['amount'] ?? '0';
          final currency = item['currency'] ?? '';
          return '$category: $amount $currency';
        })
        .join(isArabic ? '، ' : ', ');
    return isArabic
        ? 'أكبر فئات الصرف في البيانات المتاحة: $labels.'
        : 'The top spending categories in the available data are $labels.';
  }

  String _change(Map<String, Object?> data, {required bool isArabic}) {
    final value = data['expenseChangePercent'];
    if (value == null || value.toString().trim().isEmpty) {
      return '';
    }
    return isArabic
        ? '، بتغيّر ${value.toString()}%'
        : ', a ${value.toString()}% change';
  }

  String _value(Map<String, Object?> data, String key) =>
      data[key]?.toString() ?? '0';
}
