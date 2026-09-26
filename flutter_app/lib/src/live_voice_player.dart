import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Gapless playback of the live model's raw PCM16 mono stream.
///
/// Audio is appended to one continuously playing stream instead of being
/// played clip by clip, so speech has no gaps between network packets; [flush]
/// drops everything still queued when the owner talks over the assistant.
///
/// Android plays through a native voice-communication AudioTrack so the audio
/// stays on the Telecom call's route and echo canceller. Every other platform
/// uses a SoLoud buffer stream with a small jitter cushion.
class LiveVoicePlayer {
  static const MethodChannel _androidChannel = MethodChannel(
    'neoagent/voice_audio',
  );
  static const double _jitterCushionSeconds = 0.15;

  final bool _useAndroidTrack =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  AudioSource? _source;
  SoundHandle? _handle;
  int _sampleRate = 24000;
  bool _androidStarted = false;

  Future<void> start({required int sampleRate}) async {
    _sampleRate = sampleRate;
    if (_useAndroidTrack) {
      if (_androidStarted) return;
      await _androidChannel.invokeMethod<void>('start', <String, Object>{
        'sampleRate': sampleRate,
      });
      _androidStarted = true;
      return;
    }
    final soloud = SoLoud.instance;
    if (!soloud.isInitialized) {
      await soloud.init(bufferSize: 1024);
    }
    if (_source == null) {
      await _openStream();
    }
  }

  void add(Uint8List pcm16) {
    if (pcm16.isEmpty) return;
    if (_useAndroidTrack) {
      if (_androidStarted) {
        _androidChannel.invokeMethod<void>('write', <String, Object>{
          'pcm': pcm16,
        });
      }
      return;
    }
    final source = _source;
    if (source != null) SoLoud.instance.addAudioDataStream(source, pcm16);
  }

  /// Plays out a tail shorter than the jitter cushion once the model has
  /// stopped sending audio for this turn.
  void drain() {
    final handle = _handle;
    if (handle == null || !SoLoud.instance.getPause(handle)) return;
    SoLoud.instance.setPause(handle, false);
  }

  Future<void> flush() async {
    if (_useAndroidTrack) {
      if (_androidStarted) await _androidChannel.invokeMethod<void>('flush');
      return;
    }
    if (_source == null) return;
    await _closeStream();
    await _openStream();
  }

  Future<void> stop() async {
    if (_useAndroidTrack) {
      if (!_androidStarted) return;
      _androidStarted = false;
      await _androidChannel.invokeMethod<void>('stop');
      return;
    }
    await _closeStream();
  }

  Future<void> _openStream() async {
    final source = SoLoud.instance.setBufferStream(
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: _jitterCushionSeconds,
      sampleRate: _sampleRate,
      channels: Channels.mono,
      format: BufferType.s16le,
    );
    _source = source;
    _handle = await SoLoud.instance.play(source);
  }

  Future<void> _closeStream() async {
    final source = _source;
    final handle = _handle;
    _source = null;
    _handle = null;
    if (handle != null) await SoLoud.instance.stop(handle);
    if (source != null) await SoLoud.instance.disposeSource(source);
  }
}
