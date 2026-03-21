// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'recording_bridge.dart';

RecordingBridge createPlatformRecordingBridge() => WebRecordingBridge();

class WebRecordingBridge extends RecordingBridge {
  RecordingRuntimeStatus _status = const RecordingRuntimeStatus(
    supportsScreenAndMic: true,
    supportsBackgroundMic: false,
    platformLabel: 'Browser screen + microphone recorder',
  );

  html.MediaStream? _displayStream;
  html.MediaStream? _microphoneStream;
  html.MediaRecorder? _screenRecorder;
  html.MediaRecorder? _microphoneRecorder;
  final Map<String, int> _nextSequenceBySource = <String, int>{};
  final Map<String, int> _lastEndMsBySource = <String, int>{};
  final Map<String, Future<void>> _uploadQueueBySource =
      <String, Future<void>>{};
  Stopwatch? _stopwatch;
  String? _baseUrl;
  String? _sessionId;
  bool _stopping = false;
  StreamSubscription<html.Event>? _displayEndedSub;

  @override
  RecordingRuntimeStatus get status => _status;

  @override
  Future<void> refreshStatus() async {}

  @override
  Future<void> startWebRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    if (_status.active) {
      throw const RecordingBridgeException(
        'A recording is already in progress.',
      );
    }

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw const RecordingBridgeException(
          'This browser does not expose media device APIs.',
        );
      }

      final displayStream = await js_util.promiseToFuture<html.MediaStream>(
        js_util.callMethod(mediaDevices, 'getDisplayMedia', <Object?>[
          js_util.jsify(<String, Object>{'video': true, 'audio': true}),
        ]),
      );
      if (displayStream.getVideoTracks().isEmpty) {
        throw const RecordingBridgeException(
          'Screen sharing was cancelled before capture started.',
        );
      }
      if (displayStream.getAudioTracks().isEmpty) {
        displayStream.getTracks().forEach((track) => track.stop());
        throw const RecordingBridgeException(
          'Screen share did not include audio. Share a tab/window and enable audio.',
        );
      }

      final microphoneStream = await mediaDevices.getUserMedia(
        <String, dynamic>{
          'audio': <String, dynamic>{
            'channelCount': 1,
            'echoCancellation': false,
            'noiseSuppression': false,
            'autoGainControl': false,
          },
        },
      );
      if (microphoneStream.getAudioTracks().isEmpty) {
        displayStream.getTracks().forEach((track) => track.stop());
        throw const RecordingBridgeException(
          'Microphone permission is required to start recording.',
        );
      }

      _baseUrl = baseUrl;
      _sessionId = sessionId;
      _displayStream = displayStream;
      _microphoneStream = microphoneStream;
      _nextSequenceBySource
        ..clear()
        ..addAll(<String, int>{'screen': 0, 'microphone': 0});
      _lastEndMsBySource
        ..clear()
        ..addAll(<String, int>{'screen': 0, 'microphone': 0});
      _uploadQueueBySource
        ..clear()
        ..addAll(<String, Future<void>>{
          'screen': Future<void>.value(),
          'microphone': Future<void>.value(),
        });
      _stopwatch = Stopwatch()..start();

      final screenMimeType = _pickMimeType(<String>[
        'video/webm;codecs=vp9,opus',
        'video/webm;codecs=vp8,opus',
        'video/webm',
      ]);
      final micMimeType = _pickMimeType(<String>[
        'audio/webm;codecs=opus',
        'audio/webm',
      ]);

      _screenRecorder = html.MediaRecorder(
        displayStream,
        screenMimeType == null
            ? null
            : <String, String>{'mimeType': screenMimeType},
      );

      _displayEndedSub = displayStream.getVideoTracks().first.onEnded.listen((
        _,
      ) {
        unawaited(_handleExternalStop());
      });

      _bindRecorder(
        recorder: _screenRecorder!,
        sourceKey: 'screen',
        mimeType: screenMimeType ?? 'video/webm',
      );
      _microphoneRecorder = html.MediaRecorder(
        microphoneStream,
        micMimeType == null ? null : <String, String>{'mimeType': micMimeType},
      );
      _bindRecorder(
        recorder: _microphoneRecorder!,
        sourceKey: 'microphone',
        mimeType: micMimeType ?? 'audio/webm',
      );

      _screenRecorder!.start(4000);
      _microphoneRecorder!.start(4000);
      _status = _status.copyWith(
        active: true,
        paused: false,
        sessionId: sessionId,
        startedAt: DateTime.now(),
        errorMessage: null,
      );
      notifyListeners();
    } catch (error) {
      await _disposeStreams();
      _status = _status.copyWith(
        active: false,
        paused: false,
        sessionId: null,
        startedAt: null,
        errorMessage: error.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> startBackgroundRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Background microphone recording is available on Android only.',
    );
  }

  @override
  Future<void> pauseBackgroundRecording() async {
    throw const RecordingBridgeException(
      'Pause is only available for Android background recording.',
    );
  }

  @override
  Future<void> resumeBackgroundRecording() async {
    throw const RecordingBridgeException(
      'Resume is only available for Android background recording.',
    );
  }

  @override
  Future<void> stopActiveRecording({bool notifyEnded = false}) async {
    if (_stopping || !_status.active) {
      return;
    }
    _stopping = true;
    final sessionId = _sessionId;
    try {
      await _stopRecorders();
      await Future.wait(_uploadQueueBySource.values);
      await _disposeStreams();
      _status = _status.copyWith(
        active: false,
        paused: false,
        startedAt: null,
        sessionId: sessionId,
      );
      notifyListeners();
      if (notifyEnded && sessionId != null && onRecordingStopped != null) {
        await onRecordingStopped!(sessionId);
      }
    } finally {
      _stopping = false;
    }
  }

  void _bindRecorder({
    required html.MediaRecorder recorder,
    required String sourceKey,
    required String mimeType,
  }) {
    recorder.addEventListener('dataavailable', (html.Event event) {
      final blob = js_util.getProperty<html.Blob?>(event, 'data');
      if (blob == null || blob.size == 0) {
        return;
      }
      final endMs = _stopwatch?.elapsedMilliseconds ?? 0;
      final startMs = _lastEndMsBySource[sourceKey] ?? 0;
      _lastEndMsBySource[sourceKey] = endMs;
      final sequence = _nextSequenceBySource[sourceKey] ?? 0;
      _nextSequenceBySource[sourceKey] = sequence + 1;
      final upload = (_uploadQueueBySource[sourceKey] ?? Future<void>.value())
          .then(
            (_) => _uploadChunk(
              sourceKey: sourceKey,
              sequence: sequence,
              startMs: startMs,
              endMs: endMs,
              blob: blob,
              mimeType: mimeType,
            ),
          );
      _uploadQueueBySource[sourceKey] = upload.catchError((error) {
        _status = _status.copyWith(errorMessage: error.toString());
        notifyListeners();
        throw error;
      });
    });
  }

  Future<void> _uploadChunk({
    required String sourceKey,
    required int sequence,
    required int startMs,
    required int endMs,
    required html.Blob blob,
    required String mimeType,
  }) async {
    final sessionId = _sessionId;
    final baseUrl = _baseUrl;
    if (sessionId == null || baseUrl == null) {
      throw const RecordingBridgeException(
        'Recording session is not initialized.',
      );
    }
    final bytes = await _blobToBytes(blob);
    final uri = _resolveUri(baseUrl, '/api/recordings/$sessionId/chunks');
    await _requestWithRetry(
      uri.toString(),
      headers: <String, String>{
        'Content-Type': mimeType,
        'X-Recording-Source-Key': sourceKey,
        'X-Recording-Sequence': '$sequence',
        'X-Recording-Start-Ms': '$startMs',
        'X-Recording-End-Ms': '$endMs',
      },
      body: bytes,
    );
  }

  Future<void> _handleExternalStop() async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    await stopActiveRecording(notifyEnded: true);
  }

  Future<void> _stopRecorders() async {
    final futures = <Future<void>>[];
    if (_screenRecorder != null && _screenRecorder!.state != 'inactive') {
      futures.add(_waitForStop(_screenRecorder!));
      _screenRecorder!.stop();
    }
    if (_microphoneRecorder != null &&
        _microphoneRecorder!.state != 'inactive') {
      futures.add(_waitForStop(_microphoneRecorder!));
      _microphoneRecorder!.stop();
    }
    await Future.wait(futures);
  }

  Future<void> _disposeStreams() async {
    await _displayEndedSub?.cancel();
    _displayEndedSub = null;
    _displayStream?.getTracks().forEach((track) => track.stop());
    _microphoneStream?.getTracks().forEach((track) => track.stop());
    _displayStream = null;
    _microphoneStream = null;
    _screenRecorder = null;
    _microphoneRecorder = null;
    _stopwatch?.stop();
    _stopwatch = null;
  }

  Future<void> _requestWithRetry(
    String url, {
    required Map<String, String> headers,
    required Uint8List body,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        await html.HttpRequest.request(
          url,
          method: 'POST',
          sendData: body,
          requestHeaders: headers,
          withCredentials: true,
        );
        return;
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw RecordingBridgeException(
      'Could not upload a recording chunk: ${lastError ?? 'unknown error'}',
    );
  }

  Future<Uint8List> _blobToBytes(html.Blob blob) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();
    reader.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          const RecordingBridgeException(
            'Could not read recorded browser chunk.',
          ),
        );
      }
    });
    reader.onLoadEnd.first.then((_) {
      if (completer.isCompleted) {
        return;
      }
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(result.asUint8List());
        return;
      }
      if (result is Uint8List) {
        completer.complete(result);
        return;
      }
      completer.completeError(
        const RecordingBridgeException(
          'Browser returned an unsupported chunk format.',
        ),
      );
    });
    reader.readAsArrayBuffer(blob);
    return completer.future;
  }

  Future<void> _waitForStop(html.MediaRecorder recorder) {
    final completer = Completer<void>();
    late html.EventListener listener;
    listener = (html.Event _) {
      recorder.removeEventListener('stop', listener);
      if (!completer.isCompleted) {
        completer.complete();
      }
    };
    recorder.addEventListener('stop', listener);
    return completer.future;
  }

  String? _pickMimeType(List<String> candidates) {
    for (final candidate in candidates) {
      if (html.MediaRecorder.isTypeSupported(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  Uri _resolveUri(String baseUrl, String path) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      return Uri.parse(path);
    }
    return Uri.parse(trimmed.replaceFirst(RegExp(r'/$'), '') + path);
  }
}
