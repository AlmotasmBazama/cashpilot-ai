// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Goal {

 String get id; String get title; String get description; GoalType get type;@DecimalConverter() Decimal get targetAmount;@DecimalConverter() Decimal get currentAmount; String get currency; String? get linkedAccountId; DateTime? get targetDate; String get icon; int get color; GoalStatus get status; DateTime get createdAt; DateTime get updatedAt; DateTime? get archivedAt; DateTime? get completedAt;
/// Create a copy of Goal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCopyWith<Goal> get copyWith => _$GoalCopyWithImpl<Goal>(this as Goal, _$identity);

  /// Serializes this Goal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Goal&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.type, type) || other.type == type)&&(identical(other.targetAmount, targetAmount) || other.targetAmount == targetAmount)&&(identical(other.currentAmount, currentAmount) || other.currentAmount == currentAmount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.linkedAccountId, linkedAccountId) || other.linkedAccountId == linkedAccountId)&&(identical(other.targetDate, targetDate) || other.targetDate == targetDate)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.color, color) || other.color == color)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,type,targetAmount,currentAmount,currency,linkedAccountId,targetDate,icon,color,status,createdAt,updatedAt,archivedAt,completedAt);

@override
String toString() {
  return 'Goal(id: $id, title: $title, description: $description, type: $type, targetAmount: $targetAmount, currentAmount: $currentAmount, currency: $currency, linkedAccountId: $linkedAccountId, targetDate: $targetDate, icon: $icon, color: $color, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $GoalCopyWith<$Res>  {
  factory $GoalCopyWith(Goal value, $Res Function(Goal) _then) = _$GoalCopyWithImpl;
@useResult
$Res call({
 String id, String title, String description, GoalType type,@DecimalConverter() Decimal targetAmount,@DecimalConverter() Decimal currentAmount, String currency, String? linkedAccountId, DateTime? targetDate, String icon, int color, GoalStatus status, DateTime createdAt, DateTime updatedAt, DateTime? archivedAt, DateTime? completedAt
});




}
/// @nodoc
class _$GoalCopyWithImpl<$Res>
    implements $GoalCopyWith<$Res> {
  _$GoalCopyWithImpl(this._self, this._then);

  final Goal _self;
  final $Res Function(Goal) _then;

/// Create a copy of Goal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = null,Object? type = null,Object? targetAmount = null,Object? currentAmount = null,Object? currency = null,Object? linkedAccountId = freezed,Object? targetDate = freezed,Object? icon = null,Object? color = null,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = freezed,Object? completedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as GoalType,targetAmount: null == targetAmount ? _self.targetAmount : targetAmount // ignore: cast_nullable_to_non_nullable
as Decimal,currentAmount: null == currentAmount ? _self.currentAmount : currentAmount // ignore: cast_nullable_to_non_nullable
as Decimal,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,linkedAccountId: freezed == linkedAccountId ? _self.linkedAccountId : linkedAccountId // ignore: cast_nullable_to_non_nullable
as String?,targetDate: freezed == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime?,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as GoalStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Goal].
extension GoalPatterns on Goal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Goal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Goal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Goal value)  $default,){
final _that = this;
switch (_that) {
case _Goal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Goal value)?  $default,){
final _that = this;
switch (_that) {
case _Goal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String description,  GoalType type, @DecimalConverter()  Decimal targetAmount, @DecimalConverter()  Decimal currentAmount,  String currency,  String? linkedAccountId,  DateTime? targetDate,  String icon,  int color,  GoalStatus status,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt,  DateTime? completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Goal() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.type,_that.targetAmount,_that.currentAmount,_that.currency,_that.linkedAccountId,_that.targetDate,_that.icon,_that.color,_that.status,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String description,  GoalType type, @DecimalConverter()  Decimal targetAmount, @DecimalConverter()  Decimal currentAmount,  String currency,  String? linkedAccountId,  DateTime? targetDate,  String icon,  int color,  GoalStatus status,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt,  DateTime? completedAt)  $default,) {final _that = this;
switch (_that) {
case _Goal():
return $default(_that.id,_that.title,_that.description,_that.type,_that.targetAmount,_that.currentAmount,_that.currency,_that.linkedAccountId,_that.targetDate,_that.icon,_that.color,_that.status,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String description,  GoalType type, @DecimalConverter()  Decimal targetAmount, @DecimalConverter()  Decimal currentAmount,  String currency,  String? linkedAccountId,  DateTime? targetDate,  String icon,  int color,  GoalStatus status,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt,  DateTime? completedAt)?  $default,) {final _that = this;
switch (_that) {
case _Goal() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.type,_that.targetAmount,_that.currentAmount,_that.currency,_that.linkedAccountId,_that.targetDate,_that.icon,_that.color,_that.status,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Goal extends Goal {
  const _Goal({required this.id, required this.title, required this.description, required this.type, @DecimalConverter() required this.targetAmount, @DecimalConverter() required this.currentAmount, required this.currency, this.linkedAccountId, this.targetDate, required this.icon, required this.color, required this.status, required this.createdAt, required this.updatedAt, this.archivedAt, this.completedAt}): super._();
  factory _Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);

@override final  String id;
@override final  String title;
@override final  String description;
@override final  GoalType type;
@override@DecimalConverter() final  Decimal targetAmount;
@override@DecimalConverter() final  Decimal currentAmount;
@override final  String currency;
@override final  String? linkedAccountId;
@override final  DateTime? targetDate;
@override final  String icon;
@override final  int color;
@override final  GoalStatus status;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime? archivedAt;
@override final  DateTime? completedAt;

/// Create a copy of Goal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalCopyWith<_Goal> get copyWith => __$GoalCopyWithImpl<_Goal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Goal&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.type, type) || other.type == type)&&(identical(other.targetAmount, targetAmount) || other.targetAmount == targetAmount)&&(identical(other.currentAmount, currentAmount) || other.currentAmount == currentAmount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.linkedAccountId, linkedAccountId) || other.linkedAccountId == linkedAccountId)&&(identical(other.targetDate, targetDate) || other.targetDate == targetDate)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.color, color) || other.color == color)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,type,targetAmount,currentAmount,currency,linkedAccountId,targetDate,icon,color,status,createdAt,updatedAt,archivedAt,completedAt);

@override
String toString() {
  return 'Goal(id: $id, title: $title, description: $description, type: $type, targetAmount: $targetAmount, currentAmount: $currentAmount, currency: $currency, linkedAccountId: $linkedAccountId, targetDate: $targetDate, icon: $icon, color: $color, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$GoalCopyWith<$Res> implements $GoalCopyWith<$Res> {
  factory _$GoalCopyWith(_Goal value, $Res Function(_Goal) _then) = __$GoalCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String description, GoalType type,@DecimalConverter() Decimal targetAmount,@DecimalConverter() Decimal currentAmount, String currency, String? linkedAccountId, DateTime? targetDate, String icon, int color, GoalStatus status, DateTime createdAt, DateTime updatedAt, DateTime? archivedAt, DateTime? completedAt
});




}
/// @nodoc
class __$GoalCopyWithImpl<$Res>
    implements _$GoalCopyWith<$Res> {
  __$GoalCopyWithImpl(this._self, this._then);

  final _Goal _self;
  final $Res Function(_Goal) _then;

/// Create a copy of Goal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? type = null,Object? targetAmount = null,Object? currentAmount = null,Object? currency = null,Object? linkedAccountId = freezed,Object? targetDate = freezed,Object? icon = null,Object? color = null,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = freezed,Object? completedAt = freezed,}) {
  return _then(_Goal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as GoalType,targetAmount: null == targetAmount ? _self.targetAmount : targetAmount // ignore: cast_nullable_to_non_nullable
as Decimal,currentAmount: null == currentAmount ? _self.currentAmount : currentAmount // ignore: cast_nullable_to_non_nullable
as Decimal,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,linkedAccountId: freezed == linkedAccountId ? _self.linkedAccountId : linkedAccountId // ignore: cast_nullable_to_non_nullable
as String?,targetDate: freezed == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime?,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as GoalStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
