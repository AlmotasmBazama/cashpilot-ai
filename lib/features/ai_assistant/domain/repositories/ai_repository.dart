import '../../../../core/error/result.dart';
import '../entities/ai_model.dart';
import '../entities/ai_request.dart';
import '../entities/ai_response.dart';

abstract interface class AiRepository {
  Future<AppResult<List<AiModel>>> getAvailableModels();

  Future<AppResult<AiResponse>> sendMessage(AiRequest request);
}
