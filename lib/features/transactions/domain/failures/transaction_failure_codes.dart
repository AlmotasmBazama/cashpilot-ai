abstract final class TransactionFailureCodes {
  static const transferCreationRequiresPair = 'transfer_creation_requires_pair';
  static const invalidInitialStatus = 'invalid_transaction_initial_status';
  static const invalidTransferInitialStatus = 'invalid_transfer_initial_status';
  static const invalidStatusTransition = 'invalid_status_transition';
  static const terminalStatus = 'terminal_transaction_status';
  static const transferGroupMissing = 'transfer_group_missing';
  static const transferGroupMalformed = 'transfer_group_malformed';
  static const transferGroupConflict = 'transfer_group_conflict';
  static const transferIdentityInvalid = 'transfer_identity_invalid';
  static const transferScopeIntegrityQuarantined =
      'transfer_scope_integrity_quarantined';
  static const transferDirectEditNotAllowed =
      'transfer_direct_edit_not_allowed';
  static const transferHardDeleteNotAllowed =
      'transfer_hard_delete_not_allowed';
  static const staleMutationTarget = 'stale_transaction_mutation_target';
}
