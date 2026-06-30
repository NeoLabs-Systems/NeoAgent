import 'dart:typed_data';

class DesktopOcrResult {
  const DesktopOcrResult({
    required this.text,
    required this.engine,
    this.confidence,
  });

  final String text;
  final String engine;
  final double? confidence;
}

class DesktopOcrBridge {
  const DesktopOcrBridge();

  Future<String?> unavailableReason() async {
    return 'Local OCR is not available on this platform.';
  }

  Future<DesktopOcrResult> recognize({
    required Uint8List bytes,
    required String mimeType,
  }) {
    throw UnsupportedError('Local OCR is not available on this platform.');
  }
}

DesktopOcrBridge createDesktopOcrBridge() => const DesktopOcrBridge();
