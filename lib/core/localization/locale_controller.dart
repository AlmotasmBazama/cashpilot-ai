import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_exception.dart';
import '../storage/settings_local_data_source.dart';

const supportedLocales = [Locale('en'), Locale('ar')];

bool isSupportedLocale(Locale locale) {
  return supportedLocales.any(
    (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
  );
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    return ref.watch(settingsLocalDataSourceProvider).readLocale();
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale != null && !isSupportedLocale(locale)) {
      throw AppException.validation(
        message: 'Unsupported locale: ${locale.languageCode}',
      );
    }

    await ref.read(settingsLocalDataSourceProvider).saveLocale(locale);
    state = locale;
  }
}
