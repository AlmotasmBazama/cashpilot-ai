import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';

class GroqAiAgentModelGateway implements ResettableAiAgentModelGateway {
  const GroqAiAgentModelGateway({
    required AiConversationGateway gateway,
    required String clientVersion,
    required bool toolSelectionEnabled,
    required bool financialExplanationEnabled,
  }) : _gateway = gateway,
       _clientVersion = clientVersion,
       _toolSelectionEnabled = toolSelectionEnabled,
       _financialExplanationEnabled = financialExplanationEnabled;

  final AiConversationGateway _gateway;
  final String _clientVersion;
  final bool _toolSelectionEnabled;
  final bool _financialExplanationEnabled;

  @override
  Future<AiAgentModelSession> startSession({
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required AiProviderEgressGuard egressGuard,
  }) async {
    egressGuard.assertActive();
    if (request.taskClass != ModelTask.generalConversation &&
        request.taskClass != ModelTask.personalFinancialAnalysis) {
      throw const AiGatewayException(
        code: AiGatewayFailureCode.configurationFailure,
        safeMessage: 'This capability is not routed through the Groq gateway.',
      );
    }
    final approvedTools = tools
        .where(
          (tool) =>
              tool.permission == AiToolPermission.readFinancialData ||
              tool.permission == AiToolPermission.calculate,
        )
        .toList(growable: false);
    return _GroqAiAgentModelSession(
      gateway: _gateway,
      request: request,
      tools: approvedTools,
      clientVersion: _clientVersion,
      toolSelectionEnabled: _toolSelectionEnabled,
      financialExplanationEnabled: _financialExplanationEnabled,
      egressGuard: egressGuard,
    );
  }

  @override
  void clearSessions() {
    // The secure gateway is intentionally stateless.
  }
}

class _GroqAiAgentModelSession implements StreamingAiAgentModelSession {
  _GroqAiAgentModelSession({
    required AiConversationGateway gateway,
    required AiAgentModelRequest request,
    required List<AiToolDefinition> tools,
    required String clientVersion,
    required bool toolSelectionEnabled,
    required bool financialExplanationEnabled,
    required AiProviderEgressGuard egressGuard,
  }) : _gateway = gateway,
       _request = request,
       _tools = tools,
       _clientVersion = clientVersion,
       _toolSelectionEnabled = toolSelectionEnabled,
       _financialExplanationEnabled = financialExplanationEnabled,
       _egressGuard = egressGuard;

  final AiConversationGateway _gateway;
  final AiAgentModelRequest _request;
  final List<AiToolDefinition> _tools;
  final String _clientVersion;
  final bool _toolSelectionEnabled;
  final bool _financialExplanationEnabled;
  final AiProviderEgressGuard _egressGuard;
  final Uuid _uuid = const Uuid();

  @override
  Future<AiAgentModelTurn> sendInitial() async {
    if (_request.taskClass == ModelTask.generalConversation) {
      var text = '';
      final gatewayRequest = _gatewayRequest(AiGatewayMode.generalConversation);
      _egressGuard.assertActive();
      await for (final event in _gateway.streamGeneralConversation(
        gatewayRequest,
        egressGuard: _egressGuard,
      )) {
        if (event.delta case final delta?) {
          text += delta;
        }
      }
      return AiAgentModelTurn(text: text);
    }
    if (!_toolSelectionEnabled || _tools.isEmpty) {
      return const AiAgentModelTurn();
    }
    final gatewayRequest = _gatewayRequest(
      AiGatewayMode.governedToolSelection,
      allowedToolIds: _tools.map((tool) => tool.name).toList(growable: false),
    );
    _egressGuard.assertActive();
    final selection = await _gateway.selectGovernedTools(
      gatewayRequest,
      egressGuard: _egressGuard,
    );
    return AiAgentModelTurn(
      text: selection.calls.isEmpty ? selection.clarification : null,
      toolCalls: selection.calls
          .map(
            (call) => AiAgentToolCall(
              id: _uuid.v4(),
              name: call.name,
              arguments: call.arguments,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<AiAgentModelTurn> sendInitialStream() async* {
    if (_request.taskClass != ModelTask.generalConversation) {
      yield await sendInitial();
      return;
    }
    var text = '';
    final gatewayRequest = _gatewayRequest(AiGatewayMode.generalConversation);
    _egressGuard.assertActive();
    await for (final event in _gateway.streamGeneralConversation(
      gatewayRequest,
      egressGuard: _egressGuard,
    )) {
      if (event.delta case final delta?) {
        text += delta;
        yield AiAgentModelTurn(text: text);
      }
    }
  }

  @override
  Future<AiAgentModelTurn> sendToolResults(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) async {
    _egressGuard.assertActive();
    if (calls.length != results.length) {
      throw const AiGatewayException(
        code: AiGatewayFailureCode.invalidResponse,
        safeMessage: 'Tool call and result counts do not match.',
      );
    }
    if (!_financialExplanationEnabled) {
      return const AiAgentModelTurn();
    }
    final context = _boundedFinancialContext(calls, results);
    if (context.records.isEmpty) {
      return const AiAgentModelTurn();
    }
    var text = '';
    final gatewayRequest = _gatewayRequest(
      AiGatewayMode.financialExplanation,
      financialContext: context,
    );
    _egressGuard.assertActive();
    await for (final event in _gateway.streamFinancialExplanation(
      gatewayRequest,
      egressGuard: _egressGuard,
    )) {
      if (event.delta case final delta?) {
        text += delta;
      }
    }
    return AiAgentModelTurn(text: text);
  }

  AiGatewayRequest _gatewayRequest(
    AiGatewayMode mode, {
    AiGatewayFinancialContext? financialContext,
    List<String>? allowedToolIds,
  }) {
    final isGeneralConversation = mode == AiGatewayMode.generalConversation;
    return AiGatewayRequest(
      requestId: _uuid.v4(),
      mode: mode,
      locale: _safeLocale(_request.locale),
      // Financial and tool-selection calls receive only the current request.
      // Conversation history and memory are never financial-context inputs.
      sanitizedMessages: isGeneralConversation
          ? _boundedMessages()
          : _currentMessageOnly(),
      compactMemorySummary: isGeneralConversation
          ? _safeText(_request.compactMemorySummary, maxLength: 2000)
          : null,
      sanitizedFinancialContext: financialContext,
      allowedToolIds: allowedToolIds,
      timeoutClass: mode == AiGatewayMode.generalConversation
          ? AiGatewayTimeoutClass.interactive
          : AiGatewayTimeoutClass.analysis,
      clientVersion: _clientVersion,
    );
  }

  List<AiGatewayMessage> _currentMessageOnly() {
    final safeUserMessage = _safeText(_request.userMessage, maxLength: 2000);
    if (safeUserMessage == null) {
      throw const AiGatewayException(
        code: AiGatewayFailureCode.invalidResponse,
        safeMessage: 'Private or credential-like content was blocked.',
      );
    }
    return <AiGatewayMessage>[
      AiGatewayMessage(role: 'user', content: safeUserMessage),
    ];
  }

  List<AiGatewayMessage> _boundedMessages() {
    final history = _request.conversationHistory
        .map(
          (message) => AiGatewayMessage(
            role: message.role == AiAgentMessageRole.user
                ? 'user'
                : 'assistant',
            content: _safeText(message.content, maxLength: 2000) ?? '',
          ),
        )
        .where((message) => message.content.isNotEmpty)
        .toList(growable: true);
    if (history.isNotEmpty &&
        history.last.role == 'user' &&
        history.last.content.trim() == _request.userMessage.trim()) {
      history.removeLast();
    }
    final safeUserMessage = _safeText(_request.userMessage, maxLength: 2000);
    if (safeUserMessage == null) {
      throw const AiGatewayException(
        code: AiGatewayFailureCode.invalidResponse,
        safeMessage: 'Private or credential-like content was blocked.',
      );
    }
    history.add(AiGatewayMessage(role: 'user', content: safeUserMessage));
    return history.length <= 8
        ? List<AiGatewayMessage>.unmodifiable(history)
        : List<AiGatewayMessage>.unmodifiable(
            history.sublist(history.length - 8),
          );
  }

  AiGatewayFinancialContext _boundedFinancialContext(
    List<AiAgentToolCall> calls,
    List<Object> results,
  ) {
    final records = <AiGatewayFinancialRecord>[];
    final assumptions = <String>[];
    for (var index = 0; index < calls.length && records.length < 12; index++) {
      final result = results[index];
      if (result is! Map || result['ok'] != true || result['data'] is! Map) {
        continue;
      }
      final toolId = calls[index].name;
      final schema = _financialToolSchemas[toolId];
      if (schema == null ||
          !_tools.any((tool) => tool.name == toolId) ||
          (result['tool'] != null && result['tool'] != toolId)) {
        continue;
      }
      final values = _safeFinancialMap(result['data'] as Map, schema.fields);
      if (values.isEmpty) {
        continue;
      }
      final partial = result['partial'] == true || values['partial'] == true;
      if (partial) {
        assumptions.add(
          'Some deterministic CashPilot values are partial because local conversion data is incomplete.',
        );
      }
      records.add(
        AiGatewayFinancialRecord(
          toolId: toolId,
          values: values,
          partial: partial,
        ),
      );
    }
    final currency = _request.baseCurrencyCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const AiGatewayException(
        code: AiGatewayFailureCode.invalidResponse,
        safeMessage: 'A valid local base currency is required.',
      );
    }
    return AiGatewayFinancialContext(
      currency: currency,
      records: List<AiGatewayFinancialRecord>.unmodifiable(records),
      assumptions: assumptions.toSet().take(8).toList(growable: false),
    );
  }

  Map<String, Object?> _safeFinancialMap(
    Map<Object?, Object?> source,
    Map<String, _FinancialFieldSchema> fields,
  ) {
    final output = <String, Object?>{};
    for (final field in fields.entries) {
      if (!source.containsKey(field.key)) {
        continue;
      }
      final value = _safeFinancialValue(source[field.key], field.value);
      if (value != null) {
        output[field.key] = value;
      }
    }
    return output;
  }

  Object? _safeFinancialValue(Object? value, _FinancialFieldSchema schema) {
    return switch (schema.kind) {
      _FinancialFieldKind.decimal => _safeDecimal(value),
      _FinancialFieldKind.integer => _safeInteger(value),
      _FinancialFieldKind.boolean => value is bool ? value : null,
      _FinancialFieldKind.currency => _safeCurrency(value),
      _FinancialFieldKind.token => _safeToken(value),
      _FinancialFieldKind.date => _safeDate(value),
      _FinancialFieldKind.label => value is String ? _safeLabel(value) : null,
      _FinancialFieldKind.decimalList =>
        value is List
            ? value
                  .take(20)
                  .map(_safeDecimal)
                  .whereType<String>()
                  .toList(growable: false)
            : null,
      _FinancialFieldKind.recordList =>
        value is List
            ? value
                  .take(20)
                  .whereType<Map>()
                  .map(
                    (item) => _safeFinancialMap(
                      item.cast<Object?, Object?>(),
                      schema.nestedFields,
                    ),
                  )
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false)
            : null,
    };
  }

  String? _safeDecimal(Object? value) {
    if (value is! String) {
      return null;
    }
    final decimal = value.trim();
    return decimal.length <= 80 && _decimalStringPattern.hasMatch(decimal)
        ? decimal
        : null;
  }

  int? _safeInteger(Object? value) {
    if (value is! int || value.abs() > 1000000000) {
      return null;
    }
    return value;
  }

  String? _safeCurrency(Object? value) {
    if (value is! String) {
      return null;
    }
    final currency = value.trim().toUpperCase();
    return _currencyPattern.hasMatch(currency) ? currency : null;
  }

  String? _safeToken(Object? value) {
    if (value is! String) {
      return null;
    }
    final token = value.trim();
    return _safeTokenPattern.hasMatch(token) ? token : null;
  }

  String? _safeDate(Object? value) {
    if (value is! String) {
      return null;
    }
    final date = value.trim();
    if (date.length > 40 || !_datePattern.hasMatch(date)) {
      return null;
    }
    return DateTime.tryParse(date) == null ? null : date;
  }

  String? _safeLabel(String value) {
    final label = _safeText(value, maxLength: 80);
    if (label == null) {
      return null;
    }
    if (_promptInjectionLabelPattern.hasMatch(label) ||
        label.contains('\n') ||
        label.contains('\r') ||
        label.contains('{') ||
        label.contains('}') ||
        label.contains('```')) {
      return '[untrusted label]';
    }
    return label.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _safeText(String? value, {required int maxLength}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    if (RegExp(r'\bBearer\s+\S+', caseSensitive: false).hasMatch(text) ||
        RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}').hasMatch(text) ||
        RegExp(
          r'[A-Z]:\\(?:Users|Documents|Windows)\\',
          caseSensitive: false,
        ).hasMatch(text) ||
        _phoneLikeIdentifierPattern.hasMatch(text)) {
      throw const AiGatewayException(
        code: AiGatewayFailureCode.invalidResponse,
        safeMessage: 'Private or credential-like content was blocked.',
      );
    }
    return text.length <= maxLength ? text : text.substring(0, maxLength);
  }

  String _safeLocale(String value) {
    final locale = value.trim();
    return RegExp(
          r'^[a-z]{2}(?:[-_][A-Za-z0-9]{2,8})?$',
          caseSensitive: false,
        ).hasMatch(locale)
        ? locale
        : 'en';
  }
}

enum _FinancialFieldKind {
  decimal,
  integer,
  boolean,
  currency,
  token,
  date,
  label,
  decimalList,
  recordList,
}

class _FinancialFieldSchema {
  const _FinancialFieldSchema(
    this.kind, {
    this.nestedFields = const <String, _FinancialFieldSchema>{},
  });

  final _FinancialFieldKind kind;
  final Map<String, _FinancialFieldSchema> nestedFields;
}

class _FinancialToolSchema {
  const _FinancialToolSchema(this.fields);

  final Map<String, _FinancialFieldSchema> fields;
}

const _decimalField = _FinancialFieldSchema(_FinancialFieldKind.decimal);
const _integerField = _FinancialFieldSchema(_FinancialFieldKind.integer);
const _booleanField = _FinancialFieldSchema(_FinancialFieldKind.boolean);
const _currencyField = _FinancialFieldSchema(_FinancialFieldKind.currency);
const _tokenField = _FinancialFieldSchema(_FinancialFieldKind.token);
const _dateField = _FinancialFieldSchema(_FinancialFieldKind.date);
const _labelField = _FinancialFieldSchema(_FinancialFieldKind.label);
const _decimalListField = _FinancialFieldSchema(
  _FinancialFieldKind.decimalList,
);

const _categoryRecordsField = _FinancialFieldSchema(
  _FinancialFieldKind.recordList,
  nestedFields: <String, _FinancialFieldSchema>{
    'category': _labelField,
    'amount': _decimalField,
    'currency': _currencyField,
  },
);
const _budgetRecordsField = _FinancialFieldSchema(
  _FinancialFieldKind.recordList,
  nestedFields: <String, _FinancialFieldSchema>{
    'name': _labelField,
    'spent': _decimalField,
    'limit': _decimalField,
    'remaining': _decimalField,
    'currency': _currencyField,
    'progressPercent': _decimalField,
    'status': _tokenField,
    'partial': _booleanField,
  },
);
const _savedTotalRecordsField = _FinancialFieldSchema(
  _FinancialFieldKind.recordList,
  nestedFields: <String, _FinancialFieldSchema>{
    'amount': _decimalField,
    'currency': _currencyField,
  },
);
const _goalRecordsField = _FinancialFieldSchema(
  _FinancialFieldKind.recordList,
  nestedFields: <String, _FinancialFieldSchema>{
    'title': _labelField,
    'current': _decimalField,
    'target': _decimalField,
    'remaining': _decimalField,
    'currency': _currencyField,
    'progressPercent': _decimalField,
    'daysRemaining': _integerField,
    'monthlyNeeded': _decimalField,
    'status': _tokenField,
  },
);
const _accountRecordsField = _FinancialFieldSchema(
  _FinancialFieldKind.recordList,
  nestedFields: <String, _FinancialFieldSchema>{
    'name': _labelField,
    'type': _tokenField,
    'balance': _decimalField,
    'currency': _currencyField,
  },
);
const _transactionRecordsField = _FinancialFieldSchema(
  _FinancialFieldKind.recordList,
  nestedFields: <String, _FinancialFieldSchema>{
    'date': _dateField,
    'type': _tokenField,
    'amount': _decimalField,
    'currency': _currencyField,
    'category': _labelField,
    'account': _labelField,
    'status': _tokenField,
  },
);

const _categorySpendingSchema = _FinancialToolSchema(
  <String, _FinancialFieldSchema>{
    'period': _tokenField,
    'categories': _categoryRecordsField,
    'partial': _booleanField,
  },
);
const _goalFeasibilitySchema = _FinancialToolSchema(
  <String, _FinancialFieldSchema>{
    'monthsNeeded': _integerField,
    'feasibleWithinPeriod': _booleanField,
  },
);

const _financialToolSchemas = <String, _FinancialToolSchema>{
  'get_dashboard_summary': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'currency': _currencyField,
    'monthlyIncome': _decimalField,
    'monthlyExpense': _decimalField,
    'monthlySavings': _decimalField,
    'netWorth': _decimalField,
    'accountCount': _integerField,
    'partial': _booleanField,
  }),
  'get_monthly_comparison':
      _FinancialToolSchema(<String, _FinancialFieldSchema>{
        'currency': _currencyField,
        'currentExpense': _decimalField,
        'previousExpense': _decimalField,
        'expenseChangePercent': _decimalField,
        'partial': _booleanField,
      }),
  'get_category_spending': _categorySpendingSchema,
  'get_top_spending_categories': _categorySpendingSchema,
  'get_budget_summary': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'activeCount': _integerField,
    'warningCount': _integerField,
    'exceededCount': _integerField,
  }),
  'get_budget_progress': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'budgets': _budgetRecordsField,
  }),
  'get_goal_summary': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'activeCount': _integerField,
    'completedCount': _integerField,
    'savedTotals': _savedTotalRecordsField,
    'nearestTargetDate': _dateField,
  }),
  'get_goal_progress': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'goals': _goalRecordsField,
  }),
  'get_cash_flow_trend': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'hasData': _booleanField,
    'currentNet': _decimalField,
    'previousNet': _decimalField,
    'currency': _currencyField,
    'partial': _booleanField,
    'sixMonthExpenseTrend': _decimalListField,
  }),
  'get_recurring_transactions':
      _FinancialToolSchema(<String, _FinancialFieldSchema>{
        'detectedPatternCount': _integerField,
        'periodStart': _dateField,
        'periodEnd': _dateField,
      }),
  'get_income_expense_breakdown':
      _FinancialToolSchema(<String, _FinancialFieldSchema>{
        'period': _tokenField,
        'income': _decimalField,
        'expense': _decimalField,
        'currency': _currencyField,
        'partial': _booleanField,
      }),
  'get_net_worth': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'amount': _decimalField,
    'currency': _currencyField,
    'partial': _booleanField,
  }),
  'get_accounts_summary': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'accounts': _accountRecordsField,
  }),
  'get_exchange_rate': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'from': _currencyField,
    'to': _currencyField,
    'rate': _decimalField,
    'asOf': _dateField,
  }),
  'search_transactions': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'transactions': _transactionRecordsField,
    'resultCount': _integerField,
    'bounded': _booleanField,
  }),
  'calculate_savings_rate': _FinancialToolSchema(
    <String, _FinancialFieldSchema>{
      'savings': _decimalField,
      'savingsRatePercent': _decimalField,
    },
  ),
  'project_month_end': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'projectedAmount': _decimalField,
  }),
  'simulate_budget_change': _FinancialToolSchema(
    <String, _FinancialFieldSchema>{'remaining': _decimalField},
  ),
  'calculate_goal_feasibility': _goalFeasibilitySchema,
  'forecast_goal_completion': _goalFeasibilitySchema,
  'calculate_safe_allowance': _FinancialToolSchema(
    <String, _FinancialFieldSchema>{'safeAllowance': _decimalField},
  ),
  'simulate_income_change': _FinancialToolSchema(
    <String, _FinancialFieldSchema>{'projectedCashFlow': _decimalField},
  ),
  'compare_scenarios': _FinancialToolSchema(<String, _FinancialFieldSchema>{
    'difference': _decimalField,
    'betterScenario': _tokenField,
  }),
  'convert_currency_amount': _FinancialToolSchema(
    <String, _FinancialFieldSchema>{
      'amount': _decimalField,
      'from': _currencyField,
      'to': _currencyField,
    },
  ),
};

final _decimalStringPattern = RegExp(r'^-?\d+(?:\.\d+)?$');
final _currencyPattern = RegExp(r'^[A-Z]{3}$');
final _safeTokenPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,39}$');
final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}(?:[T ][0-9:.+\-Z]+)?$');
final _promptInjectionLabelPattern = RegExp(
  r'\b(?:assistant|developer|disregard|expose|ignore|instruction|jailbreak|prompt|reveal|system)\b|(?:اظهر|اكشف|النظام|تجاهل|تعليمات)',
  caseSensitive: false,
);

/// Matches seven or more digits in one phone-shaped run, including Arabic
/// digit forms and common separators. Separate ordinary amounts such as
/// "500 LYD and 100 LYD" do not form one run and remain valid.
final _phoneLikeIdentifierPattern = RegExp(
  r'(?:\+|00)?[0-9\u0660-\u0669\u06F0-\u06F9]'
  r'(?:[ \t\u00A0()./-]{0,3}[0-9\u0660-\u0669\u06F0-\u06F9]){6,}',
);
