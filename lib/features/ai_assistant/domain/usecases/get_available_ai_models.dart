import '../../../../core/error/result.dart';
import '../entities/ai_model.dart';
import '../repositories/ai_repository.dart';

class GetAvailableAiModels {
  const GetAvailableAiModels(this._repository);

  final AiRepository _repository;

  Future<AppResult<List<AiModel>>> call() {
    return _repository.getAvailableModels();
  }
}
