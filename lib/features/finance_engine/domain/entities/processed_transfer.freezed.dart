// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'processed_transfer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProcessedTransfer {

 String get sourceAccountId; String get targetAccountId; Money get sourceAmount; Money get targetAmount; Money get sourcePreviousBalance; Money get sourceNewBalance; Money get targetPreviousBalance; Money get targetNewBalance; ExchangeRate get exchangeRate; DateTime get processedAt;
/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProcessedTransferCopyWith<ProcessedTransfer> get copyWith => _$ProcessedTransferCopyWithImpl<ProcessedTransfer>(this as ProcessedTransfer, _$identity);

  /// Serializes this ProcessedTransfer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProcessedTransfer&&(identical(other.sourceAccountId, sourceAccountId) || other.sourceAccountId == sourceAccountId)&&(identical(other.targetAccountId, targetAccountId) || other.targetAccountId == targetAccountId)&&(identical(other.sourceAmount, sourceAmount) || other.sourceAmount == sourceAmount)&&(identical(other.targetAmount, targetAmount) || other.targetAmount == targetAmount)&&(identical(other.sourcePreviousBalance, sourcePreviousBalance) || other.sourcePreviousBalance == sourcePreviousBalance)&&(identical(other.sourceNewBalance, sourceNewBalance) || other.sourceNewBalance == sourceNewBalance)&&(identical(other.targetPreviousBalance, targetPreviousBalance) || other.targetPreviousBalance == targetPreviousBalance)&&(identical(other.targetNewBalance, targetNewBalance) || other.targetNewBalance == targetNewBalance)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.processedAt, processedAt) || other.processedAt == processedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sourceAccountId,targetAccountId,sourceAmount,targetAmount,sourcePreviousBalance,sourceNewBalance,targetPreviousBalance,targetNewBalance,exchangeRate,processedAt);

@override
String toString() {
  return 'ProcessedTransfer(sourceAccountId: $sourceAccountId, targetAccountId: $targetAccountId, sourceAmount: $sourceAmount, targetAmount: $targetAmount, sourcePreviousBalance: $sourcePreviousBalance, sourceNewBalance: $sourceNewBalance, targetPreviousBalance: $targetPreviousBalance, targetNewBalance: $targetNewBalance, exchangeRate: $exchangeRate, processedAt: $processedAt)';
}


}

/// @nodoc
abstract mixin class $ProcessedTransferCopyWith<$Res>  {
  factory $ProcessedTransferCopyWith(ProcessedTransfer value, $Res Function(ProcessedTransfer) _then) = _$ProcessedTransferCopyWithImpl;
@useResult
$Res call({
 String sourceAccountId, String targetAccountId, Money sourceAmount, Money targetAmount, Money sourcePreviousBalance, Money sourceNewBalance, Money targetPreviousBalance, Money targetNewBalance, ExchangeRate exchangeRate, DateTime processedAt
});


$MoneyCopyWith<$Res> get sourceAmount;$MoneyCopyWith<$Res> get targetAmount;$MoneyCopyWith<$Res> get sourcePreviousBalance;$MoneyCopyWith<$Res> get sourceNewBalance;$MoneyCopyWith<$Res> get targetPreviousBalance;$MoneyCopyWith<$Res> get targetNewBalance;$ExchangeRateCopyWith<$Res> get exchangeRate;

}
/// @nodoc
class _$ProcessedTransferCopyWithImpl<$Res>
    implements $ProcessedTransferCopyWith<$Res> {
  _$ProcessedTransferCopyWithImpl(this._self, this._then);

  final ProcessedTransfer _self;
  final $Res Function(ProcessedTransfer) _then;

/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceAccountId = null,Object? targetAccountId = null,Object? sourceAmount = null,Object? targetAmount = null,Object? sourcePreviousBalance = null,Object? sourceNewBalance = null,Object? targetPreviousBalance = null,Object? targetNewBalance = null,Object? exchangeRate = null,Object? processedAt = null,}) {
  return _then(_self.copyWith(
sourceAccountId: null == sourceAccountId ? _self.sourceAccountId : sourceAccountId // ignore: cast_nullable_to_non_nullable
as String,targetAccountId: null == targetAccountId ? _self.targetAccountId : targetAccountId // ignore: cast_nullable_to_non_nullable
as String,sourceAmount: null == sourceAmount ? _self.sourceAmount : sourceAmount // ignore: cast_nullable_to_non_nullable
as Money,targetAmount: null == targetAmount ? _self.targetAmount : targetAmount // ignore: cast_nullable_to_non_nullable
as Money,sourcePreviousBalance: null == sourcePreviousBalance ? _self.sourcePreviousBalance : sourcePreviousBalance // ignore: cast_nullable_to_non_nullable
as Money,sourceNewBalance: null == sourceNewBalance ? _self.sourceNewBalance : sourceNewBalance // ignore: cast_nullable_to_non_nullable
as Money,targetPreviousBalance: null == targetPreviousBalance ? _self.targetPreviousBalance : targetPreviousBalance // ignore: cast_nullable_to_non_nullable
as Money,targetNewBalance: null == targetNewBalance ? _self.targetNewBalance : targetNewBalance // ignore: cast_nullable_to_non_nullable
as Money,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as ExchangeRate,processedAt: null == processedAt ? _self.processedAt : processedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get sourceAmount {
  
  return $MoneyCopyWith<$Res>(_self.sourceAmount, (value) {
    return _then(_self.copyWith(sourceAmount: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get targetAmount {
  
  return $MoneyCopyWith<$Res>(_self.targetAmount, (value) {
    return _then(_self.copyWith(targetAmount: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get sourcePreviousBalance {
  
  return $MoneyCopyWith<$Res>(_self.sourcePreviousBalance, (value) {
    return _then(_self.copyWith(sourcePreviousBalance: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get sourceNewBalance {
  
  return $MoneyCopyWith<$Res>(_self.sourceNewBalance, (value) {
    return _then(_self.copyWith(sourceNewBalance: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get targetPreviousBalance {
  
  return $MoneyCopyWith<$Res>(_self.targetPreviousBalance, (value) {
    return _then(_self.copyWith(targetPreviousBalance: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get targetNewBalance {
  
  return $MoneyCopyWith<$Res>(_self.targetNewBalance, (value) {
    return _then(_self.copyWith(targetNewBalance: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExchangeRateCopyWith<$Res> get exchangeRate {
  
  return $ExchangeRateCopyWith<$Res>(_self.exchangeRate, (value) {
    return _then(_self.copyWith(exchangeRate: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProcessedTransfer].
extension ProcessedTransferPatterns on ProcessedTransfer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProcessedTransfer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProcessedTransfer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProcessedTransfer value)  $default,){
final _that = this;
switch (_that) {
case _ProcessedTransfer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProcessedTransfer value)?  $default,){
final _that = this;
switch (_that) {
case _ProcessedTransfer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sourceAccountId,  String targetAccountId,  Money sourceAmount,  Money targetAmount,  Money sourcePreviousBalance,  Money sourceNewBalance,  Money targetPreviousBalance,  Money targetNewBalance,  ExchangeRate exchangeRate,  DateTime processedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProcessedTransfer() when $default != null:
return $default(_that.sourceAccountId,_that.targetAccountId,_that.sourceAmount,_that.targetAmount,_that.sourcePreviousBalance,_that.sourceNewBalance,_that.targetPreviousBalance,_that.targetNewBalance,_that.exchangeRate,_that.processedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sourceAccountId,  String targetAccountId,  Money sourceAmount,  Money targetAmount,  Money sourcePreviousBalance,  Money sourceNewBalance,  Money targetPreviousBalance,  Money targetNewBalance,  ExchangeRate exchangeRate,  DateTime processedAt)  $default,) {final _that = this;
switch (_that) {
case _ProcessedTransfer():
return $default(_that.sourceAccountId,_that.targetAccountId,_that.sourceAmount,_that.targetAmount,_that.sourcePreviousBalance,_that.sourceNewBalance,_that.targetPreviousBalance,_that.targetNewBalance,_that.exchangeRate,_that.processedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sourceAccountId,  String targetAccountId,  Money sourceAmount,  Money targetAmount,  Money sourcePreviousBalance,  Money sourceNewBalance,  Money targetPreviousBalance,  Money targetNewBalance,  ExchangeRate exchangeRate,  DateTime processedAt)?  $default,) {final _that = this;
switch (_that) {
case _ProcessedTransfer() when $default != null:
return $default(_that.sourceAccountId,_that.targetAccountId,_that.sourceAmount,_that.targetAmount,_that.sourcePreviousBalance,_that.sourceNewBalance,_that.targetPreviousBalance,_that.targetNewBalance,_that.exchangeRate,_that.processedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProcessedTransfer implements ProcessedTransfer {
  const _ProcessedTransfer({required this.sourceAccountId, required this.targetAccountId, required this.sourceAmount, required this.targetAmount, required this.sourcePreviousBalance, required this.sourceNewBalance, required this.targetPreviousBalance, required this.targetNewBalance, required this.exchangeRate, required this.processedAt});
  factory _ProcessedTransfer.fromJson(Map<String, dynamic> json) => _$ProcessedTransferFromJson(json);

@override final  String sourceAccountId;
@override final  String targetAccountId;
@override final  Money sourceAmount;
@override final  Money targetAmount;
@override final  Money sourcePreviousBalance;
@override final  Money sourceNewBalance;
@override final  Money targetPreviousBalance;
@override final  Money targetNewBalance;
@override final  ExchangeRate exchangeRate;
@override final  DateTime processedAt;

/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProcessedTransferCopyWith<_ProcessedTransfer> get copyWith => __$ProcessedTransferCopyWithImpl<_ProcessedTransfer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProcessedTransferToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProcessedTransfer&&(identical(other.sourceAccountId, sourceAccountId) || other.sourceAccountId == sourceAccountId)&&(identical(other.targetAccountId, targetAccountId) || other.targetAccountId == targetAccountId)&&(identical(other.sourceAmount, sourceAmount) || other.sourceAmount == sourceAmount)&&(identical(other.targetAmount, targetAmount) || other.targetAmount == targetAmount)&&(identical(other.sourcePreviousBalance, sourcePreviousBalance) || other.sourcePreviousBalance == sourcePreviousBalance)&&(identical(other.sourceNewBalance, sourceNewBalance) || other.sourceNewBalance == sourceNewBalance)&&(identical(other.targetPreviousBalance, targetPreviousBalance) || other.targetPreviousBalance == targetPreviousBalance)&&(identical(other.targetNewBalance, targetNewBalance) || other.targetNewBalance == targetNewBalance)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.processedAt, processedAt) || other.processedAt == processedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sourceAccountId,targetAccountId,sourceAmount,targetAmount,sourcePreviousBalance,sourceNewBalance,targetPreviousBalance,targetNewBalance,exchangeRate,processedAt);

@override
String toString() {
  return 'ProcessedTransfer(sourceAccountId: $sourceAccountId, targetAccountId: $targetAccountId, sourceAmount: $sourceAmount, targetAmount: $targetAmount, sourcePreviousBalance: $sourcePreviousBalance, sourceNewBalance: $sourceNewBalance, targetPreviousBalance: $targetPreviousBalance, targetNewBalance: $targetNewBalance, exchangeRate: $exchangeRate, processedAt: $processedAt)';
}


}

/// @nodoc
abstract mixin class _$ProcessedTransferCopyWith<$Res> implements $ProcessedTransferCopyWith<$Res> {
  factory _$ProcessedTransferCopyWith(_ProcessedTransfer value, $Res Function(_ProcessedTransfer) _then) = __$ProcessedTransferCopyWithImpl;
@override @useResult
$Res call({
 String sourceAccountId, String targetAccountId, Money sourceAmount, Money targetAmount, Money sourcePreviousBalance, Money sourceNewBalance, Money targetPreviousBalance, Money targetNewBalance, ExchangeRate exchangeRate, DateTime processedAt
});


@override $MoneyCopyWith<$Res> get sourceAmount;@override $MoneyCopyWith<$Res> get targetAmount;@override $MoneyCopyWith<$Res> get sourcePreviousBalance;@override $MoneyCopyWith<$Res> get sourceNewBalance;@override $MoneyCopyWith<$Res> get targetPreviousBalance;@override $MoneyCopyWith<$Res> get targetNewBalance;@override $ExchangeRateCopyWith<$Res> get exchangeRate;

}
/// @nodoc
class __$ProcessedTransferCopyWithImpl<$Res>
    implements _$ProcessedTransferCopyWith<$Res> {
  __$ProcessedTransferCopyWithImpl(this._self, this._then);

  final _ProcessedTransfer _self;
  final $Res Function(_ProcessedTransfer) _then;

/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceAccountId = null,Object? targetAccountId = null,Object? sourceAmount = null,Object? targetAmount = null,Object? sourcePreviousBalance = null,Object? sourceNewBalance = null,Object? targetPreviousBalance = null,Object? targetNewBalance = null,Object? exchangeRate = null,Object? processedAt = null,}) {
  return _then(_ProcessedTransfer(
sourceAccountId: null == sourceAccountId ? _self.sourceAccountId : sourceAccountId // ignore: cast_nullable_to_non_nullable
as String,targetAccountId: null == targetAccountId ? _self.targetAccountId : targetAccountId // ignore: cast_nullable_to_non_nullable
as String,sourceAmount: null == sourceAmount ? _self.sourceAmount : sourceAmount // ignore: cast_nullable_to_non_nullable
as Money,targetAmount: null == targetAmount ? _self.targetAmount : targetAmount // ignore: cast_nullable_to_non_nullable
as Money,sourcePreviousBalance: null == sourcePreviousBalance ? _self.sourcePreviousBalance : sourcePreviousBalance // ignore: cast_nullable_to_non_nullable
as Money,sourceNewBalance: null == sourceNewBalance ? _self.sourceNewBalance : sourceNewBalance // ignore: cast_nullable_to_non_nullable
as Money,targetPreviousBalance: null == targetPreviousBalance ? _self.targetPreviousBalance : targetPreviousBalance // ignore: cast_nullable_to_non_nullable
as Money,targetNewBalance: null == targetNewBalance ? _self.targetNewBalance : targetNewBalance // ignore: cast_nullable_to_non_nullable
as Money,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as ExchangeRate,processedAt: null == processedAt ? _self.processedAt : processedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get sourceAmount {
  
  return $MoneyCopyWith<$Res>(_self.sourceAmount, (value) {
    return _then(_self.copyWith(sourceAmount: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get targetAmount {
  
  return $MoneyCopyWith<$Res>(_self.targetAmount, (value) {
    return _then(_self.copyWith(targetAmount: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get sourcePreviousBalance {
  
  return $MoneyCopyWith<$Res>(_self.sourcePreviousBalance, (value) {
    return _then(_self.copyWith(sourcePreviousBalance: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get sourceNewBalance {
  
  return $MoneyCopyWith<$Res>(_self.sourceNewBalance, (value) {
    return _then(_self.copyWith(sourceNewBalance: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get targetPreviousBalance {
  
  return $MoneyCopyWith<$Res>(_self.targetPreviousBalance, (value) {
    return _then(_self.copyWith(targetPreviousBalance: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get targetNewBalance {
  
  return $MoneyCopyWith<$Res>(_self.targetNewBalance, (value) {
    return _then(_self.copyWith(targetNewBalance: value));
  });
}/// Create a copy of ProcessedTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExchangeRateCopyWith<$Res> get exchangeRate {
  
  return $ExchangeRateCopyWith<$Res>(_self.exchangeRate, (value) {
    return _then(_self.copyWith(exchangeRate: value));
  });
}
}

// dart format on
