enum ModelTask {
  localConversation,
  generalConversation,
  groundedCurrentKnowledge,
  financialCommandExtraction,
  personalFinancialAnalysis,
  complexFinancialPlanning,
  receiptAnalysis,
  // Compatibility values for the first financial-agent iteration. New routing
  // uses the task-specific values above.
  conversation,
  commandUnderstanding,
  financialAnalysis,
  complexPlanning,
}

typedef AiAgentTaskClass = ModelTask;

enum AiAgentMessageRole { user, assistant }

enum AiAgentResponseKind {
  answer,
  clarification,
  refusal,
  actionDraft,
  navigation,
  failure,
}

enum AssistantTurnKind {
  directConversation,
  groundedKnowledge,
  personalFinancialAnalysis,
  financialActionDraft,
  appNavigation,
  receiptAction,
  clarification,
  blocked,
  failure,
}

class AiAgentLimits {
  const AiAgentLimits({
    this.maxRounds = 4,
    this.maxCallsPerRound = 6,
    this.maxCallsPerRequest = 12,
    this.toolTimeout = const Duration(seconds: 5),
    this.requestTimeout = const Duration(seconds: 45),
    this.maxConversationTurns = 8,
    this.maxSearchResults = 20,
  });

  final int maxRounds;
  final int maxCallsPerRound;
  final int maxCallsPerRequest;
  final Duration toolTimeout;
  final Duration requestTimeout;
  final int maxConversationTurns;
  final int maxSearchResults;
}

class AiAgentEvidence {
  const AiAgentEvidence({
    required this.toolName,
    required this.summary,
    this.period,
    this.isPartial = false,
  });

  final String toolName;
  final String summary;
  final String? period;
  final bool isPartial;
}

class GroundedSource {
  const GroundedSource({
    required this.title,
    required this.uri,
    required this.domain,
    this.supportingText,
  });

  final String title;
  final Uri uri;
  final String domain;
  final String? supportingText;
}

class AiAgentMessage {
  const AiAgentMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final AiAgentMessageRole role;
  final String content;
  final DateTime createdAt;

  Map<String, Object?> toSafeJson() => <String, Object?>{
    'role': role.name,
    'content': content,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static AiAgentMessage? fromSafeJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final role = AiAgentMessageRole.values
        .where((item) => item.name == value['role'])
        .firstOrNull;
    final content = value['content'];
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    if (role == null || content is! String || createdAt == null) {
      return null;
    }
    return AiAgentMessage(
      role: role,
      content: content,
      createdAt: createdAt.toUtc(),
    );
  }
}

class AiAgentSessionMemory {
  const AiAgentSessionMemory({
    this.messages = const <AiAgentMessage>[],
    this.compactedSummary,
    this.activeTopic,
    this.activeCategory,
    this.activeAccount,
    this.activeBudget,
    this.activeGoal,
    this.activePeriod,
    this.updatedAt,
  });

  final List<AiAgentMessage> messages;
  final String? compactedSummary;
  final String? activeTopic;
  final String? activeCategory;
  final String? activeAccount;
  final String? activeBudget;
  final String? activeGoal;
  final String? activePeriod;
  final DateTime? updatedAt;

  AiAgentSessionMemory copyWith({
    List<AiAgentMessage>? messages,
    String? compactedSummary,
    String? activeTopic,
    String? activeCategory,
    String? activeAccount,
    String? activeBudget,
    String? activeGoal,
    String? activePeriod,
    DateTime? updatedAt,
    bool clearSummary = false,
  }) {
    return AiAgentSessionMemory(
      messages: messages ?? this.messages,
      compactedSummary: clearSummary
          ? null
          : compactedSummary ?? this.compactedSummary,
      activeTopic: activeTopic ?? this.activeTopic,
      activeCategory: activeCategory ?? this.activeCategory,
      activeAccount: activeAccount ?? this.activeAccount,
      activeBudget: activeBudget ?? this.activeBudget,
      activeGoal: activeGoal ?? this.activeGoal,
      activePeriod: activePeriod ?? this.activePeriod,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toSafeJson() => <String, Object?>{
    'messages': messages.map((item) => item.toSafeJson()).toList(),
    'compactedSummary': compactedSummary,
    'activeTopic': activeTopic,
    'activeCategory': activeCategory,
    'activeAccount': activeAccount,
    'activeBudget': activeBudget,
    'activeGoal': activeGoal,
    'activePeriod': activePeriod,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  static AiAgentSessionMemory fromSafeJson(Object? value) {
    if (value is! Map) {
      return const AiAgentSessionMemory();
    }
    final messages = (value['messages'] as List? ?? const <Object?>[])
        .map(AiAgentMessage.fromSafeJson)
        .whereType<AiAgentMessage>()
        .toList(growable: false);
    return AiAgentSessionMemory(
      messages: messages,
      compactedSummary: value['compactedSummary'] as String?,
      activeTopic: value['activeTopic'] as String?,
      activeCategory: value['activeCategory'] as String?,
      activeAccount: value['activeAccount'] as String?,
      activeBudget: value['activeBudget'] as String?,
      activeGoal: value['activeGoal'] as String?,
      activePeriod: value['activePeriod'] as String?,
      updatedAt: DateTime.tryParse(value['updatedAt']?.toString() ?? ''),
    );
  }
}

class AiAgentRequest {
  const AiAgentRequest({
    required this.message,
    required this.locale,
    required this.baseCurrencyCode,
    this.allowComplexPlanning = false,
  });

  final String message;
  final String locale;
  final String baseCurrencyCode;
  final bool allowComplexPlanning;
}

class AssistantTurnResult {
  const AssistantTurnResult({
    required this.turnKind,
    required this.message,
    this.evidence = const <AiAgentEvidence>[],
    this.followUpPrompts = const <String>[],
    this.executedToolNames = const <String>[],
    this.sources = const <GroundedSource>[],
    this.searchEntryPointRenderedContent,
    this.responseDate,
    this.warnings = const <String>[],
    this.navigationPath,
    this.actionDraft,
    this.isPartial = false,
  });

  final AssistantTurnKind turnKind;
  final String message;
  final List<AiAgentEvidence> evidence;
  final List<String> followUpPrompts;
  final List<String> executedToolNames;
  final List<GroundedSource> sources;
  final String? searchEntryPointRenderedContent;
  final DateTime? responseDate;
  final List<String> warnings;
  final String? navigationPath;
  final Map<String, Object?>? actionDraft;
  final bool isPartial;
}

class AiAgentResponse extends AssistantTurnResult {
  const AiAgentResponse({
    required this.kind,
    required super.message,
    super.turnKind = AssistantTurnKind.directConversation,
    super.evidence,
    super.followUpPrompts,
    super.executedToolNames,
    super.sources,
    super.searchEntryPointRenderedContent,
    super.responseDate,
    super.warnings,
    super.navigationPath,
    super.actionDraft,
    super.isPartial,
    this.retryable,
  });

  final AiAgentResponseKind kind;
  final bool? retryable;
}

class AiAgentToolCall {
  const AiAgentToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, Object?> arguments;
}

class AiAgentModelTurn {
  const AiAgentModelTurn({
    this.text,
    this.toolCalls = const <AiAgentToolCall>[],
    this.sources = const <GroundedSource>[],
    this.searchEntryPointRenderedContent,
    this.responseDate,
    this.warnings = const <String>[],
  });

  final String? text;
  final List<AiAgentToolCall> toolCalls;
  final List<GroundedSource> sources;
  final String? searchEntryPointRenderedContent;
  final DateTime? responseDate;
  final List<String> warnings;
}

class AiAgentModelRequest {
  const AiAgentModelRequest({
    required this.userMessage,
    required this.systemInstruction,
    required this.memoryContext,
    required this.taskClass,
    this.locale = 'en',
    this.baseCurrencyCode = '',
    this.conversationHistory = const <AiAgentMessage>[],
    this.compactMemorySummary,
  });

  final String userMessage;
  final String systemInstruction;
  final String memoryContext;
  final ModelTask taskClass;
  final String locale;
  final String baseCurrencyCode;
  final List<AiAgentMessage> conversationHistory;
  final String? compactMemorySummary;
}
