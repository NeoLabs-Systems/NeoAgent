import 'dart:async';
import 'dart:io';

import 'package:desktop_audio_capture/audio_capture.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'diagnostics_logger.dart';
import 'recording_bridge.dart';

RecordingBridge createPlatformRecordingBridge() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidRecordingBridge();
  }
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    return DesktopRecordingBridge();
  }
  return UnsupportedIoRecordingBridge();
}

class UnsupportedIoRecordingBridge extends RecordingBridge {
  RecordingRuntimeStatus _status = const RecordingRuntimeStatus(
    supportsScreenAndMic: false,
    supportsBackgroundMic: false,
    platformLabel: 'Unsupported',
  );

  @override
  RecordingRuntimeStatus get status => _status;

  @override
  Future<void> refreshStatus() async {}

  @override
  Future<void> startWebRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Screen and microphone recording is available on web only.',
    );
  }

  @override
  Future<void> startWebMicrophoneRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Microphone-only browser recording is available on web only.',
    );
  }

  @override
  Future<void> startBackgroundRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Background microphone recording is not supported on this platform.',
    );
  }

  @override
  Future<void> startDesktopAudioRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
    bool autoShowToolbar = true,
  }) async {
    throw const RecordingBridgeException(
      'Desktop recording is not supported on this platform.',
    );
  }

  @override
  Future<void> pauseBackgroundRecording() async {
    throw const RecordingBridgeException(
      'Recording is not supported on this platform.',
    );
  }

  @override
  Future<void> resumeBackgroundRecording() async {
    throw const RecordingBridgeException(
      'Recording is not supported on this platform.',
    );
  }

  @override
  Future<void> pauseDesktopRecording() async {
    throw const RecordingBridgeException(
      'Recording is not supported on this platform.',
    );
  }

  @override
  Future<void> resumeDesktopRecording() async {
    throw const RecordingBridgeException(
      'Recording is not supported on this platform.',
    );
  }

  @override
  Future<void> showFloatingToolbar() async {}

  @override
  Future<void> hideFloatingToolbar() async {}

  @override
  Future<void> openMicrophoneSettings() async {
    throw const RecordingBridgeException(
      'Microphone settings are not supported on this platform.',
    );
  }

  @override
  Future<void> openSystemAudioSettings() async {
    throw const RecordingBridgeException(
      'System audio settings are not supported on this platform.',
    );
  }

  @override
  Future<void> stopActiveRecording({bool notifyEnded = false}) async {
    _status = _status.copyWith(
      active: false,
      paused: false,
      sessionId: null,
      errorMessage: null,
      floatingToolbarVisible: false,
    );
    notifyListeners();
  }
}

class AndroidRecordingBridge extends RecordingBridge {
  static const MethodChannel _channel = MethodChannel('neoagent/recordings');

  RecordingRuntimeStatus _status = RecordingRuntimeStatus(
    supportsScreenAndMic: false,
    supportsBackgroundMic: true,
    platformLabel: 'Android background recorder',
    backgroundRuntimeActive: true,
  );

  @override
  RecordingRuntimeStatus get status => _status;

  void _log(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppDiagnostics.log(
      'recording.bridge.android',
      event,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  Future<void> refreshStatus() async {
    _log('refresh_status.request');
    final result = await _channel.invokeMapMethod<String, dynamic>('status');
    _status = _status.copyWith(
      active: result?['active'] == true,
      paused: result?['paused'] == true,
      sessionId: result?['sessionId']?.toString(),
      errorMessage: result?['errorMessage']?.toString(),
      startedAt: _parseDate(result?['startedAt']),
      activeSources: result?['active'] == true
          ? const <String>['microphone']
          : const <String>[],
    );
    notifyListeners();
  }

  @override
  Future<void> startBackgroundRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
  }) async {
    _log('start_background.request', data: <String, Object?>{
      'sessionId': sessionId,
      'baseUrl': baseUrl,
      'hasSessionCookie': sessionCookie.isNotEmpty,
    });
    await _channel.invokeMethod('startBackgroundRecording', <String, dynamic>{
      'backendUrl': baseUrl,
      'sessionCookie': sessionCookie,
      'sessionId': sessionId,
    });
    await refreshStatus();
  }

  @override
  Future<void> pauseBackgroundRecording() async {
    await _channel.invokeMethod('pauseBackgroundRecording');
    await refreshStatus();
  }

  @override
  Future<void> resumeBackgroundRecording() async {
    await _channel.invokeMethod('resumeBackgroundRecording');
    await refreshStatus();
  }

  @override
  Future<void> stopActiveRecording({bool notifyEnded = false}) async {
    final sessionId = _status.sessionId;
    await _channel.invokeMethod('stopBackgroundRecording');
    await refreshStatus();
    if (notifyEnded && sessionId != null && onRecordingStopped != null) {
      await onRecordingStopped!(sessionId);
    }
  }

  @override
  Future<void> startDesktopAudioRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
    bool autoShowToolbar = true,
  }) async {
    throw const RecordingBridgeException(
      'Native desktop recording is not available on Android.',
    );
  }

  @override
  Future<void> pauseDesktopRecording() async {
    throw const RecordingBridgeException(
      'Desktop recording controls are not available on Android.',
    );
  }

  @override
  Future<void> resumeDesktopRecording() async {
    throw const RecordingBridgeException(
      'Desktop recording controls are not available on Android.',
    );
  }

  @override
  Future<void> showFloatingToolbar() async {}

  @override
  Future<void> hideFloatingToolbar() async {}

  @override
  Future<void> openMicrophoneSettings() async {
    throw const RecordingBridgeException(
      'Manage Android microphone permissions from system settings.',
    );
  }

  @override
  Future<void> openSystemAudioSettings() async {
    throw const RecordingBridgeException(
      'System audio capture settings are only available on desktop.',
    );
  }

  @override
  Future<void> startWebRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Screen and microphone recording is available on web only.',
    );
  }

  @override
  Future<void> startWebMicrophoneRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Microphone-only browser recording is available on web only.',
    );
  }

  DateTime? _parseDate(Object? raw) {
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw.toString());
  }
}

class DesktopRecordingBridge extends RecordingBridge {
  DesktopRecordingBridge()
    : _micCapture = MicAudioCapture(
        config: MicAudioConfig(
          sampleRate: _sampleRate,
          channels: _channels,
          bitDepth: 16,
          gainBoost: 1.4,
          inputVolume: 1.0,
        ),
      ),
      _systemCapture = SystemAudioCapture(
        config: SystemAudioConfig(
          sampleRate: _sampleRate,
          channels: _channels,
        ),
      );

  static const int _sampleRate = 16000;
  static const int _channels = 1;
  static const int _bytesPerSample = 2;
  static const int _chunkDurationMs = 4000;

  final MicAudioCapture _micCapture;
  final SystemAudioCapture _systemCapture;
  http.Client _httpClient = http.Client();

  RecordingRuntimeStatus _status = RecordingRuntimeStatus(
    supportsScreenAndMic: false,
    supportsBackgroundMic: false,
    supportsSystemAudio: true,
    supportsDesktopBackgroundRuntime: true,
    supportsFloatingToolbar: true,
    supportsGlobalHotkeys: true,
    platformLabel: _desktopPlatformLabel(),
    backgroundRuntimeActive: true,
  );

  final Map<String, List<int>> _pcmBuffers = <String, List<int>>{
    'microphone': <int>[],
    'system': <int>[],
  };
  final Map<String, int> _nextSequenceBySource = <String, int>{
    'microphone': 0,
    'system': 0,
  };
  final Map<String, int> _lastEndMsBySource = <String, int>{
    'microphone': 0,
    'system': 0,
  };
  final Map<String, Future<void>> _uploadQueueBySource = <String, Future<void>>{
    'microphone': Future<void>.value(),
    'system': Future<void>.value(),
  };
  final Map<String, int> _bytesPerSecondBySource = <String, int>{
    'microphone': _sampleRate * _channels * _bytesPerSample,
    'system': _sampleRate * _channels * _bytesPerSample,
  };

  StreamSubscription<Uint8List>? _micAudioSub;
  StreamSubscription<Uint8List>? _systemAudioSub;
  StreamSubscription<MicAudioStatus>? _micStatusSub;
  StreamSubscription<SystemAudioStatus>? _systemStatusSub;
  StreamSubscription<DecibelData>? _micLevelSub;
  StreamSubscription<DecibelData>? _systemLevelSub;

  String? _baseUrl;
  String? _sessionCookie;
  String? _sessionId;

  @override
  RecordingRuntimeStatus get status => _status;

  @override
  Future<void> refreshStatus() async {
    final availableInputDevices = await _loadInputDevices();
    final selectedInput = availableInputDevices.cast<RecordingInputDevice?>()
        .firstWhere(
          (device) => device?.isDefault == true,
          orElse: () => availableInputDevices.isEmpty
              ? null
              : availableInputDevices.first,
        );
    _status = _status.copyWith(
      availableInputDevices: availableInputDevices,
      selectedInputDeviceId: selectedInput?.id,
      selectedInputDeviceName: selectedInput?.name,
    );
    notifyListeners();
  }

  @override
  Future<void> startDesktopAudioRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
    bool autoShowToolbar = true,
  }) async {
    if (_status.active) {
      throw const RecordingBridgeException(
        'A desktop recording is already in progress.',
      );
    }

    _baseUrl = baseUrl;
    _sessionCookie = sessionCookie;
    _sessionId = sessionId;
    _resetBuffers();
    await refreshStatus();

    try {
      await _ensureDesktopPermissions();
      await _startStreams();
      _status = _status.copyWith(
        active: true,
        paused: false,
        sessionId: sessionId,
        startedAt: DateTime.now(),
        errorMessage: null,
        activeSources: const <String>['microphone', 'system'],
        floatingToolbarVisible: autoShowToolbar,
      );
      notifyListeners();
    } catch (error, stackTrace) {
      _log('start_desktop.failed', error: error, stackTrace: stackTrace);
      _status = _status.copyWith(
        active: false,
        paused: false,
        sessionId: null,
        startedAt: null,
        activeSources: const <String>[],
        errorMessage: error.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> pauseDesktopRecording() async {
    if (!_status.active || _status.paused) {
      return;
    }
    await _stopStreams(flushPending: true);
    await Future.wait(_uploadQueueBySource.values);
    _status = _status.copyWith(
      paused: true,
      activeSources: const <String>[],
      microphoneLevelDb: -120,
      systemAudioLevelDb: -120,
    );
    notifyListeners();
  }

  @override
  Future<void> resumeDesktopRecording() async {
    if (!_status.active || !_status.paused) {
      return;
    }
    await _ensureDesktopPermissions();
    await _startStreams();
    _status = _status.copyWith(
      paused: false,
      activeSources: const <String>['microphone', 'system'],
      errorMessage: null,
    );
    notifyListeners();
  }

  @override
  Future<void> showFloatingToolbar() async {
    _status = _status.copyWith(floatingToolbarVisible: true);
    notifyListeners();
  }

  @override
  Future<void> hideFloatingToolbar() async {
    _status = _status.copyWith(floatingToolbarVisible: false);
    notifyListeners();
  }

  @override
  Future<void> openMicrophoneSettings() async {
    await _openPlatformSettings(
      macUrl:
          'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone',
      windowsCommand: const <String>[
        'cmd',
        '/c',
        'start',
        'ms-settings:privacy-microphone',
      ],
      linuxCommands: const <List<String>>[
        <String>['xdg-open', 'settings://privacy'],
        <String>['gnome-control-center', 'privacy'],
        <String>['gnome-control-center', 'sound'],
        <String>['pavucontrol'],
      ],
      failureMessage: 'Could not open microphone settings.',
    );
  }

  @override
  Future<void> openSystemAudioSettings() async {
    await _openPlatformSettings(
      macUrl:
          'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture',
      windowsCommand: const <String>[
        'cmd',
        '/c',
        'start',
        'ms-settings:sound',
      ],
      linuxCommands: const <List<String>>[
        <String>['xdg-open', 'settings://sound'],
        <String>['gnome-control-center', 'sound'],
        <String>['pavucontrol'],
      ],
      failureMessage: 'Could not open system audio settings.',
    );
  }

  @override
  Future<void> stopActiveRecording({bool notifyEnded = false}) async {
    if (!_status.active) {
      return;
    }
    final sessionId = _sessionId;
    await _stopStreams(flushPending: true);
    await Future.wait(_uploadQueueBySource.values);
    _status = _status.copyWith(
      active: false,
      paused: false,
      sessionId: null,
      startedAt: null,
      activeSources: const <String>[],
      microphoneLevelDb: -120,
      systemAudioLevelDb: -120,
      floatingToolbarVisible: false,
    );
    notifyListeners();
    if (notifyEnded && sessionId != null && onRecordingStopped != null) {
      await onRecordingStopped!(sessionId);
    }
  }

  @override
  Future<void> pauseBackgroundRecording() async {
    throw const RecordingBridgeException(
      'Android background recording controls are not available on desktop.',
    );
  }

  @override
  Future<void> resumeBackgroundRecording() async {
    throw const RecordingBridgeException(
      'Android background recording controls are not available on desktop.',
    );
  }

  @override
  Future<void> startBackgroundRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Android background recording is not available on desktop.',
    );
  }

  @override
  Future<void> startWebRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Screen and microphone recording is available on web only.',
    );
  }

  @override
  Future<void> startWebMicrophoneRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Microphone-only browser recording is available on web only.',
    );
  }

  @override
  void dispose() {
    unawaited(_disposeDesktopBridge());
    super.dispose();
  }

  Future<void> _disposeDesktopBridge() async {
    try {
      await _stopStreams(
        flushPending: false,
      ).timeout(const Duration(seconds: 2));
    } on TimeoutException {
      _log('dispose.stop_streams.timeout');
    } catch (error, stackTrace) {
      _log('dispose.stop_streams.failed', error: error, stackTrace: stackTrace);
    }

    try {
      await _micCapture.stopCapture();
    } catch (_) {}
    try {
      await _systemCapture.stopCapture();
    } catch (_) {}

    _httpClient.close();
  }

  Future<void> _ensureDesktopPermissions() async {
    final micGranted = await _requestMicPermission();
    final systemGranted = await _requestSystemPermission();
    if (!micGranted || !systemGranted) {
      throw RecordingBridgeException(
        _permissionFailureMessage(
          micGranted: micGranted,
          systemGranted: systemGranted,
        ),
      );
    }
  }

  Future<bool> _requestMicPermission() async {
    try {
      final granted = await _micCapture.requestPermissions();
      _status = _status.copyWith(
        microphonePermission: granted
            ? RecordingPermissionState.granted
            : RecordingPermissionState.denied,
      );
      return granted;
    } catch (error) {
      _status = _status.copyWith(
        microphonePermission: _permissionStateFromError(error),
      );
      return false;
    }
  }

  Future<bool> _requestSystemPermission() async {
    try {
      final granted = await _systemCapture.requestPermissions();
      _status = _status.copyWith(
        systemAudioPermission: granted
            ? RecordingPermissionState.granted
            : RecordingPermissionState.denied,
      );
      return granted;
    } catch (error) {
      _status = _status.copyWith(
        systemAudioPermission: _permissionStateFromError(error),
      );
      return false;
    }
  }

  Future<List<RecordingInputDevice>> _loadInputDevices() async {
    try {
      final devices = await _micCapture.getAvailableInputDevices();
      return devices
          .map(
            (device) => RecordingInputDevice(
              id: device.id,
              name: device.name,
              kind: device.type.toString(),
              channelCount: device.channelCount,
              isDefault: device.isDefault,
            ),
          )
          .toList();
    } catch (error, stackTrace) {
      _log('input_devices.failed', error: error, stackTrace: stackTrace);
      return const <RecordingInputDevice>[];
    }
  }

  Future<void> _startStreams() async {
    await _micCapture.startCapture();
    await _systemCapture.startCapture();

    _micAudioSub = _micCapture.audioStream?.listen(
      (bytes) => _handleAudioChunk('microphone', bytes),
      onError: (Object error, StackTrace stackTrace) {
        _handleRuntimeError('microphone.stream', error, stackTrace);
      },
    );
    _systemAudioSub = _systemCapture.audioStream?.listen(
      (bytes) => _handleAudioChunk('system', bytes),
      onError: (Object error, StackTrace stackTrace) {
        _handleRuntimeError('system.stream', error, stackTrace);
      },
    );
    _micStatusSub = _micCapture.statusStream?.listen((status) {
      _status = _status.copyWith(
        selectedInputDeviceName: status.deviceName,
      );
      notifyListeners();
    });
    _systemStatusSub = _systemCapture.statusStream?.listen((_) {});
    _micLevelSub = _micCapture.decibelStream?.listen((level) {
      _status = _status.copyWith(microphoneLevelDb: level.decibel);
      notifyListeners();
    });
    _systemLevelSub = _systemCapture.decibelStream?.listen((level) {
      _status = _status.copyWith(systemAudioLevelDb: level.decibel);
      notifyListeners();
    });
  }

  void _handleAudioChunk(String sourceKey, Uint8List bytes) {
    final buffer = _pcmBuffers[sourceKey]!;
    buffer.addAll(bytes);
    final chunkByteTarget =
        (_bytesPerSecondBySource[sourceKey]! * _chunkDurationMs) ~/ 1000;
    while (buffer.length >= chunkByteTarget) {
      final pcmBytes = Uint8List.fromList(buffer.sublist(0, chunkByteTarget));
      buffer.removeRange(0, chunkByteTarget);
      _queueUpload(
        sourceKey: sourceKey,
        pcmBytes: pcmBytes,
        byteLength: chunkByteTarget,
      );
    }
  }

  void _queueUpload({
    required String sourceKey,
    required Uint8List pcmBytes,
    required int byteLength,
  }) {
    final startMs = _lastEndMsBySource[sourceKey] ?? 0;
    final durationMs =
        (byteLength * 1000) ~/ _bytesPerSecondBySource[sourceKey]!;
    final endMs = startMs + durationMs;
    final sequence = _nextSequenceBySource[sourceKey] ?? 0;
    _nextSequenceBySource[sourceKey] = sequence + 1;
    _lastEndMsBySource[sourceKey] = endMs;

    final previous = _uploadQueueBySource[sourceKey] ?? Future<void>.value();
    _uploadQueueBySource[sourceKey] = previous
        // Keep the queue moving even if a previous upload failed.
        .catchError((Object _, StackTrace __) {})
        .then((_) async {
          try {
            await _uploadChunk(
              sourceKey: sourceKey,
              sequence: sequence,
              startMs: startMs,
              endMs: endMs,
              bytes: _wrapPcmAsWav(pcmBytes),
            );
          } catch (error, stackTrace) {
            _handleRuntimeError('$sourceKey.upload', error, stackTrace);
          }
        });
  }

  Future<void> _uploadChunk({
    required String sourceKey,
    required int sequence,
    required int startMs,
    required int endMs,
    required Uint8List bytes,
  }) async {
    final sessionId = _sessionId;
    final baseUrl = _baseUrl;
    if (sessionId == null || baseUrl == null || baseUrl.trim().isEmpty) {
      throw const RecordingBridgeException(
        'Desktop recording session is not initialized.',
      );
    }

    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/recordings/$sessionId/chunks',
    );

    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        final headers = <String, String>{
          'Content-Type': 'audio/wav',
          'X-Recording-Source-Key': sourceKey,
          'X-Recording-Sequence': '$sequence',
          'X-Recording-Start-Ms': '$startMs',
          'X-Recording-End-Ms': '$endMs',
          if ((_sessionCookie ?? '').trim().isNotEmpty)
            'Cookie': _sessionCookie!.trim(),
        };
        final response = await _httpClient
            .post(uri, headers: headers, body: bytes)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw RecordingBridgeException(
            'Chunk upload failed with status ${response.statusCode}.',
          );
        }
        return;
      } on TimeoutException catch (error, stackTrace) {
        _log(
          'upload.timeout',
          data: <String, Object?>{
            'sourceKey': sourceKey,
            'sequence': sequence,
            'attempt': attempt + 1,
          },
          error: error,
          stackTrace: stackTrace,
        );
        _httpClient.close();
        _httpClient = http.Client();
        if (attempt == 2) {
          throw const RecordingBridgeException('Chunk upload timed out.');
        }
      } catch (error) {
        if (attempt == 2) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
  }

  Future<void> _stopStreams({required bool flushPending}) async {
    await _micAudioSub?.cancel();
    await _systemAudioSub?.cancel();
    await _micStatusSub?.cancel();
    await _systemStatusSub?.cancel();
    await _micLevelSub?.cancel();
    await _systemLevelSub?.cancel();
    _micAudioSub = null;
    _systemAudioSub = null;
    _micStatusSub = null;
    _systemStatusSub = null;
    _micLevelSub = null;
    _systemLevelSub = null;

    if (_micCapture.isRecording) {
      await _micCapture.stopCapture();
    }
    if (_systemCapture.isRecording) {
      await _systemCapture.stopCapture();
    }

    if (flushPending) {
      for (final entry in _pcmBuffers.entries) {
        if (entry.value.isEmpty) {
          continue;
        }
        final remaining = Uint8List.fromList(entry.value);
        entry.value.clear();
        _queueUpload(
          sourceKey: entry.key,
          pcmBytes: remaining,
          byteLength: remaining.length,
        );
      }
    } else {
      _resetBuffers();
    }
  }

  void _resetBuffers() {
    for (final sourceKey in _pcmBuffers.keys) {
      _pcmBuffers[sourceKey] = <int>[];
      _nextSequenceBySource[sourceKey] = 0;
      _lastEndMsBySource[sourceKey] = 0;
      _uploadQueueBySource[sourceKey] = Future<void>.value();
    }
  }

  Uint8List _wrapPcmAsWav(Uint8List pcmBytes) {
    final totalLength = pcmBytes.length + 44;
    final data = ByteData(totalLength);
    void writeAscii(int offset, String value) {
      for (var index = 0; index < value.length; index += 1) {
        data.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    writeAscii(0, 'RIFF');
    data.setUint32(4, totalLength - 8, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, _channels, Endian.little);
    data.setUint32(24, _sampleRate, Endian.little);
    data.setUint32(
      28,
      _sampleRate * _channels * _bytesPerSample,
      Endian.little,
    );
    data.setUint16(32, _channels * _bytesPerSample, Endian.little);
    data.setUint16(34, _bytesPerSample * 8, Endian.little);
    writeAscii(36, 'data');
    data.setUint32(40, pcmBytes.length, Endian.little);
    for (var index = 0; index < pcmBytes.length; index += 1) {
      data.setUint8(44 + index, pcmBytes[index]);
    }
    return data.buffer.asUint8List();
  }

  RecordingPermissionState _permissionStateFromError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('restart')) {
      return RecordingPermissionState.needsRestart;
    }
    if (message.contains('permission')) {
      return RecordingPermissionState.denied;
    }
    return RecordingPermissionState.unknown;
  }

  String _permissionFailureMessage({
    required bool micGranted,
    required bool systemGranted,
  }) {
    if (!micGranted && !systemGranted) {
      return 'Grant microphone and system audio permissions before starting desktop recording.';
    }
    if (!micGranted) {
      return 'Grant microphone permission before starting desktop recording.';
    }
    return 'Grant system audio permission before starting desktop recording.';
  }

  Future<void> _openPlatformSettings({
    required String macUrl,
    required List<String> windowsCommand,
    required List<List<String>> linuxCommands,
    required String failureMessage,
  }) async {
    try {
      ProcessResult result;
      if (Platform.isMacOS) {
        result = await Process.run('open', <String>[macUrl]);
      } else if (Platform.isWindows) {
        result = await Process.run(
          windowsCommand.first,
          windowsCommand.sublist(1),
          runInShell: true,
        );
      } else if (Platform.isLinux) {
        var success = false;
        for (final command in linuxCommands) {
          if (command.isEmpty) {
            continue;
          }
          result = await Process.run(command.first, command.sublist(1));
          if (result.exitCode == 0) {
            success = true;
            break;
          }
        }
        if (!success) {
          throw RecordingBridgeException(failureMessage);
        }
        return;
      } else {
        throw RecordingBridgeException(failureMessage);
      }
      if (result.exitCode != 0) {
        throw RecordingBridgeException(failureMessage);
      }
    } catch (error) {
      if (error is RecordingBridgeException) {
        rethrow;
      }
      throw RecordingBridgeException(failureMessage);
    }
  }

  void _handleRuntimeError(
    String event,
    Object error,
    StackTrace stackTrace,
  ) {
    _log(event, error: error, stackTrace: stackTrace);
    _status = _status.copyWith(errorMessage: error.toString());
    notifyListeners();
  }

  void _log(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppDiagnostics.log(
      'recording.bridge.desktop',
      event,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _desktopPlatformLabel() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return 'Desktop dual-source recorder (macOS)';
      case TargetPlatform.windows:
        return 'Desktop dual-source recorder (Windows)';
      case TargetPlatform.linux:
        return 'Desktop dual-source recorder (Linux)';
      default:
        return 'Desktop dual-source recorder';
    }
  }
}
