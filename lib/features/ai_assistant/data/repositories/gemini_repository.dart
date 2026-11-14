import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/entities/ai_request.dart';
import '../../domain/entities/ai_response.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/firebase_ai_provider_data_source.dart';
import 'ai_repository_impl.dart';

class GeminiRepository implements AiRepository {
  GeminiRepository({
    required FirebaseAiProviderDataSource providerDataSource,
    required AppLogger logger,
  }) : _delegate = AiRepositoryImpl(
         providerDataSource: providerDataSource,
         logger: logger,
       );

  final AiRepositoryImpl _delegate;

  @override
  Future<AppResult<List<AiModel>>> getAvailableModels() {
    return _delegate.getAvailableModels();
  }

  @override
  Future<AppResult<AiResponse>> sendMessage(AiRequest request) {
    return _delegate.sendMessage(request);
  }
}
