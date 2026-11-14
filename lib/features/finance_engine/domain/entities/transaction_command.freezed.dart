// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction_command.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TransactionCommand {

 String get accountId; Money get amount; FinanceTransactionDirection get direction; DateTime? get occurredAt;
/// Create a copy of TransactionCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionCommandCopyWith<TransactionCommand> get copyWith => _$TransactionCommandCopyWithImpl<TransactionCommand>(this as TransactionCommand, _$identity);

  /// Serializes this TransactionCommand to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionCommand&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,amount,direction,occurredAt);

@override
String toString() {
  return 'TransactionCommand(accountId: $accountId, amount: $amount, direction: $direction, occurredAt: $occurredAt)';
}


}

/// @nodoc
abstract mixin class $TransactionCommandCopyWith<$Res>  {
  factory $TransactionCommandCopyWith(TransactionCommand value, $Res Function(TransactionCommand) _then) = _$TransactionCommandCopyWithImpl;
@useResult
$Res call({
 String accountId, Money amount, FinanceTransactionDirection direction, DateTime? occurredAt
});


$MoneyCopyWith<$Res> get amount;

}
/// @nodoc
class _$TransactionCommandCopyWithImpl<$Res>
    implements $TransactionCommandCopyWith<$Res> {
  _$TransactionCommandCopyWithImpl(this._self, this._then);

  final TransactionCommand _self;
  final $Res Function(TransactionCommand) _then;

/// Create a copy of TransactionCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accountId = null,Object? amount = null,Object? direction = null,Object? occurredAt = freezed,}) {
  return _then(_self.copyWith(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as FinanceTransactionDirection,occurredAt: freezed == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of TransactionCommand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get amount {
  
  return $MoneyCopyWith<$Res>(_self.amount, (value) {
    return _then(_self.copyWith(amount: value));
  });
}
}


/// Adds pattern-matching-related methods to [TransactionCommand].
extension TransactionCommandPatterns on TransactionCommand {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransactionCommand value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransactionCommand() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransactionCommand value)  $default,){
final _that = this;
switch (_that) {
case _TransactionCommand():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransactionCommand value)?  $default,){
final _that = this;
switch (_that) {
case _TransactionCommand() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accountId,  Money amount,  FinanceTransactionDirection direction,  DateTime? occurredAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransactionCommand() when $default != null:
return $default(_that.accountId,_that.amount,_that.direction,_that.occurredAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accountId,  Money amount,  FinanceTransactionDirection direction,  DateTime? occurredAt)  $default,) {final _that = this;
switch (_that) {
case _TransactionCommand():
return $default(_that.accountId,_that.amount,_that.direction,_that.occurredAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accountId,  Money amount,  FinanceTransactionDirection direction,  DateTime? occurredAt)?  $default,) {final _that = this;
switch (_that) {
case _TransactionCommand() when $default != null:
return $default(_that.accountId,_that.amount,_that.direction,_that.occurredAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TransactionCommand implements TransactionCommand {
  const _TransactionCommand({required this.accountId, required this.amount, required this.direction, this.occurredAt});
  factory _TransactionCommand.fromJson(Map<String, dynamic> json) => _$TransactionCommandFromJson(json);

@override final  String accountId;
@override final  Money amount;
@override final  FinanceTransactionDirection direction;
@override final  DateTime? occurredAt;

/// Create a copy of TransactionCommand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransactionCommandCopyWith<_TransactionCommand> get copyWith => __$TransactionCommandCopyWithImpl<_TransactionCommand>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransactionCommandToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransactionCommand&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,amount,direction,occurredAt);

@override
String toString() {
  return 'TransactionCommand(accountId: $accountId, amount: $amount, direction: $direction, occurredAt: $occurredAt)';
}


}

/// @nodoc
abstract mixin class _$TransactionCommandCopyWith<$Res> implements $TransactionCommandCopyWith<$Res> {
  factory _$TransactionCommandCopyWith(_TransactionCommand value, $Res Function(_TransactionCommand) _then) = __$TransactionCommandCopyWithImpl;
@override @useResult
$Res call({
 String accountId, Money amount, FinanceTransactionDirection direction, DateTime? occurredAt
});


@override $MoneyCopyWith<$Res> get amount;

}
/// @nodoc
class __$TransactionCommandCopyWithImpl<$Res>
    implements _$TransactionCommandCopyWith<$Res> {
  __$TransactionCommandCopyWithImpl(this._self, this._then);

  final _TransactionCommand _self;
  final $Res Function(_TransactionCommand) _then;

/// Create a copy of TransactionCommand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accountId = null,Object? amount = null,Object? direction = null,Object? occurredAt = freezed,}) {
  return _then(_TransactionCommand(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as FinanceTransactionDirection,occurredAt: freezed == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of TransactionCommand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get amount {
  
  return $MoneyCopyWith<$Res>(_self.amount, (value) {
    return _then(_self.copyWith(amount: value));
  });
}
}

// dart format on
