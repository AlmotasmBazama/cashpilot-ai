import '../../../../core/error/result.dart';
import '../repositories/receipt_repository.dart';

class DeleteReceiptImageUseCase {
  const DeleteReceiptImageUseCase(this._repository);

  final ReceiptRepository _repository;

  Future<AppResult<void>> call(String receiptId) {
    return _repository.deleteLocalImage(receiptId);
  }
}
