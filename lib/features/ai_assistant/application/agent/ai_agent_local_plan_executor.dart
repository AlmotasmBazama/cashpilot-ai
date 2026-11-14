import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/agent/tool_relevance_policy.dart';
import '../../domain/services/ai_intent_router.dart';

/// Executes the bounded, deterministic financial-read plan selected locally.
///
/// The caller remains responsible for routing and for creating the
/// owner-scoped execution context. Implementations must never widen the tool
/// registry or convert a failed tool call into a successful result.
abstract interface class AiAgentLocalPlanExecutor {
  Future<AiAgentLocalPlanExecution> execute({
    required String message,
    required AiAgentSessionMemory memory,
    required AiIntentRoute route,
    required AiToolExecutionContext context,
  });
}

class AiAgentLocalPlanExecution {
  const AiAgentLocalPlanExecution({
    required this.calls,
    required this.payloads,
    required this.successfulResults,
  });

  final List<AiAgentToolCall> calls;
  final List<Object> payloads;
  final List<AiToolResult> successfulResults;
}

/// Default local plan selection and execution policy used by the orchestrator.
class DefaultAiAgentLocalPlanExecutor implements AiAgentLocalPlanExecutor {
  const DefaultAiAgentLocalPlanExecutor({
    required AiToolRegistry toolRegistry,
    required ToolRelevancePolicy toolRelevancePolicy,
    required AiAgentLimits limits,
  }) : _toolRegistry = toolRegistry,
       _toolRelevancePolicy = toolRelevancePolicy,
       _limits = limits;

  final AiToolRegistry _toolRegistry;
  final ToolRelevancePolicy _toolRelevancePolicy;
  final AiAgentLimits _limits;

  @override
  Future<AiAgentLocalPlanExecution> execute({
    required String message,
    required AiAgentSessionMemory memory,
    required AiIntentRoute route,
    required AiToolExecutionContext context,
  }) async {
    final calls = _plan(message, memory);
    final attemptedCalls = <AiAgentToolCall>[];
    final payloads = <Object>[];
    final results = <AiToolResult>[];
    for (final call in calls.take(_limits.maxCallsPerRound)) {
      var attempted = false;
      try {
        final definition = _toolRegistry.definitionFor(call.name);
        if (definition == null ||
            !_toolRelevancePolicy.allows(
              route: route,
              userMessage: message,
              memory: memory,
              definition: definition,
            )) {
          continue;
        }
        attemptedCalls.add(call);
        attempted = true;
        final result = await _toolRegistry.execute(call, context);
        results.add(result);
        payloads.add(result.toModelPayload());
      } on AiToolFailure catch (failure) {
        if (attempted) {
          payloads.add(failure.toModelPayload());
        }
        // A deterministic fallback remains partial and never widens access.
      }
    }
    return AiAgentLocalPlanExecution(
      calls: attemptedCalls,
      payloads: payloads,
      successfulResults: results,
    );
  }

  List<AiAgentToolCall> _plan(String message, AiAgentSessionMemory memory) {
    final normalized = message.toLowerCase();
    final calls = <AiAgentToolCall>[];

    void add(String name, [Map<String, Object?> arguments = const {}]) {
      if (_toolRegistry.definitionFor(name) != null) {
        calls.add(
          AiAgentToolCall(
            id: 'local-${calls.length + 1}',
            name: name,
            arguments: arguments,
          ),
        );
      }
    }

    if (_containsAny(normalized, const <String>[
      'compare',
      'last month',
      'previous month',
      'قارن',
      'الشهر الماضي',
      'الشهر اللي فات',
      'السابق',
      'زايد',
      'ليش',
      'لماذا',
    ])) {
      add('get_monthly_comparison');
    }
    if (_containsAny(normalized, const <String>[
      'top categor',
      'category spending',
      'spend by categor',
      'زايد',
      'ليش',
      'لماذا',
      'أعلى فئة',
      'حسب الفئة',
    ])) {
      add('get_top_spending_categories', const <String, Object?>{'limit': 5});
    }
    if (_containsAny(normalized, const <String>[
      'budget',
      'ميزانية',
      'ميزانيات',
    ])) {
      add('get_budget_summary');
      if (_containsAny(normalized, const <String>[
        'progress',
        'risk',
        'warning',
        'تقدم',
        'خطر',
        'تحذير',
      ])) {
        add('get_budget_progress', const <String, Object?>{'limit': 8});
      }
    }
    if (_containsAny(normalized, const <String>['goal', 'هدف', 'أهداف'])) {
      add('get_goal_summary');
      if (_containsAny(normalized, const <String>[
        'progress',
        'remaining',
        'complete',
        'تقدم',
        'متبقي',
      ])) {
        add('get_goal_progress', const <String, Object?>{'limit': 8});
      }
    }
    if (_containsAny(normalized, const <String>[
      'cash flow',
      'trend',
      'تدفق نقدي',
      'اتجاه',
    ])) {
      add('get_cash_flow_trend');
    }
    if (_containsAny(normalized, const <String>[
      'recurring',
      'subscription',
      'متكرر',
      'اشتراك',
    ])) {
      add('get_recurring_transactions', const <String, Object?>{'limit': 10});
    }
    if (_containsAny(normalized, const <String>['net worth', 'صافي الثروة'])) {
      add('get_net_worth');
    }
    if (_containsAny(normalized, const <String>['account', 'حساب', 'حسابات'])) {
      add('get_accounts_summary', const <String, Object?>{'limit': 10});
    }
    if (_containsAny(normalized, const <String>[
      'base currency',
      'عملة الأساس',
      'العملة الأساسية',
    ])) {
      add('get_base_currency');
    }
    if (_containsAny(normalized, const <String>[
      'what can you',
      'help',
      'capabilit',
      'ماذا تستطيع',
      'مساعدة',
    ])) {
      add('get_agent_capabilities');
    }
    if (calls.isEmpty &&
        _containsAny(normalized, const <String>[
          'spend',
          'expense',
          'income',
          'saving',
          'financial',
          'أنفق',
          'مصروف',
          'دخل',
          'ادخار',
          'مالي',
        ])) {
      add('get_dashboard_summary');
    }
    if (calls.isEmpty &&
        memory.activeTopic == 'monthly_comparison' &&
        _containsAny(normalized, const <String>[
          'and before',
          'what about',
          'وقبل',
          'وماذا',
          'والشهر',
        ])) {
      add('get_monthly_comparison');
    }
    return calls;
  }

  bool _containsAny(String value, List<String> terms) =>
      terms.any(value.contains);
}
