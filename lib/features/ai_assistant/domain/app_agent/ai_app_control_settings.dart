enum AiAppControlLevel {
  off,
  readOnly,
  reviewBeforeExecution,
  fullControl;

  // Source-compatible aliases for policy records and tests written against
  // the retired five-level model. They are not additional selectable levels.
  static const readAndNavigate = readOnly;

  static const draftChanges = reviewBeforeExecution;

  static const fullGovernedControl = fullControl;
}

/// Describes where the current account-scoped policy came from without
/// exposing the account identifier or any financial data.
enum AiAppControlPolicyProvenance {
  environmentDefault,
  stagingMigration,
  persistedUserSelection,
  legacyUnresolved,
}

class AiAppControlSettings {
  const AiAppControlSettings({
    required this.level,
    required this.allowFinancialAnalysis,
    required this.allowNavigation,
    required this.allowTransactionDrafts,
    required this.allowBudgetAndGoalDrafts,
    required this.allowAccountCategoryPayeeDrafts,
    required this.allowRecurringDrafts,
    required this.allowMultiStepPlans,
    required this.requireConfirmationForEveryChange,
    this.provenance = AiAppControlPolicyProvenance.environmentDefault,
  });

  const AiAppControlSettings.conservative({
    this.provenance = AiAppControlPolicyProvenance.environmentDefault,
  }) : level = AiAppControlLevel.off,
       allowFinancialAnalysis = false,
       allowNavigation = false,
       allowTransactionDrafts = false,
       allowBudgetAndGoalDrafts = false,
       allowAccountCategoryPayeeDrafts = false,
       allowRecurringDrafts = false,
       allowMultiStepPlans = false,
       requireConfirmationForEveryChange = true;

  const AiAppControlSettings.stagingTransactionDrafts({
    this.provenance = AiAppControlPolicyProvenance.environmentDefault,
  }) : level = AiAppControlLevel.reviewBeforeExecution,
       allowFinancialAnalysis = true,
       allowNavigation = false,
       allowTransactionDrafts = true,
       allowBudgetAndGoalDrafts = false,
       allowAccountCategoryPayeeDrafts = false,
       allowRecurringDrafts = false,
       allowMultiStepPlans = false,
       requireConfirmationForEveryChange = true;

  /// Canonical capability mapping for the four user-visible control levels.
  /// Build flags and owner-health remain independent fail-closed gates.
  const AiAppControlSettings.forLevel(
    this.level, {
    this.provenance = AiAppControlPolicyProvenance.persistedUserSelection,
  }) : allowFinancialAnalysis = level != AiAppControlLevel.off,
       allowNavigation = level == AiAppControlLevel.fullControl,
       allowTransactionDrafts =
           level == AiAppControlLevel.reviewBeforeExecution ||
           level == AiAppControlLevel.fullControl,
       allowBudgetAndGoalDrafts = level == AiAppControlLevel.fullControl,
       // These families do not have an admitted production handler yet. Keep
       // the account policy visibly false in addition to their build gates.
       allowAccountCategoryPayeeDrafts = false,
       allowRecurringDrafts = false,
       allowMultiStepPlans = false,
       requireConfirmationForEveryChange = true;

  factory AiAppControlSettings.initialForEnvironment({
    required String environmentName,
    required bool isReleaseMode,
  }) {
    if (!isReleaseMode && environmentName.trim().toLowerCase() == 'staging') {
      return const AiAppControlSettings.stagingTransactionDrafts();
    }
    return const AiAppControlSettings.conservative();
  }

  final AiAppControlLevel level;
  final bool allowFinancialAnalysis;
  final bool allowNavigation;
  final bool allowTransactionDrafts;
  final bool allowBudgetAndGoalDrafts;
  final bool allowAccountCategoryPayeeDrafts;
  final bool allowRecurringDrafts;
  final bool allowMultiStepPlans;

  /// Policy-locked to true. A persisted false value is normalized back to
  /// true and can never grant confirmation bypass.
  final bool requireConfirmationForEveryChange;

  final AiAppControlPolicyProvenance provenance;

  bool get isLegacyUnresolved =>
      provenance == AiAppControlPolicyProvenance.legacyUnresolved;

  /// Rebuilds every admitted capability from the selected user-facing level.
  /// The level is the single account-scoped source of consent; persisted
  /// switches from older builds must never contradict it.
  AiAppControlSettings normalizedForLevel({
    AiAppControlPolicyProvenance? provenance,
  }) {
    return AiAppControlSettings.forLevel(
      level,
      provenance: provenance ?? this.provenance,
    );
  }

  AiAppControlSettings copyWith({
    AiAppControlLevel? level,
    bool? allowFinancialAnalysis,
    bool? allowNavigation,
    bool? allowTransactionDrafts,
    bool? allowBudgetAndGoalDrafts,
    bool? allowAccountCategoryPayeeDrafts,
    bool? allowRecurringDrafts,
    bool? allowMultiStepPlans,
    AiAppControlPolicyProvenance? provenance,
  }) {
    return AiAppControlSettings(
      level: level ?? this.level,
      allowFinancialAnalysis:
          allowFinancialAnalysis ?? this.allowFinancialAnalysis,
      allowNavigation: allowNavigation ?? this.allowNavigation,
      allowTransactionDrafts:
          allowTransactionDrafts ?? this.allowTransactionDrafts,
      allowBudgetAndGoalDrafts:
          allowBudgetAndGoalDrafts ?? this.allowBudgetAndGoalDrafts,
      // These capability families do not have an admitted handler. Keep their
      // account bits normalized off even if an older caller tries to restore
      // or toggle them.
      allowAccountCategoryPayeeDrafts: false,
      allowRecurringDrafts: false,
      allowMultiStepPlans: false,
      requireConfirmationForEveryChange: true,
      provenance: provenance ?? this.provenance,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 2,
    'level': level.name,
    'allowFinancialAnalysis': allowFinancialAnalysis,
    'allowNavigation': allowNavigation,
    'allowTransactionDrafts': allowTransactionDrafts,
    'allowBudgetAndGoalDrafts': allowBudgetAndGoalDrafts,
    'allowAccountCategoryPayeeDrafts': allowAccountCategoryPayeeDrafts,
    'allowRecurringDrafts': allowRecurringDrafts,
    'allowMultiStepPlans': allowMultiStepPlans,
    'requireConfirmationForEveryChange': true,
    'provenance': provenance.name,
  };

  /// Decodes both the canonical v2 schema and the former v1 schema. Unknown
  /// data fails closed with explicit unresolved provenance.
  static AiAppControlSettings fromJson(Object? value) {
    if (value is! Map) {
      return const AiAppControlSettings.conservative(
        provenance: AiAppControlPolicyProvenance.legacyUnresolved,
      );
    }
    final version = value['version'];
    if (version != 1 && version != 2) {
      return const AiAppControlSettings.conservative(
        provenance: AiAppControlPolicyProvenance.legacyUnresolved,
      );
    }
    final level = _decodeLevel(value['level']);
    if (level == null) {
      return const AiAppControlSettings.conservative(
        provenance: AiAppControlPolicyProvenance.legacyUnresolved,
      );
    }

    if (version == 1) {
      // The v1 store wrote records only in response to a Settings operation.
      // Treat those as persisted selections, preserving Off, while rebuilding
      // the capability bits from the selected level to repair stale false
      // bits left behind by the old level-only updater.
      return AiAppControlSettings.forLevel(
        level,
        provenance: AiAppControlPolicyProvenance.persistedUserSelection,
      );
    }

    final provenanceName = value['provenance'];
    final provenance = provenanceName is String
        ? AiAppControlPolicyProvenance.values
              .where((item) => item.name == provenanceName)
              .firstOrNull
        : null;
    if (provenance == null) {
      return const AiAppControlSettings.conservative(
        provenance: AiAppControlPolicyProvenance.legacyUnresolved,
      );
    }
    // V2 records from the retired independent-switch UI can contain a level
    // such as Full Control with stale false bits. Rebuild from the selected
    // level so read, draft, and execution checks all observe one policy model.
    return AiAppControlSettings.forLevel(level, provenance: provenance);
  }

  static AiAppControlLevel? _decodeLevel(Object? value) {
    if (value is! String) return null;
    return switch (value) {
      'off' => AiAppControlLevel.off,
      'readOnly' || 'readAndNavigate' => AiAppControlLevel.readOnly,
      'reviewBeforeExecution' ||
      'draftChanges' => AiAppControlLevel.reviewBeforeExecution,
      'fullControl' || 'fullGovernedControl' => AiAppControlLevel.fullControl,
      _ => null,
    };
  }
}

abstract interface class AiAppControlSettingsStore {
  Future<AiAppControlSettings> read(String accountScopeHash);

  Future<void> save(String accountScopeHash, AiAppControlSettings settings);

  Future<void> clear(String accountScopeHash);
}
