import '../../../../core/error/result.dart';
import '../entities/create_transfer_command.dart';
import '../entities/created_transfer.dart';

/// Executes the atomic, replay-safe creation of a transfer pair.
///
/// This narrow port keeps the repository contract as the public feature API
/// while allowing the transfer write workflow to evolve independently from
/// ordinary transaction persistence.
abstract interface class TransferCreationWorkflow {
  Future<AppResult<CreatedTransfer>> create(CreateTransferCommand command);
}
