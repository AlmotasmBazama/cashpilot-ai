import '../failures/ai_failure_codes.dart';

enum AiConnectionDiagnosticStatus { providerReady, fallbackReady, unavailable }

enum AiConnectionTestStatus {
  notTested,
  success,
  providerUnavailable,
  appCheckBlocked,
  rateLimited,
  invalidResponse,
  networkFailure,
  fallbackUsed,
}

class AiConnectionDiagnosticResult {
  const AiConnectionDiagnosticResult({
    required this.status,
    required this.providerAttempted,
    required this.providerResponded,
    required this.fallbackReady,
    required this.appCheckReady,
    this.failureCode,
    this.checkedAt,
  });

  final AiConnectionDiagnosticStatus status;
  final bool providerAttempted;
  final bool providerResponded;
  final bool fallbackReady;
  final bool? appCheckReady;
  final String? failureCode;
  final DateTime? checkedAt;

  bool get isUsable => status != AiConnectionDiagnosticStatus.unavailable;

  AiConnectionTestStatus get testStatus {
    if (status == AiConnectionDiagnosticStatus.providerReady) {
      return AiConnectionTestStatus.success;
    }
    return switch (failureCode) {
      AiFailureCodes.appCheckBlocked => AiConnectionTestStatus.appCheckBlocked,
      AiFailureCodes.rateLimited => AiConnectionTestStatus.rateLimited,
      AiFailureCodes.invalidResponse || AiFailureCodes.unsupportedSchema =>
        AiConnectionTestStatus.invalidResponse,
      AiFailureCodes.networkFailure => AiConnectionTestStatus.networkFailure,
      AiFailureCodes.providerUnavailable =>
        AiConnectionTestStatus.providerUnavailable,
      _ when fallbackReady => AiConnectionTestStatus.fallbackUsed,
      _ => AiConnectionTestStatus.providerUnavailable,
    };
  }

  factory AiConnectionDiagnosticResult.providerReady({
    required bool? appCheckReady,
    required bool fallbackReady,
    DateTime? checkedAt,
  }) {
    return AiConnectionDiagnosticResult(
      status: AiConnectionDiagnosticStatus.providerReady,
      providerAttempted: true,
      providerResponded: true,
      fallbackReady: fallbackReady,
      appCheckReady: appCheckReady,
      checkedAt: checkedAt,
    );
  }

  factory AiConnectionDiagnosticResult.fallbackReady({
    required bool providerAttempted,
    required bool? appCheckReady,
    required String failureCode,
    bool providerResponded = false,
    DateTime? checkedAt,
  }) {
    return AiConnectionDiagnosticResult(
      status: AiConnectionDiagnosticStatus.fallbackReady,
      providerAttempted: providerAttempted,
      providerResponded: providerResponded,
      fallbackReady: true,
      appCheckReady: appCheckReady,
      failureCode: failureCode,
      checkedAt: checkedAt,
    );
  }

  factory AiConnectionDiagnosticResult.unavailable({
    required bool providerAttempted,
    required bool? appCheckReady,
    String failureCode = AiFailureCodes.unknown,
    bool providerResponded = false,
    DateTime? checkedAt,
  }) {
    return AiConnectionDiagnosticResult(
      status: AiConnectionDiagnosticStatus.unavailable,
      providerAttempted: providerAttempted,
      providerResponded: providerResponded,
      fallbackReady: false,
      appCheckReady: appCheckReady,
      failureCode: failureCode,
      checkedAt: checkedAt,
    );
  }
}
