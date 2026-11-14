import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_dto.freezed.dart';
part 'transaction_dto.g.dart';

@freezed
abstract class TransactionDto with _$TransactionDto {
  const factory TransactionDto({
    required String id,
    required String accountId,
    required String categoryId,
    String? payeeId,
    required String amount,
    required String currencyCode,
    required String type,
    required String paymentMethod,
    required String source,
    required String status,
    String? incomeSourceType,
    String? transferGroupId,
    String? exchangeRateFromCurrencyCode,
    String? exchangeRateToCurrencyCode,
    String? exchangeRate,
    DateTime? exchangeRateAsOf,
    String? note,
    required DateTime transactionDate,
    String? location,
    required int attachmentCount,
    int? aiConfidence,
    required bool needsReview,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _TransactionDto;

  factory TransactionDto.fromJson(Map<String, dynamic> json) =>
      _$TransactionDtoFromJson(json);
}
