import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/settings_local_data_source.dart';

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ref.watch(settingsLocalDataSourceProvider).readThemeMode();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    await ref.read(settingsLocalDataSourceProvider).saveThemeMode(themeMode);
    state = themeMode;
  }

  Future<void> toggleBrightness() {
    return setThemeMode(
      state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
