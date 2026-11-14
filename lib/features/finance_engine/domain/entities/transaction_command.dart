import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums/finance_transaction_direction.dart';
import '../value_objects/money.dart';

part 'transaction_command.freezed.dart';
part 'transaction_command.g.dart';

@freezed
abstract class TransactionCommand with _$TransactionCommand {
  const factory TransactionCommand({
    required String accountId,
    required Money amount,
    required FinanceTransactionDirection direction,
    DateTime? occurredAt,
  }) = _TransactionCommand;

  factory TransactionCommand.fromJson(Map<String, dynamic> json) =>
      _$TransactionCommandFromJson(json);
}
