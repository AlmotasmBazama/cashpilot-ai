import '../services/ai_intent_router.dart';
import 'assistant_navigation_policy.dart';
import 'ai_agent_models.dart';
import 'ai_tool_contracts.dart';

class ToolRelevancePolicy {
  const ToolRelevancePolicy();

  List<AiToolDefinition> relevantDefinitions({
    required AiIntentRoute route,
    required String userMessage,
    required AiAgentSessionMemory memory,
    required List<AiToolDefinition> definitions,
  }) {
    return definitions
        .where(
          (definition) => allows(
            route: route,
            userMessage: userMessage,
            memory: memory,
            definition: definition,
          ),
        )
        .toList(growable: false);
  }

  bool allows({
    required AiIntentRoute route,
    required String userMessage,
    required AiAgentSessionMemory memory,
    required AiToolDefinition definition,
  }) {
    if (route.target == AssistantRouteTarget.appNavigation) {
      return definition.permission == AiToolPermission.navigate &&
          definition.name == route.navigationToolId &&
          AssistantNavigationPolicy.approvedToolPaths[definition.name] != null;
    }
    if (route.target != AssistantRouteTarget.personalFinancialAnalysis) {
      return false;
    }

    final normalized = userMessage.toLowerCase();
    final name = definition.name;
    if (definition.permission == AiToolPermission.calculate) {
      return _containsAny(normalized, const <String>[
        'احسب',
        'نسبة',
        'سيناريو',
        'لو ',
        'calculate',
        'rate',
        'scenario',
        'what if',
      ]);
    }

    if (_containsAny(normalized, const <String>[
          'ميزاني',
          'budget',
          'باقي في',
        ]) ||
        memory.activeTopic == 'budgets' && _isFollowUp(normalized)) {
      return name == 'get_budget_summary' ||
          name == 'get_budget_progress' ||
          name == 'get_category_spending';
    }

    if (_containsAny(normalized, const <String>[
          'هدف',
          'اهداف',
          'أهداف',
          'goal',
        ]) ||
        memory.activeTopic == 'goals' && _isFollowUp(normalized)) {
      return name == 'get_goal_summary' || name == 'get_goal_progress';
    }

    if (_containsAny(normalized, const <String>[
      'حساب',
      'حسابات',
      'رصيد',
      'صافي الثرو',
      'account',
      'balance',
      'net worth',
    ])) {
      return name == 'get_accounts_summary' || name == 'get_net_worth';
    }

    if (_containsAny(normalized, const <String>[
      'متكرر',
      'اشتراك',
      'recurring',
      'subscription',
    ])) {
      return name == 'get_recurring_transactions';
    }

    if (_containsAny(normalized, const <String>[
      'تدفق نقدي',
      'cash flow',
      'دخل مقابل',
    ])) {
      return name == 'get_cash_flow_trend' || name == 'get_dashboard_summary';
    }

    if (_containsAny(normalized, const <String>[
          'الشهر اللي فات',
          'الشهر الماضي',
          'السابق',
          'قارن',
          'compare',
          'previous month',
          'last month',
        ]) ||
        memory.activeTopic == 'monthly_comparison' && _isFollowUp(normalized)) {
      return name == 'get_monthly_comparison' ||
          name == 'get_top_spending_categories';
    }

    if (_containsAny(normalized, const <String>[
      'مصروف',
      'صرفت',
      'صرفي',
      'انفاق',
      'إنفاق',
      'زايد',
      'دخل',
      'ادخار',
      'spend',
      'spent',
      'expense',
      'income',
      'saving',
      'why',
      'ليش',
      'لماذا',
    ])) {
      return name == 'get_dashboard_summary' ||
          name == 'get_monthly_comparison' ||
          name == 'get_top_spending_categories';
    }

    return false;
  }

  bool _isFollowUp(String value) => _containsAny(value, const <String>[
    'وماذا',
    'والشهر',
    'وقبل',
    'نفس',
    'what about',
    'and before',
    'same',
  ]);

  bool _containsAny(String value, List<String> terms) =>
      terms.any(value.contains);
}
