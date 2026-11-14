// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TransactionDto {

 String get id; String get accountId; String get categoryId; String? get payeeId; String get amount; String get currencyCode; String get type; String get paymentMethod; String get source; String get status; String? get incomeSourceType; String? get transferGroupId; String? get exchangeRateFromCurrencyCode; String? get exchangeRateToCurrencyCode; String? get exchangeRate; DateTime? get exchangeRateAsOf; String? get note; DateTime get transactionDate; String? get location; int get attachmentCount; int? get aiConfidence; bool get needsReview; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of TransactionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionDtoCopyWith<TransactionDto> get copyWith => _$TransactionDtoCopyWithImpl<TransactionDto>(this as TransactionDto, _$identity);

  /// Serializes this TransactionDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.payeeId, payeeId) || other.payeeId == payeeId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.type, type) || other.type == type)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.source, source) || other.source == source)&&(identical(other.status, status) || other.status == status)&&(identical(other.incomeSourceType, incomeSourceType) || other.incomeSourceType == incomeSourceType)&&(identical(other.transferGroupId, transferGroupId) || other.transferGroupId == transferGroupId)&&(identical(other.exchangeRateFromCurrencyCode, exchangeRateFromCurrencyCode) || other.exchangeRateFromCurrencyCode == exchangeRateFromCurrencyCode)&&(identical(other.exchangeRateToCurrencyCode, exchangeRateToCurrencyCode) || other.exchangeRateToCurrencyCode == exchangeRateToCurrencyCode)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.exchangeRateAsOf, exchangeRateAsOf) || other.exchangeRateAsOf == exchangeRateAsOf)&&(identical(other.note, note) || other.note == note)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.location, location) || other.location == location)&&(identical(other.attachmentCount, attachmentCount) || other.attachmentCount == attachmentCount)&&(identical(other.aiConfidence, aiConfidence) || other.aiConfidence == aiConfidence)&&(identical(other.needsReview, needsReview) || other.needsReview == needsReview)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,accountId,categoryId,payeeId,amount,currencyCode,type,paymentMethod,source,status,incomeSourceType,transferGroupId,exchangeRateFromCurrencyCode,exchangeRateToCurrencyCode,exchangeRate,exchangeRateAsOf,note,transactionDate,location,attachmentCount,aiConfidence,needsReview,createdAt,updatedAt]);

@override
String toString() {
  return 'TransactionDto(id: $id, accountId: $accountId, categoryId: $categoryId, payeeId: $payeeId, amount: $amount, currencyCode: $currencyCode, type: $type, paymentMethod: $paymentMethod, source: $source, status: $status, incomeSourceType: $incomeSourceType, transferGroupId: $transferGroupId, exchangeRateFromCurrencyCode: $exchangeRateFromCurrencyCode, exchangeRateToCurrencyCode: $exchangeRateToCurrencyCode, exchangeRate: $exchangeRate, exchangeRateAsOf: $exchangeRateAsOf, note: $note, transactionDate: $transactionDate, location: $location, attachmentCount: $attachmentCount, aiConfidence: $aiConfidence, needsReview: $needsReview, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $TransactionDtoCopyWith<$Res>  {
  factory $TransactionDtoCopyWith(TransactionDto value, $Res Function(TransactionDto) _then) = _$TransactionDtoCopyWithImpl;
@useResult
$Res call({
 String id, String accountId, String categoryId, String? payeeId, String amount, String currencyCode, String type, String paymentMethod, String source, String status, String? incomeSourceType, String? transferGroupId, String? exchangeRateFromCurrencyCode, String? exchangeRateToCurrencyCode, String? exchangeRate, DateTime? exchangeRateAsOf, String? note, DateTime transactionDate, String? location, int attachmentCount, int? aiConfidence, bool needsReview, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$TransactionDtoCopyWithImpl<$Res>
    implements $TransactionDtoCopyWith<$Res> {
  _$TransactionDtoCopyWithImpl(this._self, this._then);

  final TransactionDto _self;
  final $Res Function(TransactionDto) _then;

/// Create a copy of TransactionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? accountId = null,Object? categoryId = null,Object? payeeId = freezed,Object? amount = null,Object? currencyCode = null,Object? type = null,Object? paymentMethod = null,Object? source = null,Object? status = null,Object? incomeSourceType = freezed,Object? transferGroupId = freezed,Object? exchangeRateFromCurrencyCode = freezed,Object? exchangeRateToCurrencyCode = freezed,Object? exchangeRate = freezed,Object? exchangeRateAsOf = freezed,Object? note = freezed,Object? transactionDate = null,Object? location = freezed,Object? attachmentCount = null,Object? aiConfidence = freezed,Object? needsReview = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,payeeId: freezed == payeeId ? _self.payeeId : payeeId // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,incomeSourceType: freezed == incomeSourceType ? _self.incomeSourceType : incomeSourceType // ignore: cast_nullable_to_non_nullable
as String?,transferGroupId: freezed == transferGroupId ? _self.transferGroupId : transferGroupId // ignore: cast_nullable_to_non_nullable
as String?,exchangeRateFromCurrencyCode: freezed == exchangeRateFromCurrencyCode ? _self.exchangeRateFromCurrencyCode : exchangeRateFromCurrencyCode // ignore: cast_nullable_to_non_nullable
as String?,exchangeRateToCurrencyCode: freezed == exchangeRateToCurrencyCode ? _self.exchangeRateToCurrencyCode : exchangeRateToCurrencyCode // ignore: cast_nullable_to_non_nullable
as String?,exchangeRate: freezed == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as String?,exchangeRateAsOf: freezed == exchangeRateAsOf ? _self.exchangeRateAsOf : exchangeRateAsOf // ignore: cast_nullable_to_non_nullable
as DateTime?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,transactionDate: null == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as DateTime,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,attachmentCount: null == attachmentCount ? _self.attachmentCount : attachmentCount // ignore: cast_nullable_to_non_nullable
as int,aiConfidence: freezed == aiConfidence ? _self.aiConfidence : aiConfidence // ignore: cast_nullable_to_non_nullable
as int?,needsReview: null == needsReview ? _self.needsReview : needsReview // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [TransactionDto].
extension TransactionDtoPatterns on TransactionDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransactionDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransactionDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransactionDto value)  $default,){
final _that = this;
switch (_that) {
case _TransactionDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransactionDto value)?  $default,){
final _that = this;
switch (_that) {
case _TransactionDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String accountId,  String categoryId,  String? payeeId,  String amount,  String currencyCode,  String type,  String paymentMethod,  String source,  String status,  String? incomeSourceType,  String? transferGroupId,  String? exchangeRateFromCurrencyCode,  String? exchangeRateToCurrencyCode,  String? exchangeRate,  DateTime? exchangeRateAsOf,  String? note,  DateTime transactionDate,  String? location,  int attachmentCount,  int? aiConfidence,  bool needsReview,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransactionDto() when $default != null:
return $default(_that.id,_that.accountId,_that.categoryId,_that.payeeId,_that.amount,_that.currencyCode,_that.type,_that.paymentMethod,_that.source,_that.status,_that.incomeSourceType,_that.transferGroupId,_that.exchangeRateFromCurrencyCode,_that.exchangeRateToCurrencyCode,_that.exchangeRate,_that.exchangeRateAsOf,_that.note,_that.transactionDate,_that.location,_that.attachmentCount,_that.aiConfidence,_that.needsReview,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String accountId,  String categoryId,  String? payeeId,  String amount,  String currencyCode,  String type,  String paymentMethod,  String source,  String status,  String? incomeSourceType,  String? transferGroupId,  String? exchangeRateFromCurrencyCode,  String? exchangeRateToCurrencyCode,  String? exchangeRate,  DateTime? exchangeRateAsOf,  String? note,  DateTime transactionDate,  String? location,  int attachmentCount,  int? aiConfidence,  bool needsReview,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _TransactionDto():
return $default(_that.id,_that.accountId,_that.categoryId,_that.payeeId,_that.amount,_that.currencyCode,_that.type,_that.paymentMethod,_that.source,_that.status,_that.incomeSourceType,_that.transferGroupId,_that.exchangeRateFromCurrencyCode,_that.exchangeRateToCurrencyCode,_that.exchangeRate,_that.exchangeRateAsOf,_that.note,_that.transactionDate,_that.location,_that.attachmentCount,_that.aiConfidence,_that.needsReview,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String accountId,  String categoryId,  String? payeeId,  String amount,  String currencyCode,  String type,  String paymentMethod,  String source,  String status,  String? incomeSourceType,  String? transferGroupId,  String? exchangeRateFromCurrencyCode,  String? exchangeRateToCurrencyCode,  String? exchangeRate,  DateTime? exchangeRateAsOf,  String? note,  DateTime transactionDate,  String? location,  int attachmentCount,  int? aiConfidence,  bool needsReview,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _TransactionDto() when $default != null:
return $default(_that.id,_that.accountId,_that.categoryId,_that.payeeId,_that.amount,_that.currencyCode,_that.type,_that.paymentMethod,_that.source,_that.status,_that.incomeSourceType,_that.transferGroupId,_that.exchangeRateFromCurrencyCode,_that.exchangeRateToCurrencyCode,_that.exchangeRate,_that.exchangeRateAsOf,_that.note,_that.transactionDate,_that.location,_that.attachmentCount,_that.aiConfidence,_that.needsReview,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TransactionDto implements TransactionDto {
  const _TransactionDto({required this.id, required this.accountId, required this.categoryId, this.payeeId, required this.amount, required this.currencyCode, required this.type, required this.paymentMethod, required this.source, required this.status, this.incomeSourceType, this.transferGroupId, this.exchangeRateFromCurrencyCode, this.exchangeRateToCurrencyCode, this.exchangeRate, this.exchangeRateAsOf, this.note, required this.transactionDate, this.location, required this.attachmentCount, this.aiConfidence, required this.needsReview, required this.createdAt, required this.updatedAt});
  factory _TransactionDto.fromJson(Map<String, dynamic> json) => _$TransactionDtoFromJson(json);

@override final  String id;
@override final  String accountId;
@override final  String categoryId;
@override final  String? payeeId;
@override final  String amount;
@override final  String currencyCode;
@override final  String type;
@override final  String paymentMethod;
@override final  String source;
@override final  String status;
@override final  String? incomeSourceType;
@override final  String? transferGroupId;
@override final  String? exchangeRateFromCurrencyCode;
@override final  String? exchangeRateToCurrencyCode;
@override final  String? exchangeRate;
@override final  DateTime? exchangeRateAsOf;
@override final  String? note;
@override final  DateTime transactionDate;
@override final  String? location;
@override final  int attachmentCount;
@override final  int? aiConfidence;
@override final  bool needsReview;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of TransactionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransactionDtoCopyWith<_TransactionDto> get copyWith => __$TransactionDtoCopyWithImpl<_TransactionDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransactionDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransactionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.payeeId, payeeId) || other.payeeId == payeeId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.type, type) || other.type == type)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.source, source) || other.source == source)&&(identical(other.status, status) || other.status == status)&&(identical(other.incomeSourceType, incomeSourceType) || other.incomeSourceType == incomeSourceType)&&(identical(other.transferGroupId, transferGroupId) || other.transferGroupId == transferGroupId)&&(identical(other.exchangeRateFromCurrencyCode, exchangeRateFromCurrencyCode) || other.exchangeRateFromCurrencyCode == exchangeRateFromCurrencyCode)&&(identical(other.exchangeRateToCurrencyCode, exchangeRateToCurrencyCode) || other.exchangeRateToCurrencyCode == exchangeRateToCurrencyCode)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.exchangeRateAsOf, exchangeRateAsOf) || other.exchangeRateAsOf == exchangeRateAsOf)&&(identical(other.note, note) || other.note == note)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.location, location) || other.location == location)&&(identical(other.attachmentCount, attachmentCount) || other.attachmentCount == attachmentCount)&&(identical(other.aiConfidence, aiConfidence) || other.aiConfidence == aiConfidence)&&(identical(other.needsReview, needsReview) || other.needsReview == needsReview)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,accountId,categoryId,payeeId,amount,currencyCode,type,paymentMethod,source,status,incomeSourceType,transferGroupId,exchangeRateFromCurrencyCode,exchangeRateToCurrencyCode,exchangeRate,exchangeRateAsOf,note,transactionDate,location,attachmentCount,aiConfidence,needsReview,createdAt,updatedAt]);

@override
String toString() {
  return 'TransactionDto(id: $id, accountId: $accountId, categoryId: $categoryId, payeeId: $payeeId, amount: $amount, currencyCode: $currencyCode, type: $type, paymentMethod: $paymentMethod, source: $source, status: $status, incomeSourceType: $incomeSourceType, transferGroupId: $transferGroupId, exchangeRateFromCurrencyCode: $exchangeRateFromCurrencyCode, exchangeRateToCurrencyCode: $exchangeRateToCurrencyCode, exchangeRate: $exchangeRate, exchangeRateAsOf: $exchangeRateAsOf, note: $note, transactionDate: $transactionDate, location: $location, attachmentCount: $attachmentCount, aiConfidence: $aiConfidence, needsReview: $needsReview, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$TransactionDtoCopyWith<$Res> implements $TransactionDtoCopyWith<$Res> {
  factory _$TransactionDtoCopyWith(_TransactionDto value, $Res Function(_TransactionDto) _then) = __$TransactionDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String accountId, String categoryId, String? payeeId, String amount, String currencyCode, String type, String paymentMethod, String source, String status, String? incomeSourceType, String? transferGroupId, String? exchangeRateFromCurrencyCode, String? exchangeRateToCurrencyCode, String? exchangeRate, DateTime? exchangeRateAsOf, String? note, DateTime transactionDate, String? location, int attachmentCount, int? aiConfidence, bool needsReview, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$TransactionDtoCopyWithImpl<$Res>
    implements _$TransactionDtoCopyWith<$Res> {
  __$TransactionDtoCopyWithImpl(this._self, this._then);

  final _TransactionDto _self;
  final $Res Function(_TransactionDto) _then;

/// Create a copy of TransactionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? accountId = null,Object? categoryId = null,Object? payeeId = freezed,Object? amount = null,Object? currencyCode = null,Object? type = null,Object? paymentMethod = null,Object? source = null,Object? status = null,Object? incomeSourceType = freezed,Object? transferGroupId = freezed,Object? exchangeRateFromCurrencyCode = freezed,Object? exchangeRateToCurrencyCode = freezed,Object? exchangeRate = freezed,Object? exchangeRateAsOf = freezed,Object? note = freezed,Object? transactionDate = null,Object? location = freezed,Object? attachmentCount = null,Object? aiConfidence = freezed,Object? needsReview = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_TransactionDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,payeeId: freezed == payeeId ? _self.payeeId : payeeId // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,incomeSourceType: freezed == incomeSourceType ? _self.incomeSourceType : incomeSourceType // ignore: cast_nullable_to_non_nullable
as String?,transferGroupId: freezed == transferGroupId ? _self.transferGroupId : transferGroupId // ignore: cast_nullable_to_non_nullable
as String?,exchangeRateFromCurrencyCode: freezed == exchangeRateFromCurrencyCode ? _self.exchangeRateFromCurrencyCode : exchangeRateFromCurrencyCode // ignore: cast_nullable_to_non_nullable
as String?,exchangeRateToCurrencyCode: freezed == exchangeRateToCurrencyCode ? _self.exchangeRateToCurrencyCode : exchangeRateToCurrencyCode // ignore: cast_nullable_to_non_nullable
as String?,exchangeRate: freezed == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as String?,exchangeRateAsOf: freezed == exchangeRateAsOf ? _self.exchangeRateAsOf : exchangeRateAsOf // ignore: cast_nullable_to_non_nullable
as DateTime?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,transactionDate: null == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as DateTime,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,attachmentCount: null == attachmentCount ? _self.attachmentCount : attachmentCount // ignore: cast_nullable_to_non_nullable
as int,aiConfidence: freezed == aiConfidence ? _self.aiConfidence : aiConfidence // ignore: cast_nullable_to_non_nullable
as int?,needsReview: null == needsReview ? _self.needsReview : needsReview // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
