// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_contribution.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GoalContribution {

 String get id; String get goalId;@DecimalConverter() Decimal get amount; String get currency;@DecimalConverter() Decimal? get creditedAmount; DateTime get date; String get note; String? get linkedTransactionId; DateTime get createdAt; DateTime get updatedAt; DateTime? get reversedAt;
/// Create a copy of GoalContribution
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalContributionCopyWith<GoalContribution> get copyWith => _$GoalContributionCopyWithImpl<GoalContribution>(this as GoalContribution, _$identity);

  /// Serializes this GoalContribution to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalContribution&&(identical(other.id, id) || other.id == id)&&(identical(other.goalId, goalId) || other.goalId == goalId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.creditedAmount, creditedAmount) || other.creditedAmount == creditedAmount)&&(identical(other.date, date) || other.date == date)&&(identical(other.note, note) || other.note == note)&&(identical(other.linkedTransactionId, linkedTransactionId) || other.linkedTransactionId == linkedTransactionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.reversedAt, reversedAt) || other.reversedAt == reversedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,goalId,amount,currency,creditedAmount,date,note,linkedTransactionId,createdAt,updatedAt,reversedAt);

@override
String toString() {
  return 'GoalContribution(id: $id, goalId: $goalId, amount: $amount, currency: $currency, creditedAmount: $creditedAmount, date: $date, note: $note, linkedTransactionId: $linkedTransactionId, createdAt: $createdAt, updatedAt: $updatedAt, reversedAt: $reversedAt)';
}


}

/// @nodoc
abstract mixin class $GoalContributionCopyWith<$Res>  {
  factory $GoalContributionCopyWith(GoalContribution value, $Res Function(GoalContribution) _then) = _$GoalContributionCopyWithImpl;
@useResult
$Res call({
 String id, String goalId,@DecimalConverter() Decimal amount, String currency,@DecimalConverter() Decimal? creditedAmount, DateTime date, String note, String? linkedTransactionId, DateTime createdAt, DateTime updatedAt, DateTime? reversedAt
});




}
/// @nodoc
class _$GoalContributionCopyWithImpl<$Res>
    implements $GoalContributionCopyWith<$Res> {
  _$GoalContributionCopyWithImpl(this._self, this._then);

  final GoalContribution _self;
  final $Res Function(GoalContribution) _then;

/// Create a copy of GoalContribution
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? goalId = null,Object? amount = null,Object? currency = null,Object? creditedAmount = freezed,Object? date = null,Object? note = null,Object? linkedTransactionId = freezed,Object? createdAt = null,Object? updatedAt = null,Object? reversedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,goalId: null == goalId ? _self.goalId : goalId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,creditedAmount: freezed == creditedAmount ? _self.creditedAmount : creditedAmount // ignore: cast_nullable_to_non_nullable
as Decimal?,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,linkedTransactionId: freezed == linkedTransactionId ? _self.linkedTransactionId : linkedTransactionId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,reversedAt: freezed == reversedAt ? _self.reversedAt : reversedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalContribution].
extension GoalContributionPatterns on GoalContribution {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalContribution value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalContribution() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalContribution value)  $default,){
final _that = this;
switch (_that) {
case _GoalContribution():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalContribution value)?  $default,){
final _that = this;
switch (_that) {
case _GoalContribution() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String goalId, @DecimalConverter()  Decimal amount,  String currency, @DecimalConverter()  Decimal? creditedAmount,  DateTime date,  String note,  String? linkedTransactionId,  DateTime createdAt,  DateTime updatedAt,  DateTime? reversedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalContribution() when $default != null:
return $default(_that.id,_that.goalId,_that.amount,_that.currency,_that.creditedAmount,_that.date,_that.note,_that.linkedTransactionId,_that.createdAt,_that.updatedAt,_that.reversedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String goalId, @DecimalConverter()  Decimal amount,  String currency, @DecimalConverter()  Decimal? creditedAmount,  DateTime date,  String note,  String? linkedTransactionId,  DateTime createdAt,  DateTime updatedAt,  DateTime? reversedAt)  $default,) {final _that = this;
switch (_that) {
case _GoalContribution():
return $default(_that.id,_that.goalId,_that.amount,_that.currency,_that.creditedAmount,_that.date,_that.note,_that.linkedTransactionId,_that.createdAt,_that.updatedAt,_that.reversedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String goalId, @DecimalConverter()  Decimal amount,  String currency, @DecimalConverter()  Decimal? creditedAmount,  DateTime date,  String note,  String? linkedTransactionId,  DateTime createdAt,  DateTime updatedAt,  DateTime? reversedAt)?  $default,) {final _that = this;
switch (_that) {
case _GoalContribution() when $default != null:
return $default(_that.id,_that.goalId,_that.amount,_that.currency,_that.creditedAmount,_that.date,_that.note,_that.linkedTransactionId,_that.createdAt,_that.updatedAt,_that.reversedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoalContribution extends GoalContribution {
  const _GoalContribution({required this.id, required this.goalId, @DecimalConverter() required this.amount, required this.currency, @DecimalConverter() this.creditedAmount, required this.date, required this.note, this.linkedTransactionId, required this.createdAt, required this.updatedAt, this.reversedAt}): super._();
  factory _GoalContribution.fromJson(Map<String, dynamic> json) => _$GoalContributionFromJson(json);

@override final  String id;
@override final  String goalId;
@override@DecimalConverter() final  Decimal amount;
@override final  String currency;
@override@DecimalConverter() final  Decimal? creditedAmount;
@override final  DateTime date;
@override final  String note;
@override final  String? linkedTransactionId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime? reversedAt;

/// Create a copy of GoalContribution
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalContributionCopyWith<_GoalContribution> get copyWith => __$GoalContributionCopyWithImpl<_GoalContribution>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalContributionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalContribution&&(identical(other.id, id) || other.id == id)&&(identical(other.goalId, goalId) || other.goalId == goalId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.creditedAmount, creditedAmount) || other.creditedAmount == creditedAmount)&&(identical(other.date, date) || other.date == date)&&(identical(other.note, note) || other.note == note)&&(identical(other.linkedTransactionId, linkedTransactionId) || other.linkedTransactionId == linkedTransactionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.reversedAt, reversedAt) || other.reversedAt == reversedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,goalId,amount,currency,creditedAmount,date,note,linkedTransactionId,createdAt,updatedAt,reversedAt);

@override
String toString() {
  return 'GoalContribution(id: $id, goalId: $goalId, amount: $amount, currency: $currency, creditedAmount: $creditedAmount, date: $date, note: $note, linkedTransactionId: $linkedTransactionId, createdAt: $createdAt, updatedAt: $updatedAt, reversedAt: $reversedAt)';
}


}

/// @nodoc
abstract mixin class _$GoalContributionCopyWith<$Res> implements $GoalContributionCopyWith<$Res> {
  factory _$GoalContributionCopyWith(_GoalContribution value, $Res Function(_GoalContribution) _then) = __$GoalContributionCopyWithImpl;
@override @useResult
$Res call({
 String id, String goalId,@DecimalConverter() Decimal amount, String currency,@DecimalConverter() Decimal? creditedAmount, DateTime date, String note, String? linkedTransactionId, DateTime createdAt, DateTime updatedAt, DateTime? reversedAt
});




}
/// @nodoc
class __$GoalContributionCopyWithImpl<$Res>
    implements _$GoalContributionCopyWith<$Res> {
  __$GoalContributionCopyWithImpl(this._self, this._then);

  final _GoalContribution _self;
  final $Res Function(_GoalContribution) _then;

/// Create a copy of GoalContribution
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? goalId = null,Object? amount = null,Object? currency = null,Object? creditedAmount = freezed,Object? date = null,Object? note = null,Object? linkedTransactionId = freezed,Object? createdAt = null,Object? updatedAt = null,Object? reversedAt = freezed,}) {
  return _then(_GoalContribution(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,goalId: null == goalId ? _self.goalId : goalId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,creditedAmount: freezed == creditedAmount ? _self.creditedAmount : creditedAmount // ignore: cast_nullable_to_non_nullable
as Decimal?,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,linkedTransactionId: freezed == linkedTransactionId ? _self.linkedTransactionId : linkedTransactionId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,reversedAt: freezed == reversedAt ? _self.reversedAt : reversedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
