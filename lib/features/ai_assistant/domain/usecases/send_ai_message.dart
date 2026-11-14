import '../../../../core/error/result.dart';
import '../entities/ai_request.dart';
import '../entities/ai_response.dart';
import '../repositories/ai_repository.dart';

class SendAiMessage {
  const SendAiMessage(this._repository);

  final AiRepository _repository;

  Future<AppResult<AiResponse>> call(AiRequest request) {
    return _repository.sendMessage(request);
  }
}
