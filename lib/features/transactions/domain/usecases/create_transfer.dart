import '../../../../core/error/result.dart';
import '../entities/create_transfer_command.dart';
import '../entities/created_transfer.dart';
import '../repositories/transactions_repository.dart';

class CreateTransfer {
  const CreateTransfer(this._repository);

  final TransactionsRepository _repository;

  Future<AppResult<CreatedTransfer>> call(CreateTransferCommand command) {
    return _repository.createTransfer(command);
  }
}
