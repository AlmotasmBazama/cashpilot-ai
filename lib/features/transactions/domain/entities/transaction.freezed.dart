// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Transaction {

 String get id; String get accountId; String get categoryId; String? get payeeId; Money get amount; TransactionType get type; PaymentMethod get paymentMethod; TransactionSource get source; TransactionStatus get status; IncomeSourceType? get incomeSourceType; String? get transferGroupId; ExchangeRate? get exchangeRate; String? get note; DateTime get transactionDate; String? get location; int get attachmentCount; int? get aiConfidence; bool get needsReview; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Transaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionCopyWith<Transaction> get copyWith => _$TransactionCopyWithImpl<Transaction>(this as Transaction, _$identity);

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Transaction&&(identical(other.id, id) || other.id == id)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.payeeId, payeeId) || other.payeeId == payeeId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.type, type) || other.type == type)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.source, source) || other.source == source)&&(identical(other.status, status) || other.status == status)&&(identical(other.incomeSourceType, incomeSourceType) || other.incomeSourceType == incomeSourceType)&&(identical(other.transferGroupId, transferGroupId) || other.transferGroupId == transferGroupId)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.note, note) || other.note == note)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.location, location) || other.location == location)&&(identical(other.attachmentCount, attachmentCount) || other.attachmentCount == attachmentCount)&&(identical(other.aiConfidence, aiConfidence) || other.aiConfidence == aiConfidence)&&(identical(other.needsReview, needsReview) || other.needsReview == needsReview)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,accountId,categoryId,payeeId,amount,type,paymentMethod,source,status,incomeSourceType,transferGroupId,exchangeRate,note,transactionDate,location,attachmentCount,aiConfidence,needsReview,createdAt,updatedAt]);

@override
String toString() {
  return 'Transaction(id: $id, accountId: $accountId, categoryId: $categoryId, payeeId: $payeeId, amount: $amount, type: $type, paymentMethod: $paymentMethod, source: $source, status: $status, incomeSourceType: $incomeSourceType, transferGroupId: $transferGroupId, exchangeRate: $exchangeRate, note: $note, transactionDate: $transactionDate, location: $location, attachmentCount: $attachmentCount, aiConfidence: $aiConfidence, needsReview: $needsReview, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $TransactionCopyWith<$Res>  {
  factory $TransactionCopyWith(Transaction value, $Res Function(Transaction) _then) = _$TransactionCopyWithImpl;
@useResult
$Res call({
 String id, String accountId, String categoryId, String? payeeId, Money amount, TransactionType type, PaymentMethod paymentMethod, TransactionSource source, TransactionStatus status, IncomeSourceType? incomeSourceType, String? transferGroupId, ExchangeRate? exchangeRate, String? note, DateTime transactionDate, String? location, int attachmentCount, int? aiConfidence, bool needsReview, DateTime createdAt, DateTime updatedAt
});


$MoneyCopyWith<$Res> get amount;$ExchangeRateCopyWith<$Res>? get exchangeRate;

}
/// @nodoc
class _$TransactionCopyWithImpl<$Res>
    implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._self, this._then);

  final Transaction _self;
  final $Res Function(Transaction) _then;

/// Create a copy of Transaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? accountId = null,Object? categoryId = null,Object? payeeId = freezed,Object? amount = null,Object? type = null,Object? paymentMethod = null,Object? source = null,Object? status = null,Object? incomeSourceType = freezed,Object? transferGroupId = freezed,Object? exchangeRate = freezed,Object? note = freezed,Object? transactionDate = null,Object? location = freezed,Object? attachmentCount = null,Object? aiConfidence = freezed,Object? needsReview = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,payeeId: freezed == payeeId ? _self.payeeId : payeeId // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TransactionType,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as PaymentMethod,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TransactionSource,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TransactionStatus,incomeSourceType: freezed == incomeSourceType ? _self.incomeSourceType : incomeSourceType // ignore: cast_nullable_to_non_nullable
as IncomeSourceType?,transferGroupId: freezed == transferGroupId ? _self.transferGroupId : transferGroupId // ignore: cast_nullable_to_non_nullable
as String?,exchangeRate: freezed == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as ExchangeRate?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
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
/// Create a copy of Transaction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get amount {
  
  return $MoneyCopyWith<$Res>(_self.amount, (value) {
    return _then(_self.copyWith(amount: value));
  });
}/// Create a copy of Transaction
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


/// Adds pattern-matching-related methods to [Transaction].
extension TransactionPatterns on Transaction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Transaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Transaction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Transaction value)  $default,){
final _that = this;
switch (_that) {
case _Transaction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Transaction value)?  $default,){
final _that = this;
switch (_that) {
case _Transaction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String accountId,  String categoryId,  String? payeeId,  Money amount,  TransactionType type,  PaymentMethod paymentMethod,  TransactionSource source,  TransactionStatus status,  IncomeSourceType? incomeSourceType,  String? transferGroupId,  ExchangeRate? exchangeRate,  String? note,  DateTime transactionDate,  String? location,  int attachmentCount,  int? aiConfidence,  bool needsReview,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Transaction() when $default != null:
return $default(_that.id,_that.accountId,_that.categoryId,_that.payeeId,_that.amount,_that.type,_that.paymentMethod,_that.source,_that.status,_that.incomeSourceType,_that.transferGroupId,_that.exchangeRate,_that.note,_that.transactionDate,_that.location,_that.attachmentCount,_that.aiConfidence,_that.needsReview,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String accountId,  String categoryId,  String? payeeId,  Money amount,  TransactionType type,  PaymentMethod paymentMethod,  TransactionSource source,  TransactionStatus status,  IncomeSourceType? incomeSourceType,  String? transferGroupId,  ExchangeRate? exchangeRate,  String? note,  DateTime transactionDate,  String? location,  int attachmentCount,  int? aiConfidence,  bool needsReview,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Transaction():
return $default(_that.id,_that.accountId,_that.categoryId,_that.payeeId,_that.amount,_that.type,_that.paymentMethod,_that.source,_that.status,_that.incomeSourceType,_that.transferGroupId,_that.exchangeRate,_that.note,_that.transactionDate,_that.location,_that.attachmentCount,_that.aiConfidence,_that.needsReview,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String accountId,  String categoryId,  String? payeeId,  Money amount,  TransactionType type,  PaymentMethod paymentMethod,  TransactionSource source,  TransactionStatus status,  IncomeSourceType? incomeSourceType,  String? transferGroupId,  ExchangeRate? exchangeRate,  String? note,  DateTime transactionDate,  String? location,  int attachmentCount,  int? aiConfidence,  bool needsReview,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Transaction() when $default != null:
return $default(_that.id,_that.accountId,_that.categoryId,_that.payeeId,_that.amount,_that.type,_that.paymentMethod,_that.source,_that.status,_that.incomeSourceType,_that.transferGroupId,_that.exchangeRate,_that.note,_that.transactionDate,_that.location,_that.attachmentCount,_that.aiConfidence,_that.needsReview,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Transaction extends Transaction {
  const _Transaction({required this.id, required this.accountId, required this.categoryId, this.payeeId, required this.amount, required this.type, required this.paymentMethod, required this.source, required this.status, this.incomeSourceType, this.transferGroupId, this.exchangeRate, this.note, required this.transactionDate, this.location, required this.attachmentCount, this.aiConfidence, required this.needsReview, required this.createdAt, required this.updatedAt}): super._();
  factory _Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);

@override final  String id;
@override final  String accountId;
@override final  String categoryId;
@override final  String? payeeId;
@override final  Money amount;
@override final  TransactionType type;
@override final  PaymentMethod paymentMethod;
@override final  TransactionSource source;
@override final  TransactionStatus status;
@override final  IncomeSourceType? incomeSourceType;
@override final  String? transferGroupId;
@override final  ExchangeRate? exchangeRate;
@override final  String? note;
@override final  DateTime transactionDate;
@override final  String? location;
@override final  int attachmentCount;
@override final  int? aiConfidence;
@override final  bool needsReview;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Transaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransactionCopyWith<_Transaction> get copyWith => __$TransactionCopyWithImpl<_Transaction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransactionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Transaction&&(identical(other.id, id) || other.id == id)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.payeeId, payeeId) || other.payeeId == payeeId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.type, type) || other.type == type)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.source, source) || other.source == source)&&(identical(other.status, status) || other.status == status)&&(identical(other.incomeSourceType, incomeSourceType) || other.incomeSourceType == incomeSourceType)&&(identical(other.transferGroupId, transferGroupId) || other.transferGroupId == transferGroupId)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.note, note) || other.note == note)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.location, location) || other.location == location)&&(identical(other.attachmentCount, attachmentCount) || other.attachmentCount == attachmentCount)&&(identical(other.aiConfidence, aiConfidence) || other.aiConfidence == aiConfidence)&&(identical(other.needsReview, needsReview) || other.needsReview == needsReview)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,accountId,categoryId,payeeId,amount,type,paymentMethod,source,status,incomeSourceType,transferGroupId,exchangeRate,note,transactionDate,location,attachmentCount,aiConfidence,needsReview,createdAt,updatedAt]);

@override
String toString() {
  return 'Transaction(id: $id, accountId: $accountId, categoryId: $categoryId, payeeId: $payeeId, amount: $amount, type: $type, paymentMethod: $paymentMethod, source: $source, status: $status, incomeSourceType: $incomeSourceType, transferGroupId: $transferGroupId, exchangeRate: $exchangeRate, note: $note, transactionDate: $transactionDate, location: $location, attachmentCount: $attachmentCount, aiConfidence: $aiConfidence, needsReview: $needsReview, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$TransactionCopyWith<$Res> implements $TransactionCopyWith<$Res> {
  factory _$TransactionCopyWith(_Transaction value, $Res Function(_Transaction) _then) = __$TransactionCopyWithImpl;
@override @useResult
$Res call({
 String id, String accountId, String categoryId, String? payeeId, Money amount, TransactionType type, PaymentMethod paymentMethod, TransactionSource source, TransactionStatus status, IncomeSourceType? incomeSourceType, String? transferGroupId, ExchangeRate? exchangeRate, String? note, DateTime transactionDate, String? location, int attachmentCount, int? aiConfidence, bool needsReview, DateTime createdAt, DateTime updatedAt
});


@override $MoneyCopyWith<$Res> get amount;@override $ExchangeRateCopyWith<$Res>? get exchangeRate;

}
/// @nodoc
class __$TransactionCopyWithImpl<$Res>
    implements _$TransactionCopyWith<$Res> {
  __$TransactionCopyWithImpl(this._self, this._then);

  final _Transaction _self;
  final $Res Function(_Transaction) _then;

/// Create a copy of Transaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? accountId = null,Object? categoryId = null,Object? payeeId = freezed,Object? amount = null,Object? type = null,Object? paymentMethod = null,Object? source = null,Object? status = null,Object? incomeSourceType = freezed,Object? transferGroupId = freezed,Object? exchangeRate = freezed,Object? note = freezed,Object? transactionDate = null,Object? location = freezed,Object? attachmentCount = null,Object? aiConfidence = freezed,Object? needsReview = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Transaction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,payeeId: freezed == payeeId ? _self.payeeId : payeeId // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TransactionType,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as PaymentMethod,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TransactionSource,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TransactionStatus,incomeSourceType: freezed == incomeSourceType ? _self.incomeSourceType : incomeSourceType // ignore: cast_nullable_to_non_nullable
as IncomeSourceType?,transferGroupId: freezed == transferGroupId ? _self.transferGroupId : transferGroupId // ignore: cast_nullable_to_non_nullable
as String?,exchangeRate: freezed == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as ExchangeRate?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
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

/// Create a copy of Transaction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MoneyCopyWith<$Res> get amount {
  
  return $MoneyCopyWith<$Res>(_self.amount, (value) {
    return _then(_self.copyWith(amount: value));
  });
}/// Create a copy of Transaction
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
