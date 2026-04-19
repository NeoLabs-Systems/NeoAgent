import 'dart:io';

import 'package:flutter/foundation.dart';

import 'desktop_native_bridge.dart';
import 'desktop_screen_capture.dart';

DesktopScreenCapture createPlatformDesktopScreenCapture() =>
    _DesktopScreenCaptureIo();

class _DesktopScreenCaptureIo implements DesktopScreenCapture {
  final DesktopNativeBridge _nativeBridge = DesktopNativeBridge();

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  Future<DesktopScreenCaptureResult?> captureCurrentScreen() async {
    if (!isSupported) {
      return null;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return _captureMacos();
      case TargetPlatform.windows:
        return _captureWindows();
      case TargetPlatform.linux:
        return _captureLinux();
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  Future<DesktopScreenCaptureResult?> _captureMacos() async {
    final result = await _nativeBridge.captureFrame();
    final bytes = result['bytes'];
    final mimeType = result['mimeType']?.toString() ?? 'image/png';
    if (bytes is! Uint8List || bytes.isEmpty) {
      return null;
    }
    return DesktopScreenCaptureResult(bytes: bytes, mimeType: mimeType);
  }

  Future<DesktopScreenCaptureResult?> _captureWindows() async {
    final result = await _nativeBridge.captureFrame();
    final bytes = result['bytes'];
    final mimeType = result['mimeType']?.toString() ?? 'image/png';
    if (bytes is! Uint8List || bytes.isEmpty) {
      return null;
    }
    return DesktopScreenCaptureResult(bytes: bytes, mimeType: mimeType);
  }

  Future<DesktopScreenCaptureResult?> _captureLinux() async {
    final attempts =
        <
          ({
            String command,
            List<String> args,
            String extension,
            String mimeType,
          })
        >[
          (
            command: 'grim',
            args: <String>[],
            extension: 'png',
            mimeType: 'image/png',
          ),
          (
            command: 'gnome-screenshot',
            args: <String>['-f'],
            extension: 'png',
            mimeType: 'image/png',
          ),
          (
            command: 'spectacle',
            args: <String>['-b', '-n', '-o'],
            extension: 'png',
            mimeType: 'image/png',
          ),
        ];

    Object? lastError;
    for (final attempt in attempts) {
      final file = await _temporaryFile(attempt.extension);
      try {
        final result = await Process.run(attempt.command, <String>[
          ...attempt.args,
          file.path,
        ]);
        if (result.exitCode == 0 && await file.exists()) {
          return DesktopScreenCaptureResult(
            bytes: await file.readAsBytes(),
            mimeType: attempt.mimeType,
          );
        }
        lastError = ProcessException(
          attempt.command,
          <String>[...attempt.args, file.path],
          '${result.stderr}',
          result.exitCode,
        );
      } on ProcessException catch (error) {
        lastError = error;
      } finally {
        await _deleteIfExists(file);
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    return null;
  }

  Future<File> _temporaryFile(String extension) async {
    final directory = await Directory.systemTemp.createTemp(
      'neoagent-assistant-screen-',
    );
    return File('${directory.path}/capture.$extension');
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
      final parent = file.parent;
      if (await parent.exists()) {
        await parent.delete();
      }
    } catch (_) {}
  }
}
