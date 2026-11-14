import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_message.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/entities/ai_provider_type.dart';
import '../../domain/entities/ai_request.dart';
import '../../domain/entities/ai_response.dart';
import 'ai_provider_data_source.dart';

class MockAiProviderDataSource implements AiProviderDataSource {
  const MockAiProviderDataSource();

  static const String defaultModelId = 'mock-cashpilot-finance-v1';

  @override
  AiProviderType get providerType => AiProviderType.mock;

  @override
  Future<List<AiModel>> getAvailableModels() async {
    return <AiModel>[
      AiModel(
        id: defaultModelId,
        providerType: providerType,
        displayName: 'Mock CashPilot Finance',
        capabilities: const <AiCapability>[
          AiCapability.chat,
          AiCapability.financialInsights,
          AiCapability.transactionParsing,
          AiCapability.spendingAnalysis,
          AiCapability.cashFlowExplanation,
        ],
        isDefault: true,
        maxInputTokens: 8192,
      ),
    ];
  }

  @override
  Future<AiResponse> sendMessage(AiRequest request) async {
    final latestUserMessage = request.messages.lastWhere(
      (message) => message.role == AiMessageRole.user,
      orElse: () =>
          AiMessage.user(conversationId: request.conversationId, content: ''),
    );
    final responseContent = _responseFor(latestUserMessage.content);
    final responseMessage = AiMessage.assistant(
      conversationId: request.conversationId,
      content: responseContent,
      metadata: <String, Object?>{
        'mock': true,
        'source': 'MockAiProviderDataSource',
      },
    );

    return AiResponse(
      message: responseMessage,
      providerType: providerType,
      modelId: request.modelId ?? defaultModelId,
      finishReason: AiFinishReason.complete,
      tokenUsage: AiTokenUsage(
        inputTokens: _estimateTokens(
          request.messages.map((message) => message.content).join(' '),
        ),
        outputTokens: _estimateTokens(responseContent),
      ),
      metadata: const <String, Object?>{'mock': true},
    );
  }

  String _responseFor(String input) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'Tell me what you want to understand about your finances.';
    }

    if (_containsAny(normalized, const <String>[
      'spending',
      'expense',
      'expenses',
      'مصروف',
      'مصروفات',
    ])) {
      return 'Your spending question was received. The mock AI layer is ready for a real provider to generate deeper analysis once connected.';
    }

    if (_containsAny(normalized, const <String>[
      'saving',
      'save',
      'savings',
      'وفر',
      'ادخار',
    ])) {
      return 'I can help identify savings opportunities using CashPilot data. This mock response confirms the provider-agnostic AI path is working.';
    }

    if (_containsAny(normalized, const <String>[
      'cash flow',
      'cashflow',
      'income',
      'دخل',
    ])) {
      return 'Cash flow analysis will run through this same AI contract when a production provider is added.';
    }

    return 'CashPilot AI received your message through the mock provider. The Firebase AI provider can use this same contract when selected.';
  }

  bool _containsAny(String value, List<String> tokens) {
    return tokens.any(value.contains);
  }

  int _estimateTokens(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 0;
    }

    return (trimmed.split(RegExp(r'\s+')).length * 1.3).ceil();
  }
}
