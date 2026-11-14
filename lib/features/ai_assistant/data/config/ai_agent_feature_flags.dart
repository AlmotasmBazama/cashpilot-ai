import 'package:flutter/foundation.dart';

class AiAgentFeatureFlags {
  const AiAgentFeatureFlags({
    required this.agentEnabled,
    required this.readOnlyToolsEnabled,
    required this.draftToolsEnabled,
    required this.conversationMemoryEnabled,
    required this.complexPlanningEnabled,
  });

  static final AiAgentFeatureFlags current = AiAgentFeatureFlags.resolve(
    agentValue: const String.fromEnvironment('CASH_PILOT_AI_AGENT_ENABLED'),
    readOnlyValue: const String.fromEnvironment(
      'CASH_PILOT_AI_READ_ONLY_TOOLS_ENABLED',
    ),
    draftValue: const String.fromEnvironment(
      'CASH_PILOT_AI_DRAFT_TOOLS_ENABLED',
    ),
    memoryValue: const String.fromEnvironment(
      'CASH_PILOT_AI_CONVERSATION_MEMORY_ENABLED',
    ),
    complexPlanningValue: const String.fromEnvironment(
      'CASH_PILOT_AI_COMPLEX_PLANNING_ENABLED',
    ),
    isReleaseMode: kReleaseMode,
  );

  final bool agentEnabled;
  final bool readOnlyToolsEnabled;
  final bool draftToolsEnabled;
  final bool conversationMemoryEnabled;
  final bool complexPlanningEnabled;

  factory AiAgentFeatureFlags.resolve({
    String agentValue = '',
    String readOnlyValue = '',
    String draftValue = '',
    String memoryValue = '',
    String complexPlanningValue = '',
    bool isReleaseMode = false,
  }) {
    return AiAgentFeatureFlags(
      agentEnabled: _flag(agentValue, fallback: true),
      readOnlyToolsEnabled: _flag(readOnlyValue, fallback: true),
      draftToolsEnabled: _flag(draftValue, fallback: !isReleaseMode),
      conversationMemoryEnabled: _flag(memoryValue, fallback: true),
      complexPlanningEnabled: _flag(complexPlanningValue, fallback: false),
    );
  }

  static bool _flag(String value, {required bool fallback}) {
    return switch (value.trim().toLowerCase()) {
      '1' || 'true' || 'yes' || 'on' => true,
      '0' || 'false' || 'no' || 'off' => false,
      _ => fallback,
    };
  }
}
