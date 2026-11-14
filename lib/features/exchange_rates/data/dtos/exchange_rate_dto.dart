import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_rate_dto.freezed.dart';
part 'exchange_rate_dto.g.dart';

@freezed
abstract class ExchangeRateDto with _$ExchangeRateDto {
  const factory ExchangeRateDto({
    required String id,
    required String baseCurrency,
    required String quoteCurrency,
    required String rate,
    required String source,
    required DateTime fetchedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) = _ExchangeRateDto;

  factory ExchangeRateDto.fromJson(Map<String, dynamic> json) =>
      _$ExchangeRateDtoFromJson(json);
}
