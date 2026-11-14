import '../../domain/entities/ai_model.dart';
import '../../domain/entities/ai_provider_type.dart';
import '../../domain/entities/ai_request.dart';
import '../../domain/entities/ai_response.dart';

class AiProviderException implements Exception {
  const AiProviderException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}

abstract interface class AiProviderDataSource {
  AiProviderType get providerType;

  Future<List<AiModel>> getAvailableModels();

  Future<AiResponse> sendMessage(AiRequest request);
}
