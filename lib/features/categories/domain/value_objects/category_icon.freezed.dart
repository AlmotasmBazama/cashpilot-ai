// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category_icon.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CategoryIcon {

 String get key;
/// Create a copy of CategoryIcon
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryIconCopyWith<CategoryIcon> get copyWith => _$CategoryIconCopyWithImpl<CategoryIcon>(this as CategoryIcon, _$identity);

  /// Serializes this CategoryIcon to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryIcon&&(identical(other.key, key) || other.key == key));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key);

@override
String toString() {
  return 'CategoryIcon(key: $key)';
}


}

/// @nodoc
abstract mixin class $CategoryIconCopyWith<$Res>  {
  factory $CategoryIconCopyWith(CategoryIcon value, $Res Function(CategoryIcon) _then) = _$CategoryIconCopyWithImpl;
@useResult
$Res call({
 String key
});




}
/// @nodoc
class _$CategoryIconCopyWithImpl<$Res>
    implements $CategoryIconCopyWith<$Res> {
  _$CategoryIconCopyWithImpl(this._self, this._then);

  final CategoryIcon _self;
  final $Res Function(CategoryIcon) _then;

/// Create a copy of CategoryIcon
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CategoryIcon].
extension CategoryIconPatterns on CategoryIcon {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CategoryIcon value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CategoryIcon() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CategoryIcon value)  $default,){
final _that = this;
switch (_that) {
case _CategoryIcon():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CategoryIcon value)?  $default,){
final _that = this;
switch (_that) {
case _CategoryIcon() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CategoryIcon() when $default != null:
return $default(_that.key);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key)  $default,) {final _that = this;
switch (_that) {
case _CategoryIcon():
return $default(_that.key);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key)?  $default,) {final _that = this;
switch (_that) {
case _CategoryIcon() when $default != null:
return $default(_that.key);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CategoryIcon implements CategoryIcon {
  const _CategoryIcon({required this.key});
  factory _CategoryIcon.fromJson(Map<String, dynamic> json) => _$CategoryIconFromJson(json);

@override final  String key;

/// Create a copy of CategoryIcon
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CategoryIconCopyWith<_CategoryIcon> get copyWith => __$CategoryIconCopyWithImpl<_CategoryIcon>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CategoryIconToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CategoryIcon&&(identical(other.key, key) || other.key == key));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key);

@override
String toString() {
  return 'CategoryIcon(key: $key)';
}


}

/// @nodoc
abstract mixin class _$CategoryIconCopyWith<$Res> implements $CategoryIconCopyWith<$Res> {
  factory _$CategoryIconCopyWith(_CategoryIcon value, $Res Function(_CategoryIcon) _then) = __$CategoryIconCopyWithImpl;
@override @useResult
$Res call({
 String key
});




}
/// @nodoc
class __$CategoryIconCopyWithImpl<$Res>
    implements _$CategoryIconCopyWith<$Res> {
  __$CategoryIconCopyWithImpl(this._self, this._then);

  final _CategoryIcon _self;
  final $Res Function(_CategoryIcon) _then;

/// Create a copy of CategoryIcon
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,}) {
  return _then(_CategoryIcon(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
