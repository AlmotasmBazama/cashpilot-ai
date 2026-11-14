// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stored_exchange_rate.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StoredExchangeRate {

 String get id; String get baseCurrency; String get quoteCurrency;@DecimalConverter() Decimal get rate; ExchangeRateSource get source; DateTime get fetchedAt; DateTime get createdAt; DateTime get updatedAt; DateTime? get archivedAt;
/// Create a copy of StoredExchangeRate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoredExchangeRateCopyWith<StoredExchangeRate> get copyWith => _$StoredExchangeRateCopyWithImpl<StoredExchangeRate>(this as StoredExchangeRate, _$identity);

  /// Serializes this StoredExchangeRate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoredExchangeRate&&(identical(other.id, id) || other.id == id)&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.quoteCurrency, quoteCurrency) || other.quoteCurrency == quoteCurrency)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.source, source) || other.source == source)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,baseCurrency,quoteCurrency,rate,source,fetchedAt,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'StoredExchangeRate(id: $id, baseCurrency: $baseCurrency, quoteCurrency: $quoteCurrency, rate: $rate, source: $source, fetchedAt: $fetchedAt, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $StoredExchangeRateCopyWith<$Res>  {
  factory $StoredExchangeRateCopyWith(StoredExchangeRate value, $Res Function(StoredExchangeRate) _then) = _$StoredExchangeRateCopyWithImpl;
@useResult
$Res call({
 String id, String baseCurrency, String quoteCurrency,@DecimalConverter() Decimal rate, ExchangeRateSource source, DateTime fetchedAt, DateTime createdAt, DateTime updatedAt, DateTime? archivedAt
});




}
/// @nodoc
class _$StoredExchangeRateCopyWithImpl<$Res>
    implements $StoredExchangeRateCopyWith<$Res> {
  _$StoredExchangeRateCopyWithImpl(this._self, this._then);

  final StoredExchangeRate _self;
  final $Res Function(StoredExchangeRate) _then;

/// Create a copy of StoredExchangeRate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? baseCurrency = null,Object? quoteCurrency = null,Object? rate = null,Object? source = null,Object? fetchedAt = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,quoteCurrency: null == quoteCurrency ? _self.quoteCurrency : quoteCurrency // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as Decimal,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ExchangeRateSource,fetchedAt: null == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [StoredExchangeRate].
extension StoredExchangeRatePatterns on StoredExchangeRate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StoredExchangeRate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StoredExchangeRate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StoredExchangeRate value)  $default,){
final _that = this;
switch (_that) {
case _StoredExchangeRate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StoredExchangeRate value)?  $default,){
final _that = this;
switch (_that) {
case _StoredExchangeRate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String baseCurrency,  String quoteCurrency, @DecimalConverter()  Decimal rate,  ExchangeRateSource source,  DateTime fetchedAt,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StoredExchangeRate() when $default != null:
return $default(_that.id,_that.baseCurrency,_that.quoteCurrency,_that.rate,_that.source,_that.fetchedAt,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String baseCurrency,  String quoteCurrency, @DecimalConverter()  Decimal rate,  ExchangeRateSource source,  DateTime fetchedAt,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt)  $default,) {final _that = this;
switch (_that) {
case _StoredExchangeRate():
return $default(_that.id,_that.baseCurrency,_that.quoteCurrency,_that.rate,_that.source,_that.fetchedAt,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String baseCurrency,  String quoteCurrency, @DecimalConverter()  Decimal rate,  ExchangeRateSource source,  DateTime fetchedAt,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _StoredExchangeRate() when $default != null:
return $default(_that.id,_that.baseCurrency,_that.quoteCurrency,_that.rate,_that.source,_that.fetchedAt,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StoredExchangeRate extends StoredExchangeRate {
  const _StoredExchangeRate({required this.id, required this.baseCurrency, required this.quoteCurrency, @DecimalConverter() required this.rate, required this.source, required this.fetchedAt, required this.createdAt, required this.updatedAt, this.archivedAt}): super._();
  factory _StoredExchangeRate.fromJson(Map<String, dynamic> json) => _$StoredExchangeRateFromJson(json);

@override final  String id;
@override final  String baseCurrency;
@override final  String quoteCurrency;
@override@DecimalConverter() final  Decimal rate;
@override final  ExchangeRateSource source;
@override final  DateTime fetchedAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime? archivedAt;

/// Create a copy of StoredExchangeRate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StoredExchangeRateCopyWith<_StoredExchangeRate> get copyWith => __$StoredExchangeRateCopyWithImpl<_StoredExchangeRate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StoredExchangeRateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StoredExchangeRate&&(identical(other.id, id) || other.id == id)&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.quoteCurrency, quoteCurrency) || other.quoteCurrency == quoteCurrency)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.source, source) || other.source == source)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,baseCurrency,quoteCurrency,rate,source,fetchedAt,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'StoredExchangeRate(id: $id, baseCurrency: $baseCurrency, quoteCurrency: $quoteCurrency, rate: $rate, source: $source, fetchedAt: $fetchedAt, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$StoredExchangeRateCopyWith<$Res> implements $StoredExchangeRateCopyWith<$Res> {
  factory _$StoredExchangeRateCopyWith(_StoredExchangeRate value, $Res Function(_StoredExchangeRate) _then) = __$StoredExchangeRateCopyWithImpl;
@override @useResult
$Res call({
 String id, String baseCurrency, String quoteCurrency,@DecimalConverter() Decimal rate, ExchangeRateSource source, DateTime fetchedAt, DateTime createdAt, DateTime updatedAt, DateTime? archivedAt
});




}
/// @nodoc
class __$StoredExchangeRateCopyWithImpl<$Res>
    implements _$StoredExchangeRateCopyWith<$Res> {
  __$StoredExchangeRateCopyWithImpl(this._self, this._then);

  final _StoredExchangeRate _self;
  final $Res Function(_StoredExchangeRate) _then;

/// Create a copy of StoredExchangeRate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? baseCurrency = null,Object? quoteCurrency = null,Object? rate = null,Object? source = null,Object? fetchedAt = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = freezed,}) {
  return _then(_StoredExchangeRate(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,quoteCurrency: null == quoteCurrency ? _self.quoteCurrency : quoteCurrency // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as Decimal,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ExchangeRateSource,fetchedAt: null == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
