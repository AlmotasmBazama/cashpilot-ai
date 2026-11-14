import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/entities/ai_request.dart';
import '../../domain/entities/ai_response.dart';
import '../../domain/failures/ai_failure_codes.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/ai_provider_data_source.dart';

class AiRepositoryImpl implements AiRepository {
  const AiRepositoryImpl({
    required AiProviderDataSource providerDataSource,
    required AppLogger logger,
    void Function(String message)? safeErrorLog,
  }) : _providerDataSource = providerDataSource,
       _logger = logger,
       _safeErrorLog = safeErrorLog;

  final AiProviderDataSource _providerDataSource;
  final AppLogger _logger;
  final void Function(String message)? _safeErrorLog;

  @override
  Future<AppResult<List<AiModel>>> getAvailableModels() async {
    try {
      final models = await _providerDataSource.getAvailableModels();
      return AppResult.success(models);
    } on Object catch (error) {
      return _failure('Unable to load AI models.', error);
    }
  }

  @override
  Future<AppResult<AiResponse>> sendMessage(AiRequest request) async {
    try {
      final response = await _providerDataSource.sendMessage(request);
      return AppResult.success(response);
    } on Object catch (error) {
      return _failure('Unable to send AI message.', error);
    }
  }

  AppResult<T> _failure<T>(String message, Object error) {
    final providerError = error is AiProviderException ? error : null;
    final failureMessage = providerError?.message ?? message;
    if (providerError?.code != AiFailureCodes.localParserOnly) {
      final safeCode = providerError?.code ?? AiFailureCodes.unknown;
      final safeMessage =
          'AI provider operation failed safely '
          '(code: $safeCode, type: ${error.runtimeType}).';
      final safeErrorLog = _safeErrorLog;
      if (safeErrorLog != null) {
        safeErrorLog(safeMessage);
      } else {
        _logger.error(safeMessage);
      }
    }
    return AppResult.failure(
      Failure(message: failureMessage, code: providerError?.code),
    );
  }
}
