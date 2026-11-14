import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../../core/storage/settings_keys.dart';
import '../../domain/app_agent/ai_app_control_settings.dart';

class HiveAiAppControlSettingsStore implements AiAppControlSettingsStore {
  const HiveAiAppControlSettingsStore(
    this._box, {
    this.missingPolicyDefault = const AiAppControlSettings.conservative(),
    this.migrateUninitializedPolicy = false,
    this.admitStagingMigrationPolicy = false,
  });

  final Box<dynamic> _box;
  final AiAppControlSettings missingPolicyDefault;
  final bool migrateUninitializedPolicy;
  final bool admitStagingMigrationPolicy;

  @override
  Future<AiAppControlSettings> read(String accountScopeHash) async {
    final key = _key(accountScopeHash);
    final value = _box.get(key);
    if (value == null) {
      return _migrateUninitialized(key);
    }
    if (value is! String || value.length > 4096) {
      return _unresolvedLegacyPolicy;
    }
    try {
      final decoded = jsonDecode(value);
      if (_isKnownUninitializedLegacyRecord(decoded)) {
        return _migrateUninitialized(key);
      }
      final settings = AiAppControlSettings.fromJson(decoded);
      if (settings.isLegacyUnresolved) {
        return settings;
      }
      if (settings.provenance ==
              AiAppControlPolicyProvenance.stagingMigration &&
          !admitStagingMigrationPolicy) {
        // A development default must not become an account authorization when
        // the same local data is opened by a non-staging or Release build.
        // Leave the record untouched so an explicit selection can replace it.
        return _unresolvedLegacyPolicy;
      }
      if (decoded is Map &&
          (decoded['version'] == 1 ||
              jsonEncode(decoded) != jsonEncode(settings.toJson()))) {
        // Upgrade v1 and repair contradictory v2 capability bits once while
        // retaining the explicit selected level, including a deliberate Off.
        await _box.put(key, jsonEncode(settings.toJson()));
      }
      return settings;
    } on Object {
      return _unresolvedLegacyPolicy;
    }
  }

  @override
  Future<void> save(String accountScopeHash, AiAppControlSettings settings) {
    final normalized = settings.normalizedForLevel();
    final persisted =
        normalized.provenance == AiAppControlPolicyProvenance.environmentDefault
        ? normalized.copyWith(
            provenance: AiAppControlPolicyProvenance.persistedUserSelection,
          )
        : normalized;
    return _box.put(_key(accountScopeHash), jsonEncode(persisted.toJson()));
  }

  @override
  Future<void> clear(String accountScopeHash) =>
      _box.delete(_key(accountScopeHash));

  Future<AiAppControlSettings> _migrateUninitialized(String key) async {
    if (!migrateUninitializedPolicy) {
      return missingPolicyDefault.copyWith(
        provenance: AiAppControlPolicyProvenance.environmentDefault,
      );
    }
    final migrated = missingPolicyDefault.copyWith(
      provenance: AiAppControlPolicyProvenance.stagingMigration,
    );
    await _box.put(key, jsonEncode(migrated.toJson()));
    return migrated;
  }

  bool _isKnownUninitializedLegacyRecord(Object? value) {
    if (value is! Map) return false;
    // Only an explicit legacy marker proves that a record was generated as a
    // default rather than selected by the user. Unknown legacy shapes remain
    // unresolved and are never overwritten.
    return value['explicitUserSelection'] == false ||
        value['initialized'] == false;
  }

  String _key(String accountScopeHash) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(accountScopeHash)) {
      throw ArgumentError.value(
        accountScopeHash,
        'accountScopeHash',
        'Expected a SHA-256 account scope.',
      );
    }
    return '${SettingsKeys.aiAppControlPolicyPrefix}$accountScopeHash';
  }
}

const _unresolvedLegacyPolicy = AiAppControlSettings.conservative(
  provenance: AiAppControlPolicyProvenance.legacyUnresolved,
);
