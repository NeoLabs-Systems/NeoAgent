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
  AudioSource? _clickSource;
  SoundHandle? _clickHandle;
  int _sampleRate = 24000;
  int _clickEpoch = 0;
  bool _androidStarted = false;
  Future<void>? _starting;
  Future<void>? _preparingClicks;

  Future<void> start({required int sampleRate}) {
    _sampleRate = sampleRate;
    return _starting = _openPlayback();
  }

  Future<void> _openPlayback() async {
    if (_useAndroidTrack) {
      if (_androidStarted) return;
      await _androidChannel.invokeMethod<void>('start', <String, Object>{
        'sampleRate': _sampleRate,
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

  /// A separate, quiet stream of keyboard clicks. Speech keeps the jitter
  /// cushion, which would bunch short clicks into bursts, so clicks use their
  /// own buffer. Android writes them on the call track; a click is only a few
  /// milliseconds, so speech that arrives behind one is not held up.
  Future<void> prepareWorkClicks() {
    final pending = _preparingClicks;
    if (pending != null) return pending;
    final opening = _prepareWorkClicks();
    _preparingClicks = opening;
    return opening.whenComplete(() {
      if (identical(_preparingClicks, opening)) _preparingClicks = null;
    });
  }

  Future<void> _prepareWorkClicks() async {
    if (_useAndroidTrack || _clickSource != null) return;
    final epoch = _clickEpoch;
    final starting = _starting;
    if (starting != null) {
      try {
        await starting;
      } catch (_) {
        return;
      }
    }
    if (epoch != _clickEpoch || _clickSource != null) return;
    final soloud = SoLoud.instance;
    if (!soloud.isInitialized) {
      await soloud.init(bufferSize: 1024);
    }
    if (epoch != _clickEpoch || _clickSource != null) return;
    final source = soloud.setBufferStream(
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0.005,
      sampleRate: _sampleRate,
      channels: Channels.mono,
      format: BufferType.s16le,
      maxBufferSizeDuration: const Duration(milliseconds: 400),
    );
    final handle = await soloud.play(source);
    if (epoch != _clickEpoch) {
      await soloud.stop(handle);
      await soloud.disposeSource(source);
      return;
    }
    _clickSource = source;
    _clickHandle = handle;
  }

  void addWorkClick(Uint8List pcm16) {
    if (pcm16.isEmpty) return;
    if (_useAndroidTrack) {
      if (_androidStarted) {
        _androidChannel.invokeMethod<void>('write', <String, Object>{
          'pcm': pcm16,
        });
      }
      return;
    }
    final source = _clickSource;
    if (source != null) SoLoud.instance.addAudioDataStream(source, pcm16);
  }

  Future<void> stopWorkClicks() async {
    _clickEpoch++;
    final source = _clickSource;
    final handle = _clickHandle;
    _clickSource = null;
    _clickHandle = null;
    if (_useAndroidTrack || source == null) return;
    if (handle != null) await SoLoud.instance.stop(handle);
    await SoLoud.instance.disposeSource(source);
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
    await stopWorkClicks();
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
