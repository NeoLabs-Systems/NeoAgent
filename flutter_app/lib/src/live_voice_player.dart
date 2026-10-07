import 'dart:async';

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
  final List<Uint8List> _clickPcm = <Uint8List>[];
  final List<AudioSource> _clickSounds = <AudioSource>[];
  int _sampleRate = 24000;
  int _clickEpoch = 0;
  bool _clickQueued = false;
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
        // Typing still sitting in the call track would play before this
        // speech. Drop it, then let the voice through.
        if (_clickQueued) {
          _clickQueued = false;
          _androidChannel.invokeMethod<void>('flush');
        }
        _androidChannel.invokeMethod<void>('write', <String, Object>{
          'pcm': pcm16,
        });
      }
      return;
    }
    final source = _source;
    if (source != null) SoLoud.instance.addAudioDataStream(source, pcm16);
  }

  /// Loads the typing phrases. Each one is played whole, as its own sound, so
  /// a pause between phrases is silence instead of a stream underrun. Android
  /// writes the same samples on the call track.
  Future<void> prepareWorkClicks(List<Uint8List> clicks) {
    final pending = _preparingClicks;
    if (pending != null) return pending;
    final opening = _prepareWorkClicks(clicks);
    _preparingClicks = opening;
    return opening.whenComplete(() {
      if (identical(_preparingClicks, opening)) _preparingClicks = null;
    });
  }

  Future<void> _prepareWorkClicks(List<Uint8List> clicks) async {
    if (clicks.isEmpty || _clickPcm.isNotEmpty) return;
    final epoch = _clickEpoch;
    if (_useAndroidTrack) {
      _clickPcm.addAll(clicks);
      return;
    }
    final starting = _starting;
    if (starting != null) {
      try {
        await starting;
      } catch (_) {
        return;
      }
    }
    if (epoch != _clickEpoch || _clickPcm.isNotEmpty) return;
    final soloud = SoLoud.instance;
    if (!soloud.isInitialized) {
      await soloud.init(bufferSize: 1024);
    }
    final loaded = <AudioSource>[];
    for (var index = 0; index < clicks.length; index++) {
      if (epoch != _clickEpoch) break;
      final source = await soloud.loadMem(
        'neoagent-key-click-$epoch-$index',
        pcm16MonoWav(clicks[index], _sampleRate),
      );
      if (epoch != _clickEpoch) {
        loaded.add(source);
        break;
      }
      loaded.add(source);
    }
    if (epoch != _clickEpoch || loaded.length != clicks.length) {
      for (final source in loaded) {
        await soloud.disposeSource(source);
      }
      return;
    }
    _clickPcm.addAll(clicks);
    _clickSounds.addAll(loaded);
  }

  void addWorkClick(Uint8List pcm16) {
    if (pcm16.isEmpty) return;
    if (_useAndroidTrack) {
      if (_androidStarted) {
        _clickQueued = true;
        _androidChannel.invokeMethod<void>('write', <String, Object>{
          'pcm': pcm16,
        });
      }
      return;
    }
    final index = _clickPcm.indexWhere((click) => identical(click, pcm16));
    if (index < 0 || index >= _clickSounds.length) return;
    unawaited(SoLoud.instance.play(_clickSounds[index]));
  }

  /// Stops typing that is still playing. The loaded phrases stay available.
  Future<void> stopWorkClicks() async {
    _clickEpoch++;
    if (_useAndroidTrack || _clickSounds.isEmpty) return;
    for (final source in _clickSounds) {
      for (final handle in source.handles.toList()) {
        await SoLoud.instance.stop(handle);
      }
    }
  }

  Future<void> _releaseWorkClicks() async {
    await stopWorkClicks();
    final sounds = List<AudioSource>.of(_clickSounds);
    _clickPcm.clear();
    _clickSounds.clear();
    _clickQueued = false;
    for (final source in sounds) {
      await SoLoud.instance.disposeSource(source);
    }
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
    await _releaseWorkClicks();
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

/// A minimal WAV wrapper so raw 16-bit mono samples can be loaded as a sound.
Uint8List pcm16MonoWav(Uint8List pcm, int sampleRate) {
  final bytes = Uint8List(44 + pcm.length);
  final data = ByteData.sublistView(bytes);
  _writeAscii(bytes, 0, 'RIFF');
  data.setUint32(4, 36 + pcm.length, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');
  _writeAscii(bytes, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _writeAscii(bytes, 36, 'data');
  data.setUint32(40, pcm.length, Endian.little);
  bytes.setAll(44, pcm);
  return bytes;
}

void _writeAscii(Uint8List bytes, int offset, String value) {
  for (var index = 0; index < value.length; index++) {
    bytes[offset + index] = value.codeUnitAt(index);
  }
}
