import 'package:flutter/material.dart';

import '../../shared/design_system/design_system.dart';

abstract final class AppTheme {
  static ThemeData light() => CPTheme.light();

  static ThemeData dark() => CPTheme.dark();
}
