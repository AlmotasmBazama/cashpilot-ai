import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

extension AppBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  bool get isRtl => Directionality.of(this) == TextDirection.rtl;

  ThemeData get theme => Theme.of(this);

  ColorScheme get colorScheme => theme.colorScheme;

  TextTheme get textTheme => theme.textTheme;
}
