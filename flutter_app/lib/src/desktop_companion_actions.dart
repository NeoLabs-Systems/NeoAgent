import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';

import 'desktop_command_output.dart';
import 'desktop_native_bridge.dart';
import 'desktop_screen_capture.dart';

// ─── Isolate helpers for JPEG compression ────────────────────────────────────
// `compressToJpeg` offloads the CPU-intensive pure-Dart PNG→JPEG conversion
// to a background isolate via `compute()` so the main isolate's event loop
// stays free to process incoming WebSocket commands (click, drag, etc.)
// immediately, rather than queuing behind a 300–600 ms compression job.

typedef _JpegArgs = ({Uint8List bytes, int quality});

String resolveDesktopDisplaySelection(
  Object? rawDisplays,
  String requested, {
  String? activeDisplayId,
}) {
  final normalized = requested.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(
      requested,
      'displayId',
      'Display ID is required.',
    );
  }
  final displays = rawDisplays is List
      ? rawDisplays
            .whereType<Map>()
            .map(
              (display) =>
                  display.map((key, value) => MapEntry(key.toString(), value)),
            )
            .where(
              (display) => display['id']?.toString().trim().isNotEmpty == true,
            )
            .toList(growable: false)
      : const <Map<String, Object?>>[];
  if (displays.isEmpty) {
    throw StateError('No desktop displays are currently available.');
  }

  if (normalized.toLowerCase() == 'primary') {
    for (final display in displays) {
      if (display['primary'] == true) {
        return display['id'].toString().trim();
      }
    }
    final active = activeDisplayId?.trim() ?? '';
    if (active.isNotEmpty &&
        displays.any((display) => display['id']?.toString().trim() == active)) {
      return active;
    }
  }

  for (final display in displays) {
    final id = display['id']?.toString().trim() ?? '';
    if (id == normalized) return id;
  }
  throw ArgumentError.value(
    requested,
    'displayId',
    'The requested desktop display is not available.',
  );
}

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
  final Map<String, Process> _shellProcesses = <String, Process>{};
  final Set<String> _cancelledShellCommandIds = <String>{};

  bool get isCaptureSupported => _screenCapture.isSupported;

  Future<Map<String, Object?>> buildHello({
    required String deviceId,
    required String activationId,
    required String label,
    required bool companionEnabled,
    required bool paused,
    required bool captureAllowed,
    String? activeDisplayId,
  }) async {
    final platformStatus = await _platformStatus();
    final capabilities = await _capabilities(platformStatus: platformStatus);
    final snapshot = await _safeSnapshotForStatus(
      activeDisplayId: activeDisplayId,
      platformStatus: platformStatus,
      captureAllowed: captureAllowed,
    );
    final reportedDisplays = _coerceDisplays(platformStatus['displays']);
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
      'displays': snapshot?.displays ?? reportedDisplays,
      'activeDisplayId':
          snapshot?.activeDisplayId ??
          platformStatus['activeDisplayId']?.toString() ??
          activeDisplayId ??
          'primary',
      'metadata': <String, Object?>{
        'captureSupported': _screenCapture.isSupported,
      },
      if (platformStatus['sessionLocked'] != null)
        'sessionLocked': platformStatus['sessionLocked'],
      if (platformStatus['idleSeconds'] != null)
        'idleSeconds': platformStatus['idleSeconds'],
      if (platformStatus['userIdle'] != null)
        'userIdle': platformStatus['userIdle'],
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
      activeDisplayId: 'primary',
      displays: <Map<String, Object?>>[
        <String, Object?>{
          'id': 'primary',
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
    required bool captureAllowed,
    String? activeDisplayId,
  }) async {
    final platformStatus = await _platformStatus();
    final capabilities = await _capabilities(platformStatus: platformStatus);
    final snapshot = await _safeSnapshotForStatus(
      activeDisplayId: activeDisplayId,
      platformStatus: platformStatus,
      captureAllowed: captureAllowed,
    );
    final reportedDisplays = _coerceDisplays(platformStatus['displays']);
    return <String, Object?>{
      'paused': paused,
      'label': label,
      'activeDisplayId':
          snapshot?.activeDisplayId ??
          platformStatus['activeDisplayId']?.toString() ??
          activeDisplayId ??
          'primary',
      'displays': snapshot?.displays ?? reportedDisplays,
      'permissions': _permissions(capabilities, platformStatus: platformStatus),
      'capabilities': capabilities,
      if (platformStatus['frontmostApp'] != null)
        'frontmostApp': platformStatus['frontmostApp'],
      if (platformStatus['frontmostWindowTitle'] != null)
        'frontmostWindowTitle': platformStatus['frontmostWindowTitle'],
      if (platformStatus['sessionLocked'] != null)
        'sessionLocked': platformStatus['sessionLocked'],
      if (platformStatus['idleSeconds'] != null)
        'idleSeconds': platformStatus['idleSeconds'],
      if (platformStatus['userIdle'] != null)
        'userIdle': platformStatus['userIdle'],
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
    return compute(_compressJpegInIsolate, (
      bytes: raw,
      quality: quality.clamp(30, 95),
    ));
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
      await _nativeBridge.mouseMove(x: x, y: y, displayId: displayId);
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      await _run(_ShellCommand('xdotool', <String>['mousemove', '$x', '$y']));
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

  Future<Map<String, Object?>> openUri({required String uri}) async {
    final parsed = Uri.tryParse(uri.trim());
    if (parsed == null ||
        !parsed.hasScheme ||
        !<String>{'http', 'https'}.contains(parsed.scheme)) {
      throw ArgumentError.value(
        uri,
        'uri',
        'An http or https URL is required.',
      );
    }
    final command = switch (defaultTargetPlatform) {
      TargetPlatform.macOS => _ShellCommand('open', <String>[
        parsed.toString(),
      ]),
      TargetPlatform.windows => _ShellCommand('cmd.exe', <String>[
        '/c',
        'start',
        '',
        parsed.toString(),
      ]),
      TargetPlatform.linux => _ShellCommand('xdg-open', <String>[
        parsed.toString(),
      ]),
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => throw Exception(
        'Opening desktop URLs is not supported on this platform.',
      ),
    };
    await _run(command);
    return <String, Object?>{'success': true, 'url': parsed.toString()};
  }

  Directory get _workspaceDirectory {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (home == null || home.trim().isEmpty) {
      throw StateError('The local user home directory is unavailable.');
    }
    return Directory(
      '${home.trim()}${Platform.pathSeparator}NeoAgent Workspace',
    );
  }

  Directory _resolveWorkspaceDirectory(String? workspaceRoot) {
    final override = workspaceRoot?.trim() ?? '';
    if (override.isEmpty) return _workspaceDirectory;
    final overrideDir = Directory(override);
    if (!overrideDir.isAbsolute) {
      throw ArgumentError.value(
        workspaceRoot,
        'workspaceRoot',
        'Workspace override must be an absolute path.',
      );
    }
    return overrideDir;
  }

  Future<FileSystemEntity> _workspaceEntity(
    String relativePath, {
    required bool directory,
    String? workspaceRoot,
  }) async {
    final normalized = relativePath.trim().replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.split('/').contains('..')) {
      throw ArgumentError.value(
        relativePath,
        'path',
        'Path must stay inside the workspace folder.',
      );
    }
    final root = _resolveWorkspaceDirectory(workspaceRoot).absolute;
    await root.create(recursive: true);
    final suffix = normalized == '.' || normalized.isEmpty
        ? ''
        : normalized
              .split('/')
              .where((part) => part.isNotEmpty && part != '.')
              .join(Platform.pathSeparator);
    final target = suffix.isEmpty
        ? root.path
        : '${root.path}${Platform.pathSeparator}$suffix';
    await _rejectWorkspaceSymlinks(root.path, target);
    return directory ? Directory(target) : File(target);
  }

  Future<void> _rejectWorkspaceSymlinks(
    String workspaceRoot,
    String target,
  ) async {
    var current = File(target).absolute.path;
    final root = Directory(workspaceRoot).absolute.path;
    while (true) {
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw FileSystemException(
          'Symbolic links are not allowed in NeoAgent Workspace paths.',
          current,
        );
      }
      if (current == root) return;
      final parent = FileSystemEntity.parentOf(current);
      if (parent == current || current.length < root.length) {
        throw FileSystemException(
          'Path must stay inside NeoAgent Workspace.',
          target,
        );
      }
      current = parent;
    }
  }

  Future<Map<String, Object?>> listFiles({
    required String path,
    String? workspaceRoot,
  }) async {
    final directory = await _workspaceEntity(
          path,
          directory: true,
          workspaceRoot: workspaceRoot,
        )
        as Directory;
    if (!await directory.exists()) {
      throw FileSystemException('Directory does not exist.', path);
    }
    final rootPath = _resolveWorkspaceDirectory(workspaceRoot).absolute.path;
    final entries = <Map<String, Object?>>[];
    await for (final entity in directory.list(followLinks: false)) {
      final stat = await entity.stat();
      final relative = entity.absolute.path
          .substring(rootPath.length)
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'^/+'), '');
      entries.add(<String, Object?>{
        'name': entity.uri.pathSegments.where((part) => part.isNotEmpty).last,
        'path': relative,
        'type': stat.type == FileSystemEntityType.directory
            ? 'directory'
            : 'file',
        'size': stat.size,
        'modifiedAt': stat.modified.toUtc().toIso8601String(),
      });
    }
    entries.sort((left, right) {
      final leftDirectory = left['type'] == 'directory';
      final rightDirectory = right['type'] == 'directory';
      if (leftDirectory != rightDirectory) return leftDirectory ? -1 : 1;
      return left['name'].toString().toLowerCase().compareTo(
        right['name'].toString().toLowerCase(),
      );
    });
    final relativePath = directory.absolute.path == rootPath
        ? ''
        : directory.absolute.path
              .substring(rootPath.length)
              .replaceAll('\\', '/')
              .replaceFirst(RegExp(r'^/+'), '');
    return <String, Object?>{'path': relativePath, 'entries': entries};
  }

  Future<Map<String, Object?>> readFile({
    required String path,
    bool base64 = false,
    String? workspaceRoot,
  }) async {
    final file = await _workspaceEntity(
          path,
          directory: false,
          workspaceRoot: workspaceRoot,
        )
        as File;
    final size = await file.length();
    final maximum = base64 ? 24 * 1024 * 1024 : 1024 * 1024;
    if (size > maximum) {
      throw FileSystemException('File exceeds the supported size limit.', path);
    }
    final bytes = await file.readAsBytes();
    return <String, Object?>{
      'path': path,
      'size': size,
      'filename': file.uri.pathSegments.last,
      'content': base64 ? base64Encode(bytes) : utf8.decode(bytes),
      if (base64) 'contentType': 'application/octet-stream',
      if (base64) 'encoding': 'base64',
    };
  }

  Future<Map<String, Object?>> writeFile({
    required String path,
    required String content,
    String? workspaceRoot,
  }) async {
    if (utf8.encode(content).length > 1024 * 1024) {
      throw FileSystemException('File exceeds the 1 MiB editor limit.', path);
    }
    final file = await _workspaceEntity(
          path,
          directory: false,
          workspaceRoot: workspaceRoot,
        )
        as File;
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
    return <String, Object?>{
      'success': true,
      'path': path,
      'size': await file.length(),
    };
  }

  Future<Map<String, Object?>> searchFiles({
    required String path,
    required String query,
    required String pattern,
    required int maxResults,
    String? workspaceRoot,
  }) async {
    final directory = await _workspaceEntity(
          path,
          directory: true,
          workspaceRoot: workspaceRoot,
        )
        as Directory;
    final rootPath = _resolveWorkspaceDirectory(workspaceRoot).absolute.path;
    final normalizedQuery = query.toLowerCase();
    final normalizedPattern = pattern.toLowerCase().replaceAll('*', '');
    final results = <Map<String, Object?>>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || results.length >= maxResults.clamp(1, 500)) {
        continue;
      }
      final relative = entity.absolute.path
          .substring(rootPath.length)
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'^/+'), '');
      if (normalizedPattern.isNotEmpty &&
          !relative.toLowerCase().contains(normalizedPattern)) {
        continue;
      }
      if (normalizedQuery.isNotEmpty) {
        final stat = await entity.stat();
        if (stat.size > 1024 * 1024) continue;
        try {
          final content = await entity.readAsString();
          if (!content.toLowerCase().contains(normalizedQuery)) continue;
        } catch (_) {
          continue;
        }
      }
      results.add(<String, Object?>{'path': relative});
    }
    return <String, Object?>{'results': results};
  }

  Future<Map<String, Object?>> getTree() async {
    return <String, Object?>{
      'supported': false,
      'nodes': const <Map<String, Object?>>[],
    };
  }

  Future<Map<String, Object?>> executeShellCommand({
    required String commandId,
    required String command,
    String? cwd,
    int? timeoutMs,
    String? stdinInput,
    bool requestedPty = false,
    List<String> inputs = const <String>[],
  }) async {
    if (command.trim().isEmpty) {
      throw ArgumentError.value(command, 'command', 'Command is required.');
    }
    final shell = Platform.isWindows
        ? 'cmd.exe'
        : (Platform.environment['SHELL'] ?? '/bin/sh');
    final args = Platform.isWindows
        ? <String>['/c', command]
        : <String>['-lc', command];
    final requestedCwd = cwd?.trim() ?? '';
    final workingDir = requestedCwd == '__neoagent_workspace__'
        ? _workspaceDirectory.path
        : (requestedCwd.isNotEmpty
              ? requestedCwd
              : Platform.environment[Platform.isWindows
                    ? 'USERPROFILE'
                    : 'HOME']);
    if (requestedCwd == '__neoagent_workspace__') {
      await _workspaceDirectory.create(recursive: true);
    }
    final startedAt = DateTime.now();

    final output = DesktopCommandOutputAccumulator();
    await output.initialize();
    late final Process process;
    try {
      process = await Process.start(
        shell,
        args,
        workingDirectory: workingDir,
        runInShell: false,
      );
    } catch (_) {
      await output.discard();
      rethrow;
    }
    if (commandId.isNotEmpty) {
      _shellProcesses[commandId] = process;
    }

    if (_cancelledShellCommandIds.contains(commandId)) {
      await _terminateShellProcess(process);
    } else if ((stdinInput != null && stdinInput.isNotEmpty) ||
        inputs.isNotEmpty) {
      if (stdinInput != null) process.stdin.write(stdinInput);
      for (final input in inputs) {
        process.stdin.write(input);
      }
      await process.stdin.close();
    } else {
      unawaited(process.stdin.close());
    }

    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    final stdoutSub = process.stdout.listen(
      (data) => output.add('stdout', data),
      onError: stdoutDone.completeError,
      onDone: stdoutDone.complete,
    );
    final stderrSub = process.stderr.listen(
      (data) => output.add('stderr', data),
      onError: stderrDone.completeError,
      onDone: stderrDone.complete,
    );

    final effectiveTimeout = Duration(
      milliseconds: (timeoutMs != null && timeoutMs > 0)
          ? timeoutMs
          : 15 * 60 * 1000,
    );

    bool timedOut = false;
    bool externallyCancelled = false;
    int? exitCode;
    try {
      exitCode = await process.exitCode.timeout(effectiveTimeout);
    } on TimeoutException {
      timedOut = true;
      exitCode = await _terminateShellProcess(process);
    } finally {
      externallyCancelled = _cancelledShellCommandIds.contains(commandId);
      if (commandId.isNotEmpty) {
        _shellProcesses.remove(commandId);
        _cancelledShellCommandIds.remove(commandId);
      }
    }

    try {
      await Future.wait<void>(<Future<void>>[
        stdoutDone.future,
        stderrDone.future,
      ]).timeout(const Duration(seconds: 2));
    } on TimeoutException {
      await stdoutSub.cancel();
      await stderrSub.cancel();
    }

    late final Map<String, Object?> outputResult;
    try {
      outputResult = await output.finalize();
    } catch (_) {
      await output.discard();
      rethrow;
    }

    return <String, Object?>{
      'exitCode': exitCode,
      ...outputResult,
      'timedOut': timedOut,
      'killed': timedOut || externallyCancelled,
      'cancelled': externallyCancelled,
      'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      'command': command,
      'cwd': workingDir,
      'backend': 'desktop-companion',
      'ptyRequested': requestedPty,
      'ptyAllocated': false,
    };
  }

  Future<Map<String, Object?>> cancelShellCommand(String commandId) async {
    if (commandId.isEmpty) {
      return <String, Object?>{'success': false, 'cancelled': false};
    }
    _cancelledShellCommandIds.add(commandId);
    final process = _shellProcesses[commandId];
    if (process == null) {
      return <String, Object?>{'success': true, 'cancelled': true};
    }
    await _terminateShellProcess(process);
    return <String, Object?>{'success': true, 'cancelled': true};
  }

  Future<int?> _terminateShellProcess(Process process) async {
    process.kill(ProcessSignal.sigterm);
    try {
      return await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      try {
        return await process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        return null;
      }
    }
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
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return _linuxPlatformStatus();
    }
    return const <String, Object?>{};
  }

  Future<Map<String, Object?>> _linuxPlatformStatus() async {
    try {
      final sessionState = await _linuxSessionState();
      final windowIdResult = await Process.run('xdotool', <String>[
        'getactivewindow',
      ]);
      if (windowIdResult.exitCode != 0) {
        return sessionState;
      }
      final windowId = windowIdResult.stdout?.toString().trim() ?? '';
      if (windowId.isEmpty) {
        return sessionState;
      }
      final titleResult = await Process.run('xdotool', <String>[
        'getwindowname',
        windowId,
      ]);
      final classResult = await Process.run('xprop', <String>[
        '-id',
        windowId,
        'WM_CLASS',
      ]);
      final windowTitle = titleResult.exitCode == 0
          ? titleResult.stdout?.toString().trim() ?? ''
          : '';
      final appName = _parseLinuxWmClass(classResult.stdout?.toString() ?? '');
      return <String, Object?>{
        ...sessionState,
        if (appName.isNotEmpty) 'frontmostApp': appName,
        if (windowTitle.isNotEmpty) 'frontmostWindowTitle': windowTitle,
      };
    } catch (_) {
      return const <String, Object?>{};
    }
  }

  String _parseLinuxWmClass(String raw) {
    final match = RegExp(r'"([^"]+)"\s*,\s*"([^"]+)"').firstMatch(raw);
    if (match == null) {
      return '';
    }
    final app = match.group(2)?.trim() ?? '';
    if (app.isNotEmpty) {
      return app;
    }
    return match.group(1)?.trim() ?? '';
  }

  Future<Map<String, Object?>> _linuxSessionState() async {
    final state = <String, Object?>{};
    final sessionId = Platform.environment['XDG_SESSION_ID']?.trim() ?? '';
    if (sessionId.isNotEmpty) {
      try {
        final result = await Process.run('loginctl', <String>[
          'show-session',
          sessionId,
          '-p',
          'LockedHint',
          '-p',
          'IdleHint',
        ]);
        if (result.exitCode == 0) {
          final lines =
              result.stdout
                  ?.toString()
                  .split(RegExp(r'\r?\n'))
                  .map((line) => line.trim())
                  .where((line) => line.isNotEmpty)
                  .toList(growable: false) ??
              const <String>[];
          for (final line in lines) {
            if (line.startsWith('LockedHint=')) {
              state['sessionLocked'] =
                  line.substring('LockedHint='.length).trim() == 'yes';
            } else if (line.startsWith('IdleHint=')) {
              state['userIdle'] =
                  line.substring('IdleHint='.length).trim() == 'yes';
            }
          }
        }
      } catch (_) {}
    }
    try {
      final result = await Process.run('xprintidle', const <String>[]);
      if (result.exitCode == 0) {
        final idleMs = num.tryParse(result.stdout?.toString().trim() ?? '');
        if (idleMs != null) {
          final idleSeconds = idleMs / 1000;
          state['idleSeconds'] = idleSeconds;
          state['userIdle'] = (state['userIdle'] == true) || idleSeconds >= 300;
        }
      }
    } catch (_) {}
    return state;
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

  /// Status only needs display geometry. A screenshot is taken solely when
  /// the platform cannot report displays itself and the user has allowed
  /// screen access; otherwise every status refresh would hit the OS screen
  /// recording gate (and macOS re-prompts for that).
  Future<DesktopCompanionSnapshot?> _safeSnapshotForStatus({
    required String? activeDisplayId,
    required Map<String, Object?> platformStatus,
    required bool captureAllowed,
  }) async {
    if (!captureAllowed) return null;
    if (_coerceDisplays(platformStatus['displays']).isNotEmpty) return null;
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

  List<Map<String, Object?>> _coerceDisplays(Object? raw) {
    if (raw is! List) return const <Map<String, Object?>>[];
    return raw
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .where((item) => item['id']?.toString().trim().isNotEmpty == true)
        .toList(growable: false);
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
