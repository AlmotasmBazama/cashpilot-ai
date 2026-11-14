// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'processed_transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProcessedTransaction {

 String get accountId; FinanceTransactionDirection get direction; Money get amount; Money get previousBalance; Money get newBalance; DateTime get processedAt;
/// Create a copy of ProcessedTransaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProcessedTransactionCopyWith<ProcessedTransaction> get copyWith => _$ProcessedTransactionCopyWithImpl<ProcessedTransaction>(this as ProcessedTransaction, _$identity);

  /// Serializes this ProcessedTransaction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProcessedTransaction&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.previousBalance, previousBalance) || other.previousBalance == previousBalance)&&(identical(other.newBalance, newBalance) || other.newBalance == newBalance)&&(identical(other.processedAt, processedAt) || other.processedAt == processedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,direction,amount,previousBalance,newBalance,processedAt);

@override
String toString() {
  return 'ProcessedTransaction(accountId: $accountId, direction: $direction, amount: $amount, previousBalance: $previousBalance, newBalance: $newBalance, processedAt: $processedAt)';
}


}

/// @nodoc
abstract mixin class $ProcessedTransactionCopyWith<$Res>  {
  factory $ProcessedTransactionCopyWith(ProcessedTransaction value, $Res Function(ProcessedTransaction) _then) = _$ProcessedTransactionCopyWithImpl;
@useResult
$Res call({
 String accountId, FinanceTransactionDirection direction, Money amount, Money previousBalance, Money newBalance, DateTime processedAt
});


$MoneyCopyWith<$Res> get amount;$MoneyCopyWith<$Res> get previousBalance;$MoneyCopyWith<$Res> get newBalance;

}
/// @nodoc
class _$ProcessedTransactionCopyWithImpl<$Res>
    implements $ProcessedTransactionCopyWith<$Res> {
  _$ProcessedTransactionCopyWithImpl(this._self, this._then);

  final ProcessedTransaction _self;
  final $Res Function(ProcessedTransaction) _then;

/// Create a copy of ProcessedTransaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accountId = null,Object? direction = null,Object? amount = null,Object? previousBalance = null,Object? newBalance = null,Object? processedAt = null,}) {
  return _then(_self.copyWith(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as FinanceTransactionDirection,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,previousBalance: null == previousBalance ? _self.previousBalance : previousBalance // ignore: cast_nullable_to_non_nullable
as Money,newBalance: null == newBalance ? _self.newBalance : newBalance // ignore: cast_nullable_to_non_nullable
as Money,processedAt: null == processedAt ? _self.processedAt : processedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of ProcessedTransaction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get amount {
  
  return $MoneyCopyWith<$Res>(_self.amount, (value) {
    return _then(_self.copyWith(amount: value));
  });
}/// Create a copy of ProcessedTransaction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get previousBalance {
  
  return $MoneyCopyWith<$Res>(_self.previousBalance, (value) {
    return _then(_self.copyWith(previousBalance: value));
  });
}/// Create a copy of ProcessedTransaction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get newBalance {
  
  return $MoneyCopyWith<$Res>(_self.newBalance, (value) {
    return _then(_self.copyWith(newBalance: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProcessedTransaction].
extension ProcessedTransactionPatterns on ProcessedTransaction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProcessedTransaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProcessedTransaction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProcessedTransaction value)  $default,){
final _that = this;
switch (_that) {
case _ProcessedTransaction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProcessedTransaction value)?  $default,){
final _that = this;
switch (_that) {
case _ProcessedTransaction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accountId,  FinanceTransactionDirection direction,  Money amount,  Money previousBalance,  Money newBalance,  DateTime processedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProcessedTransaction() when $default != null:
return $default(_that.accountId,_that.direction,_that.amount,_that.previousBalance,_that.newBalance,_that.processedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accountId,  FinanceTransactionDirection direction,  Money amount,  Money previousBalance,  Money newBalance,  DateTime processedAt)  $default,) {final _that = this;
switch (_that) {
case _ProcessedTransaction():
return $default(_that.accountId,_that.direction,_that.amount,_that.previousBalance,_that.newBalance,_that.processedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accountId,  FinanceTransactionDirection direction,  Money amount,  Money previousBalance,  Money newBalance,  DateTime processedAt)?  $default,) {final _that = this;
switch (_that) {
case _ProcessedTransaction() when $default != null:
return $default(_that.accountId,_that.direction,_that.amount,_that.previousBalance,_that.newBalance,_that.processedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProcessedTransaction implements ProcessedTransaction {
  const _ProcessedTransaction({required this.accountId, required this.direction, required this.amount, required this.previousBalance, required this.newBalance, required this.processedAt});
  factory _ProcessedTransaction.fromJson(Map<String, dynamic> json) => _$ProcessedTransactionFromJson(json);

@override final  String accountId;
@override final  FinanceTransactionDirection direction;
@override final  Money amount;
@override final  Money previousBalance;
@override final  Money newBalance;
@override final  DateTime processedAt;

/// Create a copy of ProcessedTransaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProcessedTransactionCopyWith<_ProcessedTransaction> get copyWith => __$ProcessedTransactionCopyWithImpl<_ProcessedTransaction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProcessedTransactionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProcessedTransaction&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.previousBalance, previousBalance) || other.previousBalance == previousBalance)&&(identical(other.newBalance, newBalance) || other.newBalance == newBalance)&&(identical(other.processedAt, processedAt) || other.processedAt == processedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,direction,amount,previousBalance,newBalance,processedAt);

@override
String toString() {
  return 'ProcessedTransaction(accountId: $accountId, direction: $direction, amount: $amount, previousBalance: $previousBalance, newBalance: $newBalance, processedAt: $processedAt)';
}


}

/// @nodoc
abstract mixin class _$ProcessedTransactionCopyWith<$Res> implements $ProcessedTransactionCopyWith<$Res> {
  factory _$ProcessedTransactionCopyWith(_ProcessedTransaction value, $Res Function(_ProcessedTransaction) _then) = __$ProcessedTransactionCopyWithImpl;
@override @useResult
$Res call({
 String accountId, FinanceTransactionDirection direction, Money amount, Money previousBalance, Money newBalance, DateTime processedAt
});


@override $MoneyCopyWith<$Res> get amount;@override $MoneyCopyWith<$Res> get previousBalance;@override $MoneyCopyWith<$Res> get newBalance;

}
/// @nodoc
class __$ProcessedTransactionCopyWithImpl<$Res>
    implements _$ProcessedTransactionCopyWith<$Res> {
  __$ProcessedTransactionCopyWithImpl(this._self, this._then);

  final _ProcessedTransaction _self;
  final $Res Function(_ProcessedTransaction) _then;

/// Create a copy of ProcessedTransaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accountId = null,Object? direction = null,Object? amount = null,Object? previousBalance = null,Object? newBalance = null,Object? processedAt = null,}) {
  return _then(_ProcessedTransaction(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as FinanceTransactionDirection,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,previousBalance: null == previousBalance ? _self.previousBalance : previousBalance // ignore: cast_nullable_to_non_nullable
as Money,newBalance: null == newBalance ? _self.newBalance : newBalance // ignore: cast_nullable_to_non_nullable
as Money,processedAt: null == processedAt ? _self.processedAt : processedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of ProcessedTransaction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get amount {
  
  return $MoneyCopyWith<$Res>(_self.amount, (value) {
    return _then(_self.copyWith(amount: value));
  });
}/// Create a copy of ProcessedTransaction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get previousBalance {
  
  return $MoneyCopyWith<$Res>(_self.previousBalance, (value) {
    return _then(_self.copyWith(previousBalance: value));
  });
}/// Create a copy of ProcessedTransaction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get newBalance {
  
  return $MoneyCopyWith<$Res>(_self.newBalance, (value) {
    return _then(_self.copyWith(newBalance: value));
  });
}
}

// dart format on
