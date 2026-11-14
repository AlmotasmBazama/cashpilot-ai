import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_dto.freezed.dart';
part 'account_dto.g.dart';

@freezed
abstract class AccountDto with _$AccountDto {
  const factory AccountDto({
    required String id,
    required String name,
    required String type,
    required String currencyCode,
    required String balance,
    required String icon,
    required int color,
    @Default(<String>[]) List<String> paymentMethodIds,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AccountDto;

  factory AccountDto.fromJson(Map<String, dynamic> json) =>
      _$AccountDtoFromJson(json);
}
