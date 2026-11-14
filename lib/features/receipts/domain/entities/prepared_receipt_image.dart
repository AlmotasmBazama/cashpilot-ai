import 'dart:typed_data';

class PreparedReceiptImage {
  const PreparedReceiptImage({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.sha256,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  final String sha256;
}
