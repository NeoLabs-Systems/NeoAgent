import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_companion_actions.dart';
import 'desktop_screen_capture.dart';

const String desktopCompanionEnabledPrefsKey = 'desktop.companion.enabled';
const String desktopCompanionLabelPrefsKey = 'desktop.companion.label';
const String desktopCompanionDeviceIdPrefsKey = 'desktop.companion.deviceId';
const String desktopCompanionActivationIdPrefsKey =
    'desktop.companion.activationId';
const String desktopCompanionPausedPrefsKey = 'desktop.companion.paused';
const String desktopCompanionActiveDisplayPrefsKey =
    'desktop.companion.activeDisplayId';

class DesktopCompanionManager extends ChangeNotifier {
  DesktopCompanionManager({required DesktopScreenCapture screenCapture})
    : _actions = DesktopCompanionActions(screenCapture: screenCapture);

  final DesktopCompanionActions _actions;
  WebSocket? _socket;
  Timer? _reconnectTimer;

  String _backendUrl = '';
  String _sessionCookie = '';
  String _label = _defaultLabel();
  String _deviceId = '';
  String _activationId = '';
  bool _enabled = false;
  bool _paused = false;
  bool _authenticated = false;
  bool _connecting = false;
  bool _connected = false;
  String _activeDisplayId = 'primary';
  String? _errorMessage;
  Map<String, Object?> _status = const <String, Object?>{};

  bool get enabled => _enabled;
  bool get paused => _paused;
  bool get connecting => _connecting;
  bool get connected => _connected;
  String? get errorMessage => _errorMessage;
  String get label => _label;
  String get deviceId => _deviceId;
  String get activationId => _activationId;
  Map<String, Object?> get status => _status;

  Future<void> bootstrap(SharedPreferences prefs) async {
    _enabled = prefs.getBool(desktopCompanionEnabledPrefsKey) ?? false;
    _paused = prefs.getBool(desktopCompanionPausedPrefsKey) ?? false;
    _label =
        prefs.getString(desktopCompanionLabelPrefsKey)?.trim() ??
        _defaultLabel();
    _deviceId =
        prefs.getString(desktopCompanionDeviceIdPrefsKey)?.trim() ??
        _randomId();
    _activationId =
        prefs.getString(desktopCompanionActivationIdPrefsKey)?.trim() ??
        _randomId();
    _activeDisplayId =
        prefs.getString(desktopCompanionActiveDisplayPrefsKey)?.trim() ??
        'primary';
    await prefs.setString(desktopCompanionDeviceIdPrefsKey, _deviceId);
    await prefs.setString(desktopCompanionActivationIdPrefsKey, _activationId);
  }

  Future<void> updateSession({
    required String backendUrl,
    required String sessionCookie,
    required bool authenticated,
  }) async {
    _backendUrl = backendUrl.trim();
    _sessionCookie = sessionCookie.trim();
    _authenticated = authenticated;
    if (!_authenticated || !_enabled || _sessionCookie.isEmpty) {
      await disconnect();
      return;
    }
    await _ensureConnected();
  }

  Future<void> setEnabled(bool value, SharedPreferences prefs) async {
    if (_enabled == value) return;
    _enabled = value;
    if (value) {
      _activationId = _randomId();
      await prefs.setString(
        desktopCompanionActivationIdPrefsKey,
        _activationId,
      );
    }
    await prefs.setBool(desktopCompanionEnabledPrefsKey, value);
    notifyListeners();
    if (!value) {
      await disconnect();
      return;
    }
    await _ensureConnected();
  }

  Future<void> setLabel(String value, SharedPreferences prefs) async {
    final normalized = value.trim().isEmpty ? _defaultLabel() : value.trim();
    _label = normalized;
    await prefs.setString(desktopCompanionLabelPrefsKey, normalized);
    notifyListeners();
    if (_connected) {
      _status = {..._status, 'label': normalized};
      await _sendEvent('statusChanged', <String, Object?>{'label': normalized});
    }
  }

  Future<void> setPaused(bool value, SharedPreferences prefs) async {
    _paused = value;
    await prefs.setBool(desktopCompanionPausedPrefsKey, value);
    notifyListeners();
    if (_connected) {
      await _sendEvent('statusChanged', <String, Object?>{'paused': value});
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connecting = false;
    _connected = false;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> rotateIdentity(SharedPreferences prefs) async {
    _deviceId = _randomId();
    _activationId = _randomId();
    await prefs.setString(desktopCompanionDeviceIdPrefsKey, _deviceId);
    await prefs.setString(desktopCompanionActivationIdPrefsKey, _activationId);
    await disconnect();
  }

  Future<Map<String, Object?>> refreshLocalStatus() async {
    final status = await _actions.getStatus(
      label: _label,
      paused: _paused,
      activeDisplayId: _activeDisplayId,
    );
    _status = <String, Object?>{
      ..._status,
      ...status,
      'activeDisplayId': status['activeDisplayId'] ?? _activeDisplayId,
      'deviceId': _deviceId,
      'activationId': _activationId,
      'label': _label,
      'platform': defaultTargetPlatform.name,
      'hostname': _localHostname(),
      'companionEnabled': _enabled,
      'paused': _paused,
    };
    notifyListeners();
    if (_connected) {
      await _sendEvent('statusChanged', <String, Object?>{
        'permissions': _status['permissions'],
        'capabilities': _status['capabilities'],
        'displays': _status['displays'],
        'activeDisplayId': _status['activeDisplayId'],
      });
    }
    return _status;
  }

  Future<void> openPermissionSettings(String permissionKey) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Desktop companion permission settings are unavailable on web.',
      );
    }
    final key = permissionKey.trim().toLowerCase();
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        await _openMacPermissionSettings(key);
      case TargetPlatform.windows:
        await _openWindowsPermissionSettings(key);
      case TargetPlatform.linux:
        await _openLinuxPermissionSettings(key);
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Desktop companion permission settings are unavailable on this platform.',
        );
    }
  }

  Future<void> _ensureConnected() async {
    if (!_enabled || !_authenticated || _sessionCookie.isEmpty) return;
    if (_connecting || _connected) return;
    _connecting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final uri = _desktopWsUri(_backendUrl);
      final socket = await WebSocket.connect(
        uri.toString(),
        headers: <String, Object>{'Cookie': _sessionCookie},
      );
      _socket = socket;
      socket.listen(
        _handleMessage,
        onDone: _handleSocketClosed,
        onError: (Object error, StackTrace stackTrace) {
          _errorMessage = '$error';
          _handleSocketClosed();
        },
        cancelOnError: true,
      );
      final hello = await _actions.buildHello(
        deviceId: _deviceId,
        activationId: _activationId,
        label: _label,
        companionEnabled: _enabled,
        paused: _paused,
        activeDisplayId: _activeDisplayId,
      );
      socket.add(
        jsonEncode(<String, Object?>{'type': 'hello', 'device': hello}),
      );
    } catch (error) {
      _connecting = false;
      _connected = false;
      _errorMessage = '$error';
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final message = jsonDecode(raw as String);
      if (message is! Map) return;
      final type = message['type']?.toString() ?? '';
      if (type == 'hello') {
        _connecting = false;
        final ok = message['ok'] == true;
        if (!ok) {
          _connected = false;
          _errorMessage =
              message['error']?.toString() ?? 'Desktop companion rejected.';
          notifyListeners();
          _handleSocketClosed();
          return;
        }
        _connected = true;
        _errorMessage = null;
        final device = message['device'];
        _status = device is Map
            ? device.map((key, value) => MapEntry(key.toString(), value))
            : const <String, Object?>{};
        _activeDisplayId =
            _status['activeDisplayId']?.toString() ?? _activeDisplayId;
        notifyListeners();
        return;
      }
      if (type != 'command') return;
      unawaited(_handleCommand(message.cast<String, Object?>()));
    } on FormatException catch (error) {
      _errorMessage = 'Ignored malformed desktop companion message: $error';
      notifyListeners();
      return;
    } catch (error) {
      _errorMessage = 'Desktop companion message handling failed: $error';
      notifyListeners();
      return;
    }
  }

  Future<void> _handleCommand(Map<String, Object?> message) async {
    final id = message['id']?.toString() ?? '';
    final command = message['command']?.toString() ?? '';
    final payload = message['payload'] is Map
        ? (message['payload'] as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : const <String, Object?>{};
    try {
      final response = await _dispatchCommand(command, payload);
      _socket?.add(
        jsonEncode(<String, Object?>{
          'type': 'result',
          'id': id,
          'ok': true,
          'payload': response,
        }),
      );
    } catch (error) {
      _socket?.add(
        jsonEncode(<String, Object?>{
          'type': 'result',
          'id': id,
          'ok': false,
          'error': '$error',
        }),
      );
    }
  }

  Future<Map<String, Object?>> _dispatchCommand(
    String command,
    Map<String, Object?> payload,
  ) async {
    if (_paused && command != 'getStatus' && command != 'pauseControl') {
      throw Exception('Desktop companion is paused locally.');
    }
    switch (command) {
      case 'getStatus':
        return _actions.getStatus(
          label: _label,
          paused: _paused,
          activeDisplayId: _activeDisplayId,
        );
      case 'captureFrame':
        return _actions.captureFrame(activeDisplayId: _activeDisplayId);
      case 'observe':
        return _actions.observe(
          includeTree: payload['includeTree'] == true,
          activeDisplayId: _activeDisplayId,
        );
      case 'click':
        return _actions.click(
          x: (payload['x'] as num?)?.round() ?? 0,
          y: (payload['y'] as num?)?.round() ?? 0,
          button: payload['button']?.toString() ?? 'left',
        );
      case 'drag':
        return _actions.drag(
          x1: (payload['x1'] as num?)?.round() ?? 0,
          y1: (payload['y1'] as num?)?.round() ?? 0,
          x2: (payload['x2'] as num?)?.round() ?? 0,
          y2: (payload['y2'] as num?)?.round() ?? 0,
          durationMs: (payload['durationMs'] as num?)?.round() ?? 280,
        );
      case 'scroll':
        return _actions.scroll(
          deltaX: (payload['deltaX'] as num?)?.round() ?? 0,
          deltaY: (payload['deltaY'] as num?)?.round() ?? 0,
        );
      case 'typeText':
        return _actions.typeText(
          text: payload['text']?.toString() ?? '',
          pressEnter: payload['pressEnter'] == true,
        );
      case 'pressKey':
        return _actions.pressKey(key: payload['key']?.toString() ?? '');
      case 'launchApp':
        return _actions.launchApp(app: payload['app']?.toString() ?? '');
      case 'listDisplays':
        final status = await _actions.getStatus(
          label: _label,
          paused: _paused,
          activeDisplayId: _activeDisplayId,
        );
        return <String, Object?>{
          'displays': status['displays'] ?? const <Map<String, Object?>>[],
          'activeDisplayId': status['activeDisplayId'] ?? 'primary',
        };
      case 'selectDisplay':
        final displayId = payload['displayId']?.toString() ?? 'primary';
        _activeDisplayId = displayId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(desktopCompanionActiveDisplayPrefsKey, displayId);
        _status = <String, Object?>{..._status, 'activeDisplayId': displayId};
        // TODO: Apply platform-specific active display switching when available.
        notifyListeners();
        return <String, Object?>{'success': true, 'activeDisplayId': displayId};
      case 'getTree':
        return _actions.getTree();
      case 'pauseControl':
        final paused = payload['paused'] != false;
        _paused = paused;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(desktopCompanionPausedPrefsKey, paused);
        notifyListeners();
        return <String, Object?>{'success': true, 'paused': _paused};
      case 'ping':
        return <String, Object?>{'pong': true};
      default:
        throw Exception('Unsupported desktop companion command: $command');
    }
  }

  void _handleSocketClosed() {
    _socket = null;
    _connecting = false;
    _connected = false;
    notifyListeners();
    _scheduleReconnect();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connecting = false;
    _connected = false;
    _enabled = false;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        socket.close();
      } catch (_) {}
    }
    super.dispose();
  }

  void _scheduleReconnect() {
    if (!_enabled || !_authenticated || _sessionCookie.isEmpty) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      unawaited(_ensureConnected());
    });
  }

  Future<void> _sendEvent(String event, Map<String, Object?> payload) async {
    final socket = _socket;
    if (socket == null || !_connected) return;
    socket.add(
      jsonEncode(<String, Object?>{
        'type': 'event',
        'event': event,
        'payload': payload,
      }),
    );
  }

  Future<void> _openMacPermissionSettings(String key) async {
    final uri = switch (key) {
      'screencapture' =>
        'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture',
      'inputcontrol' || 'accessibility' =>
        'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility',
      _ => 'x-apple.systempreferences:com.apple.preference.security',
    };
    await _runCommand('open', <String>[uri]);
  }

  Future<void> _openWindowsPermissionSettings(String key) async {
    final uri = switch (key) {
      'screencapture' => 'ms-settings:privacy-screencapture',
      'inputcontrol' || 'accessibility' => 'ms-settings:easeofaccess-display',
      _ => 'ms-settings:privacy',
    };
    await _runCommand('cmd', <String>['/c', 'start', '', uri]);
  }

  Future<void> _openLinuxPermissionSettings(String key) async {
    final commands = key == 'screencapture'
        ? <_ShellCommand>[
            const _ShellCommand('gnome-control-center', <String>['privacy']),
            const _ShellCommand('kcmshell6', <String>['kcm_screenlocker']),
            const _ShellCommand('xdg-open', <String>['settings://privacy']),
          ]
        : <_ShellCommand>[
            const _ShellCommand('gnome-control-center', <String>[
              'universal-access',
            ]),
            const _ShellCommand('gnome-control-center', <String>['privacy']),
            const _ShellCommand('xdg-open', <String>['settings://']),
          ];
    Object? lastError;
    for (final command in commands) {
      try {
        await _runCommand(command.command, command.args);
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw Exception(
      'Could not open Linux settings automatically.${lastError != null ? ' $lastError' : ''}',
    );
  }

  Future<void> _runCommand(String command, List<String> args) async {
    final result = await Process.run(command, args);
    if (result.exitCode != 0) {
      final stderr = result.stderr?.toString().trim();
      final stdout = result.stdout?.toString().trim();
      final details = stderr?.isNotEmpty == true
          ? stderr
          : (stdout?.isNotEmpty == true ? stdout : 'unknown error');
      throw Exception('Command failed ($command): $details');
    }
  }
}

Uri _desktopWsUri(String backendUrl) {
  final base = Uri.parse(backendUrl);
  final scheme = base.scheme == 'https' ? 'wss' : 'ws';
  return base.replace(scheme: scheme, path: '/api/desktop/ws', query: '');
}

String _defaultLabel() {
  final host = Platform.localHostname.trim();
  if (host.isNotEmpty) return host;
  return '${defaultTargetPlatform.name} desktop';
}

String _randomId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

String _localHostname() {
  final host = Platform.localHostname.trim();
  if (host.isNotEmpty) {
    return host;
  }
  return defaultTargetPlatform.name;
}

class _ShellCommand {
  const _ShellCommand(this.command, this.args);

  final String command;
  final List<String> args;
}
