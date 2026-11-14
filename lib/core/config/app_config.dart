import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_config.freezed.dart';
part 'app_config.g.dart';

enum AppEnvironment { development, staging, production }

@freezed
abstract class AppConfig with _$AppConfig {
  const factory AppConfig({
    @Default(AppEnvironment.development) AppEnvironment environment,
    @Default('CashPilot AI') String appName,
    @Default(false) bool firebaseEnabled,
  }) = _AppConfig;

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig(),
  name: 'appConfigProvider',
);
