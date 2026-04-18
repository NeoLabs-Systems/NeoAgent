import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class LiveVoiceCapture {
  LiveVoiceCapture() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _subscription;
  StreamSubscription<RecordState>? _stateSubscription;
  bool _stopping = false;

  Future<void> start({
    required void Function(Uint8List chunk) onChunk,
    void Function(Object error, StackTrace stackTrace)? onError,
    VoidCallback? onStoppedUnexpectedly,
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    await stop();

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError('Microphone permission is required for live voice.');
    }

    _stopping = false;
    _stateSubscription = _recorder.onStateChanged().listen(
      (state) {
        if (_stopping) {
          return;
        }
        if (state == RecordState.stop) {
          onStoppedUnexpectedly?.call();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_stopping) {
          return;
        }
        onError?.call(error, stackTrace);
      },
    );

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: channels,
      ),
    );

    _subscription = stream.listen(
      onChunk,
      onError: (Object error, StackTrace stackTrace) {
        if (_stopping) {
          return;
        }
        onError?.call(error, stackTrace);
      },
      onDone: () {
        if (_stopping) {
          return;
        }
        onStoppedUnexpectedly?.call();
      },
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    _stopping = true;
    await _subscription?.cancel();
    _subscription = null;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _recorder.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
