// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payee_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PayeeDto {

 String get id; String get name; String get normalizedName; String get type; List<String> get aliases; String? get defaultCategoryId; String? get defaultAccountId; String? get notes; DateTime? get lastUsedAt; DateTime get createdAt; DateTime get updatedAt; DateTime? get archivedAt;
/// Create a copy of PayeeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PayeeDtoCopyWith<PayeeDto> get copyWith => _$PayeeDtoCopyWithImpl<PayeeDto>(this as PayeeDto, _$identity);

  /// Serializes this PayeeDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PayeeDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.normalizedName, normalizedName) || other.normalizedName == normalizedName)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.aliases, aliases)&&(identical(other.defaultCategoryId, defaultCategoryId) || other.defaultCategoryId == defaultCategoryId)&&(identical(other.defaultAccountId, defaultAccountId) || other.defaultAccountId == defaultAccountId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,normalizedName,type,const DeepCollectionEquality().hash(aliases),defaultCategoryId,defaultAccountId,notes,lastUsedAt,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'PayeeDto(id: $id, name: $name, normalizedName: $normalizedName, type: $type, aliases: $aliases, defaultCategoryId: $defaultCategoryId, defaultAccountId: $defaultAccountId, notes: $notes, lastUsedAt: $lastUsedAt, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $PayeeDtoCopyWith<$Res>  {
  factory $PayeeDtoCopyWith(PayeeDto value, $Res Function(PayeeDto) _then) = _$PayeeDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String normalizedName, String type, List<String> aliases, String? defaultCategoryId, String? defaultAccountId, String? notes, DateTime? lastUsedAt, DateTime createdAt, DateTime updatedAt, DateTime? archivedAt
});




}
/// @nodoc
class _$PayeeDtoCopyWithImpl<$Res>
    implements $PayeeDtoCopyWith<$Res> {
  _$PayeeDtoCopyWithImpl(this._self, this._then);

  final PayeeDto _self;
  final $Res Function(PayeeDto) _then;

/// Create a copy of PayeeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? normalizedName = null,Object? type = null,Object? aliases = null,Object? defaultCategoryId = freezed,Object? defaultAccountId = freezed,Object? notes = freezed,Object? lastUsedAt = freezed,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,normalizedName: null == normalizedName ? _self.normalizedName : normalizedName // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,aliases: null == aliases ? _self.aliases : aliases // ignore: cast_nullable_to_non_nullable
as List<String>,defaultCategoryId: freezed == defaultCategoryId ? _self.defaultCategoryId : defaultCategoryId // ignore: cast_nullable_to_non_nullable
as String?,defaultAccountId: freezed == defaultAccountId ? _self.defaultAccountId : defaultAccountId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PayeeDto].
extension PayeeDtoPatterns on PayeeDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PayeeDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PayeeDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PayeeDto value)  $default,){
final _that = this;
switch (_that) {
case _PayeeDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PayeeDto value)?  $default,){
final _that = this;
switch (_that) {
case _PayeeDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String normalizedName,  String type,  List<String> aliases,  String? defaultCategoryId,  String? defaultAccountId,  String? notes,  DateTime? lastUsedAt,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PayeeDto() when $default != null:
return $default(_that.id,_that.name,_that.normalizedName,_that.type,_that.aliases,_that.defaultCategoryId,_that.defaultAccountId,_that.notes,_that.lastUsedAt,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String normalizedName,  String type,  List<String> aliases,  String? defaultCategoryId,  String? defaultAccountId,  String? notes,  DateTime? lastUsedAt,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt)  $default,) {final _that = this;
switch (_that) {
case _PayeeDto():
return $default(_that.id,_that.name,_that.normalizedName,_that.type,_that.aliases,_that.defaultCategoryId,_that.defaultAccountId,_that.notes,_that.lastUsedAt,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String normalizedName,  String type,  List<String> aliases,  String? defaultCategoryId,  String? defaultAccountId,  String? notes,  DateTime? lastUsedAt,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _PayeeDto() when $default != null:
return $default(_that.id,_that.name,_that.normalizedName,_that.type,_that.aliases,_that.defaultCategoryId,_that.defaultAccountId,_that.notes,_that.lastUsedAt,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PayeeDto implements PayeeDto {
  const _PayeeDto({required this.id, required this.name, required this.normalizedName, required this.type, final  List<String> aliases = const <String>[], this.defaultCategoryId, this.defaultAccountId, this.notes, this.lastUsedAt, required this.createdAt, required this.updatedAt, this.archivedAt}): _aliases = aliases;
  factory _PayeeDto.fromJson(Map<String, dynamic> json) => _$PayeeDtoFromJson(json);

@override final  String id;
@override final  String name;
@override final  String normalizedName;
@override final  String type;
 final  List<String> _aliases;
@override@JsonKey() List<String> get aliases {
  if (_aliases is EqualUnmodifiableListView) return _aliases;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_aliases);
}

@override final  String? defaultCategoryId;
@override final  String? defaultAccountId;
@override final  String? notes;
@override final  DateTime? lastUsedAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime? archivedAt;

/// Create a copy of PayeeDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PayeeDtoCopyWith<_PayeeDto> get copyWith => __$PayeeDtoCopyWithImpl<_PayeeDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PayeeDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PayeeDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.normalizedName, normalizedName) || other.normalizedName == normalizedName)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._aliases, _aliases)&&(identical(other.defaultCategoryId, defaultCategoryId) || other.defaultCategoryId == defaultCategoryId)&&(identical(other.defaultAccountId, defaultAccountId) || other.defaultAccountId == defaultAccountId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,normalizedName,type,const DeepCollectionEquality().hash(_aliases),defaultCategoryId,defaultAccountId,notes,lastUsedAt,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'PayeeDto(id: $id, name: $name, normalizedName: $normalizedName, type: $type, aliases: $aliases, defaultCategoryId: $defaultCategoryId, defaultAccountId: $defaultAccountId, notes: $notes, lastUsedAt: $lastUsedAt, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$PayeeDtoCopyWith<$Res> implements $PayeeDtoCopyWith<$Res> {
  factory _$PayeeDtoCopyWith(_PayeeDto value, $Res Function(_PayeeDto) _then) = __$PayeeDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String normalizedName, String type, List<String> aliases, String? defaultCategoryId, String? defaultAccountId, String? notes, DateTime? lastUsedAt, DateTime createdAt, DateTime updatedAt, DateTime? archivedAt
});




}
/// @nodoc
class __$PayeeDtoCopyWithImpl<$Res>
    implements _$PayeeDtoCopyWith<$Res> {
  __$PayeeDtoCopyWithImpl(this._self, this._then);

  final _PayeeDto _self;
  final $Res Function(_PayeeDto) _then;

/// Create a copy of PayeeDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? normalizedName = null,Object? type = null,Object? aliases = null,Object? defaultCategoryId = freezed,Object? defaultAccountId = freezed,Object? notes = freezed,Object? lastUsedAt = freezed,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = freezed,}) {
  return _then(_PayeeDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,normalizedName: null == normalizedName ? _self.normalizedName : normalizedName // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,aliases: null == aliases ? _self._aliases : aliases // ignore: cast_nullable_to_non_nullable
as List<String>,defaultCategoryId: freezed == defaultCategoryId ? _self.defaultCategoryId : defaultCategoryId // ignore: cast_nullable_to_non_nullable
as String?,defaultAccountId: freezed == defaultAccountId ? _self.defaultAccountId : defaultAccountId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
