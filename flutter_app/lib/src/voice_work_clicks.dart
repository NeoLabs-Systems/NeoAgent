import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

/// How long to wait before the next key.
///
/// Each strike is a real key recording about 140 ms long, so the gap stays
/// at least that long. Shorter gaps pile the strikes up and sound like a
/// glitch. A burst is a short run of typing; the pause is the breath
/// between phrases.
int voiceWorkClickGapMs(math.Random random, {required bool endOfBurst}) {
  if (endOfBurst) return 420 + random.nextInt(480);
  return 160 + random.nextInt(120);
}

/// Real key strikes played while a voice call is working and nobody is
/// speaking.
///
/// The samples are five Mac key presses from "Single Key Press Sounds" by
/// eklee and qubodup (CC BY 3.0). See assets/sounds/voice_key_clicks.license.txt.
class VoiceWorkClicks {
  VoiceWorkClicks({
    required this.sampleRate,
    required List<Uint8List> clicks,
    math.Random? random,
  }) : _random = random ?? math.Random(),
       _variants = List<Uint8List>.unmodifiable(clicks);

  static const int _burstMin = 4;
  static const int _burstSpan = 6;

  final int sampleRate;
  final math.Random _random;
  final List<Uint8List> _variants;
  Timer? _timer;
  int _burstRemaining = 0;

  bool get isPlaying => _timer != null;

  void start(void Function(Uint8List pcm) emit) {
    if (_timer != null || _variants.isEmpty) return;
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

/// Splits the bundled key recording into equal strikes.
///
/// The file is 24 kHz mono 16-bit PCM, five strikes back to back.
List<Uint8List> voiceKeyClicksFromWav(Uint8List bytes) {
  final pcm = _wavPcm16Mono(bytes, sampleRate: 24000);
  const strikes = 5;
  if (pcm.length % strikes != 0) {
    throw FormatException('Key click recording is not 5 equal strikes.');
  }
  final each = pcm.length ~/ strikes;
  return <Uint8List>[
    for (var index = 0; index < strikes; index++)
      Uint8List.sublistView(pcm, index * each, (index + 1) * each),
  ];
}

Uint8List _wavPcm16Mono(Uint8List bytes, {required int sampleRate}) {
  if (bytes.length < 44 ||
      _chunkId(bytes, 0) != 'RIFF' ||
      _chunkId(bytes, 8) != 'WAVE') {
    throw FormatException('Key clicks are not a WAV file.');
  }
  final data = ByteData.sublistView(bytes);
  var offset = 12;
  int? rate;
  int? channels;
  int? bits;
  Uint8List? pcm;
  while (offset + 8 <= bytes.length) {
    final id = _chunkId(bytes, offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    if (start + size > bytes.length) break;
    if (id == 'fmt ') {
      channels = data.getUint16(start + 2, Endian.little);
      rate = data.getUint32(start + 4, Endian.little);
      bits = data.getUint16(start + 14, Endian.little);
    } else if (id == 'data') {
      pcm = Uint8List.sublistView(bytes, start, start + size);
    }
    offset = start + size + (size.isOdd ? 1 : 0);
  }
  if (pcm == null || channels != 1 || bits != 16 || rate != sampleRate) {
    throw FormatException('Key clicks must be 24 kHz mono 16-bit PCM.');
  }
  return pcm;
}

String _chunkId(Uint8List bytes, int offset) {
  return String.fromCharCodes(bytes.sublist(offset, offset + 4));
}
