import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../../core/sync/application/backup_operation_fence.dart';
import '../../domain/app_agent/app_agent_contracts.dart';
import '../../domain/app_agent/app_agent_models.dart';
import '../../domain/app_agent/app_agent_policy.dart';
import '../../domain/app_agent/app_agent_reconciliation.dart';

class DriftAppAgentCommandStore implements AppAgentCommandStore {
  DriftAppAgentCommandStore({
    required ScopedAppDatabaseSession session,
    AppAgentPolicy policy = const AppAgentPolicy(),
    Iterable<AppAgentModelProposalDescriptor> canonicalDescriptors =
        const <AppAgentModelProposalDescriptor>[],
  }) : _session = session,
       _policy = policy,
       _canonicalDescriptors = <String, AppAgentModelProposalDescriptor>{
         for (final descriptor in canonicalDescriptors)
           descriptor.toolId: descriptor,
       };

  final ScopedAppDatabaseSession _session;
  final AppAgentPolicy _policy;
  final Map<String, AppAgentModelProposalDescriptor> _canonicalDescriptors;

  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  Future<void> saveCommand(AppAgentCommand command) async {
    _policy.validateModelProposal(
      command,
      descriptor: _canonicalDescriptors[command.toolId],
    );
    await _session.runGuardedWrite(() => _insert(command));
  }

  Future<void> saveTrustedLocalCommand(AppAgentCommand command) async {
    _policy.validateTrustedLocalCommand(
      command,
      descriptor: _canonicalDescriptors[command.toolId],
    );
    await _session.runGuardedWrite(() => _insert(command));
  }

  Future<void> _insert(AppAgentCommand command) async {
    _requireScope(command.userAccountScope);
    if (command.status != AppAgentCommandStatus.proposed &&
        command.status != AppAgentCommandStatus.resolving &&
        command.status != AppAgentCommandStatus.needsClarification &&
        command.status != AppAgentCommandStatus.readyForPreview) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidStatus,
        'Only a pre-confirmation command may be inserted.',
      );
    }
    final now = DateTime.now().toUtc();
    try {
      await _session.runGuardedWrite(() async {
        await _database
            .into(_database.aiAgentCommands)
            .insert(
              AiAgentCommandsCompanion.insert(
                id: command.commandId,
                ownerScopeId: _scope,
                conversationId: command.conversationId,
                commandType: command.commandType.name,
                toolId: command.toolId,
                normalizedArgumentsJson: jsonEncode(
                  command.normalizedArguments,
                ),
                permission: command.permission.name,
                risk: command.risk.name,
                status: command.status.name,
                revision: const Value(0),
                previewFingerprint: Value(command.previewFingerprint),
                safeFailureCode: Value(command.safeFailureCode),
                expiresAt: command.expiresAt.toUtc(),
                createdAt: command.createdAt.toUtc(),
                updatedAt: now,
              ),
            );
      });
    } on OwnerScopeException {
      rethrow;
    } on BackupWriterCancelledException {
      rethrow;
    } on Object {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.duplicateExecutionPrevented,
        'The command identifier has already been used.',
      );
    }
  }

  @override
  Future<AppAgentCommand?> readCommand({
    required String commandId,
    required String accountScope,
  }) async {
    if (accountScope != _scope) return null;
    final row =
        await (_database.select(_database.aiAgentCommands)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) & row.id.equals(commandId),
            ))
            .getSingleOrNull();
    return row == null ? null : _commandFromRow(row);
  }

  @override
  Future<List<AppAgentCommand>> readCommandsForScope(
    String accountScope,
  ) async {
    if (accountScope != _scope) return const <AppAgentCommand>[];
    final rows =
        await (_database.select(_database.aiAgentCommands)
              ..where((row) => row.ownerScopeId.equals(_scope))
              ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
            .get();
    return rows.map(_commandFromRow).whereType<AppAgentCommand>().toList();
  }

  @override
  Future<void> savePreview({
    required AppAgentPreview preview,
    required String accountScope,
  }) async {
    _requireScope(accountScope);
    await _session.runGuardedWrite(
      () => _database.transaction(() async {
        final commandRow =
            await (_database.select(_database.aiAgentCommands)..where(
                  (row) =>
                      row.ownerScopeId.equals(_scope) &
                      row.id.equals(preview.commandId),
                ))
                .getSingleOrNull();
        if (commandRow == null) {
          throw const AppAgentPolicyViolation(
            AppAgentFailureCodes.actionUnavailable,
            'The command does not exist in the active scope.',
          );
        }
        final command = _commandFromRow(commandRow);
        if (command == null) {
          throw const AppAgentPolicyViolation(
            AppAgentFailureCodes.invalidStatus,
            'The persisted command is invalid.',
          );
        }
        if (command.status != AppAgentCommandStatus.readyForPreview) {
          throw const AppAgentPolicyViolation(
            AppAgentFailureCodes.invalidStatus,
            'Only a command ready for preview may receive a new preview.',
          );
        }
        _policy.validatePreview(command, preview);
        final nextRevision = commandRow.revision + 1;
        final now = DateTime.now().toUtc();
        await _database
            .into(_database.aiAgentPreviews)
            .insert(
              AiAgentPreviewsCompanion.insert(
                id: '${preview.commandId}:$nextRevision',
                ownerScopeId: _scope,
                commandId: preview.commandId,
                revision: nextRevision,
                status: 'current',
                stateFingerprint: preview.stateFingerprint,
                payloadJson: jsonEncode(preview.toStorageJson()),
                expiresAt: command.expiresAt.toUtc(),
                createdAt: preview.createdAt.toUtc(),
                updatedAt: now,
              ),
            );
        await (_database.update(_database.aiAgentPreviews)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) &
                  row.commandId.equals(preview.commandId) &
                  row.revision.isSmallerThanValue(nextRevision),
            ))
            .write(
              AiAgentPreviewsCompanion(
                status: const Value('superseded'),
                updatedAt: Value(now),
              ),
            );
        final nextStatus =
            preview.confirmationLevel == AppAgentConfirmationLevel.none
            ? AppAgentCommandStatus.succeeded
            : AppAgentCommandStatus.awaitingConfirmation;
        final updated =
            await (_database.update(_database.aiAgentCommands)..where(
                  (row) =>
                      row.ownerScopeId.equals(_scope) &
                      row.id.equals(preview.commandId) &
                      row.revision.equals(commandRow.revision) &
                      row.status.equals(commandRow.status),
                ))
                .write(
                  AiAgentCommandsCompanion(
                    previewFingerprint: Value(preview.stateFingerprint),
                    status: Value(nextStatus.name),
                    revision: Value(nextRevision),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const AppAgentPolicyViolation(
            AppAgentFailureCodes.invalidStatus,
            'The command changed while its preview was saved.',
          );
        }
      }),
    );
  }

  @override
  Future<AppAgentPreview?> readPreview({
    required String commandId,
    required String accountScope,
  }) async {
    if (accountScope != _scope) return null;
    final row =
        await (_database.select(_database.aiAgentPreviews)
              ..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.commandId.equals(commandId) &
                    row.status.equals('current'),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.revision)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return AppAgentPreview.fromStorageJson(jsonDecode(row.payloadJson));
  }

  @override
  Future<AppAgentCommand?> transition({
    required String commandId,
    required String accountScope,
    required AppAgentCommandStatus expectedStatus,
    required AppAgentCommandStatus nextStatus,
    String? safeFailureCode,
  }) async {
    if (accountScope != _scope) return null;
    _policy.validateTransition(expectedStatus, nextStatus);
    return _session.runGuardedWrite(() async {
      final now = DateTime.now().toUtc();
      final changed =
          await (_database.update(_database.aiAgentCommands)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.id.equals(commandId) &
                    row.status.equals(expectedStatus.name),
              ))
              .write(
                AiAgentCommandsCompanion(
                  status: Value(nextStatus.name),
                  safeFailureCode: Value(safeFailureCode),
                  updatedAt: Value(now),
                ),
              );
      if (changed != 1) return null;
      return readCommand(commandId: commandId, accountScope: _scope);
    });
  }

  @override
  Future<void> clearScope(String accountScope) async {
    if (accountScope != _scope) return;
    await _session.runGuardedWrite(
      () => _database.transaction(() async {
        for (final table in const <String>[
          'ai_agent_plan_steps',
          'ai_agent_plans',
          'ai_agent_confirmation_proofs',
          'ai_agent_execution_results',
          'ai_agent_execution_attempts',
          'ai_agent_business_operations',
          'ai_agent_idempotency_records',
          'ai_agent_previews',
          'ai_agent_audit_events',
          'ai_agent_commands',
        ]) {
          await _database.customUpdate(
            'DELETE FROM $table WHERE owner_scope_id = ?',
            variables: <Variable<Object>>[Variable<String>(_scope)],
          );
        }
      }),
    );
  }

  AppAgentCommand? _commandFromRow(AiAgentCommandRow row) {
    try {
      return AppAgentCommand.fromStorageJson(<String, Object?>{
        'commandId': row.id,
        'conversationId': row.conversationId,
        'userAccountScope': row.ownerScopeId,
        'commandType': row.commandType,
        'toolId': row.toolId,
        'normalizedArguments': jsonDecode(row.normalizedArgumentsJson),
        'permission': row.permission,
        'risk': row.risk,
        'createdAt': row.createdAt.toUtc().toIso8601String(),
        'expiresAt': row.expiresAt.toUtc().toIso8601String(),
        'status': row.status,
        'revision': row.revision,
        if (row.previewFingerprint != null)
          'previewFingerprint': row.previewFingerprint,
        if (row.safeFailureCode != null) 'safeFailureCode': row.safeFailureCode,
      });
    } on Object {
      return null;
    }
  }

  void _requireScope(String candidate) {
    if (candidate != _scope) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.accountScopeMismatch,
        'The command does not belong to the active account scope.',
      );
    }
  }
}

class DriftAppAgentConfirmationProofStore
    implements AppAgentConfirmationProofStore {
  const DriftAppAgentConfirmationProofStore(this._session);

  static const _proofDomain = 'cashpilot.confirmation-proof.v1';
  final ScopedAppDatabaseSession _session;

  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  Future<void> saveProof({
    required String commandId,
    required String accountScope,
    required String proof,
    required AppAgentConfirmationMethod method,
    required DateTime expiresAt,
  }) async {
    if (accountScope != _scope || proof.isEmpty) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.accountScopeMismatch,
        'The proof does not belong to the active scope.',
      );
    }
    await _session.runGuardedWrite(() async {
      final command =
          await (_database.select(_database.aiAgentCommands)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) & row.id.equals(commandId),
              ))
              .getSingleOrNull();
      if (command == null ||
          command.status != AppAgentCommandStatus.confirmed.name ||
          command.previewFingerprint == null) {
        throw const AppAgentPolicyViolation(
          AppAgentFailureCodes.invalidConfirmation,
          'The command is not awaiting confirmation.',
        );
      }
      final saltBytes = List<int>.generate(
        32,
        (_) => Random.secure().nextInt(256),
      );
      final salt = base64UrlEncode(saltBytes);
      final now = DateTime.now().toUtc();
      await _database
          .into(_database.aiAgentConfirmationProofs)
          .insert(
            AiAgentConfirmationProofsCompanion.insert(
              id: const Uuid().v7(),
              ownerScopeId: _scope,
              commandId: commandId,
              previewRevision: command.revision,
              confirmationMethod: method.name,
              proofHash: _hashForScope(
                accountScope: _scope,
                proof: proof,
                salt: salt,
                commandId: commandId,
                revision: command.revision,
                method: method,
              ),
              proofSalt: salt,
              status: 'active',
              expiresAt: expiresAt.toUtc(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  @override
  Future<bool> consumeProof({
    required String commandId,
    required String accountScope,
    required String proof,
    required AppAgentConfirmationMethod method,
    required DateTime now,
  }) async {
    if (accountScope != _scope || proof.isEmpty) return false;
    return _session.runGuardedWrite(
      () => _database.transaction(() async {
        final command =
            await (_database.select(_database.aiAgentCommands)..where(
                  (row) =>
                      row.ownerScopeId.equals(_scope) &
                      row.id.equals(commandId),
                ))
                .getSingleOrNull();
        if (command == null || command.previewFingerprint == null) return false;
        final row =
            await (_database.select(_database.aiAgentConfirmationProofs)
                  ..where(
                    (row) =>
                        row.ownerScopeId.equals(_scope) &
                        row.commandId.equals(commandId) &
                        row.previewRevision.equals(command.revision) &
                        row.confirmationMethod.equals(method.name) &
                        row.status.equals('active'),
                  )
                  ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
                  ..limit(1))
                .getSingleOrNull();
        if (row == null || !now.toUtc().isBefore(row.expiresAt.toUtc())) {
          return false;
        }
        final candidate = _hashForScope(
          accountScope: _scope,
          proof: proof,
          salt: row.proofSalt,
          commandId: commandId,
          revision: row.previewRevision,
          method: method,
        );
        if (!_constantTimeEquals(candidate, row.proofHash)) return false;
        final changed =
            await (_database.update(_database.aiAgentConfirmationProofs)..where(
                  (proofRow) =>
                      proofRow.ownerScopeId.equals(_scope) &
                      proofRow.id.equals(row.id) &
                      proofRow.status.equals('active'),
                ))
                .write(
                  AiAgentConfirmationProofsCompanion(
                    status: const Value('consumed'),
                    consumedAt: Value(now.toUtc()),
                    updatedAt: Value(now.toUtc()),
                  ),
                );
        return changed == 1;
      }),
    );
  }

  @override
  Future<void> clearScope(String accountScope) async {
    if (accountScope != _scope) return;
    await _session.runGuardedWrite(
      () => (_database.delete(
        _database.aiAgentConfirmationProofs,
      )..where((row) => row.ownerScopeId.equals(_scope))).go(),
    );
  }

  static String _hashForScope({
    required String accountScope,
    required String proof,
    required String salt,
    required String commandId,
    required int revision,
    required AppAgentConfirmationMethod method,
  }) {
    return sha256
        .convert(
          utf8.encode(
            '$_proofDomain\u0000$accountScope\u0000$commandId\u0000$revision\u0000'
            '${method.name}\u0000$salt\u0000$proof',
          ),
        )
        .toString();
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var index = 0; index < a.length; index++) {
      difference |= a.codeUnitAt(index) ^ b.codeUnitAt(index);
    }
    return difference == 0;
  }
}

class DriftAppAgentAuditStore implements AppAgentAuditStore {
  const DriftAppAgentAuditStore(this._session);

  final ScopedAppDatabaseSession _session;
  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  Future<void> append(AppAgentAuditEvent event) async {
    if (event.userAccountScope != _scope) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.accountScopeMismatch,
        'The audit event does not belong to the active account scope.',
      );
    }
    await _session.runGuardedWrite(() async {
      final now = event.timestamp.toUtc();
      await _database
          .into(_database.aiAgentAuditEvents)
          .insert(
            AiAgentAuditEventsCompanion.insert(
              id: const Uuid().v7(),
              ownerScopeId: _scope,
              commandId: event.commandId,
              actionType: event.actionType,
              entityType: event.entityType,
              result: event.result.name,
              confirmationMethod: event.confirmationMethod.name,
              safeFailureCode: Value(event.safeFailureCode),
              undoAvailable: Value(event.undoAvailable),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  @override
  Future<List<AppAgentAuditEvent>> readRecent({
    required String accountScope,
    int limit = 100,
  }) async {
    if (accountScope != _scope) return const <AppAgentAuditEvent>[];
    final boundedLimit = limit.clamp(1, 200);
    final rows =
        await (_database.select(_database.aiAgentAuditEvents)
              ..where((row) => row.ownerScopeId.equals(_scope))
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(boundedLimit))
            .get();
    return rows
        .map(
          (row) => AppAgentAuditEvent.fromJson(<String, Object?>{
            'commandId': row.commandId,
            'userAccountScope': row.ownerScopeId,
            'actionType': row.actionType,
            'entityType': row.entityType,
            'result': row.result,
            'timestamp': row.createdAt.toUtc().toIso8601String(),
            'confirmationMethod': row.confirmationMethod,
            if (row.safeFailureCode != null)
              'safeFailureCode': row.safeFailureCode,
            'undoAvailable': row.undoAvailable,
          }),
        )
        .whereType<AppAgentAuditEvent>()
        .toList(growable: false);
  }

  @override
  Future<void> clearScope(String accountScope) async {
    if (accountScope != _scope) return;
    await _session.runGuardedWrite(
      () => (_database.delete(
        _database.aiAgentAuditEvents,
      )..where((row) => row.ownerScopeId.equals(_scope))).go(),
    );
  }
}

class DriftAppAgentDurableExecutionStore
    implements AppAgentDurableExecutionStore {
  const DriftAppAgentDurableExecutionStore(this._session);

  static const _idempotencyDomain = 'cashpilot.agent-idempotency.v1';
  final ScopedAppDatabaseSession _session;

  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  Future<AppAgentExecutionClaim> claim(
    AppAgentCommand command, {
    required AppAgentConfirmation confirmation,
    required DateTime now,
    AppAgentBusinessOperationSpec? operation,
  }) {
    if (command.userAccountScope != _scope) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.accountScopeMismatch,
        'The command does not belong to the active scope.',
      );
    }
    return _session.runGuardedWrite(
      () => _database.transaction(() async {
        final row =
            await (_database.select(_database.aiAgentCommands)..where(
                  (row) =>
                      row.ownerScopeId.equals(_scope) &
                      row.id.equals(command.commandId),
                ))
                .getSingleOrNull();
        if (row == null) {
          throw const AppAgentPolicyViolation(
            AppAgentFailureCodes.actionUnavailable,
            'The durable command was not found.',
          );
        }
        final idempotencyHash = _idempotencyHash(
          commandId: command.commandId,
          revision: row.revision,
          actionType: command.toolId,
        );
        final existing =
            await (_database.select(_database.aiAgentIdempotencyRecords)..where(
                  (record) =>
                      record.ownerScopeId.equals(_scope) &
                      record.idempotencyHash.equals(idempotencyHash),
                ))
                .getSingleOrNull();
        if (existing != null) {
          final previous = await readVerifiedResult(command.commandId);
          return AppAgentExecutionClaim(
            disposition: previous == null
                ? AppAgentExecutionClaimDisposition.duplicateInProgress
                : AppAgentExecutionClaimDisposition.completed,
            previousResult: previous,
          );
        }
        if (row.status != AppAgentCommandStatus.confirmed.name) {
          return const AppAgentExecutionClaim(
            disposition: AppAgentExecutionClaimDisposition.duplicateInProgress,
          );
        }

        await _consumeConfirmationForClaim(
          command: command,
          commandRow: row,
          confirmation: confirmation,
          now: now.toUtc(),
        );

        final claimedAt = now.toUtc();
        final attemptId = const Uuid().v7();
        final recordId = const Uuid().v7();
        if (operation != null) {
          if (operation.key.value.isEmpty ||
              operation.expectedPersistedIdentifiers.isEmpty) {
            throw const AppAgentPolicyViolation(
              AppAgentFailureCodes.invalidArguments,
              'The business operation correlation is incomplete.',
            );
          }
          await _database
              .into(_database.aiAgentBusinessOperations)
              .insert(
                AiAgentBusinessOperationsCompanion.insert(
                  id: operation.key.value,
                  ownerScopeId: _scope,
                  commandId: command.commandId,
                  commandRevision: row.revision,
                  actionType: command.toolId,
                  entityType: operation.expectedEntityType,
                  expectedEntityIdsJson: jsonEncode(
                    operation.expectedPersistedIdentifiers,
                  ),
                  verificationMethod: operation.verificationMethod,
                  status: 'executing',
                  automaticResumeAllowed: operation.safeAutomaticResume,
                  automaticRetryProhibited: operation.automaticRetryProhibited,
                  createdAt: claimedAt,
                  updatedAt: claimedAt,
                ),
              );
        }
        await _database
            .into(_database.aiAgentIdempotencyRecords)
            .insert(
              AiAgentIdempotencyRecordsCompanion.insert(
                id: recordId,
                ownerScopeId: _scope,
                commandId: command.commandId,
                commandRevision: row.revision,
                actionType: command.toolId,
                idempotencyHash: idempotencyHash,
                status: 'claimed',
                createdAt: claimedAt,
                updatedAt: claimedAt,
              ),
            );
        await _database
            .into(_database.aiAgentExecutionAttempts)
            .insert(
              AiAgentExecutionAttemptsCompanion.insert(
                id: attemptId,
                ownerScopeId: _scope,
                commandId: command.commandId,
                idempotencyKey: idempotencyHash,
                commandRevision: row.revision,
                actionType: command.toolId,
                status: 'executing',
                businessOperationId: Value(operation?.key.value),
                claimedAt: claimedAt,
                createdAt: claimedAt,
                updatedAt: claimedAt,
              ),
            );
        final changed =
            await (_database.update(_database.aiAgentCommands)..where(
                  (commandRow) =>
                      commandRow.ownerScopeId.equals(_scope) &
                      commandRow.id.equals(command.commandId) &
                      commandRow.revision.equals(row.revision) &
                      commandRow.status.equals(
                        AppAgentCommandStatus.confirmed.name,
                      ),
                ))
                .write(
                  AiAgentCommandsCompanion(
                    status: Value(AppAgentCommandStatus.executing.name),
                    updatedAt: Value(claimedAt),
                  ),
                );
        if (changed != 1) {
          throw const AppAgentPolicyViolation(
            AppAgentFailureCodes.duplicateExecutionPrevented,
            'Another executor already claimed the command.',
          );
        }
        return AppAgentExecutionClaim(
          disposition: AppAgentExecutionClaimDisposition.claimed,
          attemptId: attemptId,
        );
      }),
    );
  }

  Future<void> _consumeConfirmationForClaim({
    required AppAgentCommand command,
    required AiAgentCommandRow commandRow,
    required AppAgentConfirmation confirmation,
    required DateTime now,
  }) async {
    if (confirmation.commandId != command.commandId ||
        confirmation.userAccountScope != _scope ||
        confirmation.confirmedAt.toUtc().isAfter(now) ||
        !now.isBefore(commandRow.expiresAt.toUtc()) ||
        confirmation.authorityProof.isEmpty) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidConfirmation,
        'The confirmation does not authorize this execution claim.',
      );
    }
    final proofRow =
        await (_database.select(_database.aiAgentConfirmationProofs)
              ..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.commandId.equals(command.commandId) &
                    row.previewRevision.equals(commandRow.revision) &
                    row.confirmationMethod.equals(confirmation.method.name) &
                    row.status.equals('active'),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (proofRow == null || !now.isBefore(proofRow.expiresAt.toUtc())) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidConfirmation,
        'The confirmation proof is missing or expired.',
      );
    }
    final candidate = DriftAppAgentConfirmationProofStore._hashForScope(
      accountScope: _scope,
      proof: confirmation.authorityProof,
      salt: proofRow.proofSalt,
      commandId: command.commandId,
      revision: proofRow.previewRevision,
      method: confirmation.method,
    );
    if (!DriftAppAgentConfirmationProofStore._constantTimeEquals(
      candidate,
      proofRow.proofHash,
    )) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidConfirmation,
        'The confirmation proof is invalid.',
      );
    }
    final consumed =
        await (_database.update(_database.aiAgentConfirmationProofs)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) &
                  row.id.equals(proofRow.id) &
                  row.status.equals('active'),
            ))
            .write(
              AiAgentConfirmationProofsCompanion(
                status: const Value('consumed'),
                consumedAt: Value(now),
                updatedAt: Value(now),
              ),
            );
    if (consumed != 1) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidConfirmation,
        'The confirmation proof was already consumed.',
      );
    }
  }

  @override
  Future<void> complete({
    required AppAgentCommand command,
    required String attemptId,
    required AppAgentExecutionResult result,
    AppAgentReconciliationStatus? reconciliationStatus,
  }) async {
    if (command.userAccountScope != _scope) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.accountScopeMismatch,
        'The result does not belong to the active scope.',
      );
    }
    await _session.runGuardedWrite(
      () => _database.transaction(() async {
        final attempt =
            await (_database.select(_database.aiAgentExecutionAttempts)..where(
                  (row) =>
                      row.ownerScopeId.equals(_scope) &
                      row.id.equals(attemptId),
                ))
                .getSingleOrNull();
        if (attempt == null ||
            attempt.commandId != command.commandId ||
            attempt.status != 'executing') {
          throw const AppAgentPolicyViolation(
            AppAgentFailureCodes.duplicateExecutionPrevented,
            'The execution attempt is no longer claimable.',
          );
        }
        final confirmationProof =
            await (_database.select(_database.aiAgentConfirmationProofs)
                  ..where(
                    (row) =>
                        row.ownerScopeId.equals(_scope) &
                        row.commandId.equals(command.commandId) &
                        row.previewRevision.equals(attempt.commandRevision) &
                        row.status.equals('consumed'),
                  )
                  ..orderBy([(row) => OrderingTerm.desc(row.consumedAt)])
                  ..limit(1))
                .getSingleOrNull();
        if (confirmationProof == null) {
          throw const AppAgentPolicyViolation(
            AppAgentFailureCodes.invalidConfirmation,
            'The execution result has no consumed confirmation proof.',
          );
        }
        final now = result.completedAt.toUtc();
        final resultId = const Uuid().v7();
        await _database
            .into(_database.aiAgentExecutionResults)
            .insert(
              AiAgentExecutionResultsCompanion.insert(
                id: resultId,
                ownerScopeId: _scope,
                commandId: command.commandId,
                attemptId: attemptId,
                status: result.status.name,
                verified: result.verified,
                entityType: result.entityType,
                affectedCount: result.affectedCount,
                safeResultJson: jsonEncode(<String, Object?>{
                  'verified': result.verified,
                  'entityType': result.entityType,
                  'affectedCount': result.affectedCount,
                  'undoAvailable': result.undoAvailable,
                  'uiDeliveryAcknowledged': false,
                }),
                safeFailureCode: Value(result.safeFailureCode),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await (_database.update(_database.aiAgentExecutionAttempts)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) &
                  row.id.equals(attemptId) &
                  row.status.equals('executing'),
            ))
            .write(
              AiAgentExecutionAttemptsCompanion(
                status: Value(result.status.name),
                safeFailureCode: Value(result.safeFailureCode),
                completedAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        final idempotencyChanged =
            await (_database.update(_database.aiAgentIdempotencyRecords)..where(
                  (row) =>
                      row.ownerScopeId.equals(_scope) &
                      row.idempotencyHash.equals(attempt.idempotencyKey) &
                      row.status.equals('claimed'),
                ))
                .write(
                  AiAgentIdempotencyRecordsCompanion(
                    status: const Value('completed'),
                    executionResultId: Value(resultId),
                    updatedAt: Value(now),
                  ),
                );
        if (idempotencyChanged != 1) {
          throw const AppAgentPolicyViolation(
            AppAgentFailureCodes.invalidStatus,
            'The durable idempotency record could not be finalized.',
          );
        }
        if (attempt.businessOperationId != null) {
          await (_database.update(_database.aiAgentBusinessOperations)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.id.equals(attempt.businessOperationId!),
              ))
              .write(
                AiAgentBusinessOperationsCompanion(
                  status: Value(
                    reconciliationStatus?.name ??
                        (result.verified
                            ? 'verifiedSucceeded'
                            : result.status ==
                                  AppAgentCommandStatus.partiallySucceeded
                            ? 'requiresManualReview'
                            : 'verifiedNotExecuted'),
                  ),
                  safeFailureCode: Value(result.safeFailureCode),
                  completedAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        }
        final changed =
            await (_database.update(_database.aiAgentCommands)..where(
                  (row) =>
                      row.ownerScopeId.equals(_scope) &
                      row.id.equals(command.commandId) &
                      row.status.equals(AppAgentCommandStatus.executing.name),
                ))
                .write(
                  AiAgentCommandsCompanion(
                    status: Value(result.status.name),
                    safeFailureCode: Value(result.safeFailureCode),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) {
          throw const AppAgentPolicyViolation(
            AppAgentFailureCodes.invalidStatus,
            'The durable command result could not be finalized.',
          );
        }
        await _database
            .into(_database.aiAgentAuditEvents)
            .insert(
              AiAgentAuditEventsCompanion.insert(
                id: const Uuid().v7(),
                ownerScopeId: _scope,
                commandId: command.commandId,
                actionType: command.toolId,
                entityType: result.entityType,
                result: result.status.name,
                confirmationMethod: confirmationProof.confirmationMethod,
                safeFailureCode: Value(result.safeFailureCode),
                undoAvailable: Value(result.undoAvailable),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }),
    );
  }

  @override
  Future<AppAgentExecutionResult?> readVerifiedResult(String commandId) async {
    final row =
        await (_database.select(_database.aiAgentExecutionResults)
              ..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.commandId.equals(commandId),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return AppAgentExecutionResult(
      commandId: row.commandId,
      status: AppAgentCommandStatus.values.byName(row.status),
      verified: row.verified,
      entityType: row.entityType,
      affectedCount: row.affectedCount,
      completedAt: row.createdAt.toUtc(),
      safeFailureCode: row.safeFailureCode,
      undoAvailable:
          (jsonDecode(row.safeResultJson) as Map?)?['undoAvailable'] == true,
    );
  }

  @override
  Future<AppAgentExecutionResult> persistMissingCorrelationManualReview({
    required AppAgentCommand command,
  }) async {
    if (command.userAccountScope != _scope) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.accountScopeMismatch,
        'The recovery result does not belong to the active scope.',
      );
    }
    if (await readExecutionReceipt(command) != null) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidStatus,
        'A correlated execution must use normal business reconciliation.',
      );
    }
    final attempt =
        await (_database.select(_database.aiAgentExecutionAttempts)
              ..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.commandId.equals(command.commandId) &
                    row.status.equals('executing'),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.claimedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (attempt == null ||
        attempt.commandRevision != command.revision ||
        attempt.actionType != command.toolId) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidStatus,
        'The uncorrelated execution attempt is no longer recoverable.',
      );
    }
    final result = AppAgentExecutionResult(
      commandId: command.commandId,
      status: AppAgentCommandStatus.partiallySucceeded,
      verified: false,
      entityType: command.commandType.name,
      affectedCount: 0,
      completedAt: DateTime.now().toUtc(),
      safeFailureCode: AppAgentFailureCodes.recoveryManualReview,
    );
    await complete(
      command: command,
      attemptId: attempt.id,
      result: result,
      reconciliationStatus: AppAgentReconciliationStatus.requiresManualReview,
    );
    return result;
  }

  @override
  Future<List<AppAgentCommand>> readRecoverableCommands() async {
    final rows =
        await (_database.select(_database.aiAgentCommands)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) &
                  row.status.isIn(<String>[
                    AppAgentCommandStatus.confirmed.name,
                    AppAgentCommandStatus.executing.name,
                    AppAgentCommandStatus.partiallySucceeded.name,
                    AppAgentCommandStatus.succeeded.name,
                  ]),
            ))
            .get();
    final commandStore = DriftAppAgentCommandStore(session: _session);
    final commands = <AppAgentCommand>[];
    for (final row in rows) {
      if (row.status == AppAgentCommandStatus.succeeded.name ||
          row.status == AppAgentCommandStatus.partiallySucceeded.name) {
        final result =
            await (_database.select(_database.aiAgentExecutionResults)
                  ..where(
                    (result) =>
                        result.ownerScopeId.equals(_scope) &
                        result.commandId.equals(row.id),
                  )
                  ..orderBy([(result) => OrderingTerm.desc(result.createdAt)])
                  ..limit(1))
                .getSingleOrNull();
        final deliveryAcknowledged = result == null
            ? null
            : _readUiDeliveryAcknowledgement(result.safeResultJson);
        if (deliveryAcknowledged == true) continue;
        if (deliveryAcknowledged == null &&
            row.status == AppAgentCommandStatus.succeeded.name) {
          final unacknowledged =
              await (_database.select(_database.aiAgentBusinessOperations)
                    ..where(
                      (operation) =>
                          operation.ownerScopeId.equals(_scope) &
                          operation.commandId.equals(row.id) &
                          operation.uiDeliveryAcknowledged.equals(false),
                    ))
                  .getSingleOrNull();
          if (unacknowledged == null) continue;
        }
      }
      final command = await commandStore.readCommand(
        commandId: row.id,
        accountScope: _scope,
      );
      if (command != null) commands.add(command);
    }
    return commands;
  }

  @override
  Future<void> acknowledgeUiDelivery(String commandId) async {
    await _session.runGuardedWrite(
      () => _database.transaction(() async {
        final result =
            await (_database.select(_database.aiAgentExecutionResults)
                  ..where(
                    (row) =>
                        row.ownerScopeId.equals(_scope) &
                        row.commandId.equals(commandId),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (result == null) return;
        await (_database.update(_database.aiAgentExecutionResults)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) & row.id.equals(result.id),
            ))
            .write(
              AiAgentExecutionResultsCompanion(
                safeResultJson: Value(
                  jsonEncode(<String, Object?>{
                    'verified': result.verified,
                    'entityType': result.entityType,
                    'affectedCount': result.affectedCount,
                    'undoAvailable':
                        (jsonDecode(result.safeResultJson)
                            as Map?)?['undoAvailable'] ==
                        true,
                    'uiDeliveryAcknowledged': true,
                  }),
                ),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
        await (_database.update(_database.aiAgentBusinessOperations)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) &
                  row.commandId.equals(commandId) &
                  row.completedAt.isNotNull() &
                  row.status.isNotValue('executing') &
                  row.uiDeliveryAcknowledged.equals(false),
            ))
            .write(
              AiAgentBusinessOperationsCompanion(
                uiDeliveryAcknowledged: const Value(true),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }),
    );
  }

  @override
  Future<AppAgentExecutionReceipt?> readExecutionReceipt(
    AppAgentCommand command,
  ) async {
    if (command.userAccountScope != _scope) return null;
    final attempt =
        await (_database.select(_database.aiAgentExecutionAttempts)
              ..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.commandId.equals(command.commandId),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.claimedAt)])
              ..limit(1))
            .getSingleOrNull();
    final operationId = attempt?.businessOperationId;
    if (attempt == null || operationId == null) return null;
    final operation =
        await (_database.select(_database.aiAgentBusinessOperations)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) & row.id.equals(operationId),
            ))
            .getSingleOrNull();
    if (operation == null ||
        operation.commandId != command.commandId ||
        operation.commandRevision != attempt.commandRevision) {
      return null;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(operation.expectedEntityIdsJson);
    } on FormatException {
      return null;
    }
    if (decoded is! List || decoded.any((item) => item is! String)) return null;
    return AppAgentExecutionReceipt(
      attemptId: attempt.id,
      commandId: command.commandId,
      commandRevision: attempt.commandRevision,
      operation: AppAgentBusinessOperationSpec(
        key: AppAgentBusinessOperationKey(operation.id),
        expectedEntityType: operation.entityType,
        expectedPersistedIdentifiers: decoded.cast<String>(),
        verificationMethod: operation.verificationMethod,
        safeAutomaticResume: operation.automaticResumeAllowed,
        automaticRetryProhibited: operation.automaticRetryProhibited,
      ),
      claimedAt: attempt.claimedAt.toUtc(),
    );
  }

  @override
  Future<AppAgentExecutionResult> persistReconciliation({
    required AppAgentCommand command,
    required AppAgentExecutionReceipt receipt,
    required AppAgentReconciliationResult reconciliation,
  }) async {
    if (reconciliation.status == AppAgentReconciliationStatus.stillInProgress) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidStatus,
        'An in-progress operation cannot be finalized.',
      );
    }
    return _session.runGuardedWrite(() async {
      final result = reconciliation.toExecutionResult(
        commandId: command.commandId,
        completedAt: DateTime.now().toUtc(),
      );
      await complete(
        command: command,
        attemptId: receipt.attemptId,
        result: result,
        reconciliationStatus: reconciliation.status,
      );
      return result;
    });
  }

  bool? _readUiDeliveryAcknowledgement(String safeResultJson) {
    try {
      final decoded = jsonDecode(safeResultJson);
      if (decoded is! Map) return null;
      final value = decoded['uiDeliveryAcknowledged'];
      return value is bool ? value : null;
    } on FormatException {
      return null;
    }
  }

  String _idempotencyHash({
    required String commandId,
    required int revision,
    required String actionType,
  }) {
    return sha256
        .convert(
          utf8.encode(
            '$_idempotencyDomain\u0000$_scope\u0000$commandId\u0000'
            '$revision\u0000$actionType',
          ),
        )
        .toString();
  }
}
