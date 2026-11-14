import '../../../../core/error/result.dart';
import '../entities/data_deletion_request.dart';

abstract interface class DataDeletionRepository {
  Future<AppResult<DataDeletionReport>> deleteAllUserData(
    DataDeletionRequest request,
  );
}
