import '../../../../core/error/result.dart';
import '../entities/data_deletion_request.dart';
import '../repositories/data_deletion_repository.dart';

class DeleteAllUserData {
  const DeleteAllUserData(this._repository);

  final DataDeletionRepository _repository;

  Future<AppResult<DataDeletionReport>> call(DataDeletionRequest request) {
    return _repository.deleteAllUserData(request);
  }
}
