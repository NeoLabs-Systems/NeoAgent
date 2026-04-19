import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';

import 'desktop_screen_capture.dart';

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

  bool get isCaptureSupported => _screenCapture.isSupported;

  Future<Map<String, Object?>> buildHello({
    required String deviceId,
    required String activationId,
    required String label,
    required bool companionEnabled,
    required bool paused,
  }) async {
    final snapshot = await captureSnapshot();
    final packageInfo = await PackageInfo.fromPlatform();
    final capabilities = await _capabilities();
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
      'permissions': _permissions(capabilities),
      'capabilities': capabilities,
      'displays': snapshot?.displays ?? const <Map<String, Object?>>[],
      'activeDisplayId': snapshot?.activeDisplayId ?? 'primary',
      'metadata': <String, Object?>{
        'captureSupported': _screenCapture.isSupported,
      },
    };
  }

  Future<DesktopCompanionSnapshot?> captureSnapshot() async {
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
  }) async {
    final snapshot = await captureSnapshot();
    final capabilities = await _capabilities();
    return <String, Object?>{
      'paused': paused,
      'label': label,
      'activeDisplayId': snapshot?.activeDisplayId ?? 'primary',
      'displays': snapshot?.displays ?? const <Map<String, Object?>>[],
      'permissions': _permissions(capabilities),
      'capabilities': capabilities,
    };
  }

  Future<Map<String, Object?>> captureFrame() async {
    final snapshot = await captureSnapshot();
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

  Future<Map<String, Object?>> observe({bool includeTree = false}) async {
    final result = await captureFrame();
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
  }) async {
    await _assertInputSupported('click');
    final normalizedButton = _normalizeMouseButton(button);
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await _macClick(x: x, y: y, button: normalizedButton);
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      await _windowsClick(x: x, y: y, button: normalizedButton);
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      await _linuxClick(x: x, y: y, button: normalizedButton);
    } else {
      throw Exception('click is not supported on this platform.');
    }
    return <String, Object?>{'success': true, 'x': x, 'y': y, 'button': button};
  }

  Future<Map<String, Object?>> drag({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    int durationMs = 280,
  }) async {
    await _assertInputSupported('drag');
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await _macDrag(x1: x1, y1: y1, x2: x2, y2: y2, durationMs: durationMs);
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      await _windowsDrag(x1: x1, y1: y1, x2: x2, y2: y2, durationMs: durationMs);
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      await _linuxDrag(x1: x1, y1: y1, x2: x2, y2: y2, durationMs: durationMs);
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

  Future<Map<String, Object?>> scroll({int deltaX = 0, int deltaY = 0}) async {
    await _assertInputSupported('scroll');
    if (deltaY == 0 && deltaX == 0) {
      return <String, Object?>{
        'success': true,
        'deltaX': deltaX,
        'deltaY': deltaY,
      };
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await _macScroll(deltaX: deltaX, deltaY: deltaY);
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      await _windowsScroll(deltaX: deltaX, deltaY: deltaY);
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      await _linuxScroll(deltaX: deltaX, deltaY: deltaY);
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
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await _macTypeText(text: text, pressEnter: pressEnter);
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      await _windowsTypeText(text: text, pressEnter: pressEnter);
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      await _linuxTypeText(text: text, pressEnter: pressEnter);
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
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await _macPressKey(key);
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      await _windowsPressKey(key);
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      await _linuxPressKey(key);
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

  Future<Map<String, Object?>> _capabilities() async {
    final inputSupported = await _inputSupported();
    return <String, Object?>{
      'screenshot': _screenCapture.isSupported,
      'click': inputSupported,
      'drag': inputSupported,
      'scroll': inputSupported,
      'typeText': inputSupported,
      'pressKey': inputSupported,
      'launchApp': _isDesktopPlatform,
      'accessibilityTree': false,
    };
  }

  Map<String, Object?> _permissions(Map<String, Object?> capabilities) {
    final inputAvailable = capabilities['click'] == true;
    final accessibilityState = defaultTargetPlatform == TargetPlatform.macOS
        ? (inputAvailable ? 'available' : 'required')
        : (defaultTargetPlatform == TargetPlatform.windows
              ? (inputAvailable ? 'available' : 'required')
              : 'unsupported');
    return <String, Object?>{
      'screenCapture': _screenCapture.isSupported ? 'available' : 'unsupported',
      'inputControl': inputAvailable ? 'available' : 'unsupported',
      'accessibility': accessibilityState,
    };
  }

  Future<bool> _inputSupported() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return _macInputSupported();
      case TargetPlatform.windows:
        return _windowsInputSupported();
      case TargetPlatform.linux:
        return _linuxInputSupported();
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  Future<bool> _macInputSupported() async {
    try {
      final swift = await Process.run('xcrun', <String>['--find', 'swift']);
      final osascript = await Process.run('xcrun', <String>['--find', 'osascript']);
      return swift.exitCode == 0 && osascript.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _windowsInputSupported() async {
    try {
      final result = await Process.run('powershell', <String>[
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r"$PSVersionTable.PSVersion.Major",
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _linuxInputSupported() async {
    try {
      final result = await Process.run('sh', <String>[
        '-lc',
        'command -v xdotool >/dev/null 2>&1',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

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

  String _normalizeMouseButton(String button) {
    final value = button.trim().toLowerCase();
    if (value == 'left' || value == 'right' || value == 'middle') {
      return value;
    }
    return 'left';
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

  Future<void> _linuxClick({required int x, required int y, required String button}) async {
    final buttonCode = button == 'right'
        ? '3'
        : (button == 'middle' ? '2' : '1');
    await _run(_ShellCommand('xdotool', <String>['mousemove', '$x', '$y', 'click', buttonCode]));
  }

  Future<void> _linuxDrag({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required int durationMs,
  }) async {
    await _run(_ShellCommand('xdotool', <String>['mousemove', '$x1', '$y1']));
    await _run(_ShellCommand('xdotool', const <String>['mousedown', '1']));
    await Future<void>.delayed(Duration(milliseconds: durationMs.clamp(40, 2000)));
    await _run(_ShellCommand('xdotool', <String>['mousemove', '$x2', '$y2']));
    await _run(_ShellCommand('xdotool', const <String>['mouseup', '1']));
  }

  Future<void> _linuxScroll({required int deltaX, required int deltaY}) async {
    if (deltaY != 0) {
      final clicks = (deltaY.abs() / 120).ceil().clamp(1, 12);
      final button = deltaY < 0 ? '5' : '4';
      await _run(_ShellCommand('xdotool', <String>['click', '--repeat', '$clicks', button]));
    }
    if (deltaX != 0) {
      final clicks = (deltaX.abs() / 120).ceil().clamp(1, 12);
      final button = deltaX < 0 ? '6' : '7';
      await _run(_ShellCommand('xdotool', <String>['click', '--repeat', '$clicks', button]));
    }
  }

  Future<void> _linuxTypeText({required String text, required bool pressEnter}) async {
    if (text.isNotEmpty) {
      await _run(_ShellCommand('xdotool', <String>['type', '--delay', '1', '--', text]));
    }
    if (pressEnter) {
      await _run(_ShellCommand('xdotool', const <String>['key', 'Return']));
    }
  }

  Future<void> _linuxPressKey(String key) async {
    final normalized = key.trim();
    if (normalized.isEmpty) {
      throw Exception('Key is required.');
    }
    await _run(_ShellCommand('xdotool', <String>['key', normalized]));
  }

  Future<void> _macClick({required int x, required int y, required String button}) async {
    const script = r'''
import Foundation
import CoreGraphics

func buttonType(_ raw: String) -> CGMouseButton {
  switch raw.lowercased() {
  case "right": return .right
  case "middle": return .center
  default: return .left
  }
}

func downType(_ button: CGMouseButton) -> CGEventType {
  switch button {
  case .right: return .rightMouseDown
  case .center: return .otherMouseDown
  default: return .leftMouseDown
  }
}

func upType(_ button: CGMouseButton) -> CGEventType {
  switch button {
  case .right: return .rightMouseUp
  case .center: return .otherMouseUp
  default: return .leftMouseUp
  }
}

let x = Double(CommandLine.arguments[1]) ?? 0
let y = Double(CommandLine.arguments[2]) ?? 0
let b = buttonType(CommandLine.arguments[3])
let p = CGPoint(x: x, y: y)

CGWarpMouseCursorPosition(p)
usleep(8000)
let source = CGEventSource(stateID: .hidSystemState)
guard let down = CGEvent(mouseEventSource: source, mouseType: downType(b), mouseCursorPosition: p, mouseButton: b),
      let up = CGEvent(mouseEventSource: source, mouseType: upType(b), mouseCursorPosition: p, mouseButton: b) else {
  fputs("failed to create mouse events\n", stderr)
  exit(1)
}
down.post(tap: .cghidEventTap)
usleep(12000)
up.post(tap: .cghidEventTap)
''';
    await _runMacSwift(script, <String>['$x', '$y', button]);
  }

  Future<void> _macDrag({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required int durationMs,
  }) async {
    const script = r'''
import Foundation
import CoreGraphics

let x1 = Double(CommandLine.arguments[1]) ?? 0
let y1 = Double(CommandLine.arguments[2]) ?? 0
let x2 = Double(CommandLine.arguments[3]) ?? 0
let y2 = Double(CommandLine.arguments[4]) ?? 0
let durationMs = max(40, Int(CommandLine.arguments[5]) ?? 280)
let steps = max(4, min(80, durationMs / 16))
let source = CGEventSource(stateID: .hidSystemState)

let start = CGPoint(x: x1, y: y1)
let end = CGPoint(x: x2, y: y2)
CGWarpMouseCursorPosition(start)
usleep(8000)

guard let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left) else {
  fputs("failed to create drag start\n", stderr)
  exit(1)
}
down.post(tap: .cghidEventTap)

for i in 1...steps {
  let t = Double(i) / Double(steps)
  let point = CGPoint(x: x1 + ((x2 - x1) * t), y: y1 + ((y2 - y1) * t))
  if let dragged = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left) {
    dragged.post(tap: .cghidEventTap)
  }
  usleep(useconds_t((durationMs * 1000) / max(1, steps)))
}

guard let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left) else {
  fputs("failed to create drag end\n", stderr)
  exit(1)
}
up.post(tap: .cghidEventTap)
''';
    await _runMacSwift(script, <String>['$x1', '$y1', '$x2', '$y2', '$durationMs']);
  }

  Future<void> _macScroll({required int deltaX, required int deltaY}) async {
    const script = r'''
import Foundation
import CoreGraphics

let dx = Int32(CommandLine.arguments[1]) ?? 0
let dy = Int32(CommandLine.arguments[2]) ?? 0
let source = CGEventSource(stateID: .hidSystemState)
if let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: -dy, wheel2: dx, wheel3: 0) {
  event.post(tap: .cghidEventTap)
} else {
  fputs("failed to create scroll event\n", stderr)
  exit(1)
}
''';
    await _runMacSwift(script, <String>['$deltaX', '$deltaY']);
  }

  Future<void> _macTypeText({required String text, required bool pressEnter}) async {
    final lines = <String>[
      'tell application "System Events"',
      if (text.isNotEmpty) 'keystroke "${_appleScriptEscape(text)}"',
      if (pressEnter) 'key code 36',
      'end tell',
    ];
    await _runAppleScript(lines);
  }

  Future<void> _macPressKey(String key) async {
    final parsed = _parseKeyChord(key);
    if (parsed.mainKey.isEmpty) {
      throw Exception('Key is required.');
    }
    final modifierBlock = parsed.modifiers.isEmpty
        ? ''
        : ' using {${parsed.modifiers.map((e) => '$e down').join(', ')}}';
    final spec = _macKeySpec(parsed.mainKey);
    final command = spec.keyCode != null
        ? 'key code ${spec.keyCode}$modifierBlock'
        : 'keystroke "${_appleScriptEscape(spec.keystroke!)}"$modifierBlock';
    await _runAppleScript(<String>[
      'tell application "System Events"',
      command,
      'end tell',
    ]);
  }

  Future<void> _windowsClick({required int x, required int y, required String button}) async {
    const script = r'''
$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Native {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
}
"@

$x = [int]$args[0]
$y = [int]$args[1]
$button = ($args[2] + '').ToLowerInvariant()
[void][Native]::SetCursorPos($x, $y)
switch ($button) {
  'right' { $down = 0x0008; $up = 0x0010 }
  'middle' { $down = 0x0020; $up = 0x0040 }
  default { $down = 0x0002; $up = 0x0004 }
}
[Native]::mouse_event([uint32]$down, 0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 12
[Native]::mouse_event([uint32]$up, 0, 0, 0, [UIntPtr]::Zero)
''';
    await _runPowerShell(script, <String>['$x', '$y', button]);
  }

  Future<void> _windowsDrag({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required int durationMs,
  }) async {
    const script = r'''
$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Native {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
}
"@

$x1 = [int]$args[0]
$y1 = [int]$args[1]
$x2 = [int]$args[2]
$y2 = [int]$args[3]
$duration = [Math]::Max(40, [int]$args[4])
$steps = [Math]::Max(4, [Math]::Min(80, [int]($duration / 16)))
[void][Native]::SetCursorPos($x1, $y1)
[Native]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
for ($i = 1; $i -le $steps; $i++) {
  $t = $i / $steps
  $nx = [int]($x1 + (($x2 - $x1) * $t))
  $ny = [int]($y1 + (($y2 - $y1) * $t))
  [void][Native]::SetCursorPos($nx, $ny)
  Start-Sleep -Milliseconds ([Math]::Max(1, [int]($duration / $steps)))
}
[Native]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
''';
    await _runPowerShell(script, <String>['$x1', '$y1', '$x2', '$y2', '$durationMs']);
  }

  Future<void> _windowsScroll({required int deltaX, required int deltaY}) async {
    const script = r'''
$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Native {
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, int data, UIntPtr extraInfo);
}
"@

$dx = [int]$args[0]
$dy = [int]$args[1]
if ($dy -ne 0) {
  [Native]::mouse_event(0x0800, 0, 0, $dy, [UIntPtr]::Zero)
}
if ($dx -ne 0) {
  [Native]::mouse_event(0x1000, 0, 0, $dx, [UIntPtr]::Zero)
}
''';
    await _runPowerShell(script, <String>['$deltaX', '$deltaY']);
  }

  Future<void> _windowsTypeText({required String text, required bool pressEnter}) async {
    const script = r'''
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$input = $args[0] + ''
$pressEnter = [bool]::Parse($args[1])
if ($input.Length -gt 0) {
  [System.Windows.Forms.SendKeys]::SendWait($input)
}
if ($pressEnter) {
  [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
}
''';
    await _runPowerShell(script, <String>[_windowsSendKeysEscape(text), '$pressEnter']);
  }

  Future<void> _windowsPressKey(String key) async {
    final parsed = _parseKeyChord(key);
    if (parsed.mainKey.isEmpty) {
      throw Exception('Key is required.');
    }
    final sendKeys = _toWindowsSendKeysChord(parsed);
    const script = r'''
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait($args[0])
''';
    await _runPowerShell(script, <String>[sendKeys]);
  }

  Future<void> _runMacSwift(String script, List<String> args) {
    return _run(_ShellCommand('swift', <String>['-e', script, ...args]));
  }

  Future<void> _runAppleScript(List<String> lines) {
    final args = <String>[];
    for (final line in lines) {
      args.add('-e');
      args.add(line);
    }
    return _run(_ShellCommand('osascript', args));
  }

  Future<void> _runPowerShell(String script, List<String> args) {
    return _run(
      _ShellCommand('powershell', <String>[
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
        ...args,
      ]),
    );
  }

  _ParsedKeyChord _parseKeyChord(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return const _ParsedKeyChord(<String>[], '');
    final tokens = normalized
        .split(RegExp(r'\s*\+\s*'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part.trim())
        .toList();
    if (tokens.isEmpty) return const _ParsedKeyChord(<String>[], '');
    if (tokens.length == 1) return _ParsedKeyChord(const <String>[], tokens.first);
    final modifiers = <String>[];
    for (var index = 0; index < tokens.length - 1; index += 1) {
      final value = tokens[index].toLowerCase();
      if (value == 'cmd' || value == 'command' || value == 'meta') {
        modifiers.add('command');
      } else if (value == 'ctrl' || value == 'control') {
        modifiers.add('control');
      } else if (value == 'alt' || value == 'option') {
        modifiers.add('option');
      } else if (value == 'shift') {
        modifiers.add('shift');
      }
    }
    return _ParsedKeyChord(modifiers, tokens.last);
  }

  _MacKeySpec _macKeySpec(String key) {
    final value = key.trim();
    final lower = value.toLowerCase();
    const keyCodes = <String, int>{
      'enter': 36,
      'return': 36,
      'tab': 48,
      'space': 49,
      'delete': 51,
      'backspace': 51,
      'escape': 53,
      'esc': 53,
      'left': 123,
      'right': 124,
      'down': 125,
      'up': 126,
      'home': 115,
      'end': 119,
      'pageup': 116,
      'pagedown': 121,
      'f1': 122,
      'f2': 120,
      'f3': 99,
      'f4': 118,
      'f5': 96,
      'f6': 97,
      'f7': 98,
      'f8': 100,
      'f9': 101,
      'f10': 109,
      'f11': 103,
      'f12': 111,
    };
    if (keyCodes.containsKey(lower)) {
      return _MacKeySpec(keyCode: keyCodes[lower]);
    }
    if (value.length == 1) {
      return _MacKeySpec(keystroke: value);
    }
    throw Exception('Unsupported key for macOS: $key');
  }

  String _toWindowsSendKeysChord(_ParsedKeyChord parsed) {
    final prefix = parsed.modifiers
        .map((modifier) {
          if (modifier == 'control') return '^';
          if (modifier == 'option') return '%';
          if (modifier == 'shift') return '+';
          if (modifier == 'command') return '^';
          return '';
        })
        .join();
    return '$prefix${_windowsKeyToSendKeys(parsed.mainKey)}';
  }

  String _windowsKeyToSendKeys(String key) {
    final value = key.trim();
    final lower = value.toLowerCase();
    const map = <String, String>{
      'enter': '{ENTER}',
      'return': '{ENTER}',
      'tab': '{TAB}',
      'esc': '{ESC}',
      'escape': '{ESC}',
      'left': '{LEFT}',
      'right': '{RIGHT}',
      'up': '{UP}',
      'down': '{DOWN}',
      'delete': '{DELETE}',
      'backspace': '{BACKSPACE}',
      'home': '{HOME}',
      'end': '{END}',
      'pageup': '{PGUP}',
      'pagedown': '{PGDN}',
      'space': ' ',
      'f1': '{F1}',
      'f2': '{F2}',
      'f3': '{F3}',
      'f4': '{F4}',
      'f5': '{F5}',
      'f6': '{F6}',
      'f7': '{F7}',
      'f8': '{F8}',
      'f9': '{F9}',
      'f10': '{F10}',
      'f11': '{F11}',
      'f12': '{F12}',
    };
    if (map.containsKey(lower)) {
      return map[lower]!;
    }
    if (value.length == 1) {
      return _windowsSendKeysEscape(value);
    }
    throw Exception('Unsupported key for Windows: $key');
  }
}

class _ShellCommand {
  const _ShellCommand(this.command, this.args);

  final String command;
  final List<String> args;
}

class _ParsedKeyChord {
  const _ParsedKeyChord(this.modifiers, this.mainKey);

  final List<String> modifiers;
  final String mainKey;
}

class _MacKeySpec {
  const _MacKeySpec({this.keyCode, this.keystroke});

  final int? keyCode;
  final String? keystroke;
}

String _shQuote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";

String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

String _appleScriptEscape(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r');
}

String _windowsSendKeysEscape(String value) {
  final buffer = StringBuffer();
  const escaped = <String>{'+', '^', '%', '~', '(', ')', '{', '}'};
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if (escaped.contains(char)) {
      buffer.write('{$char}');
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

String _localHostname() {
  final host = Platform.localHostname.trim();
  if (host.isNotEmpty) {
    return host;
  }
  return defaultTargetPlatform.name;
}
