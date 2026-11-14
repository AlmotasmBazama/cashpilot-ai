import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../owner_scope/domain/owner_scope.dart';
import 'settings_keys.dart';

/// Central, typed derivation for every Hive key bound to one confirmed owner.
///
/// The canonical owner scope is already opaque. AI stores historically apply
/// one additional SHA-256 before composing their keys, while receipt consent
/// uses the canonical scope directly. Keeping both rules here prevents account
/// deletion from guessing a different key shape than the writers use.
final class OwnerScopedStorageKeys {
  OwnerScopedStorageKeys._({
    required this.canonicalOwnerScope,
    required this.assistantScopeHash,
    this.trustedFirebaseUid,
  });

  factory OwnerScopedStorageKeys.fromConfirmedOwnerScope(
    ConfirmedOwnerScope ownerScope,
  ) {
    return OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(
      ownerScope.id.value,
    );
  }

  factory OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(
    String ownerScopeValue,
  ) {
    final canonical = _validatedHash(ownerScopeValue, 'ownerScopeValue');
    return OwnerScopedStorageKeys._(
      canonicalOwnerScope: canonical,
      assistantScopeHash: _hash(canonical),
    );
  }

  factory OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity({
    required String firebaseUid,
    required ConfirmedOwnerScope ownerScope,
  }) {
    final uid = firebaseUid;
    if (uid.isEmpty ||
        uid != uid.trim() ||
        OwnerScopeDerivation.fromConfirmedFirebaseUid(uid) != ownerScope) {
      throw ArgumentError(
        'The Firebase identity does not match the confirmed owner scope.',
      );
    }
    final canonical = _validatedHash(ownerScope.id.value, 'ownerScope');
    return OwnerScopedStorageKeys._(
      canonicalOwnerScope: canonical,
      assistantScopeHash: _hash(canonical),
      trustedFirebaseUid: uid,
    );
  }

  final String canonicalOwnerScope;
  final String assistantScopeHash;
  final String? trustedFirebaseUid;

  String get receiptAiPrivacyConsent =>
      SettingsKeys.receiptAiPrivacyConsentForScopeHash(canonicalOwnerScope);

  String get aiAgentMemory =>
      SettingsKeys.aiAgentMemoryForScopeHash(assistantScopeHash);

  String get aiAgentMemoryPersistence =>
      SettingsKeys.aiAgentMemoryPersistenceForScopeHash(assistantScopeHash);

  String get aiAppControlPolicy =>
      '${SettingsKeys.aiAppControlPolicyPrefix}$assistantScopeHash';

  String get baseCurrencyCode =>
      '${SettingsKeys.baseCurrencyCodeOwnerPrefix}$canonicalOwnerScope';

  String get backupEnabled {
    _requiredTrustedUid();
    return '${SettingsKeys.backupEnabled}_$canonicalOwnerScope';
  }

  String get lastBackupAt {
    _requiredTrustedUid();
    return '${SettingsKeys.lastBackupAt}_$canonicalOwnerScope';
  }

  String get backupConsentGeneration {
    _requiredTrustedUid();
    return '${SettingsKeys.backupConsentGeneration}_$canonicalOwnerScope';
  }

  String get backupInitialSnapshotComplete {
    _requiredTrustedUid();
    return '${SettingsKeys.backupInitialSnapshotComplete}_$canonicalOwnerScope';
  }

  String get ownerDeletionQuarantine =>
      '${SettingsKeys.ownerDeletionQuarantinePrefix}$canonicalOwnerScope';

  String get completedAccountDeletion =>
      '${SettingsKeys.completedAccountDeletionPrefix}$canonicalOwnerScope';

  String get dataDeletionOperationState =>
      '${SettingsKeys.dataDeletionOperationStatePrefix}${_domainHash('operation-state')}';

  String receiptFileDeletionJournal(String operationId) {
    final normalized = operationId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('A deletion operation id is required.');
    }
    return '${SettingsKeys.receiptFileDeletionJournalPrefix}'
        '${_domainHash('receipt-journal\u0000$normalized')}';
  }

  List<String> get accountDeletionPreferenceKeys => List.unmodifiable(<String>[
    backupEnabled,
    lastBackupAt,
    backupConsentGeneration,
    backupInitialSnapshotComplete,
    receiptAiPrivacyConsent,
    aiAgentMemory,
    aiAgentMemoryPersistence,
    aiAppControlPolicy,
    baseCurrencyCode,
  ]);

  List<String> get legacyRawUidSyncPreferenceKeys {
    final uid = _requiredTrustedUid();
    return List.unmodifiable(<String>[
      '${SettingsKeys.backupEnabled}_$uid',
      '${SettingsKeys.lastBackupAt}_$uid',
      '${SettingsKeys.backupConsentGeneration}_$uid',
      '${SettingsKeys.backupInitialSnapshotComplete}_$uid',
    ]);
  }

  List<String> get values => List.unmodifiable(<String>[
    receiptAiPrivacyConsent,
    aiAgentMemory,
    aiAgentMemoryPersistence,
    aiAppControlPolicy,
    baseCurrencyCode,
  ]);

  String _requiredTrustedUid() {
    final uid = trustedFirebaseUid;
    if (uid == null) {
      throw StateError('A trusted Firebase identity is required for this key.');
    }
    return uid;
  }

  String _domainHash(String purpose) => _hash(
    'cashpilot.owner-storage.v1\u0000$purpose\u0000$canonicalOwnerScope',
  );

  static String _validatedHash(String value, String parameter) {
    final normalized = value.trim();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
      throw ArgumentError.value(
        '<redacted>',
        parameter,
        'Expected an opaque SHA-256 owner scope.',
      );
    }
    return normalized;
  }

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
