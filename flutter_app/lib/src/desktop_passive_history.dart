import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_companion_actions.dart';
import 'desktop_ocr_bridge.dart';

const String desktopPassiveHistoryEnabledPrefsKey =
    'desktop.passiveHistory.enabled';

class DesktopPassiveHistoryManager extends ChangeNotifier {
  DesktopPassiveHistoryManager({
    required DesktopCompanionActions actions,
    required DesktopOcrBridge ocrBridge,
  }) : _actions = actions,
       _ocrBridge = ocrBridge;

  static const Duration _captureInterval = Duration(seconds: 20);
  static const Duration _contextPollInterval = Duration(seconds: 4);
  static const Duration _idleThreshold = Duration(minutes: 5);
  static const int _maxBatchSize = 20;

  final DesktopCompanionActions _actions;
  final DesktopOcrBridge _ocrBridge;

  Timer? _captureTimer;
  Timer? _contextPollTimer;
  bool _enabled = false;
  bool _paused = false;
  bool _authenticated = false;
  bool _connected = false;
  bool _captureInFlight = false;
  String _backendUrl = '';
  String _sessionCookie = '';
  String _deviceId = '';
  String _activationId = '';
  String _label = 'Desktop';
  String? _lastUploadedAt;
  String? _lastError;
  String _lastObservedContext = '';
  String _lastUploadedFingerprint = '';
  final List<Map<String, Object?>> _pendingEntries = <Map<String, Object?>>[];

  bool get enabled => _enabled;
  String? get lastUploadedAt => _lastUploadedAt;
  String? get lastError => _lastError;

  Future<void> bootstrap(SharedPreferences prefs) async {
    _enabled = prefs.getBool(desktopPassiveHistoryEnabledPrefsKey) ?? false;
  }

  Future<void> setEnabled(bool value, SharedPreferences prefs) async {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    await prefs.setBool(desktopPassiveHistoryEnabledPrefsKey, value);
    if (!value) {
      _resetLocalCaptureState();
      _stopTimers();
    } else {
      _syncTimers();
      unawaited(_captureIfNeeded(force: true));
    }
    notifyListeners();
  }

  void updateRuntimeState({
    required String backendUrl,
    required String sessionCookie,
    required bool authenticated,
    required bool connected,
    required bool paused,
    required String deviceId,
    required String activationId,
    required String label,
  }) {
    final identityChanged =
        _sessionCookie != sessionCookie.trim() ||
        _deviceId != deviceId.trim() ||
        _activationId != activationId.trim();
    _backendUrl = backendUrl.trim();
    _sessionCookie = sessionCookie.trim();
    _authenticated = authenticated;
    _connected = connected;
    _paused = paused;
    _deviceId = deviceId.trim();
    _activationId = activationId.trim();
    _label = label.trim().isEmpty ? 'Desktop' : label.trim();
    if (identityChanged) {
      _resetLocalCaptureState();
    }
    _syncTimers();
    if (_enabled && _connected) {
      unawaited(_flushQueue());
    }
  }

  Map<String, Object?> statusPayload() {
    return <String, Object?>{
      'passiveHistoryEnabled': _enabled,
      'passiveHistoryLastUploadedAt': _lastUploadedAt,
      'passiveHistoryLastError': _lastError,
    };
  }

  bool get _shouldRun =>
      _enabled &&
      !_paused &&
      _authenticated &&
      _connected &&
      _backendUrl.isNotEmpty &&
      _sessionCookie.isNotEmpty &&
      _deviceId.isNotEmpty &&
      _activationId.isNotEmpty;

  void _syncTimers() {
    if (!_shouldRun) {
      _stopTimers();
      return;
    }
    _captureTimer ??= Timer.periodic(_captureInterval, (_) {
      unawaited(_captureIfNeeded());
    });
    _contextPollTimer ??= Timer.periodic(_contextPollInterval, (_) {
      unawaited(_pollContext());
    });
  }

  void _stopTimers() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _contextPollTimer?.cancel();
    _contextPollTimer = null;
  }

  Future<void> _pollContext() async {
    if (!_shouldRun || _captureInFlight) {
      return;
    }
    try {
      final status = await _actions.getStatus(label: _label, paused: _paused);
      if (_skipForStatus(status)) {
        return;
      }
      final context = _contextKey(status);
      if (context.isEmpty || context == _lastObservedContext) {
        return;
      }
      _lastObservedContext = context;
      await _captureIfNeeded(force: true, statusOverride: status);
    } catch (error) {
      _setLastError('$error');
    }
  }

  Future<void> _captureIfNeeded({
    bool force = false,
    Map<String, Object?>? statusOverride,
  }) async {
    if (!_shouldRun || _captureInFlight) {
      return;
    }
    _captureInFlight = true;
    try {
      final status =
          statusOverride ??
          await _actions.getStatus(label: _label, paused: _paused);
      if (_skipForStatus(status)) {
        return;
      }
      final snapshot = await _actions.captureSnapshot(
        activeDisplayId: status['activeDisplayId']?.toString(),
      );
      if (snapshot == null) {
        return;
      }
      final unavailableReason = await _ocrBridge.unavailableReason();
      if (unavailableReason != null) {
        _setLastError(unavailableReason);
        return;
      }
      final bytes = base64Decode(snapshot.screenshotBase64);
      final ocr = await _ocrBridge.recognize(
        bytes: bytes,
        mimeType: snapshot.contentType,
      );
      final text = _normalizeText(ocr.text);
      if (text.isEmpty) {
        return;
      }
      final frontmostApp = status['frontmostApp']?.toString().trim() ?? '';
      final windowTitle =
          status['frontmostWindowTitle']?.toString().trim() ?? '';
      final fingerprint = '$frontmostApp\n$windowTitle\n$text';
      if (!force && fingerprint == _lastUploadedFingerprint) {
        return;
      }
      _lastUploadedFingerprint = fingerprint;
      _pendingEntries.add(<String, Object?>{
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        'frontmostApp': frontmostApp,
        'windowTitle': windowTitle,
        'text': text,
        if (ocr.confidence != null) 'ocrConfidence': ocr.confidence,
      });
      _lastObservedContext = _contextKey(status);
      await _flushQueue();
    } catch (error) {
      _setLastError('$error');
    } finally {
      _captureInFlight = false;
    }
  }

  bool _skipForStatus(Map<String, Object?> status) {
    if (!_shouldRun) {
      return true;
    }
    final permissions = status['permissions'];
    if (permissions is Map) {
      final captureState =
          permissions['screenCapture']?.toString().toLowerCase() ?? '';
      if (captureState == 'required' || captureState == 'unsupported') {
        return true;
      }
    }
    if (status['sessionLocked'] == true) {
      return true;
    }
    if (status['userIdle'] == true) {
      return true;
    }
    final idleSeconds = num.tryParse(status['idleSeconds']?.toString() ?? '');
    if (idleSeconds != null &&
        idleSeconds >= _idleThreshold.inSeconds) {
      return true;
    }
    final frontmostApp = status['frontmostApp']?.toString().trim() ?? '';
    final windowTitle =
        status['frontmostWindowTitle']?.toString().trim() ?? '';
    return frontmostApp.isEmpty && windowTitle.isEmpty;
  }

  String _contextKey(Map<String, Object?> status) {
    final app = status['frontmostApp']?.toString().trim() ?? '';
    final window = status['frontmostWindowTitle']?.toString().trim() ?? '';
    if (app.isEmpty && window.isEmpty) {
      return '';
    }
    return '$app::$window';
  }

  String _normalizeText(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 4000) {
      return normalized;
    }
    return normalized.substring(0, 4000);
  }

  Future<void> _flushQueue() async {
    if (!_shouldRun || _pendingEntries.isEmpty) {
      return;
    }
    final batch = _pendingEntries.take(_maxBatchSize).toList(growable: false);
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse(_backendUrl).resolve('/api/screen-history/entries'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.cookieHeader, _sessionCookie);
      request.add(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'deviceId': _deviceId,
            'activationId': _activationId,
            'entries': batch,
          }),
        ),
      );
      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          responseBody.isEmpty
              ? 'Passive history upload failed (${response.statusCode}).'
              : responseBody,
          uri: request.uri,
        );
      }
      _pendingEntries.removeRange(0, batch.length);
      _lastUploadedAt = DateTime.now().toUtc().toIso8601String();
      _lastError = null;
      notifyListeners();
      if (_pendingEntries.isNotEmpty) {
        await _flushQueue();
      }
    } catch (error) {
      _setLastError('$error');
    } finally {
      client.close(force: true);
    }
  }

  void _setLastError(String? value) {
    final normalized = value?.trim() ?? '';
    final next = normalized.isEmpty ? null : normalized;
    if (_lastError == next) {
      return;
    }
    _lastError = next;
    notifyListeners();
  }

  void _resetLocalCaptureState() {
    _pendingEntries.clear();
    _lastObservedContext = '';
    _lastUploadedFingerprint = '';
    _captureInFlight = false;
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
