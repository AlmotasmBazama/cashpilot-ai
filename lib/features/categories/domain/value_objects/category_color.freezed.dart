// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category_color.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CategoryColor {

 int get argb;
/// Create a copy of CategoryColor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryColorCopyWith<CategoryColor> get copyWith => _$CategoryColorCopyWithImpl<CategoryColor>(this as CategoryColor, _$identity);

  /// Serializes this CategoryColor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryColor&&(identical(other.argb, argb) || other.argb == argb));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,argb);

@override
String toString() {
  return 'CategoryColor(argb: $argb)';
}


}

/// @nodoc
abstract mixin class $CategoryColorCopyWith<$Res>  {
  factory $CategoryColorCopyWith(CategoryColor value, $Res Function(CategoryColor) _then) = _$CategoryColorCopyWithImpl;
@useResult
$Res call({
 int argb
});




}
/// @nodoc
class _$CategoryColorCopyWithImpl<$Res>
    implements $CategoryColorCopyWith<$Res> {
  _$CategoryColorCopyWithImpl(this._self, this._then);

  final CategoryColor _self;
  final $Res Function(CategoryColor) _then;

/// Create a copy of CategoryColor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? argb = null,}) {
  return _then(_self.copyWith(
argb: null == argb ? _self.argb : argb // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CategoryColor].
extension CategoryColorPatterns on CategoryColor {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CategoryColor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CategoryColor() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CategoryColor value)  $default,){
final _that = this;
switch (_that) {
case _CategoryColor():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CategoryColor value)?  $default,){
final _that = this;
switch (_that) {
case _CategoryColor() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int argb)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CategoryColor() when $default != null:
return $default(_that.argb);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int argb)  $default,) {final _that = this;
switch (_that) {
case _CategoryColor():
return $default(_that.argb);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int argb)?  $default,) {final _that = this;
switch (_that) {
case _CategoryColor() when $default != null:
return $default(_that.argb);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CategoryColor implements CategoryColor {
  const _CategoryColor({required this.argb});
  factory _CategoryColor.fromJson(Map<String, dynamic> json) => _$CategoryColorFromJson(json);

@override final  int argb;

/// Create a copy of CategoryColor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CategoryColorCopyWith<_CategoryColor> get copyWith => __$CategoryColorCopyWithImpl<_CategoryColor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CategoryColorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CategoryColor&&(identical(other.argb, argb) || other.argb == argb));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,argb);

@override
String toString() {
  return 'CategoryColor(argb: $argb)';
}


}

/// @nodoc
abstract mixin class _$CategoryColorCopyWith<$Res> implements $CategoryColorCopyWith<$Res> {
  factory _$CategoryColorCopyWith(_CategoryColor value, $Res Function(_CategoryColor) _then) = __$CategoryColorCopyWithImpl;
@override @useResult
$Res call({
 int argb
});




}
/// @nodoc
class __$CategoryColorCopyWithImpl<$Res>
    implements _$CategoryColorCopyWith<$Res> {
  __$CategoryColorCopyWithImpl(this._self, this._then);

  final _CategoryColor _self;
  final $Res Function(_CategoryColor) _then;

/// Create a copy of CategoryColor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? argb = null,}) {
  return _then(_CategoryColor(
argb: null == argb ? _self.argb : argb // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
