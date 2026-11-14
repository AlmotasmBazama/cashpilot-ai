import 'package:drift/drift.dart';

mixin _OwnedAgentRow on Table {
  TextColumn get ownerScopeId => text().named('owner_scope_id')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}

@DataClassName('AiAgentCommandRow')
class AiAgentCommands extends Table with _OwnedAgentRow {
  TextColumn get id => text()();
  TextColumn get conversationId => text().named('conversation_id')();
  TextColumn get commandType => text().named('command_type')();
  TextColumn get toolId => text().named('tool_id')();
  TextColumn get normalizedArgumentsJson =>
      text().named('normalized_arguments_json')();
  TextColumn get permission => text()();
  TextColumn get risk => text()();
  TextColumn get status => text()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  TextColumn get previewFingerprint =>
      text().named('preview_fingerprint').nullable()();
  TextColumn get safeFailureCode =>
      text().named('safe_failure_code').nullable()();
  DateTimeColumn get expiresAt => dateTime().named('expires_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AiAgentPreviewRow')
class AiAgentPreviews extends Table with _OwnedAgentRow {
  TextColumn get id => text()();
  TextColumn get commandId => text().named('command_id')();
  IntColumn get revision => integer()();
  TextColumn get status => text()();
  TextColumn get stateFingerprint => text().named('state_fingerprint')();
  TextColumn get payloadJson => text().named('payload_json')();
  DateTimeColumn get expiresAt => dateTime().named('expires_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AiAgentConfirmationProofRow')
class AiAgentConfirmationProofs extends Table with _OwnedAgentRow {
  TextColumn get id => text()();
  TextColumn get commandId => text().named('command_id')();
  IntColumn get previewRevision => integer().named('preview_revision')();
  TextColumn get confirmationMethod => text().named('confirmation_method')();
  TextColumn get proofHash => text().named('proof_hash')();
  TextColumn get proofSalt => text().named('proof_salt')();
  TextColumn get status => text()();
  DateTimeColumn get expiresAt => dateTime().named('expires_at')();
  DateTimeColumn get consumedAt => dateTime().named('consumed_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AiAgentExecutionAttemptRow')
class AiAgentExecutionAttempts extends Table with _OwnedAgentRow {
  TextColumn get id => text()();
  TextColumn get commandId => text().named('command_id')();
  TextColumn get idempotencyKey => text().named('idempotency_key')();
  IntColumn get commandRevision => integer().named('command_revision')();
  TextColumn get actionType => text().named('action_type')();
  TextColumn get status => text()();
  TextColumn get businessOperationId =>
      text().named('business_operation_id').nullable()();
  TextColumn get safeFailureCode =>
      text().named('safe_failure_code').nullable()();
  DateTimeColumn get claimedAt => dateTime().named('claimed_at')();
  DateTimeColumn get completedAt =>
      dateTime().named('completed_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AiAgentExecutionResultRow')
class AiAgentExecutionResults extends Table with _OwnedAgentRow {
  TextColumn get id => text()();
  TextColumn get commandId => text().named('command_id')();
  TextColumn get attemptId => text().named('attempt_id')();
  TextColumn get status => text()();
  BoolColumn get verified => boolean()();
  TextColumn get entityType => text().named('entity_type')();
  IntColumn get affectedCount => integer().named('affected_count')();
  TextColumn get safeResultJson => text().named('safe_result_json')();
  TextColumn get safeFailureCode =>
      text().named('safe_failure_code').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AiAgentPlanRow')
class AiAgentPlans extends Table with _OwnedAgentRow {
  TextColumn get id => text()();
  TextColumn get conversationId => text().named('conversation_id')();
  TextColumn get status => text()();
  BoolColumn get atomic => boolean().withDefault(const Constant(false))();
  DateTimeColumn get expiresAt => dateTime().named('expires_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AiAgentPlanStepRow')
class AiAgentPlanSteps extends Table with _OwnedAgentRow {
  TextColumn get id => text()();
  TextColumn get planId => text().named('plan_id')();
  TextColumn get commandId => text().named('command_id')();
  IntColumn get position => integer()();
  TextColumn get status => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AiAgentAuditEventRow')
class AiAgentAuditEvents extends Table with _OwnedAgentRow {
  TextColumn get id => text()();
  TextColumn get commandId => text().named('command_id')();
  TextColumn get actionType => text().named('action_type')();
  TextColumn get entityType => text().named('entity_type')();
  TextColumn get result => text()();
  TextColumn get confirmationMethod => text().named('confirmation_method')();
  TextColumn get safeFailureCode =>
      text().named('safe_failure_code').nullable()();
  BoolColumn get undoAvailable =>
      boolean().named('undo_available').withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AiAgentIdempotencyRecordRow')
class AiAgentIdempotencyRecords extends Table with _OwnedAgentRow {
  TextColumn get id => text()();
  TextColumn get commandId => text().named('command_id')();
  IntColumn get commandRevision => integer().named('command_revision')();
  TextColumn get actionType => text().named('action_type')();
  TextColumn get idempotencyHash => text().named('idempotency_hash')();
  TextColumn get status => text()();
  TextColumn get executionResultId =>
      text().named('execution_result_id').nullable()();
  DateTimeColumn get expiresAt => dateTime().named('expires_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Authoritative correlation between a claimed agent command and the exact
/// business entities that must exist for the operation to be considered
/// committed. This contains opaque local identifiers only.
@DataClassName('AiAgentBusinessOperationRow')
class AiAgentBusinessOperations extends Table with _OwnedAgentRow {
  TextColumn get id => text()();
  TextColumn get commandId => text().named('command_id')();
  IntColumn get commandRevision => integer().named('command_revision')();
  TextColumn get actionType => text().named('action_type')();
  TextColumn get entityType => text().named('entity_type')();
  TextColumn get expectedEntityIdsJson =>
      text().named('expected_entity_ids_json')();
  TextColumn get verificationMethod => text().named('verification_method')();
  TextColumn get status => text()();
  BoolColumn get automaticResumeAllowed =>
      boolean().named('automatic_resume_allowed')();
  BoolColumn get automaticRetryProhibited =>
      boolean().named('automatic_retry_prohibited')();
  BoolColumn get uiDeliveryAcknowledged => boolean()
      .named('ui_delivery_acknowledged')
      .withDefault(const Constant(false))();
  TextColumn get safeFailureCode =>
      text().named('safe_failure_code').nullable()();
  DateTimeColumn get completedAt =>
      dateTime().named('completed_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
