// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountDto {

 String get id; String get name; String get type; String get currencyCode; String get balance; String get icon; int get color; List<String> get paymentMethodIds; bool get isArchived; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of AccountDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountDtoCopyWith<AccountDto> get copyWith => _$AccountDtoCopyWithImpl<AccountDto>(this as AccountDto, _$identity);

  /// Serializes this AccountDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.color, color) || other.color == color)&&const DeepCollectionEquality().equals(other.paymentMethodIds, paymentMethodIds)&&(identical(other.isArchived, isArchived) || other.isArchived == isArchived)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,currencyCode,balance,icon,color,const DeepCollectionEquality().hash(paymentMethodIds),isArchived,createdAt,updatedAt);

@override
String toString() {
  return 'AccountDto(id: $id, name: $name, type: $type, currencyCode: $currencyCode, balance: $balance, icon: $icon, color: $color, paymentMethodIds: $paymentMethodIds, isArchived: $isArchived, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $AccountDtoCopyWith<$Res>  {
  factory $AccountDtoCopyWith(AccountDto value, $Res Function(AccountDto) _then) = _$AccountDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String type, String currencyCode, String balance, String icon, int color, List<String> paymentMethodIds, bool isArchived, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$AccountDtoCopyWithImpl<$Res>
    implements $AccountDtoCopyWith<$Res> {
  _$AccountDtoCopyWithImpl(this._self, this._then);

  final AccountDto _self;
  final $Res Function(AccountDto) _then;

/// Create a copy of AccountDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? currencyCode = null,Object? balance = null,Object? icon = null,Object? color = null,Object? paymentMethodIds = null,Object? isArchived = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,paymentMethodIds: null == paymentMethodIds ? _self.paymentMethodIds : paymentMethodIds // ignore: cast_nullable_to_non_nullable
as List<String>,isArchived: null == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountDto].
extension AccountDtoPatterns on AccountDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountDto value)  $default,){
final _that = this;
switch (_that) {
case _AccountDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountDto value)?  $default,){
final _that = this;
switch (_that) {
case _AccountDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String currencyCode,  String balance,  String icon,  int color,  List<String> paymentMethodIds,  bool isArchived,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountDto() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.currencyCode,_that.balance,_that.icon,_that.color,_that.paymentMethodIds,_that.isArchived,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String currencyCode,  String balance,  String icon,  int color,  List<String> paymentMethodIds,  bool isArchived,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _AccountDto():
return $default(_that.id,_that.name,_that.type,_that.currencyCode,_that.balance,_that.icon,_that.color,_that.paymentMethodIds,_that.isArchived,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String type,  String currencyCode,  String balance,  String icon,  int color,  List<String> paymentMethodIds,  bool isArchived,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _AccountDto() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.currencyCode,_that.balance,_that.icon,_that.color,_that.paymentMethodIds,_that.isArchived,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountDto implements AccountDto {
  const _AccountDto({required this.id, required this.name, required this.type, required this.currencyCode, required this.balance, required this.icon, required this.color, final  List<String> paymentMethodIds = const <String>[], required this.isArchived, required this.createdAt, required this.updatedAt}): _paymentMethodIds = paymentMethodIds;
  factory _AccountDto.fromJson(Map<String, dynamic> json) => _$AccountDtoFromJson(json);

@override final  String id;
@override final  String name;
@override final  String type;
@override final  String currencyCode;
@override final  String balance;
@override final  String icon;
@override final  int color;
 final  List<String> _paymentMethodIds;
@override@JsonKey() List<String> get paymentMethodIds {
  if (_paymentMethodIds is EqualUnmodifiableListView) return _paymentMethodIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_paymentMethodIds);
}

@override final  bool isArchived;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of AccountDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountDtoCopyWith<_AccountDto> get copyWith => __$AccountDtoCopyWithImpl<_AccountDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.color, color) || other.color == color)&&const DeepCollectionEquality().equals(other._paymentMethodIds, _paymentMethodIds)&&(identical(other.isArchived, isArchived) || other.isArchived == isArchived)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,currencyCode,balance,icon,color,const DeepCollectionEquality().hash(_paymentMethodIds),isArchived,createdAt,updatedAt);

@override
String toString() {
  return 'AccountDto(id: $id, name: $name, type: $type, currencyCode: $currencyCode, balance: $balance, icon: $icon, color: $color, paymentMethodIds: $paymentMethodIds, isArchived: $isArchived, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$AccountDtoCopyWith<$Res> implements $AccountDtoCopyWith<$Res> {
  factory _$AccountDtoCopyWith(_AccountDto value, $Res Function(_AccountDto) _then) = __$AccountDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String type, String currencyCode, String balance, String icon, int color, List<String> paymentMethodIds, bool isArchived, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$AccountDtoCopyWithImpl<$Res>
    implements _$AccountDtoCopyWith<$Res> {
  __$AccountDtoCopyWithImpl(this._self, this._then);

  final _AccountDto _self;
  final $Res Function(_AccountDto) _then;

/// Create a copy of AccountDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? currencyCode = null,Object? balance = null,Object? icon = null,Object? color = null,Object? paymentMethodIds = null,Object? isArchived = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_AccountDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,paymentMethodIds: null == paymentMethodIds ? _self._paymentMethodIds : paymentMethodIds // ignore: cast_nullable_to_non_nullable
as List<String>,isArchived: null == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
