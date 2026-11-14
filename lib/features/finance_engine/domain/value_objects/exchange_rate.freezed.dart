// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exchange_rate.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExchangeRate {

 String get fromCurrencyCode; String get toCurrencyCode;@DecimalConverter() Decimal get rate; DateTime? get asOf;
/// Create a copy of ExchangeRate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExchangeRateCopyWith<ExchangeRate> get copyWith => _$ExchangeRateCopyWithImpl<ExchangeRate>(this as ExchangeRate, _$identity);

  /// Serializes this ExchangeRate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExchangeRate&&(identical(other.fromCurrencyCode, fromCurrencyCode) || other.fromCurrencyCode == fromCurrencyCode)&&(identical(other.toCurrencyCode, toCurrencyCode) || other.toCurrencyCode == toCurrencyCode)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.asOf, asOf) || other.asOf == asOf));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fromCurrencyCode,toCurrencyCode,rate,asOf);

@override
String toString() {
  return 'ExchangeRate(fromCurrencyCode: $fromCurrencyCode, toCurrencyCode: $toCurrencyCode, rate: $rate, asOf: $asOf)';
}


}

/// @nodoc
abstract mixin class $ExchangeRateCopyWith<$Res>  {
  factory $ExchangeRateCopyWith(ExchangeRate value, $Res Function(ExchangeRate) _then) = _$ExchangeRateCopyWithImpl;
@useResult
$Res call({
 String fromCurrencyCode, String toCurrencyCode,@DecimalConverter() Decimal rate, DateTime? asOf
});




}
/// @nodoc
class _$ExchangeRateCopyWithImpl<$Res>
    implements $ExchangeRateCopyWith<$Res> {
  _$ExchangeRateCopyWithImpl(this._self, this._then);

  final ExchangeRate _self;
  final $Res Function(ExchangeRate) _then;

/// Create a copy of ExchangeRate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fromCurrencyCode = null,Object? toCurrencyCode = null,Object? rate = null,Object? asOf = freezed,}) {
  return _then(_self.copyWith(
fromCurrencyCode: null == fromCurrencyCode ? _self.fromCurrencyCode : fromCurrencyCode // ignore: cast_nullable_to_non_nullable
as String,toCurrencyCode: null == toCurrencyCode ? _self.toCurrencyCode : toCurrencyCode // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as Decimal,asOf: freezed == asOf ? _self.asOf : asOf // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExchangeRate].
extension ExchangeRatePatterns on ExchangeRate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExchangeRate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExchangeRate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExchangeRate value)  $default,){
final _that = this;
switch (_that) {
case _ExchangeRate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExchangeRate value)?  $default,){
final _that = this;
switch (_that) {
case _ExchangeRate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fromCurrencyCode,  String toCurrencyCode, @DecimalConverter()  Decimal rate,  DateTime? asOf)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExchangeRate() when $default != null:
return $default(_that.fromCurrencyCode,_that.toCurrencyCode,_that.rate,_that.asOf);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fromCurrencyCode,  String toCurrencyCode, @DecimalConverter()  Decimal rate,  DateTime? asOf)  $default,) {final _that = this;
switch (_that) {
case _ExchangeRate():
return $default(_that.fromCurrencyCode,_that.toCurrencyCode,_that.rate,_that.asOf);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fromCurrencyCode,  String toCurrencyCode, @DecimalConverter()  Decimal rate,  DateTime? asOf)?  $default,) {final _that = this;
switch (_that) {
case _ExchangeRate() when $default != null:
return $default(_that.fromCurrencyCode,_that.toCurrencyCode,_that.rate,_that.asOf);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExchangeRate implements ExchangeRate {
  const _ExchangeRate({required this.fromCurrencyCode, required this.toCurrencyCode, @DecimalConverter() required this.rate, this.asOf});
  factory _ExchangeRate.fromJson(Map<String, dynamic> json) => _$ExchangeRateFromJson(json);

@override final  String fromCurrencyCode;
@override final  String toCurrencyCode;
@override@DecimalConverter() final  Decimal rate;
@override final  DateTime? asOf;

/// Create a copy of ExchangeRate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExchangeRateCopyWith<_ExchangeRate> get copyWith => __$ExchangeRateCopyWithImpl<_ExchangeRate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExchangeRateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExchangeRate&&(identical(other.fromCurrencyCode, fromCurrencyCode) || other.fromCurrencyCode == fromCurrencyCode)&&(identical(other.toCurrencyCode, toCurrencyCode) || other.toCurrencyCode == toCurrencyCode)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.asOf, asOf) || other.asOf == asOf));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fromCurrencyCode,toCurrencyCode,rate,asOf);

@override
String toString() {
  return 'ExchangeRate(fromCurrencyCode: $fromCurrencyCode, toCurrencyCode: $toCurrencyCode, rate: $rate, asOf: $asOf)';
}


}

/// @nodoc
abstract mixin class _$ExchangeRateCopyWith<$Res> implements $ExchangeRateCopyWith<$Res> {
  factory _$ExchangeRateCopyWith(_ExchangeRate value, $Res Function(_ExchangeRate) _then) = __$ExchangeRateCopyWithImpl;
@override @useResult
$Res call({
 String fromCurrencyCode, String toCurrencyCode,@DecimalConverter() Decimal rate, DateTime? asOf
});




}
/// @nodoc
class __$ExchangeRateCopyWithImpl<$Res>
    implements _$ExchangeRateCopyWith<$Res> {
  __$ExchangeRateCopyWithImpl(this._self, this._then);

  final _ExchangeRate _self;
  final $Res Function(_ExchangeRate) _then;

/// Create a copy of ExchangeRate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fromCurrencyCode = null,Object? toCurrencyCode = null,Object? rate = null,Object? asOf = freezed,}) {
  return _then(_ExchangeRate(
fromCurrencyCode: null == fromCurrencyCode ? _self.fromCurrencyCode : fromCurrencyCode // ignore: cast_nullable_to_non_nullable
as String,toCurrencyCode: null == toCurrencyCode ? _self.toCurrencyCode : toCurrencyCode // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as Decimal,asOf: freezed == asOf ? _self.asOf : asOf // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
