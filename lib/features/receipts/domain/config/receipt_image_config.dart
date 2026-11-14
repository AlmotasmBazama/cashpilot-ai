class ReceiptImageConfig {
  const ReceiptImageConfig({
    required this.maxWidth,
    required this.maxHeight,
    required this.jpegQuality,
    required this.maxFileBytes,
    required this.minimumReadableWidth,
    required this.minimumReadableHeight,
    required this.supportedMimeTypes,
  });

  static const standard = ReceiptImageConfig(
    maxWidth: 2048,
    maxHeight: 2048,
    jpegQuality: 86,
    maxFileBytes: 8 * 1024 * 1024,
    minimumReadableWidth: 480,
    minimumReadableHeight: 480,
    supportedMimeTypes: <String>['image/jpeg', 'image/png', 'image/webp'],
  );

  final int maxWidth;
  final int maxHeight;
  final int jpegQuality;
  final int maxFileBytes;
  final int minimumReadableWidth;
  final int minimumReadableHeight;
  final List<String> supportedMimeTypes;
}
