import 'desktop_screen_capture.dart';

DesktopScreenCapture createPlatformDesktopScreenCapture() =>
    _UnsupportedDesktopScreenCapture();

class _UnsupportedDesktopScreenCapture implements DesktopScreenCapture {
  @override
  bool get isSupported => false;

  @override
  Future<DesktopScreenCaptureResult?> captureCurrentScreen() async => null;
}
