abstract final class SettingsKeys {
  static const themeMode = 'theme_mode';
  static const locale = 'locale';
  static const baseCurrencyCode = 'base_currency_code';
  static const baseCurrencyCodeOwnerPrefix = 'base_currency_code_v2_';
  static const rememberMe = 'remember_me';
  static const onboardingCompleted = 'onboarding_completed';
  static const backupEnabled = 'backup_enabled';
  static const lastBackupAt = 'last_backup_at';
  static const syncDeviceId = 'sync_device_id';
  // Retained only so account-deletion cleanup can remove the legacy global
  // value. It must never be read as authorization for a signed-in owner.
  @Deprecated('Use receiptAiPrivacyConsentForScopeHash instead.')
  static const receiptAiPrivacyConsent = 'receipt_ai_privacy_consent_v1';
  static const receiptAiPrivacyConsentPrefix = 'receipt_ai_privacy_consent_v2_';
  static const aiAgentMemoryPrefix = 'ai_agent_memory_v2_';
  static const aiAgentMemoryPersistenceEnabledPrefix =
      'ai_agent_memory_persistence_enabled_v2_';
  static const aiAppControlPolicyPrefix = 'ai_app_control_policy_v1_';
  static const dataDeletionOperationStatePrefix =
      'data_deletion_operation_state_v1_';
  static const receiptFileDeletionJournalPrefix =
      'receipt_file_deletion_journal_v1_';
  static const ownerDeletionQuarantinePrefix = 'owner_deletion_quarantine_v1_';
  static const completedAccountDeletionPrefix =
      'completed_account_deletion_v1_';
  static const backupConsentGeneration = 'backup_consent_generation_v1';
  static const backupInitialSnapshotComplete = 'backup_snapshot_complete_v1';

  static String aiAgentMemoryForScopeHash(String accountScopeHash) =>
      '$aiAgentMemoryPrefix${_validatedScopeHash(accountScopeHash)}';

  static String receiptAiPrivacyConsentForScopeHash(String accountScopeHash) =>
      '$receiptAiPrivacyConsentPrefix${_validatedScopeHash(accountScopeHash)}';

  static String aiAgentMemoryPersistenceForScopeHash(String accountScopeHash) =>
      '$aiAgentMemoryPersistenceEnabledPrefix${_validatedScopeHash(accountScopeHash)}';

  static String _validatedScopeHash(String accountScopeHash) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(accountScopeHash)) {
      throw ArgumentError(
        'AI assistant storage requires a SHA-256 account scope.',
      );
    }
    return accountScopeHash;
  }
}
