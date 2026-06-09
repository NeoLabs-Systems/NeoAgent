import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';

import 'desktop_native_bridge.dart';
import 'desktop_screen_capture.dart';

// ─── Isolate helpers for JPEG compression ────────────────────────────────────
// `compressToJpeg` offloads the CPU-intensive pure-Dart PNG→JPEG conversion
// to a background isolate via `compute()` so the main isolate's event loop
// stays free to process incoming WebSocket commands (click, drag, etc.)
// immediately, rather than queuing behind a 300–600 ms compression job.

typedef _JpegArgs = ({Uint8List bytes, int quality});

Uint8List _compressJpegInIsolate(_JpegArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) return args.bytes;
  return Uint8List.fromList(img.encodeJpg(decoded, quality: args.quality));
}

class DesktopCompanionSnapshot {
  const DesktopCompanionSnapshot({
    required this.screenshotBase64,
    required this.contentType,
    required this.width,
    required this.height,
    required this.displays,
    required this.activeDisplayId,
  });

  final String screenshotBase64;
  final String contentType;
  final int width;
  final int height;
  final List<Map<String, Object?>> displays;
  final String activeDisplayId;
}

class DesktopCompanionActions {
  DesktopCompanionActions({required DesktopScreenCapture screenCapture})
    : _screenCapture = screenCapture;

  final DesktopScreenCapture _screenCapture;
  final DesktopNativeBridge _nativeBridge = DesktopNativeBridge();

  bool get isCaptureSupported => _screenCapture.isSupported;

  Future<Map<String, Object?>> buildHello({
    required String deviceId,
    required String activationId,
    required String label,
    required bool companionEnabled,
    required bool paused,
    String? activeDisplayId,
  }) async {
    final platformStatus = await _platformStatus();
    final capabilities = await _capabilities(platformStatus: platformStatus);
    final snapshot = await _safeSnapshotForStatus(
      activeDisplayId: activeDisplayId,
      platformStatus: platformStatus,
    );
    final packageInfo = await PackageInfo.fromPlatform();
    return <String, Object?>{
      'deviceId': deviceId,
      'activationId': activationId,
      'label': label,
      'hostname': _localHostname(),
      'platform': defaultTargetPlatform.name,
      'platformVersion': Platform.operatingSystemVersion,
      'appVersion': packageInfo.version,
      'companionEnabled': companionEnabled,
      'paused': paused,
      'permissions': _permissions(capabilities, platformStatus: platformStatus),
      'capabilities': capabilities,
      'displays': snapshot?.displays ?? const <Map<String, Object?>>[],
      'activeDisplayId':
          snapshot?.activeDisplayId ??
          platformStatus['activeDisplayId']?.toString() ??
          activeDisplayId ??
          'primary',
      'metadata': <String, Object?>{
        'captureSupported': _screenCapture.isSupported,
      },
    };
  }

  Future<DesktopCompanionSnapshot?> captureSnapshot({
    String? activeDisplayId,
  }) async {
    if (_usesNativeDesktopBridge) {
      final frame = await _nativeBridge.captureFrame(
        displayId: activeDisplayId,
      );
      final bytes = frame['bytes'];
      if (bytes is! Uint8List || bytes.isEmpty) {
        return null;
      }
      // Prefer dimensions reported by the native bridge; only fall back to a
      // pure-Dart image decode (which is slow) when the bridge omits them.
      final nativeWidth = (frame['width'] as num?)?.round();
      final nativeHeight = (frame['height'] as num?)?.round();
      final decoded = (nativeWidth == null || nativeHeight == null)
          ? img.decodeImage(bytes)
          : null;
      final width = nativeWidth ?? decoded?.width ?? 0;
      final height = nativeHeight ?? decoded?.height ?? 0;
      final displays = _normalizeDisplays(
        frame['displays'],
        fallbackDisplayId:
            frame['displayId']?.toString() ?? activeDisplayId ?? 'primary',
        width: width,
        height: height,
      );
      return DesktopCompanionSnapshot(
        screenshotBase64: base64Encode(bytes),
        contentType: frame['mimeType']?.toString() ?? 'image/png',
        width: width,
        height: height,
        displays: displays,
        activeDisplayId:
            frame['displayId']?.toString() ?? activeDisplayId ?? 'primary',
      );
    }

    final capture = await _screenCapture.captureCurrentScreen();
    if (capture == null || capture.bytes.isEmpty) return null;
    final bytes = Uint8List.fromList(capture.bytes);
    final decoded = img.decodeImage(bytes);
    final width = decoded?.width ?? 0;
    final height = decoded?.height ?? 0;
    return DesktopCompanionSnapshot(
      screenshotBase64: base64Encode(bytes),
      contentType: capture.mimeType,
      width: width,
      height: height,
      activeDisplayId: activeDisplayId ?? 'primary',
      displays: <Map<String, Object?>>[
        <String, Object?>{
          'id': activeDisplayId ?? 'primary',
          'label': 'Primary Display',
          'width': width,
          'height': height,
          'scaleFactor': 1,
          'primary': true,
        },
      ],
    );
  }

  Future<Map<String, Object?>> getStatus({
    required String label,
    required bool paused,
    String? activeDisplayId,
  }) async {
    final platformStatus = await _platformStatus();
    final capabilities = await _capabilities(platformStatus: platformStatus);
    final snapshot = await _safeSnapshotForStatus(
      activeDisplayId: activeDisplayId,
      platformStatus: platformStatus,
    );
    return <String, Object?>{
      'paused': paused,
      'label': label,
      'activeDisplayId':
          snapshot?.activeDisplayId ??
          platformStatus['activeDisplayId']?.toString() ??
          activeDisplayId ??
          'primary',
      'displays': snapshot?.displays ?? const <Map<String, Object?>>[],
      'permissions': _permissions(capabilities, platformStatus: platformStatus),
      'capabilities': capabilities,
      if (platformStatus['frontmostApp'] != null)
        'frontmostApp': platformStatus['frontmostApp'],
      if (platformStatus['frontmostWindowTitle'] != null)
        'frontmostWindowTitle': platformStatus['frontmostWindowTitle'],
    };
  }

  Future<Map<String, Object?>> captureFrame({String? activeDisplayId}) async {
    final snapshot = await captureSnapshot(activeDisplayId: activeDisplayId);
    if (snapshot == null) {
      throw Exception('Desktop capture is not available on this platform.');
    }
    return <String, Object?>{
      'screenshotBase64': snapshot.screenshotBase64,
      'contentType': snapshot.contentType,
      'width': snapshot.width,
      'height': snapshot.height,
      'displayId': snapshot.activeDisplayId,
      'displays': snapshot.displays,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<Uint8List> compressToJpeg(
    DesktopCompanionSnapshot snapshot,
    int quality,
  ) async {
    final raw = _decodeScreenshotBytes(snapshot.screenshotBase64);
    // Already JPEG — return immediately without any heavy work on this isolate.
    if (_looksLikeJpeg(raw)) return raw;
    // Run the pure-Dart PNG decode + JPEG encode in a background isolate so the
    // main isolate's event loop stays responsive for incoming commands.
    return compute(
      _compressJpegInIsolate,
      (bytes: raw, quality: quality.clamp(30, 95)),
    );
  }

  Future<Map<String, Object?>> observe({
    bool includeTree = false,
    String? activeDisplayId,
  }) async {
    final result = await captureFrame(activeDisplayId: activeDisplayId);
    return <String, Object?>{
      ...result,
      'tree': includeTree ? const <Map<String, Object?>>[] : null,
      'treeSupported': false,
    };
  }

  Future<Map<String, Object?>> click({
    required int x,
    required int y,
    String button = 'left',
    String? displayId,
  }) async {
    await _assertInputSupported('click');
    final normalizedButton = _normalizeMouseButton(button);
    if (_usesNativeDesktopBridge) {
      await _nativeBridge.click(
        x: x,
        y: y,
        button: normalizedButton,
        displayId: displayId,
      );
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      final buttonCode = normalizedButton == 'right'
          ? '3'
          : (normalizedButton == 'middle' ? '2' : '1');
      await _run(
        _ShellCommand('xdotool', <String>[
          'mousemove',
          '$x',
          '$y',
          'click',
          buttonCode,
        ]),
      );
    } else {
      throw Exception('click is not supported on this platform.');
    }
    return <String, Object?>{'success': true, 'x': x, 'y': y, 'button': button};
  }

  Future<Map<String, Object?>> mouseMove({
    required int x,
    required int y,
    String? displayId,
  }) async {
    await _assertInputSupported('mouseMove');
    if (_usesNativeDesktopBridge) {
      await _nativeBridge.mouseMove(
        x: x,
        y: y,
        displayId: displayId,
      );
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      await _run(
        _ShellCommand('xdotool', <String>[
          'mousemove',
          '$x',
          '$y',
        ]),
      );
    } else {
      throw Exception('mouseMove is not supported on this platform.');
    }
    return <String, Object?>{'success': true, 'x': x, 'y': y};
  }

  Future<Map<String, Object?>> drag({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    int durationMs = 280,
    String? displayId,
  }) async {
    await _assertInputSupported('drag');
    if (_usesNativeDesktopBridge) {
      await _nativeBridge.drag(
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        durationMs: durationMs,
        displayId: displayId,
      );
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      await _run(_ShellCommand('xdotool', <String>['mousemove', '$x1', '$y1']));
      await _run(_ShellCommand('xdotool', const <String>['mousedown', '1']));
      await Future<void>.delayed(
        Duration(milliseconds: durationMs.clamp(40, 2000)),
      );
      await _run(_ShellCommand('xdotool', <String>['mousemove', '$x2', '$y2']));
      await _run(_ShellCommand('xdotool', const <String>['mouseup', '1']));
    } else {
      throw Exception('drag is not supported on this platform.');
    }
    return <String, Object?>{
      'success': true,
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      'durationMs': durationMs,
    };
  }

  Future<Map<String, Object?>> scroll({
    int deltaX = 0,
    int deltaY = 0,
    String? displayId,
  }) async {
    await _assertInputSupported('scroll');
    if (deltaY == 0 && deltaX == 0) {
      return <String, Object?>{
        'success': true,
        'deltaX': deltaX,
        'deltaY': deltaY,
      };
    }
    if (_usesNativeDesktopBridge) {
      await _nativeBridge.scroll(
        deltaX: deltaX,
        deltaY: deltaY,
        displayId: displayId,
      );
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      if (deltaY != 0) {
        final clicks = (deltaY.abs() / 120).ceil().clamp(1, 12);
        final button = deltaY < 0 ? '5' : '4';
        await _run(
          _ShellCommand('xdotool', <String>[
            'click',
            '--repeat',
            '$clicks',
            button,
          ]),
        );
      }
      if (deltaX != 0) {
        final clicks = (deltaX.abs() / 120).ceil().clamp(1, 12);
        final button = deltaX < 0 ? '6' : '7';
        await _run(
          _ShellCommand('xdotool', <String>[
            'click',
            '--repeat',
            '$clicks',
            button,
          ]),
        );
      }
    } else {
      throw Exception('scroll is not supported on this platform.');
    }
    return <String, Object?>{
      'success': true,
      'deltaX': deltaX,
      'deltaY': deltaY,
    };
  }

  Future<Map<String, Object?>> typeText({
    required String text,
    bool pressEnter = false,
  }) async {
    await _assertInputSupported('type text');
    if (_usesNativeDesktopBridge) {
      await _nativeBridge.typeText(text: text, pressEnter: pressEnter);
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      if (text.isNotEmpty) {
        await _run(
          _ShellCommand('xdotool', <String>[
            'type',
            '--delay',
            '1',
            '--',
            text,
          ]),
        );
      }
      if (pressEnter) {
        await _run(_ShellCommand('xdotool', const <String>['key', 'Return']));
      }
    } else {
      throw Exception('type text is not supported on this platform.');
    }
    return <String, Object?>{
      'success': true,
      'textLength': text.length,
      'pressEnter': pressEnter,
    };
  }

  Future<Map<String, Object?>> pressKey({required String key}) async {
    await _assertInputSupported('press keys');
    if (_usesNativeDesktopBridge) {
      await _nativeBridge.pressKey(key);
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      final normalized = key.trim();
      if (normalized.isEmpty) {
        throw Exception('Key is required.');
      }
      await _run(_ShellCommand('xdotool', <String>['key', normalized]));
    } else {
      throw Exception('press keys is not supported on this platform.');
    }
    return <String, Object?>{'success': true, 'key': key};
  }

  Future<Map<String, Object?>> launchApp({required String app}) async {
    if (app.trim().isEmpty) {
      throw Exception('App name is required.');
    }
    final command = switch (defaultTargetPlatform) {
      TargetPlatform.macOS => _ShellCommand('open', <String>['-a', app]),
      TargetPlatform.windows => _ShellCommand('powershell', <String>[
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Start-Process -FilePath ${_psQuote(app)}',
      ]),
      TargetPlatform.linux => _ShellCommand('sh', <String>[
        '-lc',
        'if command -v ${_shQuote(app)} >/dev/null 2>&1; then ${_shQuote(app)} >/dev/null 2>&1 & disown; else gtk-launch ${_shQuote(app)} >/dev/null 2>&1 & disown; fi',
      ]),
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => throw Exception(
        'Launching desktop apps is not supported on this platform.',
      ),
    };
    await _run(command);
    return <String, Object?>{'success': true, 'app': app};
  }

  Future<Map<String, Object?>> getTree() async {
    return <String, Object?>{
      'supported': false,
      'nodes': const <Map<String, Object?>>[],
    };
  }

  Future<Map<String, Object?>> executeShellCommand({
    required String command,
    String? cwd,
    int? timeoutMs,
    String? stdinInput,
  }) async {
    final shell = Platform.isWindows ? 'cmd.exe' : (Platform.environment['SHELL'] ?? '/bin/sh');
    final args = Platform.isWindows ? <String>['/c', command] : <String>['-lc', command];
    final workingDir = cwd?.trim().isNotEmpty == true ? cwd : Platform.environment['HOME'];
    final startedAt = DateTime.now();

    final process = await Process.start(
      shell,
      args,
      workingDirectory: workingDir,
      runInShell: false,
    );

    if (stdinInput != null && stdinInput.isNotEmpty) {
      process.stdin.write(stdinInput);
      await process.stdin.close();
    } else {
      unawaited(process.stdin.close());
    }

    const maxChars = 50000;
    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

    final stdoutSub = process.stdout.transform(utf8.decoder).listen((data) {
      stdoutBuf.write(data);
    });
    final stderrSub = process.stderr.transform(utf8.decoder).listen((data) {
      stderrBuf.write(data);
    });

    final effectiveTimeout = Duration(
      milliseconds: (timeoutMs != null && timeoutMs > 0) ? timeoutMs : 15 * 60 * 1000,
    );

    bool timedOut = false;
    int? exitCode;
    try {
      exitCode = await process.exitCode.timeout(effectiveTimeout);
    } on TimeoutException {
      timedOut = true;
      process.kill(ProcessSignal.sigterm);
      exitCode = null;
    }

    await stdoutSub.cancel();
    await stderrSub.cancel();

    String trimOutput(StringBuffer buf) {
      final s = buf.toString().trim();
      return s.length > maxChars ? '${s.substring(0, maxChars)}\n...[truncated, ${s.length} total chars]' : s;
    }

    return <String, Object?>{
      'exitCode': exitCode,
      'stdout': trimOutput(stdoutBuf),
      'stderr': trimOutput(stderrBuf),
      'timedOut': timedOut,
      'killed': timedOut,
      'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      'command': command,
      'cwd': workingDir,
      'backend': 'desktop-companion',
    };
  }

  Future<Map<String, Object?>> _capabilities({
    Map<String, Object?>? platformStatus,
  }) async {
    final status = platformStatus ?? await _platformStatus();
    final inputSupported = await _inputSupported(platformStatus: status);
    final permissions = status['permissions'];
    final screenCapturePermission = permissions is Map
        ? permissions['screenCapture']?.toString()
        : null;
    return <String, Object?>{
      'screenshot':
          _screenCapture.isSupported &&
          screenCapturePermission != 'required' &&
          screenCapturePermission != 'unsupported',
      'click': inputSupported,
      'drag': inputSupported,
      'scroll': inputSupported,
      'typeText': inputSupported,
      'pressKey': inputSupported,
      'launchApp': _isDesktopPlatform,
      'accessibilityTree': false,
    };
  }

  Map<String, Object?> _permissions(
    Map<String, Object?> capabilities, {
    Map<String, Object?>? platformStatus,
  }) {
    final status = platformStatus ?? const <String, Object?>{};
    final reportedPermissions = status['permissions'];
    if (reportedPermissions is Map) {
      return reportedPermissions.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    final inputAvailable = capabilities['click'] == true;
    return <String, Object?>{
      'screenCapture': _screenCapture.isSupported ? 'available' : 'unsupported',
      'inputControl': inputAvailable ? 'available' : 'unsupported',
      'accessibility': defaultTargetPlatform == TargetPlatform.windows
          ? 'available'
          : 'unsupported',
    };
  }

  Future<bool> _inputSupported({Map<String, Object?>? platformStatus}) async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        final status = platformStatus ?? await _platformStatus();
        final permissions = status['permissions'];
        if (permissions is Map) {
          return permissions['inputControl'] == 'available' &&
              permissions['accessibility'] == 'available';
        }
        return false;
      case TargetPlatform.windows:
        return true;
      case TargetPlatform.linux:
        try {
          final result = await Process.run('sh', <String>[
            '-lc',
            'command -v xdotool >/dev/null 2>&1',
          ]);
          return result.exitCode == 0;
        } catch (_) {
          return false;
        }
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  Future<Map<String, Object?>> _platformStatus() async {
    if (_usesNativeDesktopBridge) {
      return await _nativeBridge.getStatus();
    }
    return const <String, Object?>{};
  }

  bool get _usesNativeDesktopBridge =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;

  bool get _isDesktopPlatform =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  Future<void> _assertInputSupported(String action) async {
    final supported = await _inputSupported();
    if (!supported) {
      throw Exception(
        '$action is not available on ${defaultTargetPlatform.name} (missing runtime permission or dependency).',
      );
    }
  }

  Future<DesktopCompanionSnapshot?> _safeSnapshotForStatus({
    required String? activeDisplayId,
    required Map<String, Object?> platformStatus,
  }) async {
    final permissions = _permissions(
      const <String, Object?>{},
      platformStatus: platformStatus,
    );
    final screenCaptureState =
        permissions['screenCapture']?.toString().toLowerCase() ?? 'unknown';
    if (screenCaptureState == 'required' ||
        screenCaptureState == 'unsupported') {
      return null;
    }
    try {
      return await captureSnapshot(activeDisplayId: activeDisplayId);
    } catch (_) {
      return null;
    }
  }

  Uint8List _decodeScreenshotBytes(String screenshotBase64) {
    final trimmed = screenshotBase64.trim();
    final commaIndex = trimmed.indexOf(',');
    final encoded = trimmed.startsWith('data:image/') && commaIndex >= 0
        ? trimmed.substring(commaIndex + 1)
        : trimmed;
    return Uint8List.fromList(base64Decode(encoded));
  }

  bool _looksLikeJpeg(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[bytes.length - 2] == 0xff &&
        bytes[bytes.length - 1] == 0xd9;
  }

  String _normalizeMouseButton(String button) {
    final value = button.trim().toLowerCase();
    if (value == 'left' || value == 'right' || value == 'middle') {
      return value;
    }
    return 'left';
  }

  List<Map<String, Object?>> _normalizeDisplays(
    Object? raw, {
    required String fallbackDisplayId,
    required int width,
    required int height,
  }) {
    if (raw is List) {
      final displays = raw
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false);
      if (displays.isNotEmpty) {
        return displays;
      }
    }
    return <Map<String, Object?>>[
      <String, Object?>{
        'id': fallbackDisplayId,
        'label': 'Primary Display',
        'width': width,
        'height': height,
        'scaleFactor': 1,
        'primary': true,
      },
    ];
  }

  Future<void> _run(_ShellCommand command) async {
    final result = await Process.run(command.command, command.args);
    if (result.exitCode != 0) {
      final stderr = result.stderr?.toString().trim();
      final stdout = result.stdout?.toString().trim();
      final details = stderr?.isNotEmpty == true
          ? stderr
          : (stdout?.isNotEmpty == true ? stdout : 'unknown error');
      throw Exception('Command failed (${command.command}): $details');
    }
  }
}

class _ShellCommand {
  const _ShellCommand(this.command, this.args);

  final String command;
  final List<String> args;
}

String _shQuote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";

String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

String _localHostname() {
  final host = Platform.localHostname.trim();
  if (host.isNotEmpty) {
    return host;
  }
  return defaultTargetPlatform.name;
}
