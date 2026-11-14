import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/entities/ai_provider_type.dart';
import '../../domain/entities/ai_request.dart';
import '../../domain/entities/ai_response.dart';
import '../../domain/failures/ai_failure_codes.dart';
import 'ai_provider_data_source.dart';

class LocalParserOnlyAiProviderDataSource implements AiProviderDataSource {
  const LocalParserOnlyAiProviderDataSource();

  static const String modelId = 'cashpilot-local-parser-v1';

  @override
  AiProviderType get providerType => AiProviderType.localParser;

  @override
  Future<List<AiModel>> getAvailableModels() async {
    return <AiModel>[
      AiModel(
        id: modelId,
        providerType: AiProviderType.localParser,
        displayName: 'CashPilot local parser',
        capabilities: <AiCapability>[AiCapability.transactionParsing],
        isDefault: true,
        maxInputTokens: 512,
      ),
    ];
  }

  @override
  Future<AiResponse> sendMessage(AiRequest request) {
    throw const AiProviderException(
      code: AiFailureCodes.localParserOnly,
      message: 'Remote AI is disabled for this runtime.',
    );
  }
}
