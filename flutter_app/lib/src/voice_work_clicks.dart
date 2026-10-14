import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

/// The typing recordings, each a short real phrase of keystrokes.
///
/// Cut from "Keyboard Soundpack #1" by unicaegames (CC0), human typing on a
/// Cherry KC 1000. See assets/sounds/typing/LICENSE.txt.
const List<String> voiceWorkTypingAssets = <String>[
  'assets/sounds/typing/typing_01.wav',
  'assets/sounds/typing/typing_02.wav',
  'assets/sounds/typing/typing_03.wav',
  'assets/sounds/typing/typing_04.wav',
  'assets/sounds/typing/typing_05.wav',
  'assets/sounds/typing/typing_06.wav',
  'assets/sounds/typing/typing_07.wav',
  'assets/sounds/typing/typing_08.wav',
];

/// How long to rest after a phrase before typing on: mostly a brief beat, as
/// between words, and now and then a longer pause, as when thinking.
int voiceWorkTypingPauseMs(math.Random random) {
  if (random.nextDouble() < 0.3) return 700 + random.nextInt(900);
  return 120 + random.nextInt(280);
}

/// Someone typing, played while a voice call is working and nobody is
/// speaking: real recorded phrases, one after another with natural pauses.
class VoiceWorkClicks {
  VoiceWorkClicks({
    required this.sampleRate,
    required List<Uint8List> clicks,
    math.Random? random,
  }) : _random = random ?? math.Random(),
       _phrases = List<Uint8List>.unmodifiable(clicks);

  final int sampleRate;
  final math.Random _random;
  final List<Uint8List> _phrases;
  Timer? _timer;
  int _last = -1;

  bool get isPlaying => _timer != null;

  void start(void Function(Uint8List pcm) emit) {
    if (_timer != null || _phrases.isEmpty) return;
    _arm(emit, Duration.zero);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  void _arm(void Function(Uint8List pcm) emit, Duration delay) {
    _timer = Timer(delay, () {
      final phrase = _phrases[_nextIndex()];
      emit(phrase);
      // 16-bit mono: two bytes a sample.
      final playMs = phrase.length * 1000 ~/ (2 * sampleRate);
      _arm(
        emit,
        Duration(milliseconds: playMs + voiceWorkTypingPauseMs(_random)),
      );
    });
  }

  /// Never the same phrase twice in a row, which is what gives a loop away.
  int _nextIndex() {
    if (_phrases.length == 1) return 0;
    var next = _random.nextInt(_phrases.length - 1);
    if (next >= _last) next += 1;
    return _last = next;
  }
}

/// The samples of one bundled typing phrase, 24 kHz mono 16-bit PCM.
Uint8List voiceWorkTypingFromWav(Uint8List bytes) =>
    _wavPcm16Mono(bytes, sampleRate: 24000);

Uint8List _wavPcm16Mono(Uint8List bytes, {required int sampleRate}) {
  if (bytes.length < 44 ||
      _chunkId(bytes, 0) != 'RIFF' ||
      _chunkId(bytes, 8) != 'WAVE') {
    throw FormatException('Typing sound is not a WAV file.');
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
    throw FormatException('Typing sound must be 24 kHz mono 16-bit PCM.');
  }
  return pcm;
}

String _chunkId(Uint8List bytes, int offset) {
  return String.fromCharCodes(bytes.sublist(offset, offset + 4));
}
