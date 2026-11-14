import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';
import 'groq_gateway_client.dart';

class GroqGatewayDataSource {
  const GroqGatewayDataSource(this._client);

  final GroqGatewayClient _client;

  Stream<AiGatewayEvent> streamGeneralConversation(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) async* {
    egressGuard.assertActive();
    yield* _client.streamRequest(
      '/v1/ai/general-chat',
      request,
      egressGuard: egressGuard,
    );
  }

  Stream<AiGatewayEvent> streamFinancialExplanation(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) async* {
    egressGuard.assertActive();
    yield* _client.streamRequest(
      '/v1/ai/financial-explanation',
      request,
      egressGuard: egressGuard,
    );
  }

  Future<AiGatewayToolSelection> selectGovernedTools(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) async {
    AiGatewayToolSelection? selection;
    egressGuard.assertActive();
    await for (final event in _client.streamRequest(
      '/v1/ai/tool-selection',
      request,
      egressGuard: egressGuard,
    )) {
      selection = event.toolSelection ?? selection;
    }
    if (selection == null) {
      throw const AiGatewayException(
        code: AiGatewayFailureCode.toolSelectionInvalid,
        safeMessage: 'The gateway returned no valid tool selection.',
      );
    }
    return selection;
  }

  Future<AiGatewayHealth> healthCheck() => _client.healthCheck();
}
