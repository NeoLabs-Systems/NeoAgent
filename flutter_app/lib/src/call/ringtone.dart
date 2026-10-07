import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../live_voice_player.dart';

const int _sampleRate = 24000;

/// One cycle of a classic double ring: two short dual-tone bursts, then a
/// rest. Looped, it rings until the call is answered or ends.
@visibleForTesting
Uint8List ringtoneCyclePcm() {
  const toneHz = <double>[400, 450];
  const burstMs = 400;
  const gapMs = 200;
  const restMs = 2000;
  const fadeSamples = _sampleRate * 10 ~/ 1000;
  const burst = _sampleRate * burstMs ~/ 1000;
  const gap = _sampleRate * gapMs ~/ 1000;
  const rest = _sampleRate * restMs ~/ 1000;
  final samples = Int16List(burst * 2 + gap + rest);
  for (final start in <int>[0, burst + gap]) {
    for (var i = 0; i < burst; i++) {
      final t = i / _sampleRate;
      // Short fades keep the bursts from clicking.
      final edge = math.min(i, burst - 1 - i);
      final envelope = edge < fadeSamples ? edge / fadeSamples : 1.0;
      var value = 0.0;
      for (final hz in toneHz) {
        value += math.sin(2 * math.pi * hz * t);
      }
      samples[start + i] = (value / toneHz.length * envelope * 0.35 * 32767)
          .round();
    }
  }
  return samples.buffer.asUint8List();
}

/// The incoming-call ring on platforms without a native ringer (web, iOS and
/// desktop), played through the same SoLoud engine as live voice.
class Ringtone {
  Ringtone._();

  static AudioSource? _source;
  static SoundHandle? _handle;
  static int _epoch = 0;

  static Future<void> start() async {
    final epoch = ++_epoch;
    if (_handle != null) return;
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) await soloud.init(bufferSize: 1024);
      _source ??= await soloud.loadMem(
        'neoagent-ringtone',
        pcm16MonoWav(ringtoneCyclePcm(), _sampleRate),
      );
      // Stopped while the engine was starting.
      if (epoch != _epoch || _handle != null) return;
      _handle = await soloud.play(_source!, looping: true);
      if (epoch != _epoch) await stop();
    } catch (error) {
      // A browser blocks audio until the page has been interacted with; the
      // notification and haptics still announce the call.
      debugPrint('Ringtone failed to start: $error');
    }
  }

  static Future<void> stop() async {
    _epoch++;
    final handle = _handle;
    _handle = null;
    if (handle != null) await SoLoud.instance.stop(handle);
  }
}
