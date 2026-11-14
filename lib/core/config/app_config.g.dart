// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => _AppConfig(
  environment:
      $enumDecodeNullable(_$AppEnvironmentEnumMap, json['environment']) ??
      AppEnvironment.development,
  appName: json['appName'] as String? ?? 'CashPilot AI',
  firebaseEnabled: json['firebaseEnabled'] as bool? ?? false,
);

Map<String, dynamic> _$AppConfigToJson(_AppConfig instance) =>
    <String, dynamic>{
      'environment': _$AppEnvironmentEnumMap[instance.environment]!,
      'appName': instance.appName,
      'firebaseEnabled': instance.firebaseEnabled,
    };

const _$AppEnvironmentEnumMap = {
  AppEnvironment.development: 'development',
  AppEnvironment.staging: 'staging',
  AppEnvironment.production: 'production',
};
