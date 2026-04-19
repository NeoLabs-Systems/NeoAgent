import 'desktop_screen_capture_stub.dart'
    if (dart.library.io) 'desktop_screen_capture_io.dart';

DesktopScreenCapture createDesktopScreenCapture() =>
    createPlatformDesktopScreenCapture();

class DesktopScreenCaptureResult {
  const DesktopScreenCaptureResult({
    required this.bytes,
    required this.mimeType,
  });

  final List<int> bytes;
  final String mimeType;
}

abstract class DesktopScreenCapture {
  bool get isSupported;

  Future<DesktopScreenCaptureResult?> captureCurrentScreen();
}
