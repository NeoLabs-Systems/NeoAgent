import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class LiveVoiceCapture {
  LiveVoiceCapture() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _subscription;
  StreamSubscription<RecordState>? _stateSubscription;
  bool _stopping = false;

  /// Starts and stops run one after another. A call that ends and a new one
  /// that starts right away would otherwise interleave, and the old call's
  /// late stop would shut the new call's microphone.
  Future<void> _queue = Future<void>.value();

  Future<void> _serial(Future<void> Function() step) {
    final next = _queue.then((_) => step());
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> start({
    required void Function(Uint8List chunk) onChunk,
    void Function(Object error, StackTrace stackTrace)? onError,
    VoidCallback? onStoppedUnexpectedly,
    int sampleRate = 16000,
    int channels = 1,
  }) => _serial(
    () => _start(
      onChunk: onChunk,
      onError: onError,
      onStoppedUnexpectedly: onStoppedUnexpectedly,
      sampleRate: sampleRate,
      channels: channels,
    ),
  );

  Future<void> _start({
    required void Function(Uint8List chunk) onChunk,
    void Function(Object error, StackTrace stackTrace)? onError,
    VoidCallback? onStoppedUnexpectedly,
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    await _stop();

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError(appStrings.microphonePermissionIsRequiredForLive);
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

    // Voice processing keeps the assistant's own playback out of the
    // microphone, which a full-duplex live call depends on.
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: channels,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
        androidConfig: const AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
        ),
        // A call starts at the ear, as on Android; the call screen's speaker
        // button switches the route.
        iosConfig: const IosRecordConfig(
          categoryOptions: <IosAudioCategoryOption>[
            IosAudioCategoryOption.allowBluetooth,
            IosAudioCategoryOption.allowBluetoothA2DP,
          ],
        ),
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

  Future<void> stop() => _serial(_stop);

  Future<void> _stop() async {
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
