/// Synchronous, non-secret application version metadata used by compile-time
/// configuration. Runtime diagnostics still use `PackageInfo` so installed
/// package metadata remains authoritative for what is actually running.
abstract final class CashPilotAppVersion {
  static const String version = '1.0.0';
  static const String buildNumber = '1';
  static const String pubspecVersion = '$version+$buildNumber';
}
