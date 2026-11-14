import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';
import 'groq_gateway_data_source.dart';

class GroqConversationGateway implements AiConversationGateway {
  const GroqConversationGateway(this._dataSource);

  final GroqGatewayDataSource _dataSource;

  @override
  Stream<AiGatewayEvent> streamGeneralConversation(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) =>
      _dataSource.streamGeneralConversation(request, egressGuard: egressGuard);

  @override
  Stream<AiGatewayEvent> streamFinancialExplanation(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) =>
      _dataSource.streamFinancialExplanation(request, egressGuard: egressGuard);

  @override
  Future<AiGatewayToolSelection> selectGovernedTools(
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) => _dataSource.selectGovernedTools(request, egressGuard: egressGuard);

  @override
  Future<AiGatewayHealth> healthCheck() => _dataSource.healthCheck();
}
