import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/voice_work_clicks.dart';

void main() {
  test('bundled key strikes are real presses, not a short blip', () {
    final clicks = voiceKeyClicksFromWav(
      File('assets/sounds/voice_key_clicks.wav').readAsBytesSync(),
    );

    expect(clicks, hasLength(5));
    final peaks = <int>{};
    for (final click in clicks) {
      final seconds = click.length / 2 / 24000;
      expect(seconds, closeTo(0.14, 0.001));
      final peak = _peak(click);
      expect(peak, inInclusiveRange(6000, 8000));
      peaks.add(peak);
      expect(_energy(click, 0, click.length ~/ 5), greaterThan(0));
    }
    expect(clicks.map((pcm) => pcm.join(',')).toSet(), hasLength(5));
    expect(peaks, isNotEmpty);
  });

  test('typing plays one strike at a time and then stops', () {
    fakeAsync((async) {
      final clicks = voiceKeyClicksFromWav(
        File('assets/sounds/voice_key_clicks.wav').readAsBytesSync(),
      );
      final player = VoiceWorkClicks(
        sampleRate: 24000,
        clicks: clicks,
        random: math.Random(2),
      );
      final heard = <Uint8List>[];
      player.start(heard.add);
      async.elapse(const Duration(milliseconds: 1));
      expect(heard, hasLength(1));
      expect(clicks, contains(heard.single));

      async.elapse(const Duration(milliseconds: 900));
      expect(heard.length, greaterThan(2));

      final stoppedAt = heard.length;
      player.stop();
      async.elapse(const Duration(seconds: 2));
      expect(heard, hasLength(stoppedAt));
      player.dispose();
    });
  });

  test('typing gaps leave room for a whole key strike', () {
    final random = math.Random(4);
    final gaps = List<int>.generate(
      40,
      (index) => voiceWorkClickGapMs(random, endOfBurst: index % 8 == 7),
    );

    expect(gaps.every((gap) => gap >= 160 && gap < 900), isTrue);
    expect(gaps.where((gap) => gap < 280), isNotEmpty);
    expect(gaps.where((gap) => gap >= 420), isNotEmpty);
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
