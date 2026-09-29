import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

/// How long to wait before the next key click.
///
/// A burst is quick and slightly uneven, like someone typing. The pause at
/// the end of a burst is the breath between phrases, so the sound stays
/// quiet instead of becoming a metronome.
int voiceWorkClickGapMs(math.Random random, {required bool endOfBurst}) {
  if (endOfBurst) return 280 + random.nextInt(420);
  if (random.nextInt(6) == 0) return 36 + random.nextInt(16);
  return 70 + random.nextInt(90);
}

/// Soft keyboard clicks played while a voice call is working and nobody is
/// speaking. The samples are synthesized so the client ships no audio asset.
class VoiceWorkClicks {
  VoiceWorkClicks({required this.sampleRate, math.Random? random})
    : _random = random ?? math.Random(),
      _variants = List<Uint8List>.generate(
        _clickVariants,
        (variant) =>
            _synthesizeKeyClick(sampleRate: sampleRate, variant: variant),
      );

  static const int _clickVariants = 6;
  static const int _burstMin = 4;
  static const int _burstSpan = 7;

  final int sampleRate;
  final math.Random _random;
  final List<Uint8List> _variants;
  Timer? _timer;
  int _burstRemaining = 0;

  bool get isPlaying => _timer != null;

  void start(void Function(Uint8List pcm) emit) {
    if (_timer != null) return;
    _arm(emit, Duration.zero);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _burstRemaining = 0;
  }

  void dispose() => stop();

  void _arm(void Function(Uint8List pcm) emit, Duration delay) {
    _timer = Timer(delay, () {
      if (_burstRemaining <= 0) {
        _burstRemaining = _burstMin + _random.nextInt(_burstSpan);
      }
      emit(_variants[_random.nextInt(_variants.length)]);
      _burstRemaining -= 1;
      _arm(
        emit,
        Duration(
          milliseconds: voiceWorkClickGapMs(
            _random,
            endOfBurst: _burstRemaining == 0,
          ),
        ),
      );
    });
  }
}

/// A short mechanical tick: a bright noise transient over a soft body tone,
/// scaled so the loudest sample stays well under speech level.
Uint8List _synthesizeKeyClick({required int sampleRate, required int variant}) {
  const bodies = <double>[180, 220, 150, 260, 190, 240];
  const ticks = <double>[2500, 3200, 2800, 3600, 2100, 3000];
  const peaks = <double>[0.11, 0.08, 0.12, 0.07, 0.10, 0.09];
  final bodyHz = bodies[variant % bodies.length];
  final tickHz = ticks[variant % ticks.length];
  final peak = peaks[variant % peaks.length];
  final count = (sampleRate * 0.018).round();
  final raw = List<double>.filled(count, 0);
  var noise = 0x12345678 + variant * 0x9E3779B9;
  var loudest = 0.0;
  for (var i = 0; i < count; i++) {
    noise = (noise ^ (noise << 13)) & 0x7fffffff;
    noise ^= noise >> 17;
    noise ^= noise << 5;
    final unit = ((noise & 0xFFFF) / 32768.0) - 1.0;
    final t = i / sampleRate;
    final tickEnv = math.exp(-t * 460);
    final bodyEnv = math.exp(-t * 170);
    final attack = (i / (sampleRate * 0.0007)).clamp(0.0, 1.0);
    final sample =
        attack *
        (0.7 * unit * tickEnv +
            0.35 * math.sin(2 * math.pi * tickHz * t) * tickEnv +
            0.5 * math.sin(2 * math.pi * bodyHz * t) * bodyEnv);
    raw[i] = sample;
    final magnitude = sample.abs();
    if (magnitude > loudest) loudest = magnitude;
  }
  final scale = loudest == 0 ? 0.0 : peak / loudest;
  final bytes = Uint8List(count * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < count; i++) {
    final faded = i == count - 1 ? 0.0 : raw[i] * scale;
    data.setInt16(
      i * 2,
      (faded.clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  return bytes;
}
