import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
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
const String localComputerPermissionsPrefsKey = 'computer.local.permissions';

class LocalComputerPermissionException implements Exception {
  const LocalComputerPermissionException(this.capability);

  final String capability;

  @override
  String toString() => 'Permission required: $capability';
}

class DesktopCompanionManager extends ChangeNotifier {
  DesktopCompanionManager({required DesktopScreenCapture screenCapture})
    : _actions = DesktopCompanionActions(screenCapture: screenCapture);

  final DesktopCompanionActions _actions;
  WebSocket? _socket;
  Timer? _reconnectTimer;
  Timer? _connectionWatchdogTimer;
  Timer? _helloTimer;
  Timer? _streamTimer;
  bool _streamCaptureInFlight = false;
  // Set true while a click / drag / scroll / typeText / pressKey command is
  // being executed.  _captureAndSendBinaryFrame respects this flag so it does
  // not compete with the input command for the native bridge or the WebSocket
  // send buffer, and a fresh frame is forced immediately after the action.
  bool _inputCommandInFlight = false;
  int _frameSeq = 0;
  int _streamGeneration = 0;
  // Tracks the current stream quality so the forced post-input capture can use
  // the same setting without re-parsing the original startStream payload.
  int _currentStreamQuality = 80;
  Future<void> _inputCommandQueue = Future<void>.value();
  final Set<String> _pendingCommandIds = <String>{};
  final Set<String> _pendingShellCommandIds = <String>{};
  final Set<String> _cancelledCommandIds = <String>{};
  final Map<String, HttpClientRequest> _outputUploadRequests =
      <String, HttpClientRequest>{};
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;
  bool _disposed = false;

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
  final Set<String> _persistentPermissions = <String>{};
  final Set<String> _sessionPermissions = <String>{};
  String? _pendingPermission;

  bool get supported =>
      !kIsWeb &&
      <TargetPlatform>{
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);
  bool get enabled => _enabled;
  bool get paused => _paused;
  bool get connecting => _connecting;
  bool get connected => _connected;
  String? get errorMessage => _errorMessage;
  String get label => _label;
  String get deviceId => _deviceId;
  String get activationId => _activationId;
  Map<String, Object?> get status => _status;
  String? get pendingPermission => _pendingPermission;
  Set<String> get grantedPermissions => <String>{
    ..._persistentPermissions,
    ..._sessionPermissions,
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> bootstrap(SharedPreferences prefs) async {
    _enabled = prefs.getBool(desktopCompanionEnabledPrefsKey) ?? false;
    // Always start unpaused — paused state must not carry over across restarts.
    _paused = false;
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
    _persistentPermissions
      ..clear()
      ..addAll(
        (prefs.getStringList(localComputerPermissionsPrefsKey) ??
                const <String>[])
            .where(_isKnownPermission),
      );
  }

  bool _isKnownPermission(String value) =>
      const <String>{'screen', 'input', 'files', 'shell'}.contains(value);

  Future<void> grantPermission(
    String capability,
    SharedPreferences prefs, {
    required bool remember,
  }) async {
    final normalized = capability.trim().toLowerCase();
    if (!_isKnownPermission(normalized)) {
      throw ArgumentError.value(
        capability,
        'capability',
        'Unknown local computer permission.',
      );
    }
    if (remember) {
      _persistentPermissions.add(normalized);
      _sessionPermissions.remove(normalized);
      await prefs.setStringList(
        localComputerPermissionsPrefsKey,
        _persistentPermissions.toList(growable: false)..sort(),
      );
    } else {
      _sessionPermissions.add(normalized);
    }
    if (_pendingPermission == normalized) _pendingPermission = null;
    await _publishPermissionState();
  }

  Future<void> denyPermission(String capability) async {
    final normalized = capability.trim().toLowerCase();
    _sessionPermissions.remove(normalized);
    if (_pendingPermission == normalized) _pendingPermission = null;
    await _publishPermissionState();
  }

  Future<void> revokePermission(
    String capability,
    SharedPreferences prefs,
  ) async {
    final normalized = capability.trim().toLowerCase();
    _sessionPermissions.remove(normalized);
    _persistentPermissions.remove(normalized);
    await prefs.setStringList(
      localComputerPermissionsPrefsKey,
      _persistentPermissions.toList(growable: false)..sort(),
    );
    await _publishPermissionState();
  }

  Future<void> _publishPermissionState() async {
    _status = <String, Object?>{
      ..._status,
      'appApprovals': _approvalSnapshot(),
      'pendingPermission': _pendingPermission,
    };
    _notify();
    if (_connected) {
      await _sendEvent('permissionsChanged', <String, Object?>{
        'permissions': <String, Object?>{
          ...(_status['permissions'] is Map
              ? Map<String, Object?>.from(_status['permissions'] as Map)
              : const <String, Object?>{}),
          'appApprovals': _approvalSnapshot(),
        },
        'metadata': <String, Object?>{'pendingPermission': _pendingPermission},
      });
    }
  }

  Map<String, Object?> _approvalSnapshot() => <String, Object?>{
    for (final capability in const <String>[
      'screen',
      'input',
      'files',
      'shell',
    ])
      capability: _persistentPermissions.contains(capability)
          ? 'always'
          : (_sessionPermissions.contains(capability) ? 'once' : 'denied'),
  };

  Future<void> updateSession({
    required String backendUrl,
    required String sessionCookie,
    required bool authenticated,
  }) async {
    final nextBackendUrl = backendUrl.trim();
    final nextSessionCookie = sessionCookie.trim();
    final sessionChanged =
        _backendUrl != nextBackendUrl || _sessionCookie != nextSessionCookie;
    _backendUrl = nextBackendUrl;
    _sessionCookie = nextSessionCookie;
    _authenticated = authenticated;
    if (!_authenticated || !_enabled || _sessionCookie.isEmpty) {
      await disconnect();
      return;
    }
    if (sessionChanged && (_connected || _connecting || _socket != null)) {
      await disconnect();
    }
    _ensureConnectionWatchdog();
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
    _notify();
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
    _notify();
    if (_connected) {
      _status = {..._status, 'label': normalized};
      await _sendEvent('statusChanged', <String, Object?>{'label': normalized});
    }
  }

  Future<void> setPaused(bool value, SharedPreferences prefs) async {
    _paused = value;
    _notify();
    if (_connected) {
      await _sendEvent('statusChanged', <String, Object?>{'paused': value});
    }
  }

  Future<void> disconnect() async {
    _connectionGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectionWatchdogTimer?.cancel();
    _connectionWatchdogTimer = null;
    _helloTimer?.cancel();
    _helloTimer = null;
    _stopStreaming();
    _connecting = false;
    _connected = false;
    _sessionPermissions.clear();
    _pendingPermission = null;
    _status = <String, Object?>{
      ..._status,
      'appApprovals': _approvalSnapshot(),
      'pendingPermission': null,
    };
    _cancelPendingCommands();
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await _closeSocket(socket);
    }
    _notify();
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
      'appApprovals': _approvalSnapshot(),
      'pendingPermission': _pendingPermission,
    };
    _notify();
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
    if (_disposed || !_enabled || !_authenticated || _sessionCookie.isEmpty) {
      return;
    }
    if (_connecting || _connected) return;
    final generation = ++_connectionGeneration;
    _connecting = true;
    _errorMessage = null;
    _notify();
    WebSocket? connectedSocket;
    try {
      final uri = _desktopWsUri(_backendUrl);
      final socket = await _openWebSocket(uri);
      connectedSocket = socket;
      if (_disposed || generation != _connectionGeneration) {
        await _closeSocket(socket);
        return;
      }
      socket.pingInterval = const Duration(seconds: 25);
      _socket = socket;
      socket.listen(
        (dynamic raw) => _handleMessage(socket, generation, raw),
        onDone: () => _handleSocketClosed(socket, generation),
        onError: (Object error, StackTrace stackTrace) {
          if (_socket == socket && generation == _connectionGeneration) {
            _errorMessage = '$error';
          }
          _handleSocketClosed(socket, generation);
        },
        cancelOnError: true,
      );
      final hello = await _actions
          .buildHello(
            deviceId: _deviceId,
            activationId: _activationId,
            label: _label,
            companionEnabled: _enabled,
            paused: _paused,
            activeDisplayId: _activeDisplayId,
          )
          .timeout(const Duration(seconds: 10));
      hello['permissions'] = <String, Object?>{
        ...(hello['permissions'] is Map
            ? Map<String, Object?>.from(hello['permissions'] as Map)
            : const <String, Object?>{}),
        'appApprovals': _approvalSnapshot(),
      };
      hello['metadata'] = <String, Object?>{
        ...(hello['metadata'] is Map
            ? Map<String, Object?>.from(hello['metadata'] as Map)
            : const <String, Object?>{}),
        'pendingPermission': _pendingPermission,
      };
      if (_socket != socket || generation != _connectionGeneration) return;
      socket.add(
        jsonEncode(<String, Object?>{'type': 'hello', 'device': hello}),
      );
      _helloTimer?.cancel();
      _helloTimer = Timer(const Duration(seconds: 10), () {
        if (_socket != socket ||
            generation != _connectionGeneration ||
            _connected) {
          return;
        }
        _errorMessage = 'Desktop companion handshake timed out.';
        _handleSocketClosed(socket, generation);
      });
    } catch (error) {
      if (connectedSocket != null && connectedSocket == _socket) {
        _socket = null;
        unawaited(_closeSocket(connectedSocket));
      }
      if (_disposed || generation != _connectionGeneration) return;
      _connecting = false;
      _connected = false;
      _errorMessage = '$error';
      _notify();
      _scheduleReconnect();
    }
  }

  Future<WebSocket> _openWebSocket(Uri uri) async {
    final pending = WebSocket.connect(
      uri.toString(),
      headers: <String, Object>{'Cookie': _sessionCookie},
    );
    try {
      return await pending.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      unawaited(() async {
        try {
          final lateSocket = await pending;
          await _closeSocket(lateSocket);
        } catch (_) {}
      }());
      throw TimeoutException(
        'Desktop companion connection timed out.',
        const Duration(seconds: 15),
      );
    }
  }

  Future<void> _closeSocket(WebSocket socket) async {
    try {
      await socket.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  void _handleMessage(WebSocket source, int generation, dynamic raw) {
    if (_socket != source || generation != _connectionGeneration) return;
    try {
      final message = jsonDecode(raw as String);
      if (message is! Map) return;
      final type = message['type']?.toString() ?? '';
      if (type == 'hello') {
        _helloTimer?.cancel();
        _helloTimer = null;
        _connecting = false;
        final ok = message['ok'] == true;
        if (!ok) {
          _connected = false;
          _errorMessage =
              message['error']?.toString() ?? 'Desktop companion rejected.';
          _notify();
          _handleSocketClosed(source, generation);
          return;
        }
        _connected = true;
        _reconnectAttempt = 0;
        _errorMessage = null;
        final device = message['device'];
        _status = device is Map
            ? device.map((key, value) => MapEntry(key.toString(), value))
            : const <String, Object?>{};
        _activeDisplayId =
            _status['activeDisplayId']?.toString() ?? _activeDisplayId;
        _notify();
        return;
      }
      if (type != 'command') return;
      final commandMessage = message.cast<String, Object?>();
      final command = commandMessage['command']?.toString() ?? '';
      final commandId = commandMessage['id']?.toString() ?? '';
      if (command != 'cancelCommand' && commandId.isNotEmpty) {
        _pendingCommandIds.add(commandId);
        if (command == 'executeCommand') {
          _pendingShellCommandIds.add(commandId);
        }
      }
      if (_inputCommands.contains(command)) {
        final previous = _inputCommandQueue;
        _inputCommandQueue = () async {
          try {
            await previous;
          } catch (_) {}
          await _handleCommand(commandMessage, source, generation);
        }();
      } else {
        unawaited(_handleCommand(commandMessage, source, generation));
      }
    } on FormatException catch (error) {
      _errorMessage = 'Ignored malformed desktop companion message: $error';
      _notify();
      return;
    } catch (error) {
      _errorMessage = 'Desktop companion message handling failed: $error';
      _notify();
      return;
    }
  }

  // Commands that interact with the remote machine's input system.  While one
  // of these is executing we pause frame captures so the WebSocket send buffer
  // is clear for the result message, and to avoid the native bridge being busy
  // with a screenshot when the click/drag/etc. needs to run.
  static const _inputCommands = <String>{
    'click',
    'mouseMove',
    'drag',
    'scroll',
    'typeText',
    'pressKey',
  };

  Future<void> _handleCommand(
    Map<String, Object?> message,
    WebSocket source,
    int generation,
  ) async {
    final id = message['id']?.toString() ?? '';
    final command = message['command']?.toString() ?? '';
    final payload = message['payload'] is Map
        ? (message['payload'] as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : const <String, Object?>{};

    if (_socket != source || generation != _connectionGeneration) {
      _pendingCommandIds.remove(id);
      _pendingShellCommandIds.remove(id);
      _cancelledCommandIds.remove(id);
      return;
    }

    final isInput = _inputCommands.contains(command);
    if (isInput) _inputCommandInFlight = true;

    try {
      if (command != 'cancelCommand' && _cancelledCommandIds.contains(id)) {
        _sendCommandResult(source, generation, <String, Object?>{
          'type': 'result',
          'id': id,
          'ok': false,
          'code': 'COMMAND_CANCELLED',
          'error': 'Desktop companion command was cancelled.',
        });
        return;
      }
      final requiredPermission = _permissionForCommand(command);
      if (requiredPermission != null &&
          !grantedPermissions.contains(requiredPermission)) {
        _pendingPermission = requiredPermission;
        await _publishPermissionState();
        throw LocalComputerPermissionException(requiredPermission);
      }
      var response = await _dispatchCommand(command, payload, commandId: id);
      if (command != 'cancelCommand' && _cancelledCommandIds.contains(id)) {
        await _discardCommandOutput(response);
        _sendCommandResult(source, generation, <String, Object?>{
          'type': 'result',
          'id': id,
          'ok': false,
          'code': 'COMMAND_CANCELLED',
          'error': 'Desktop companion command was cancelled.',
        });
        return;
      }
      if (command == 'executeCommand') {
        response = await _uploadCommandOutput(id, response);
      }
      if (command != 'cancelCommand' && _cancelledCommandIds.contains(id)) {
        _sendCommandResult(source, generation, <String, Object?>{
          'type': 'result',
          'id': id,
          'ok': false,
          'code': 'COMMAND_CANCELLED',
          'error': 'Desktop companion command was cancelled.',
        });
        return;
      }
      _sendCommandResult(source, generation, <String, Object?>{
        'type': 'result',
        'id': id,
        'ok': true,
        'payload': response,
      });
      // Immediately capture a fresh frame after an input action so the user
      // sees the result of their interaction without waiting for the next
      // timer tick.
      if (isInput &&
          _streamTimer != null &&
          _connected &&
          _socket == source &&
          generation == _connectionGeneration) {
        unawaited(
          _captureAndSendBinaryFrame(
            _currentStreamQuality,
            _streamGeneration,
            forced: true,
          ),
        );
      }
    } catch (error) {
      _sendCommandResult(source, generation, <String, Object?>{
        'type': 'result',
        'id': id,
        'ok': false,
        if (error is LocalComputerPermissionException)
          'code': 'LOCAL_COMPUTER_PERMISSION_REQUIRED',
        'error': '$error',
      });
    } finally {
      if (isInput) _inputCommandInFlight = false;
      _pendingCommandIds.remove(id);
      _pendingShellCommandIds.remove(id);
      _cancelledCommandIds.remove(id);
    }
  }

  String? _permissionForCommand(String command) {
    if (<String>{'captureFrame', 'startStream', 'observe'}.contains(command)) {
      return 'screen';
    }
    if (_inputCommands.contains(command)) {
      return 'input';
    }
    if (<String>{
      'listFiles',
      'readFile',
      'writeFile',
      'searchFiles',
    }.contains(command)) {
      return 'files';
    }
    if (<String>{'executeCommand', 'launchApp', 'openUri'}.contains(command)) {
      return 'shell';
    }
    return null;
  }

  void _sendCommandResult(
    WebSocket source,
    int generation,
    Map<String, Object?> message,
  ) {
    if (_socket != source || generation != _connectionGeneration) return;
    try {
      source.add(jsonEncode(message));
    } catch (error) {
      _errorMessage = 'Desktop companion response failed: $error';
      _handleSocketClosed(source, generation);
    }
  }

  Future<Map<String, Object?>> _uploadCommandOutput(
    String commandId,
    Map<String, Object?> response,
  ) async {
    final path = response['_outputFilePath']?.toString() ?? '';
    final sanitized = <String, Object?>{...response}
      ..remove('_outputFilePath')
      ..remove('_outputFileByteSize')
      ..remove('_outputFileComplete');
    if (path.isEmpty) return sanitized;

    final file = File(path);
    final client = HttpClient();
    try {
      final byteSize = await file.length();
      final checksum = await sha256.bind(file.openRead()).first;
      final request = await client.postUrl(
        _desktopCommandOutputUri(_backendUrl),
      );
      _outputUploadRequests[commandId] = request;
      request.headers
        ..set(HttpHeaders.cookieHeader, _sessionCookie)
        ..set(HttpHeaders.contentTypeHeader, 'application/octet-stream')
        ..set('x-neoagent-device-id', _deviceId)
        ..set('x-neoagent-command-id', commandId)
        ..set('x-neoagent-output-sha256', checksum.toString())
        ..set(
          'x-neoagent-output-complete',
          response['_outputFileComplete'] == false ? 'false' : 'true',
        )
        ..set('x-neoagent-stdout-bytes', '${response['stdoutBytes'] ?? 0}')
        ..set('x-neoagent-stderr-bytes', '${response['stderrBytes'] ?? 0}');
      request.contentLength = byteSize;
      await request.addStream(file.openRead());
      final uploadResponse = await request.close();
      final responseText = await utf8.decoder.bind(uploadResponse).join();
      if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
        throw HttpException(
          'Command output upload failed (${uploadResponse.statusCode}): $responseText',
        );
      }
      final decoded = jsonDecode(responseText);
      final outputArtifact = decoded is Map ? decoded['outputArtifact'] : null;
      if (outputArtifact is! Map) {
        throw const FormatException(
          'Command output upload omitted artifact metadata.',
        );
      }
      return <String, Object?>{
        ...sanitized,
        'outputArtifact': outputArtifact.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      };
    } catch (error) {
      return <String, Object?>{...sanitized, 'artifactError': '$error'};
    } finally {
      _outputUploadRequests.remove(commandId);
      client.close(force: true);
      await _discardCommandOutput(response);
    }
  }

  Future<void> _discardCommandOutput(Map<String, Object?> response) async {
    final path = response['_outputFilePath']?.toString() ?? '';
    if (path.isEmpty) return;
    final directory = File(path).parent;
    final tempRoot = Directory.systemTemp.absolute.path;
    if (!directory.absolute.path.startsWith(
          '$tempRoot${Platform.pathSeparator}',
        ) ||
        !directory.path
            .split(Platform.pathSeparator)
            .last
            .startsWith('neoagent-command-output-')) {
      return;
    }
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {}
  }

  void _abortOutputUpload(String commandId) {
    _outputUploadRequests[commandId]?.abort(
      const HttpException('Desktop command output upload cancelled.'),
    );
  }

  Future<Map<String, Object?>> _dispatchCommand(
    String command,
    Map<String, Object?> payload, {
    required String commandId,
  }) async {
    if (_paused &&
        command != 'getStatus' &&
        command != 'pauseControl' &&
        command != 'cancelCommand') {
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
      case 'startStream':
        return _startStreaming(payload);
      case 'stopStream':
        return _stopStreaming();
      case 'observe':
        return _actions.observe(
          includeTree: payload['includeTree'] == true,
          activeDisplayId: _activeDisplayId,
        );
      case 'click':
        return _actions.click(
          x: _requiredCoordinate(payload, 'x'),
          y: _requiredCoordinate(payload, 'y'),
          button: payload['button']?.toString() ?? 'left',
          displayId: _activeDisplayId,
        );
      case 'mouseMove':
        return _actions.mouseMove(
          x: _requiredCoordinate(payload, 'x'),
          y: _requiredCoordinate(payload, 'y'),
          displayId: _activeDisplayId,
        );
      case 'drag':
        return _actions.drag(
          x1: _requiredCoordinate(payload, 'x1'),
          y1: _requiredCoordinate(payload, 'y1'),
          x2: _requiredCoordinate(payload, 'x2'),
          y2: _requiredCoordinate(payload, 'y2'),
          durationMs: (payload['durationMs'] as num?)?.round() ?? 280,
          displayId: _activeDisplayId,
        );
      case 'scroll':
        return _actions.scroll(
          deltaX: (payload['deltaX'] as num?)?.round() ?? 0,
          deltaY: (payload['deltaY'] as num?)?.round() ?? 0,
          displayId: _activeDisplayId,
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
      case 'openUri':
        return _actions.openUri(uri: payload['uri']?.toString() ?? '');
      case 'listFiles':
        return _actions.listFiles(path: payload['path']?.toString() ?? '.');
      case 'readFile':
        return _actions.readFile(
          path: payload['path']?.toString() ?? '',
          base64: payload['encoding'] == 'base64',
        );
      case 'writeFile':
        return _actions.writeFile(
          path: payload['path']?.toString() ?? '',
          content: payload['content']?.toString() ?? '',
        );
      case 'searchFiles':
        return _actions.searchFiles(
          path: payload['path']?.toString() ?? '.',
          query: payload['query']?.toString() ?? '',
          pattern: payload['glob']?.toString() ?? '',
          maxResults: (payload['maxResults'] as num?)?.round() ?? 100,
        );
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
        final displayId = await _resolveDisplaySelection(
          payload['displayId']?.toString() ?? '',
        );
        final prefs = await SharedPreferences.getInstance();
        final persisted = await prefs.setString(
          desktopCompanionActiveDisplayPrefsKey,
          displayId,
        );
        if (!persisted) {
          throw StateError('Unable to persist the selected desktop display.');
        }
        _activeDisplayId = displayId;
        _status = <String, Object?>{..._status, 'activeDisplayId': displayId};
        _notify();
        return <String, Object?>{'success': true, 'activeDisplayId': displayId};
      case 'getTree':
        return _actions.getTree();
      case 'pauseControl':
        final paused = payload['paused'] != false;
        _paused = paused;
        _notify();
        return <String, Object?>{'success': true, 'paused': _paused};
      case 'executeCommand':
        return _actions.executeShellCommand(
          commandId: commandId,
          command: payload['command']?.toString() ?? '',
          cwd: payload['cwd']?.toString(),
          timeoutMs: (payload['timeout'] as num?)?.toInt(),
          stdinInput: payload['stdin_input']?.toString(),
          requestedPty: payload['pty'] == true,
          inputs: payload['inputs'] is List
              ? (payload['inputs'] as List)
                    .map((value) => value.toString())
                    .toList(growable: false)
              : const <String>[],
        );
      case 'cancelCommand':
        final targetId = payload['commandId']?.toString() ?? '';
        if (targetId.isNotEmpty && _pendingCommandIds.contains(targetId)) {
          _cancelledCommandIds.add(targetId);
        }
        if (_pendingShellCommandIds.contains(targetId)) {
          _abortOutputUpload(targetId);
          return _actions.cancelShellCommand(targetId);
        }
        return <String, Object?>{
          'success': targetId.isNotEmpty,
          'cancelled': _cancelledCommandIds.contains(targetId),
        };
      case 'ping':
        return <String, Object?>{'pong': true};
      default:
        throw Exception('Unsupported desktop companion command: $command');
    }
  }

  int _requiredCoordinate(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! num || !value.isFinite) {
      throw FormatException('$key must be a finite number.');
    }
    return value.round();
  }

  void _handleSocketClosed(WebSocket source, int generation) {
    if (_socket != source || generation != _connectionGeneration) return;
    _connectionGeneration++;
    _helloTimer?.cancel();
    _helloTimer = null;
    _stopStreaming();
    _socket = null;
    _connecting = false;
    _connected = false;
    _cancelPendingCommands();
    unawaited(_closeSocket(source));
    if (_disposed) return;
    _notify();
    _scheduleReconnect();
  }

  void _cancelPendingCommands() {
    for (final commandId in _pendingCommandIds.toList(growable: false)) {
      _cancelledCommandIds.add(commandId);
      if (_pendingShellCommandIds.contains(commandId)) {
        _abortOutputUpload(commandId);
        unawaited(_actions.cancelShellCommand(commandId));
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _connectionGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectionWatchdogTimer?.cancel();
    _connectionWatchdogTimer = null;
    _helloTimer?.cancel();
    _helloTimer = null;
    _stopStreaming();
    _connecting = false;
    _connected = false;
    _enabled = false;
    _cancelPendingCommands();
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      unawaited(_closeSocket(socket));
    }
    super.dispose();
  }

  void _scheduleReconnect() {
    if (_disposed || !_enabled || !_authenticated || _sessionCookie.isEmpty) {
      return;
    }
    _ensureConnectionWatchdog();
    _reconnectTimer?.cancel();
    final exponentialMs = min(60000, 1000 * (1 << min(_reconnectAttempt, 6)));
    _reconnectAttempt++;
    final jitterMs = Random().nextInt(max(1, exponentialMs ~/ 4));
    _reconnectTimer = Timer(
      Duration(milliseconds: exponentialMs + jitterMs),
      () {
        unawaited(_ensureConnected());
      },
    );
  }

  void _ensureConnectionWatchdog() {
    if (_disposed || !_enabled || !_authenticated || _sessionCookie.isEmpty) {
      return;
    }
    if (_connectionWatchdogTimer != null) return;
    _connectionWatchdogTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_disposed || !_enabled || !_authenticated || _sessionCookie.isEmpty) {
        _connectionWatchdogTimer?.cancel();
        _connectionWatchdogTimer = null;
        return;
      }
      if (!_connected && !_connecting) {
        unawaited(_ensureConnected());
      }
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

  Future<Map<String, Object?>> _startStreaming(
    Map<String, Object?> payload,
  ) async {
    final fps = ((payload['fps'] as num?)?.round() ?? 15).clamp(1, 20);
    final quality = ((payload['quality'] as num?)?.round() ?? 80).clamp(30, 95);
    final displayId = payload['displayId']?.toString().trim();
    var selectedDisplayId = _activeDisplayId;
    if (displayId != null && displayId.isNotEmpty) {
      selectedDisplayId = await _resolveDisplaySelection(displayId);
    }
    _streamTimer?.cancel();
    final generation = ++_streamGeneration;
    _activeDisplayId = selectedDisplayId;
    final interval = Duration(milliseconds: max(1, (1000 / fps).floor()));
    _frameSeq = 0;
    _currentStreamQuality = quality;
    _streamTimer = Timer.periodic(interval, (_) {
      unawaited(_captureAndSendBinaryFrame(quality, generation));
    });
    unawaited(_captureAndSendBinaryFrame(quality, generation));
    return <String, Object?>{
      'success': true,
      'fps': fps,
      'quality': quality,
      'displayId': _activeDisplayId,
    };
  }

  Future<String> _resolveDisplaySelection(String requested) async {
    final status = await _actions.getStatus(
      label: _label,
      paused: _paused,
      activeDisplayId: _activeDisplayId,
    );
    return resolveDesktopDisplaySelection(
      status['displays'],
      requested,
      activeDisplayId: status['activeDisplayId']?.toString(),
    );
  }

  Map<String, Object?> _stopStreaming() {
    _streamTimer?.cancel();
    _streamTimer = null;
    _streamGeneration++;
    _streamCaptureInFlight = false;
    return <String, Object?>{'success': true};
  }

  Future<void> _captureAndSendBinaryFrame(
    int quality,
    int generation, {
    bool forced = false,
  }) async {
    final socket = _socket;
    if (socket == null ||
        !_connected ||
        _streamCaptureInFlight ||
        generation != _streamGeneration) {
      return;
    }
    // If an input command is actively running, skip this frame unless we were
    // explicitly forced (i.e. this IS the post-input refresh capture).
    if (!forced && _inputCommandInFlight) return;
    _streamCaptureInFlight = true;
    try {
      final snapshot = await _actions.captureSnapshot(
        activeDisplayId: _activeDisplayId,
      );
      if (snapshot == null) return;
      final jpeg = await _actions.compressToJpeg(snapshot, quality);
      if (jpeg.isEmpty) return;
      if (!_connected || generation != _streamGeneration || _socket != socket) {
        return;
      }
      final frame = Uint8List(10 + jpeg.length);
      final header = ByteData.sublistView(frame, 0, 10);
      header.setUint8(0, 0x01);
      header.setUint32(1, _frameSeq++ & 0xffffffff, Endian.big);
      header.setUint32(
        5,
        DateTime.now().millisecondsSinceEpoch & 0xffffffff,
        Endian.big,
      );
      header.setUint8(9, 0x01);
      frame.setRange(10, frame.length, jpeg);
      socket.add(frame);
    } catch (error) {
      _errorMessage = 'Desktop stream capture failed: $error';
      _notify();
    } finally {
      _streamCaptureInFlight = false;
    }
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
  final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
  return base.replace(
    scheme: scheme,
    path: '$basePath/api/computer/local/ws',
    query: '',
    fragment: '',
  );
}

Uri _desktopCommandOutputUri(String backendUrl) {
  final base = Uri.parse(backendUrl);
  final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
  return base.replace(
    path: '$basePath/api/computer/local/command-output',
    query: '',
    fragment: '',
  );
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
