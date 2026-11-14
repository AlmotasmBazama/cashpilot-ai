class ReceiptFeatureConfig {
  const ReceiptFeatureConfig({required this.enabled});

  static const String enabledDefine = 'CASH_PILOT_RECEIPT_SCANNING_ENABLED';

  factory ReceiptFeatureConfig.current() {
    const value = String.fromEnvironment(enabledDefine, defaultValue: 'true');
    return ReceiptFeatureConfig(
      enabled: switch (value.trim().toLowerCase()) {
        'false' || '0' || 'no' => false,
        _ => true,
      },
    );
  }

  final bool enabled;
}
