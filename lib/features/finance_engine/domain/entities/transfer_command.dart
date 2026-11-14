import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/exchange_rate.dart';
import '../value_objects/money.dart';

part 'transfer_command.freezed.dart';
part 'transfer_command.g.dart';

@freezed
abstract class TransferCommand with _$TransferCommand {
  const factory TransferCommand({
    required String sourceAccountId,
    required String targetAccountId,
    required Money sourceAmount,
    Money? targetAmount,
    ExchangeRate? exchangeRate,
    DateTime? occurredAt,
  }) = _TransferCommand;

  factory TransferCommand.fromJson(Map<String, dynamic> json) =>
      _$TransferCommandFromJson(json);
}
