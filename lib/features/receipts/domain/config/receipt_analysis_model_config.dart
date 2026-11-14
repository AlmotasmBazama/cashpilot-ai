class ReceiptAnalysisModelConfig {
  const ReceiptAnalysisModelConfig({
    required this.modelName,
    required this.temperature,
    required this.maxOutputTokens,
    required this.timeout,
    required this.structuredOutputEnabled,
    required this.maximumImageSize,
    required this.retryBackoff,
  });

  static const String modelDefine = 'CASH_PILOT_RECEIPT_AI_MODEL';

  factory ReceiptAnalysisModelConfig.current({required String fallbackModel}) {
    const configured = String.fromEnvironment(modelDefine);
    return ReceiptAnalysisModelConfig(
      modelName: configured.trim().isEmpty ? fallbackModel : configured.trim(),
      temperature: 0.05,
      maxOutputTokens: 4096,
      timeout: const Duration(seconds: 30),
      structuredOutputEnabled: true,
      maximumImageSize: 8 * 1024 * 1024,
      retryBackoff: const <Duration>[
        Duration(milliseconds: 400),
        Duration(seconds: 1),
      ],
    );
  }

  final String modelName;
  final double temperature;
  final int maxOutputTokens;
  final Duration timeout;
  final bool structuredOutputEnabled;
  final int maximumImageSize;
  final List<Duration> retryBackoff;
}
