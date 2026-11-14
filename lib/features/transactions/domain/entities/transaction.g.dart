// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Transaction _$TransactionFromJson(Map<String, dynamic> json) => _Transaction(
  id: json['id'] as String,
  accountId: json['accountId'] as String,
  categoryId: json['categoryId'] as String,
  payeeId: json['payeeId'] as String?,
  amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
  type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
  paymentMethod: $enumDecode(_$PaymentMethodEnumMap, json['paymentMethod']),
  source: $enumDecode(_$TransactionSourceEnumMap, json['source']),
  status: $enumDecode(_$TransactionStatusEnumMap, json['status']),
  incomeSourceType: $enumDecodeNullable(
    _$IncomeSourceTypeEnumMap,
    json['incomeSourceType'],
  ),
  transferGroupId: json['transferGroupId'] as String?,
  exchangeRate: json['exchangeRate'] == null
      ? null
      : ExchangeRate.fromJson(json['exchangeRate'] as Map<String, dynamic>),
  note: json['note'] as String?,
  transactionDate: DateTime.parse(json['transactionDate'] as String),
  location: json['location'] as String?,
  attachmentCount: (json['attachmentCount'] as num).toInt(),
  aiConfidence: (json['aiConfidence'] as num?)?.toInt(),
  needsReview: json['needsReview'] as bool,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$TransactionToJson(_Transaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'accountId': instance.accountId,
      'categoryId': instance.categoryId,
      'payeeId': instance.payeeId,
      'amount': instance.amount,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'paymentMethod': _$PaymentMethodEnumMap[instance.paymentMethod]!,
      'source': _$TransactionSourceEnumMap[instance.source]!,
      'status': _$TransactionStatusEnumMap[instance.status]!,
      'incomeSourceType': _$IncomeSourceTypeEnumMap[instance.incomeSourceType],
      'transferGroupId': instance.transferGroupId,
      'exchangeRate': instance.exchangeRate,
      'note': instance.note,
      'transactionDate': instance.transactionDate.toIso8601String(),
      'location': instance.location,
      'attachmentCount': instance.attachmentCount,
      'aiConfidence': instance.aiConfidence,
      'needsReview': instance.needsReview,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$TransactionTypeEnumMap = {
  TransactionType.expense: 'expense',
  TransactionType.income: 'income',
  TransactionType.transferOut: 'transferOut',
  TransactionType.transferIn: 'transferIn',
};

const _$PaymentMethodEnumMap = {
  PaymentMethod.cash: 'cash',
  PaymentMethod.debitCard: 'debitCard',
  PaymentMethod.creditCard: 'creditCard',
  PaymentMethod.bankTransfer: 'bankTransfer',
  PaymentMethod.digitalWallet: 'digitalWallet',
  PaymentMethod.edfaly: 'edfaly',
  PaymentMethod.masrafiPay: 'masrafiPay',
  PaymentMethod.mobiCash: 'mobiCash',
  PaymentMethod.yusrPay: 'yusrPay',
  PaymentMethod.check: 'check',
  PaymentMethod.crypto: 'crypto',
  PaymentMethod.other: 'other',
};

const _$TransactionSourceEnumMap = {
  TransactionSource.manual: 'manual',
  TransactionSource.imported: 'imported',
  TransactionSource.recurring: 'recurring',
  TransactionSource.aiGenerated: 'aiGenerated',
  TransactionSource.cloudSync: 'cloudSync',
  TransactionSource.system: 'system',
};

const _$TransactionStatusEnumMap = {
  TransactionStatus.pending: 'pending',
  TransactionStatus.posted: 'posted',
  TransactionStatus.cancelled: 'cancelled',
  TransactionStatus.failed: 'failed',
};

const _$IncomeSourceTypeEnumMap = {
  IncomeSourceType.salary: 'salary',
  IncomeSourceType.freelance: 'freelance',
  IncomeSourceType.businessRevenue: 'businessRevenue',
  IncomeSourceType.gift: 'gift',
  IncomeSourceType.allowance: 'allowance',
  IncomeSourceType.refund: 'refund',
  IncomeSourceType.sale: 'sale',
  IncomeSourceType.rentalIncome: 'rentalIncome',
  IncomeSourceType.governmentSupport: 'governmentSupport',
  IncomeSourceType.scholarship: 'scholarship',
  IncomeSourceType.investmentReturn: 'investmentReturn',
  IncomeSourceType.reimbursement: 'reimbursement',
  IncomeSourceType.debtRepayment: 'debtRepayment',
  IncomeSourceType.prize: 'prize',
  IncomeSourceType.loanProceeds: 'loanProceeds',
  IncomeSourceType.externalTransfer: 'externalTransfer',
  IncomeSourceType.other: 'other',
};
