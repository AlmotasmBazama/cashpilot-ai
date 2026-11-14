// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transfer_command.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TransferCommand {

 String get sourceAccountId; String get targetAccountId; Money get sourceAmount; Money? get targetAmount; ExchangeRate? get exchangeRate; DateTime? get occurredAt;
/// Create a copy of TransferCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferCommandCopyWith<TransferCommand> get copyWith => _$TransferCommandCopyWithImpl<TransferCommand>(this as TransferCommand, _$identity);

  /// Serializes this TransferCommand to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferCommand&&(identical(other.sourceAccountId, sourceAccountId) || other.sourceAccountId == sourceAccountId)&&(identical(other.targetAccountId, targetAccountId) || other.targetAccountId == targetAccountId)&&(identical(other.sourceAmount, sourceAmount) || other.sourceAmount == sourceAmount)&&(identical(other.targetAmount, targetAmount) || other.targetAmount == targetAmount)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sourceAccountId,targetAccountId,sourceAmount,targetAmount,exchangeRate,occurredAt);

@override
String toString() {
  return 'TransferCommand(sourceAccountId: $sourceAccountId, targetAccountId: $targetAccountId, sourceAmount: $sourceAmount, targetAmount: $targetAmount, exchangeRate: $exchangeRate, occurredAt: $occurredAt)';
}


}

/// @nodoc
abstract mixin class $TransferCommandCopyWith<$Res>  {
  factory $TransferCommandCopyWith(TransferCommand value, $Res Function(TransferCommand) _then) = _$TransferCommandCopyWithImpl;
@useResult
$Res call({
 String sourceAccountId, String targetAccountId, Money sourceAmount, Money? targetAmount, ExchangeRate? exchangeRate, DateTime? occurredAt
});


$MoneyCopyWith<$Res> get sourceAmount;$MoneyCopyWith<$Res>? get targetAmount;$ExchangeRateCopyWith<$Res>? get exchangeRate;

}
/// @nodoc
class _$TransferCommandCopyWithImpl<$Res>
    implements $TransferCommandCopyWith<$Res> {
  _$TransferCommandCopyWithImpl(this._self, this._then);

  final TransferCommand _self;
  final $Res Function(TransferCommand) _then;

/// Create a copy of TransferCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceAccountId = null,Object? targetAccountId = null,Object? sourceAmount = null,Object? targetAmount = freezed,Object? exchangeRate = freezed,Object? occurredAt = freezed,}) {
  return _then(_self.copyWith(
sourceAccountId: null == sourceAccountId ? _self.sourceAccountId : sourceAccountId // ignore: cast_nullable_to_non_nullable
as String,targetAccountId: null == targetAccountId ? _self.targetAccountId : targetAccountId // ignore: cast_nullable_to_non_nullable
as String,sourceAmount: null == sourceAmount ? _self.sourceAmount : sourceAmount // ignore: cast_nullable_to_non_nullable
as Money,targetAmount: freezed == targetAmount ? _self.targetAmount : targetAmount // ignore: cast_nullable_to_non_nullable
as Money?,exchangeRate: freezed == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as ExchangeRate?,occurredAt: freezed == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of TransferCommand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get sourceAmount {
  
  return $MoneyCopyWith<$Res>(_self.sourceAmount, (value) {
    return _then(_self.copyWith(sourceAmount: value));
  });
}/// Create a copy of TransferCommand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res>? get targetAmount {
    if (_self.targetAmount == null) {
    return null;
  }

  return $MoneyCopyWith<$Res>(_self.targetAmount!, (value) {
    return _then(_self.copyWith(targetAmount: value));
  });
}/// Create a copy of TransferCommand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExchangeRateCopyWith<$Res>? get exchangeRate {
    if (_self.exchangeRate == null) {
    return null;
  }

  return $ExchangeRateCopyWith<$Res>(_self.exchangeRate!, (value) {
    return _then(_self.copyWith(exchangeRate: value));
  });
}
}


/// Adds pattern-matching-related methods to [TransferCommand].
extension TransferCommandPatterns on TransferCommand {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransferCommand value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransferCommand() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransferCommand value)  $default,){
final _that = this;
switch (_that) {
case _TransferCommand():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransferCommand value)?  $default,){
final _that = this;
switch (_that) {
case _TransferCommand() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sourceAccountId,  String targetAccountId,  Money sourceAmount,  Money? targetAmount,  ExchangeRate? exchangeRate,  DateTime? occurredAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransferCommand() when $default != null:
return $default(_that.sourceAccountId,_that.targetAccountId,_that.sourceAmount,_that.targetAmount,_that.exchangeRate,_that.occurredAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sourceAccountId,  String targetAccountId,  Money sourceAmount,  Money? targetAmount,  ExchangeRate? exchangeRate,  DateTime? occurredAt)  $default,) {final _that = this;
switch (_that) {
case _TransferCommand():
return $default(_that.sourceAccountId,_that.targetAccountId,_that.sourceAmount,_that.targetAmount,_that.exchangeRate,_that.occurredAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sourceAccountId,  String targetAccountId,  Money sourceAmount,  Money? targetAmount,  ExchangeRate? exchangeRate,  DateTime? occurredAt)?  $default,) {final _that = this;
switch (_that) {
case _TransferCommand() when $default != null:
return $default(_that.sourceAccountId,_that.targetAccountId,_that.sourceAmount,_that.targetAmount,_that.exchangeRate,_that.occurredAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TransferCommand implements TransferCommand {
  const _TransferCommand({required this.sourceAccountId, required this.targetAccountId, required this.sourceAmount, this.targetAmount, this.exchangeRate, this.occurredAt});
  factory _TransferCommand.fromJson(Map<String, dynamic> json) => _$TransferCommandFromJson(json);

@override final  String sourceAccountId;
@override final  String targetAccountId;
@override final  Money sourceAmount;
@override final  Money? targetAmount;
@override final  ExchangeRate? exchangeRate;
@override final  DateTime? occurredAt;

/// Create a copy of TransferCommand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransferCommandCopyWith<_TransferCommand> get copyWith => __$TransferCommandCopyWithImpl<_TransferCommand>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransferCommandToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransferCommand&&(identical(other.sourceAccountId, sourceAccountId) || other.sourceAccountId == sourceAccountId)&&(identical(other.targetAccountId, targetAccountId) || other.targetAccountId == targetAccountId)&&(identical(other.sourceAmount, sourceAmount) || other.sourceAmount == sourceAmount)&&(identical(other.targetAmount, targetAmount) || other.targetAmount == targetAmount)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sourceAccountId,targetAccountId,sourceAmount,targetAmount,exchangeRate,occurredAt);

@override
String toString() {
  return 'TransferCommand(sourceAccountId: $sourceAccountId, targetAccountId: $targetAccountId, sourceAmount: $sourceAmount, targetAmount: $targetAmount, exchangeRate: $exchangeRate, occurredAt: $occurredAt)';
}


}

/// @nodoc
abstract mixin class _$TransferCommandCopyWith<$Res> implements $TransferCommandCopyWith<$Res> {
  factory _$TransferCommandCopyWith(_TransferCommand value, $Res Function(_TransferCommand) _then) = __$TransferCommandCopyWithImpl;
@override @useResult
$Res call({
 String sourceAccountId, String targetAccountId, Money sourceAmount, Money? targetAmount, ExchangeRate? exchangeRate, DateTime? occurredAt
});


@override $MoneyCopyWith<$Res> get sourceAmount;@override $MoneyCopyWith<$Res>? get targetAmount;@override $ExchangeRateCopyWith<$Res>? get exchangeRate;

}
/// @nodoc
class __$TransferCommandCopyWithImpl<$Res>
    implements _$TransferCommandCopyWith<$Res> {
  __$TransferCommandCopyWithImpl(this._self, this._then);

  final _TransferCommand _self;
  final $Res Function(_TransferCommand) _then;

/// Create a copy of TransferCommand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceAccountId = null,Object? targetAccountId = null,Object? sourceAmount = null,Object? targetAmount = freezed,Object? exchangeRate = freezed,Object? occurredAt = freezed,}) {
  return _then(_TransferCommand(
sourceAccountId: null == sourceAccountId ? _self.sourceAccountId : sourceAccountId // ignore: cast_nullable_to_non_nullable
as String,targetAccountId: null == targetAccountId ? _self.targetAccountId : targetAccountId // ignore: cast_nullable_to_non_nullable
as String,sourceAmount: null == sourceAmount ? _self.sourceAmount : sourceAmount // ignore: cast_nullable_to_non_nullable
as Money,targetAmount: freezed == targetAmount ? _self.targetAmount : targetAmount // ignore: cast_nullable_to_non_nullable
as Money?,exchangeRate: freezed == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as ExchangeRate?,occurredAt: freezed == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of TransferCommand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get sourceAmount {
  
  return $MoneyCopyWith<$Res>(_self.sourceAmount, (value) {
    return _then(_self.copyWith(sourceAmount: value));
  });
}/// Create a copy of TransferCommand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res>? get targetAmount {
    if (_self.targetAmount == null) {
    return null;
  }

  return $MoneyCopyWith<$Res>(_self.targetAmount!, (value) {
    return _then(_self.copyWith(targetAmount: value));
  });
}/// Create a copy of TransferCommand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExchangeRateCopyWith<$Res>? get exchangeRate {
    if (_self.exchangeRate == null) {
    return null;
  }

  return $ExchangeRateCopyWith<$Res>(_self.exchangeRate!, (value) {
    return _then(_self.copyWith(exchangeRate: value));
  });
}
}

// dart format on
