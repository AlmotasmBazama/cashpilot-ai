import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/services/transaction_content_comparator.dart';

enum AiTransactionDeleteMode {
  deletePending,
  reverseAndDeletePosted,
  deletePendingTransferPair,
  cancelPostedTransferPair,
}

enum AiUndoOperationType {
  undoCreateTransaction,
  undoCreateTransfer,
  undoUpdateTransaction,
  undoDeleteTransaction,
}

/// A locally resolved transaction plus display-safe labels used by previews.
///
/// The transaction identifier is persisted only inside the owner-scoped local
/// command store. It is never accepted from, or sent to, an AI provider.
class AiTransactionTargetSnapshot {
  const AiTransactionTargetSnapshot({
    required this.transaction,
    required this.accountName,
    required this.categoryName,
    this.payeeName,
  });

  final Transaction transaction;
  final String accountName;
  final String categoryName;
  final String? payeeName;

  Map<String, Object?> toJson() => <String, Object?>{
    'transaction': _transactionToFlatJson(transaction),
    'accountName': accountName,
    'categoryName': categoryName,
    if (payeeName != null) 'payeeName': payeeName,
  };

  static AiTransactionTargetSnapshot? fromJson(Object? value) {
    if (value is! Map || value['transaction'] is! Map) return null;
    try {
      final rawTransaction = Map<String, dynamic>.from(
        value['transaction'] as Map,
      );
      return AiTransactionTargetSnapshot(
        transaction: Transaction.fromJson(
          _transactionJsonFromFlat(rawTransaction),
        ),
        accountName: value['accountName']?.toString() ?? '',
        categoryName: value['categoryName']?.toString() ?? '',
        payeeName: value['payeeName']?.toString(),
      );
    } on Object {
      return null;
    }
  }
}

Map<String, Object?> _transactionToFlatJson(
  Transaction value,
) => <String, Object?>{
  'id': value.id,
  'accountId': value.accountId,
  'categoryId': value.categoryId,
  if (value.payeeId != null) 'payeeId': value.payeeId,
  'amount': value.amount.amount.toString(),
  'currencyCode': value.amount.currencyCode,
  'type': value.type.name,
  'paymentMethod': value.paymentMethod.name,
  'source': value.source.name,
  'status': value.status.name,
  if (value.incomeSourceType != null)
    'incomeSourceType': value.incomeSourceType!.name,
  if (value.transferGroupId != null) 'transferGroupId': value.transferGroupId,
  if (value.exchangeRate != null) ...<String, Object?>{
    'exchangeRateFromCurrencyCode': value.exchangeRate!.fromCurrencyCode,
    'exchangeRateToCurrencyCode': value.exchangeRate!.toCurrencyCode,
    'exchangeRate': value.exchangeRate!.rate.toString(),
    if (value.exchangeRate!.asOf != null)
      'exchangeRateAsOf': value.exchangeRate!.asOf!.toUtc().toIso8601String(),
  },
  if (value.note != null) 'note': value.note,
  'transactionDate': value.transactionDate.toUtc().toIso8601String(),
  if (value.location != null) 'location': value.location,
  'attachmentCount': value.attachmentCount,
  if (value.aiConfidence != null) 'aiConfidence': value.aiConfidence,
  'needsReview': value.needsReview,
  'createdAt': value.createdAt.toUtc().toIso8601String(),
  'updatedAt': value.updatedAt.toUtc().toIso8601String(),
};

Map<String, dynamic> _transactionJsonFromFlat(Map<String, dynamic> value) {
  if (value['amount'] is Map) return value;
  final exchangeRate = value['exchangeRate'];
  return <String, dynamic>{
    ...value,
    'payeeId': value['payeeId'],
    'amount': <String, dynamic>{
      'amount': value['amount'],
      'currencyCode': value['currencyCode'],
    },
    'incomeSourceType': value['incomeSourceType'],
    'transferGroupId': value['transferGroupId'],
    'exchangeRate': exchangeRate == null
        ? null
        : <String, dynamic>{
            'fromCurrencyCode': value['exchangeRateFromCurrencyCode'],
            'toCurrencyCode': value['exchangeRateToCurrencyCode'],
            'rate': exchangeRate,
            'asOf': value['exchangeRateAsOf'],
          },
    'note': value['note'],
    'location': value['location'],
    'aiConfidence': value['aiConfidence'],
  };
}

/// Typed, durable update proposal. Owner binding, authoritative command
/// revision, and confirmation proof live in the enclosing [AppAgentCommand].
class UpdateTransactionCommand {
  UpdateTransactionCommand({
    required this.commandId,
    required this.original,
    required this.updated,
    required this.operationRevision,
    required this.previewFingerprint,
    String? idempotencyKey,
    required this.createdAt,
    required this.expiresAt,
  }) : idempotencyKey = idempotencyKey ?? _idempotencyKey(commandId, 'update');

  final String commandId;
  final AiTransactionTargetSnapshot original;
  final AiTransactionTargetSnapshot updated;
  final int operationRevision;
  final String previewFingerprint;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, Object?> toArguments() => <String, Object?>{
    'commandId': commandId,
    'original': original.toJson(),
    'updated': updated.toJson(),
    'operationRevision': operationRevision,
    'previewFingerprint': previewFingerprint,
    'idempotencyKey': idempotencyKey,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  static UpdateTransactionCommand? fromArguments(Map<String, Object?> value) {
    final original = AiTransactionTargetSnapshot.fromJson(value['original']);
    final updated = AiTransactionTargetSnapshot.fromJson(value['updated']);
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(value['expiresAt']?.toString() ?? '');
    if (original == null ||
        updated == null ||
        createdAt == null ||
        expiresAt == null ||
        value['commandId'] is! String ||
        value['previewFingerprint'] is! String ||
        value['idempotencyKey'] is! String) {
      return null;
    }
    return UpdateTransactionCommand(
      commandId: value['commandId']! as String,
      original: original,
      updated: updated,
      operationRevision: value['operationRevision'] is int
          ? value['operationRevision']! as int
          : 0,
      previewFingerprint: value['previewFingerprint']! as String,
      idempotencyKey: value['idempotencyKey']! as String,
      createdAt: createdAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
    );
  }
}

class DeleteTransactionCommand {
  DeleteTransactionCommand({
    required this.commandId,
    required List<AiTransactionTargetSnapshot> targets,
    required this.mode,
    required this.operationRevision,
    required this.previewFingerprint,
    String? idempotencyKey,
    required this.createdAt,
    required this.expiresAt,
  }) : targets = List<AiTransactionTargetSnapshot>.unmodifiable(targets),
       idempotencyKey = idempotencyKey ?? _idempotencyKey(commandId, 'delete');

  final String commandId;
  final List<AiTransactionTargetSnapshot> targets;
  final AiTransactionDeleteMode mode;
  final int operationRevision;
  final String previewFingerprint;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, Object?> toArguments() => <String, Object?>{
    'commandId': commandId,
    'targets': targets.map((item) => item.toJson()).toList(growable: false),
    'deleteMode': mode.name,
    'operationRevision': operationRevision,
    'previewFingerprint': previewFingerprint,
    'idempotencyKey': idempotencyKey,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  static DeleteTransactionCommand? fromArguments(Map<String, Object?> value) {
    final targets = (value['targets'] as List? ?? const <Object?>[])
        .map(AiTransactionTargetSnapshot.fromJson)
        .whereType<AiTransactionTargetSnapshot>()
        .toList(growable: false);
    final mode = AiTransactionDeleteMode.values
        .where((item) => item.name == value['deleteMode'])
        .firstOrNull;
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(value['expiresAt']?.toString() ?? '');
    if (targets.isEmpty ||
        mode == null ||
        createdAt == null ||
        expiresAt == null ||
        value['commandId'] is! String ||
        value['previewFingerprint'] is! String ||
        value['idempotencyKey'] is! String) {
      return null;
    }
    return DeleteTransactionCommand(
      commandId: value['commandId']! as String,
      targets: targets,
      mode: mode,
      operationRevision: value['operationRevision'] is int
          ? value['operationRevision']! as int
          : 0,
      previewFingerprint: value['previewFingerprint']! as String,
      idempotencyKey: value['idempotencyKey']! as String,
      createdAt: createdAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
    );
  }
}

class UndoAiActionCommand {
  UndoAiActionCommand({
    required this.commandId,
    required this.sourceCommandId,
    required this.sourceToolId,
    required this.operationType,
    required List<AiTransactionTargetSnapshot> before,
    required List<AiTransactionTargetSnapshot> after,
    required this.sourceOperationRevision,
    required this.operationRevision,
    required this.previewFingerprint,
    String? idempotencyKey,
    required this.createdAt,
    required this.expiresAt,
  }) : before = List<AiTransactionTargetSnapshot>.unmodifiable(before),
       after = List<AiTransactionTargetSnapshot>.unmodifiable(after),
       idempotencyKey = idempotencyKey ?? _idempotencyKey(commandId, 'undo');

  final String commandId;
  final String sourceCommandId;
  final String sourceToolId;
  final AiUndoOperationType operationType;
  final List<AiTransactionTargetSnapshot> before;
  final List<AiTransactionTargetSnapshot> after;
  final int sourceOperationRevision;
  final int operationRevision;
  final String previewFingerprint;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, Object?> toArguments() => <String, Object?>{
    'commandId': commandId,
    'sourceCommandId': sourceCommandId,
    'sourceToolId': sourceToolId,
    'undoOperationType': operationType.name,
    'before': before.map((item) => item.toJson()).toList(growable: false),
    'after': after.map((item) => item.toJson()).toList(growable: false),
    'sourceOperationRevision': sourceOperationRevision,
    'operationRevision': operationRevision,
    'previewFingerprint': previewFingerprint,
    'idempotencyKey': idempotencyKey,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  static UndoAiActionCommand? fromArguments(Map<String, Object?> value) {
    final before = (value['before'] as List? ?? const <Object?>[])
        .map(AiTransactionTargetSnapshot.fromJson)
        .whereType<AiTransactionTargetSnapshot>()
        .toList(growable: false);
    final after = (value['after'] as List? ?? const <Object?>[])
        .map(AiTransactionTargetSnapshot.fromJson)
        .whereType<AiTransactionTargetSnapshot>()
        .toList(growable: false);
    final operationType = AiUndoOperationType.values
        .where((item) => item.name == value['undoOperationType'])
        .firstOrNull;
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(value['expiresAt']?.toString() ?? '');
    if (operationType == null ||
        createdAt == null ||
        expiresAt == null ||
        value['commandId'] is! String ||
        value['sourceCommandId'] is! String ||
        value['sourceToolId'] is! String ||
        value['previewFingerprint'] is! String ||
        value['idempotencyKey'] is! String) {
      return null;
    }
    return UndoAiActionCommand(
      commandId: value['commandId']! as String,
      sourceCommandId: value['sourceCommandId']! as String,
      sourceToolId: value['sourceToolId']! as String,
      operationType: operationType,
      before: before,
      after: after,
      sourceOperationRevision: value['sourceOperationRevision'] is int
          ? value['sourceOperationRevision']! as int
          : 0,
      operationRevision: value['operationRevision'] is int
          ? value['operationRevision']! as int
          : 0,
      previewFingerprint: value['previewFingerprint']! as String,
      idempotencyKey: value['idempotencyKey']! as String,
      createdAt: createdAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
    );
  }
}

String aiTransactionSnapshotFingerprint(
  Iterable<AiTransactionTargetSnapshot> snapshots,
) {
  return sha256
      .convert(
        utf8.encode(
          jsonEncode(
            snapshots
                .map(
                  (item) => <String, Object?>{
                    'transaction': canonicalTransactionJson(item.transaction),
                    'accountName': item.accountName,
                    'categoryName': item.categoryName,
                    if (item.payeeName != null) 'payeeName': item.payeeName,
                  },
                )
                .toList(growable: false),
          ),
        ),
      )
      .toString();
}

String _idempotencyKey(String commandId, String operation) {
  return sha256
      .convert(
        utf8.encode(
          'cashpilot.ai-transaction-mutation.v1\u0000$operation\u0000$commandId',
        ),
      )
      .toString();
}
