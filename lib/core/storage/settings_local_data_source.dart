import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../shared/domain/currency/currency_catalog.dart';
import '../owner_scope/domain/owner_scope.dart';
import 'hive_box_names.dart';
import 'owner_scoped_storage_keys.dart';
import 'settings_keys.dart';

final settingsLocalDataSourceProvider = Provider<SettingsLocalDataSource>((
  ref,
) {
  return SettingsLocalDataSource(Hive.box<dynamic>(HiveBoxNames.settings));
}, name: 'settingsLocalDataSourceProvider');

class SettingsLocalDataSource {
  const SettingsLocalDataSource(this._box);

  final Box<dynamic> _box;

  ThemeMode readThemeMode() {
    final value = _box.get(SettingsKeys.themeMode);
    if (value is! String) {
      return ThemeMode.dark;
    }

    return ThemeMode.values.firstWhereOrNull((mode) => mode.name == value) ??
        ThemeMode.dark;
  }

  Future<void> saveThemeMode(ThemeMode themeMode) {
    return _box.put(SettingsKeys.themeMode, themeMode.name);
  }

  Locale? readLocale() {
    final value = _box.get(SettingsKeys.locale);
    if (value is! String || value.isEmpty) {
      return null;
    }

    return Locale(value);
  }

  Future<void> saveLocale(Locale? locale) {
    if (locale == null) {
      return _box.delete(SettingsKeys.locale);
    }

    return _box.put(SettingsKeys.locale, locale.languageCode);
  }

  String readBaseCurrencyCode() {
    final value = _box.get(SettingsKeys.baseCurrencyCode);
    if (value is! String || value.trim().isEmpty) {
      return CurrencyCatalog.defaultCurrencyCode;
    }

    return CurrencyCatalog.normalizeCode(value);
  }

  Future<void> saveBaseCurrencyCode(String currencyCode) {
    return _box.put(
      SettingsKeys.baseCurrencyCode,
      CurrencyCatalog.normalizeCode(currencyCode),
    );
  }

  String? readOwnerBaseCurrencyCode(ConfirmedOwnerScope ownerScope) {
    final value = _box.get(
      OwnerScopedStorageKeys.fromConfirmedOwnerScope(
        ownerScope,
      ).baseCurrencyCode,
    );
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return CurrencyCatalog.normalizeCode(value);
  }

  Future<void> saveOwnerBaseCurrencyCode(
    ConfirmedOwnerScope ownerScope,
    String currencyCode,
  ) {
    return _box.put(
      OwnerScopedStorageKeys.fromConfirmedOwnerScope(
        ownerScope,
      ).baseCurrencyCode,
      CurrencyCatalog.normalizeCode(currencyCode),
    );
  }

  bool readRememberMe() {
    return _box.get(SettingsKeys.rememberMe) == true;
  }

  Future<void> saveRememberMe(bool rememberMe) {
    return _box.put(SettingsKeys.rememberMe, rememberMe);
  }

  bool readOnboardingCompleted() {
    return _box.get(SettingsKeys.onboardingCompleted) == true;
  }

  Future<void> saveOnboardingCompleted(bool completed) {
    return _box.put(SettingsKeys.onboardingCompleted, completed);
  }

  bool readAiAgentMemoryPersistenceEnabled({required String accountScope}) {
    return _box.get(_keys(accountScope).aiAgentMemoryPersistence) == true;
  }

  Future<void> saveAiAgentMemoryPersistenceEnabled({
    required String accountScope,
    required bool enabled,
    void Function()? assertWriteAllowed,
  }) {
    // Hive updates its in-memory value synchronously when put is invoked. Keep
    // this checkpoint immediately adjacent to that logical commit boundary.
    assertWriteAllowed?.call();
    return _box.put(_keys(accountScope).aiAgentMemoryPersistence, enabled);
  }

  Future<void> clearAiAgentMemory({required String accountScope}) {
    return _box.delete(_keys(accountScope).aiAgentMemory);
  }

  OwnerScopedStorageKeys _keys(String accountScope) =>
      OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(accountScope);
}
