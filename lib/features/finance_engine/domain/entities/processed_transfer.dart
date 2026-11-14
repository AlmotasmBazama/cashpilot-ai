import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/exchange_rate.dart';
import '../value_objects/money.dart';

part 'processed_transfer.freezed.dart';
part 'processed_transfer.g.dart';

@freezed
abstract class ProcessedTransfer with _$ProcessedTransfer {
  const factory ProcessedTransfer({
    required String sourceAccountId,
    required String targetAccountId,
    required Money sourceAmount,
    required Money targetAmount,
    required Money sourcePreviousBalance,
    required Money sourceNewBalance,
    required Money targetPreviousBalance,
    required Money targetNewBalance,
    required ExchangeRate exchangeRate,
    required DateTime processedAt,
  }) = _ProcessedTransfer;

  factory ProcessedTransfer.fromJson(Map<String, dynamic> json) =>
      _$ProcessedTransferFromJson(json);
}
