import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../enums/transaction_source.dart';
import '../enums/transaction_status.dart';

const defaultTransferCategoryId = '01900000-0000-7000-8000-000000000029';

class CreateTransferCommand {
  factory CreateTransferCommand({
    required String sourceAccountId,
    required String targetAccountId,
    required Money sourceAmount,
    Money? targetAmount,
    ExchangeRate? exchangeRate,
    String categoryId = defaultTransferCategoryId,
    TransactionStatus status = TransactionStatus.posted,
    TransactionSource source = TransactionSource.manual,
    String? note,
    DateTime? occurredAt,
    String? transferGroupId,
    String? outgoingTransactionId,
    String? incomingTransactionId,
  }) {
    final suppliedGroup = transferGroupId;
    if (suppliedGroup != null && !_isCanonicalIdentifier(suppliedGroup)) {
      throw ArgumentError.value(
        '<redacted>',
        'transferGroupId',
        'A non-empty canonical transfer group is required.',
      );
    }
    final hasOutgoing = outgoingTransactionId != null;
    final hasIncoming = incomingTransactionId != null;
    if (hasOutgoing != hasIncoming) {
      throw ArgumentError(
        'Transfer leg identifiers must be supplied together or omitted.',
      );
    }
    if (outgoingTransactionId != null &&
        (!_isCanonicalIdentifier(outgoingTransactionId) ||
            !_isCanonicalIdentifier(incomingTransactionId!) ||
            outgoingTransactionId == incomingTransactionId)) {
      throw ArgumentError(
        'Transfer leg identifiers must be distinct and canonical.',
      );
    }

    final resolvedGroup = suppliedGroup ?? const Uuid().v7();
    return CreateTransferCommand._(
      sourceAccountId: sourceAccountId,
      targetAccountId: targetAccountId,
      sourceAmount: sourceAmount,
      targetAmount: targetAmount,
      exchangeRate: exchangeRate,
      categoryId: categoryId,
      status: status,
      source: source,
      note: note,
      occurredAt: occurredAt,
      transferGroupId: resolvedGroup,
      outgoingTransactionId:
          outgoingTransactionId ?? _stableLegId(resolvedGroup, 'out'),
      incomingTransactionId:
          incomingTransactionId ?? _stableLegId(resolvedGroup, 'in'),
    );
  }

  const CreateTransferCommand._({
    required this.sourceAccountId,
    required this.targetAccountId,
    required this.sourceAmount,
    required this.targetAmount,
    required this.exchangeRate,
    required this.categoryId,
    required this.status,
    required this.source,
    required this.note,
    required this.occurredAt,
    required this.transferGroupId,
    required this.outgoingTransactionId,
    required this.incomingTransactionId,
  });

  final String sourceAccountId;
  final String targetAccountId;
  final Money sourceAmount;
  final Money? targetAmount;
  final ExchangeRate? exchangeRate;
  final String categoryId;
  final TransactionStatus status;
  final TransactionSource source;
  final String? note;
  final DateTime? occurredAt;
  final String transferGroupId;
  final String outgoingTransactionId;
  final String incomingTransactionId;

  static bool _isCanonicalIdentifier(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$').hasMatch(value);

  static String _stableLegId(String groupId, String role) {
    final hex = sha256
        .convert(
          utf8.encode('cashpilot.transfer-leg.v1\u0000$groupId\u0000$role'),
        )
        .toString();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '5${hex.substring(13, 16)}-a${hex.substring(17, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
