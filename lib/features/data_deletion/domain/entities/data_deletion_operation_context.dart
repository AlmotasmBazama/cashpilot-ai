import '../../../../core/owner_scope/domain/owner_scope.dart';

enum DataDeletionStage {
  captured,
  reauthenticated,
  backupFenced,
  writersVerified,
  cloudDeleted,
  localDatabaseDeleted,
  receiptFilesDeleted,
  preferencesDeleted,
  authDeleted,
  aborted,
}

enum DataDeletionIdempotencyState { newOperation, resumed }

/// UID-free coordinates for completing an Auth-last deletion after Firebase
/// no longer has a current user. Values may be discovered from untrusted local
/// storage, so construction validates both opaque components before any use.
final class AccountDeletionRecoveryTarget {
  AccountDeletionRecoveryTarget({
    required String operationId,
    required String ownerScopeValue,
  }) : operationId = _validatedOperationId(operationId),
       ownerScopeValue = _validatedOwnerScope(ownerScopeValue);

  final String operationId;
  final String ownerScopeValue;

  static String _validatedOperationId(String value) {
    if (!RegExp(r'^[A-Za-z0-9-]{8,80}$').hasMatch(value)) {
      throw ArgumentError.value(
        '<redacted>',
        'operationId',
        'A canonical account-deletion operation id is required.',
      );
    }
    return value;
  }

  static String _validatedOwnerScope(String value) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw ArgumentError.value(
        '<redacted>',
        'ownerScopeValue',
        'A canonical opaque owner scope is required.',
      );
    }
    return value;
  }
}

/// Identity captured from Firebase Auth at the beginning of one deletion.
/// Caller-provided widget or route values never construct this object.
final class TrustedDeletionIdentity {
  const TrustedDeletionIdentity({
    required this.authSessionId,
    required this.authStateGeneration,
    required this.userId,
    required this.isAnonymous,
    required this.ownerScope,
  });

  final String authSessionId;
  final int authStateGeneration;
  final String userId;
  final bool isAnonymous;
  final ConfirmedOwnerScope ownerScope;
}

/// Immutable snapshot carried through every destructive deletion stage.
final class DataDeletionOperationContext {
  const DataDeletionOperationContext({
    required this.operationId,
    required this.identity,
    required this.stage,
    required this.startedAtUtc,
    required this.idempotencyState,
    this.backupFenceEpoch,
    this.failureCode,
    this.abandonedFromStage,
  });

  factory DataDeletionOperationContext.captured({
    required String operationId,
    required TrustedDeletionIdentity identity,
    required DateTime startedAtUtc,
    DataDeletionIdempotencyState idempotencyState =
        DataDeletionIdempotencyState.newOperation,
  }) {
    return DataDeletionOperationContext(
      operationId: operationId,
      identity: identity,
      stage: DataDeletionStage.captured,
      startedAtUtc: startedAtUtc.toUtc(),
      idempotencyState: idempotencyState,
    );
  }

  final String operationId;
  final TrustedDeletionIdentity identity;
  final DataDeletionStage stage;
  final DateTime startedAtUtc;
  final DataDeletionIdempotencyState idempotencyState;
  final int? backupFenceEpoch;
  final String? failureCode;
  final DataDeletionStage? abandonedFromStage;

  AccountDeletionRecoveryTarget get recoveryTarget =>
      AccountDeletionRecoveryTarget(
        operationId: operationId,
        ownerScopeValue: identity.ownerScope.id.value,
      );

  DataDeletionOperationContext advance(
    DataDeletionStage nextStage, {
    int? backupFenceEpoch,
  }) {
    if (stage == DataDeletionStage.aborted ||
        stage == DataDeletionStage.authDeleted ||
        nextStage == DataDeletionStage.aborted ||
        nextStage.index != stage.index + 1) {
      throw StateError('Data deletion stages must advance monotonically.');
    }
    return DataDeletionOperationContext(
      operationId: operationId,
      identity: identity,
      stage: nextStage,
      startedAtUtc: startedAtUtc,
      idempotencyState: idempotencyState,
      backupFenceEpoch: backupFenceEpoch ?? this.backupFenceEpoch,
      abandonedFromStage: abandonedFromStage,
    );
  }

  DataDeletionOperationContext abort(String code) {
    if (stage == DataDeletionStage.authDeleted ||
        stage == DataDeletionStage.aborted) {
      throw StateError('A terminal deletion context cannot be aborted.');
    }
    return DataDeletionOperationContext(
      operationId: operationId,
      identity: identity,
      stage: DataDeletionStage.aborted,
      startedAtUtc: startedAtUtc,
      idempotencyState: idempotencyState,
      backupFenceEpoch: backupFenceEpoch,
      failureCode: code,
      abandonedFromStage: stage,
    );
  }
}
