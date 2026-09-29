import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/voice_work_clicks.dart';

void main() {
  test('clicks stay quiet and fall away like a key tick', () {
    fakeAsync((async) {
      final clicks = VoiceWorkClicks(sampleRate: 24000, random: math.Random(2));
      final heard = <Uint8List>[];
      clicks.start(heard.add);
      async.elapse(const Duration(milliseconds: 1));
      expect(heard, hasLength(1));

      final click = heard.single;
      expect(click.length / 2 / 24000, lessThan(0.03));
      expect(_peak(click), inInclusiveRange(1800, 4500));
      final early = _energy(click, 0, click.length ~/ 3);
      final late = _energy(click, click.length * 2 ~/ 3, click.length);
      expect(early, greaterThan(late));

      async.elapse(const Duration(milliseconds: 700));
      expect(heard.length, greaterThan(2));
      expect(heard.map((pcm) => pcm.join(',')).toSet().length, greaterThan(1));

      final stoppedAt = heard.length;
      clicks.stop();
      async.elapse(const Duration(seconds: 2));
      expect(heard, hasLength(stoppedAt));
      clicks.dispose();
    });
  });

  test('typing gaps mix quick clicks with pauses', () {
    final random = math.Random(4);
    final gaps = List<int>.generate(
      40,
      (index) => voiceWorkClickGapMs(random, endOfBurst: index % 8 == 7),
    );

    expect(gaps.every((gap) => gap >= 36 && gap < 700), isTrue);
    expect(gaps.where((gap) => gap < 180), isNotEmpty);
    expect(gaps.where((gap) => gap >= 280), isNotEmpty);
  });
}

int _peak(Uint8List pcm) {
  final data = ByteData.sublistView(pcm);
  var peak = 0;
  for (var offset = 0; offset < pcm.length; offset += 2) {
    final sample = data.getInt16(offset, Endian.little).abs();
    if (sample > peak) peak = sample;
  }
  return peak;
}

int _energy(Uint8List pcm, int start, int end) {
  final data = ByteData.sublistView(pcm);
  var total = 0;
  for (var offset = start - (start.isOdd ? 1 : 0); offset < end; offset += 2) {
    total += data.getInt16(offset, Endian.little).abs();
  }
  return total;
}
