import 'package:decimal/decimal.dart';

import '../../domain/agent/assistant_navigation_policy.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/app_agent/app_agent_models.dart';
import '../../domain/app_agent/canonical_app_tool_catalog.dart';
import 'governed_ai_tool_registry.dart';

abstract interface class FinancialAgentDataGateway {
  Future<AiToolResult> executeReadTool(
    String name,
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
  );
}

class FinancialAgentToolCatalog {
  const FinancialAgentToolCatalog(this._dataGateway);

  final FinancialAgentDataGateway _dataGateway;

  List<RegisteredAiTool> build({
    bool readOnlyEnabled = true,
    bool draftEnabled = true,
    bool navigationEnabled = true,
  }) {
    CanonicalAppToolCatalog.validate();
    final candidates = <RegisteredAiTool>[
      if (readOnlyEnabled) ..._readTools(),
      ..._calculationTools(),
      if (draftEnabled) ..._draftTools(),
      if (navigationEnabled) ..._navigationTools(),
    ];
    return candidates
        .where((tool) {
          final descriptors = CanonicalAppToolCatalog.byProviderToolName(
            tool.definition.name,
          );
          if (descriptors.isEmpty) {
            return false;
          }
          final descriptor = descriptors.first;
          if (tool.definition.permission != descriptor.permission ||
              tool.definition.risk != descriptor.risk ||
              tool.definition.modelCallable != descriptor.modelCallable) {
            throw StateError(
              'Provider tool metadata does not match the canonical catalog.',
            );
          }
          return true;
        })
        .toList(growable: false);
  }

  List<RegisteredAiTool> _readTools() {
    const period = AiToolArgument(
      description: 'Bounded period: current_month, previous_month, or year.',
      type: AiToolValueType.string,
      allowedValues: <String>['current_month', 'previous_month', 'year'],
    );
    const limit = AiToolArgument(
      description: 'Maximum number of bounded results.',
      type: AiToolValueType.integer,
    );
    const category = AiToolArgument(
      description:
          'Required category name, trimmed to 1-80 characters; not an internal identifier.',
      type: AiToolValueType.string,
      required: true,
      trimWhitespace: true,
      minLength: 1,
      maxLength: 80,
    );
    const query = AiToolArgument(
      description: 'A short transaction search phrase.',
      type: AiToolValueType.string,
      required: true,
    );
    const readDefinitions = <AiToolDefinition>[
      AiToolDefinition(
        name: 'get_dashboard_summary',
        description:
            'Returns minimized current-month income, expense, savings, and net-worth totals.',
        permission: AiToolPermission.readFinancialData,
      ),
      AiToolDefinition(
        name: 'get_monthly_comparison',
        description: 'Compares current and previous month income and expenses.',
        permission: AiToolPermission.readFinancialData,
      ),
      AiToolDefinition(
        name: 'get_category_spending',
        description:
            'Returns bounded spending totals for a category or period.',
        permission: AiToolPermission.readFinancialData,
        arguments: <String, AiToolArgument>{
          'category': category,
          'period': period,
          'limit': limit,
        },
      ),
      AiToolDefinition(
        name: 'get_top_spending_categories',
        description: 'Returns top bounded spending categories for a period.',
        permission: AiToolPermission.readFinancialData,
        arguments: <String, AiToolArgument>{'period': period, 'limit': limit},
      ),
      AiToolDefinition(
        name: 'get_budget_summary',
        description: 'Returns active budget counts and at-risk totals.',
        permission: AiToolPermission.readFinancialData,
      ),
      AiToolDefinition(
        name: 'get_budget_progress',
        description: 'Returns bounded active budget progress summaries.',
        permission: AiToolPermission.readFinancialData,
        arguments: <String, AiToolArgument>{'limit': limit},
      ),
      AiToolDefinition(
        name: 'get_goal_summary',
        description: 'Returns active goal progress totals.',
        permission: AiToolPermission.readFinancialData,
      ),
      AiToolDefinition(
        name: 'get_goal_progress',
        description: 'Returns bounded progress for active financial goals.',
        permission: AiToolPermission.readFinancialData,
        arguments: <String, AiToolArgument>{'limit': limit},
      ),
      AiToolDefinition(
        name: 'get_cash_flow_trend',
        description: 'Returns a bounded six-month expense trend.',
        permission: AiToolPermission.readFinancialData,
      ),
      AiToolDefinition(
        name: 'get_recurring_transactions',
        description:
            'Returns bounded detected recurring transaction summaries.',
        permission: AiToolPermission.readFinancialData,
        arguments: <String, AiToolArgument>{'limit': limit},
      ),
      AiToolDefinition(
        name: 'get_income_expense_breakdown',
        description: 'Returns minimized income and expense totals by period.',
        permission: AiToolPermission.readFinancialData,
        arguments: <String, AiToolArgument>{'period': period},
      ),
      AiToolDefinition(
        name: 'get_net_worth',
        description: 'Returns net worth in the configured base currency.',
        permission: AiToolPermission.readFinancialData,
      ),
      AiToolDefinition(
        name: 'get_accounts_summary',
        description:
            'Returns bounded account names, types, currencies, and balances.',
        permission: AiToolPermission.readFinancialData,
        arguments: <String, AiToolArgument>{'limit': limit},
      ),
      AiToolDefinition(
        name: 'get_exchange_rate',
        description: 'Returns a stored exchange rate for one currency pair.',
        permission: AiToolPermission.readFinancialData,
        arguments: <String, AiToolArgument>{
          'from': AiToolArgument(
            description: 'Three-letter source currency code.',
            type: AiToolValueType.string,
            required: true,
          ),
          'to': AiToolArgument(
            description: 'Three-letter target currency code.',
            type: AiToolValueType.string,
            required: true,
          ),
        },
      ),
      AiToolDefinition(
        name: 'search_transactions',
        description:
            'Returns a bounded, minimized transaction search result without notes or attachments.',
        permission: AiToolPermission.readFinancialData,
        arguments: <String, AiToolArgument>{'query': query, 'limit': limit},
      ),
      AiToolDefinition(
        name: 'get_base_currency',
        description: 'Returns the configured base currency code.',
        permission: AiToolPermission.readAppConfiguration,
      ),
      AiToolDefinition(
        name: 'get_agent_capabilities',
        description: 'Returns a safe list of CashPilot agent capabilities.',
        permission: AiToolPermission.readAppConfiguration,
      ),
    ];
    return readDefinitions
        .map(
          (definition) => RegisteredAiTool(
            definition: definition,
            handler: (arguments, context) => _dataGateway.executeReadTool(
              definition.name,
              _normalizeArguments(definition, arguments),
              context,
            ),
          ),
        )
        .toList(growable: false);
  }

  Map<String, Object?> _normalizeArguments(
    AiToolDefinition definition,
    Map<String, Object?> arguments,
  ) => <String, Object?>{
    for (final entry in arguments.entries)
      entry.key:
          definition.arguments[entry.key]?.trimWhitespace == true &&
              entry.value is String
          ? (entry.value as String).trim()
          : entry.value,
  };

  List<RegisteredAiTool> _calculationTools() {
    const amount = AiToolArgument(
      description: 'A decimal amount encoded as a string.',
      type: AiToolValueType.string,
      required: true,
    );
    const optionalAmount = AiToolArgument(
      description: 'A decimal amount encoded as a string.',
      type: AiToolValueType.string,
    );
    const tools = <AiToolDefinition>[
      AiToolDefinition(
        name: 'calculate_savings_rate',
        description: 'Calculates savings rate from income and expense amounts.',
        permission: AiToolPermission.calculate,
        arguments: <String, AiToolArgument>{
          'income': amount,
          'expense': amount,
        },
      ),
      AiToolDefinition(
        name: 'project_month_end',
        description:
            'Projects month-end spending from spending-to-date and elapsed days.',
        permission: AiToolPermission.calculate,
        arguments: <String, AiToolArgument>{
          'spentToDate': amount,
          'elapsedDays': AiToolArgument(
            description: 'Elapsed days in the month.',
            type: AiToolValueType.integer,
            required: true,
          ),
          'daysInMonth': AiToolArgument(
            description: 'Total days in the month.',
            type: AiToolValueType.integer,
            required: true,
          ),
        },
      ),
      AiToolDefinition(
        name: 'simulate_budget_change',
        description: 'Simulates remaining budget after a proposed limit.',
        permission: AiToolPermission.calculate,
        arguments: <String, AiToolArgument>{
          'currentSpending': amount,
          'proposedBudget': amount,
        },
      ),
      AiToolDefinition(
        name: 'calculate_goal_feasibility',
        description:
            'Calculates months needed and feasibility for a savings goal.',
        permission: AiToolPermission.calculate,
        arguments: <String, AiToolArgument>{
          'remaining': amount,
          'monthlyContribution': amount,
          'monthsAvailable': AiToolArgument(
            description: 'Optional number of available months.',
            type: AiToolValueType.integer,
          ),
        },
      ),
      AiToolDefinition(
        name: 'forecast_goal_completion',
        description: 'Forecasts goal completion from a monthly contribution.',
        permission: AiToolPermission.calculate,
        arguments: <String, AiToolArgument>{
          'remaining': amount,
          'monthlyContribution': amount,
        },
      ),
      AiToolDefinition(
        name: 'calculate_safe_allowance',
        description:
            'Calculates a conservative allowance after fixed costs and savings.',
        permission: AiToolPermission.calculate,
        arguments: <String, AiToolArgument>{
          'income': amount,
          'fixedCosts': amount,
          'plannedSavings': optionalAmount,
        },
      ),
      AiToolDefinition(
        name: 'simulate_income_change',
        description: 'Simulates monthly cash flow after an income change.',
        permission: AiToolPermission.calculate,
        arguments: <String, AiToolArgument>{
          'income': amount,
          'expense': amount,
          'incomeChange': amount,
        },
      ),
      AiToolDefinition(
        name: 'compare_scenarios',
        description: 'Compares two decimal scenario outcomes.',
        permission: AiToolPermission.calculate,
        arguments: <String, AiToolArgument>{
          'scenarioA': amount,
          'scenarioB': amount,
        },
      ),
      AiToolDefinition(
        name: 'convert_currency_amount',
        description:
            'Converts an amount with a supplied trusted exchange rate.',
        permission: AiToolPermission.calculate,
        arguments: <String, AiToolArgument>{
          'amount': amount,
          'rate': amount,
          'from': AiToolArgument(
            description: 'Source currency.',
            type: AiToolValueType.string,
            required: true,
          ),
          'to': AiToolArgument(
            description: 'Target currency.',
            type: AiToolValueType.string,
            required: true,
          ),
        },
      ),
    ];
    return tools
        .map(
          (definition) => RegisteredAiTool(
            definition: definition,
            handler: (arguments, context) =>
                _calculate(definition.name, arguments),
          ),
        )
        .toList(growable: false);
  }

  Future<AiToolResult> _calculate(
    String name,
    Map<String, Object?> arguments,
  ) async {
    Decimal amount(String key, {Decimal? fallback}) {
      final parsed = Decimal.tryParse(arguments[key]?.toString() ?? '');
      if (parsed == null) {
        if (fallback != null) {
          return fallback;
        }
        throw const AiToolFailure(
          code: 'invalid_amount',
          safeMessage: 'A valid decimal amount is required.',
        );
      }
      return parsed;
    }

    Map<String, Object?> data;
    switch (name) {
      case 'calculate_savings_rate':
        final income = amount('income');
        final expense = amount('expense');
        data = <String, Object?>{
          'savings': (income - expense).toString(),
          'savingsRatePercent': income <= Decimal.zero
              ? null
              : (((income - expense) / income).toDecimal(
                          scaleOnInfinitePrecision: 6,
                        ) *
                        Decimal.fromInt(100))
                    .toString(),
        };
      case 'project_month_end':
        final elapsed = arguments['elapsedDays']! as int;
        final total = arguments['daysInMonth']! as int;
        if (elapsed < 1 || total < elapsed || total > 31) {
          throw const AiToolFailure(
            code: 'invalid_period',
            safeMessage: 'The month projection period is invalid.',
          );
        }
        data = <String, Object?>{
          'projectedAmount':
              ((amount('spentToDate') / Decimal.fromInt(elapsed)).toDecimal(
                        scaleOnInfinitePrecision: 8,
                      ) *
                      Decimal.fromInt(total))
                  .toString(),
        };
      case 'simulate_budget_change':
        data = <String, Object?>{
          'remaining': (amount('proposedBudget') - amount('currentSpending'))
              .toString(),
        };
      case 'calculate_goal_feasibility':
      case 'forecast_goal_completion':
        final remaining = amount('remaining');
        final contribution = amount('monthlyContribution');
        if (remaining < Decimal.zero || contribution <= Decimal.zero) {
          throw const AiToolFailure(
            code: 'invalid_amount',
            safeMessage: 'Goal amounts must be positive.',
          );
        }
        final months = (remaining / contribution).ceil().toInt();
        final available = arguments['monthsAvailable'] as int?;
        data = <String, Object?>{
          'monthsNeeded': months,
          if (available != null) 'feasibleWithinPeriod': months <= available,
        };
      case 'calculate_safe_allowance':
        final allowance =
            amount('income') -
            amount('fixedCosts') -
            amount('plannedSavings', fallback: Decimal.zero);
        data = <String, Object?>{
          'safeAllowance': (allowance < Decimal.zero ? Decimal.zero : allowance)
              .toString(),
        };
      case 'simulate_income_change':
        data = <String, Object?>{
          'projectedCashFlow':
              (amount('income') + amount('incomeChange') - amount('expense'))
                  .toString(),
        };
      case 'compare_scenarios':
        final a = amount('scenarioA');
        final b = amount('scenarioB');
        data = <String, Object?>{
          'difference': (b - a).toString(),
          'betterScenario': a == b ? 'equal' : (a > b ? 'A' : 'B'),
        };
      case 'convert_currency_amount':
        final rate = amount('rate');
        if (rate <= Decimal.zero) {
          throw const AiToolFailure(
            code: 'invalid_rate',
            safeMessage: 'The exchange rate must be positive.',
          );
        }
        data = <String, Object?>{
          'amount': (amount('amount') * rate).toString(),
          'from': arguments['from'].toString().toUpperCase(),
          'to': arguments['to'].toString().toUpperCase(),
        };
      default:
        throw const AiToolFailure(
          code: 'tool_not_allowed',
          safeMessage: 'That calculation is not available.',
        );
    }
    return AiToolResult(
      toolName: name,
      data: data,
      evidenceSummary: 'Calculation completed from the supplied values.',
    );
  }

  List<RegisteredAiTool> _draftTools() {
    const amount = AiToolArgument(
      description: 'A decimal amount encoded as a string.',
      type: AiToolValueType.string,
      required: true,
    );
    const currency = AiToolArgument(
      description: 'Three-letter currency code.',
      type: AiToolValueType.string,
      required: true,
    );
    const name = AiToolArgument(
      description: 'User-visible name.',
      type: AiToolValueType.string,
      required: true,
    );
    const definitions = <AiToolDefinition>[
      AiToolDefinition(
        name: 'draft_transaction',
        description:
            'Creates a review-only transaction draft. It never saves a transaction.',
        permission: AiToolPermission.createDraft,
        risk: AgentActionRisk.low,
        modelCallable: false,
        arguments: <String, AiToolArgument>{
          'amount': amount,
          'currency': currency,
          'type': AiToolArgument(
            description: 'income or expense.',
            type: AiToolValueType.string,
            required: true,
            allowedValues: <String>['income', 'expense'],
          ),
          'category': name,
          'account': name,
        },
      ),
      AiToolDefinition(
        name: 'draft_transfer',
        description:
            'Creates a review-only transfer draft. It never moves funds.',
        permission: AiToolPermission.createDraft,
        risk: AgentActionRisk.medium,
        modelCallable: false,
        arguments: <String, AiToolArgument>{
          'amount': amount,
          'currency': currency,
          'fromAccount': name,
          'toAccount': name,
        },
      ),
      AiToolDefinition(
        name: 'draft_budget',
        description:
            'Creates a review-only budget draft. It never saves a budget.',
        permission: AiToolPermission.createDraft,
        risk: AgentActionRisk.low,
        modelCallable: false,
        arguments: <String, AiToolArgument>{
          'name': name,
          'amount': amount,
          'currency': currency,
          'category': name,
        },
      ),
      AiToolDefinition(
        name: 'draft_goal',
        description: 'Creates a review-only goal draft. It never saves a goal.',
        permission: AiToolPermission.createDraft,
        risk: AgentActionRisk.low,
        modelCallable: false,
        arguments: <String, AiToolArgument>{
          'title': name,
          'targetAmount': amount,
          'currency': currency,
        },
      ),
      AiToolDefinition(
        name: 'draft_goal_contribution',
        description:
            'Creates a review-only goal contribution draft. It never saves a contribution.',
        permission: AiToolPermission.createDraft,
        risk: AgentActionRisk.low,
        modelCallable: false,
        arguments: <String, AiToolArgument>{
          'goal': name,
          'amount': amount,
          'currency': currency,
        },
      ),
    ];
    return definitions
        .map(
          (definition) => RegisteredAiTool(
            definition: definition,
            handler: (arguments, context) async {
              final draft = <String, Object?>{
                'draftType': definition.name,
                ...arguments,
                'reviewRequired': true,
                'executionAllowed': false,
              };
              return AiToolResult(
                toolName: definition.name,
                data: <String, Object?>{
                  'draftCreated': true,
                  'reviewRequired': true,
                },
                actionDraft: draft,
                evidenceSummary:
                    'A draft was prepared. Review and explicitly confirm it in CashPilot before anything is saved.',
              );
            },
          ),
        )
        .toList(growable: false);
  }

  List<RegisteredAiTool> _navigationTools() {
    return AssistantNavigationPolicy.approvedToolPaths.entries
        .map(
          (entry) => RegisteredAiTool(
            definition: AiToolDefinition(
              name: entry.key,
              description:
                  'Returns an approved in-app destination. It does not change financial data.',
              permission: AiToolPermission.navigate,
            ),
            handler: (arguments, context) async => AiToolResult(
              toolName: entry.key,
              data: const <String, Object?>{'navigationApproved': true},
              navigationPath: entry.value,
            ),
          ),
        )
        .toList(growable: false);
  }
}
