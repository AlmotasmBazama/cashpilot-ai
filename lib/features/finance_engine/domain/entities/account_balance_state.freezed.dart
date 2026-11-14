// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_balance_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountBalanceState {

 String get accountId; String get currencyCode;@DecimalConverter() Decimal get balance; bool get allowsNegativeBalance;@DecimalConverter() Decimal? get creditLimit; DateTime? get updatedAt;
/// Create a copy of AccountBalanceState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountBalanceStateCopyWith<AccountBalanceState> get copyWith => _$AccountBalanceStateCopyWithImpl<AccountBalanceState>(this as AccountBalanceState, _$identity);

  /// Serializes this AccountBalanceState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountBalanceState&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.allowsNegativeBalance, allowsNegativeBalance) || other.allowsNegativeBalance == allowsNegativeBalance)&&(identical(other.creditLimit, creditLimit) || other.creditLimit == creditLimit)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,currencyCode,balance,allowsNegativeBalance,creditLimit,updatedAt);

@override
String toString() {
  return 'AccountBalanceState(accountId: $accountId, currencyCode: $currencyCode, balance: $balance, allowsNegativeBalance: $allowsNegativeBalance, creditLimit: $creditLimit, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $AccountBalanceStateCopyWith<$Res>  {
  factory $AccountBalanceStateCopyWith(AccountBalanceState value, $Res Function(AccountBalanceState) _then) = _$AccountBalanceStateCopyWithImpl;
@useResult
$Res call({
 String accountId, String currencyCode,@DecimalConverter() Decimal balance, bool allowsNegativeBalance,@DecimalConverter() Decimal? creditLimit, DateTime? updatedAt
});




}
/// @nodoc
class _$AccountBalanceStateCopyWithImpl<$Res>
    implements $AccountBalanceStateCopyWith<$Res> {
  _$AccountBalanceStateCopyWithImpl(this._self, this._then);

  final AccountBalanceState _self;
  final $Res Function(AccountBalanceState) _then;

/// Create a copy of AccountBalanceState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accountId = null,Object? currencyCode = null,Object? balance = null,Object? allowsNegativeBalance = null,Object? creditLimit = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as Decimal,allowsNegativeBalance: null == allowsNegativeBalance ? _self.allowsNegativeBalance : allowsNegativeBalance // ignore: cast_nullable_to_non_nullable
as bool,creditLimit: freezed == creditLimit ? _self.creditLimit : creditLimit // ignore: cast_nullable_to_non_nullable
as Decimal?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountBalanceState].
extension AccountBalanceStatePatterns on AccountBalanceState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountBalanceState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountBalanceState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountBalanceState value)  $default,){
final _that = this;
switch (_that) {
case _AccountBalanceState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountBalanceState value)?  $default,){
final _that = this;
switch (_that) {
case _AccountBalanceState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accountId,  String currencyCode, @DecimalConverter()  Decimal balance,  bool allowsNegativeBalance, @DecimalConverter()  Decimal? creditLimit,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountBalanceState() when $default != null:
return $default(_that.accountId,_that.currencyCode,_that.balance,_that.allowsNegativeBalance,_that.creditLimit,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accountId,  String currencyCode, @DecimalConverter()  Decimal balance,  bool allowsNegativeBalance, @DecimalConverter()  Decimal? creditLimit,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _AccountBalanceState():
return $default(_that.accountId,_that.currencyCode,_that.balance,_that.allowsNegativeBalance,_that.creditLimit,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accountId,  String currencyCode, @DecimalConverter()  Decimal balance,  bool allowsNegativeBalance, @DecimalConverter()  Decimal? creditLimit,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _AccountBalanceState() when $default != null:
return $default(_that.accountId,_that.currencyCode,_that.balance,_that.allowsNegativeBalance,_that.creditLimit,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountBalanceState extends AccountBalanceState {
  const _AccountBalanceState({required this.accountId, required this.currencyCode, @DecimalConverter() required this.balance, this.allowsNegativeBalance = false, @DecimalConverter() this.creditLimit, this.updatedAt}): super._();
  factory _AccountBalanceState.fromJson(Map<String, dynamic> json) => _$AccountBalanceStateFromJson(json);

@override final  String accountId;
@override final  String currencyCode;
@override@DecimalConverter() final  Decimal balance;
@override@JsonKey() final  bool allowsNegativeBalance;
@override@DecimalConverter() final  Decimal? creditLimit;
@override final  DateTime? updatedAt;

/// Create a copy of AccountBalanceState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountBalanceStateCopyWith<_AccountBalanceState> get copyWith => __$AccountBalanceStateCopyWithImpl<_AccountBalanceState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountBalanceStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountBalanceState&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.allowsNegativeBalance, allowsNegativeBalance) || other.allowsNegativeBalance == allowsNegativeBalance)&&(identical(other.creditLimit, creditLimit) || other.creditLimit == creditLimit)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,currencyCode,balance,allowsNegativeBalance,creditLimit,updatedAt);

@override
String toString() {
  return 'AccountBalanceState(accountId: $accountId, currencyCode: $currencyCode, balance: $balance, allowsNegativeBalance: $allowsNegativeBalance, creditLimit: $creditLimit, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$AccountBalanceStateCopyWith<$Res> implements $AccountBalanceStateCopyWith<$Res> {
  factory _$AccountBalanceStateCopyWith(_AccountBalanceState value, $Res Function(_AccountBalanceState) _then) = __$AccountBalanceStateCopyWithImpl;
@override @useResult
$Res call({
 String accountId, String currencyCode,@DecimalConverter() Decimal balance, bool allowsNegativeBalance,@DecimalConverter() Decimal? creditLimit, DateTime? updatedAt
});




}
/// @nodoc
class __$AccountBalanceStateCopyWithImpl<$Res>
    implements _$AccountBalanceStateCopyWith<$Res> {
  __$AccountBalanceStateCopyWithImpl(this._self, this._then);

  final _AccountBalanceState _self;
  final $Res Function(_AccountBalanceState) _then;

/// Create a copy of AccountBalanceState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accountId = null,Object? currencyCode = null,Object? balance = null,Object? allowsNegativeBalance = null,Object? creditLimit = freezed,Object? updatedAt = freezed,}) {
  return _then(_AccountBalanceState(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as Decimal,allowsNegativeBalance: null == allowsNegativeBalance ? _self.allowsNegativeBalance : allowsNegativeBalance // ignore: cast_nullable_to_non_nullable
as bool,creditLimit: freezed == creditLimit ? _self.creditLimit : creditLimit // ignore: cast_nullable_to_non_nullable
as Decimal?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
