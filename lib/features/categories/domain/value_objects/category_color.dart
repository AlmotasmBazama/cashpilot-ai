import 'package:freezed_annotation/freezed_annotation.dart';

part 'category_color.freezed.dart';
part 'category_color.g.dart';

@freezed
abstract class CategoryColor with _$CategoryColor {
  const factory CategoryColor({required int argb}) = _CategoryColor;

  factory CategoryColor.fromJson(Map<String, dynamic> json) =>
      _$CategoryColorFromJson(json);
}
