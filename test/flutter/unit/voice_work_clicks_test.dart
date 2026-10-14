import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/voice_work_clicks.dart';

void main() {
  test('every bundled typing phrase is a short 24 kHz recording', () {
    for (final asset in voiceWorkTypingAssets) {
      final pcm = voiceWorkTypingFromWav(File(asset).readAsBytesSync());
      final seconds = pcm.length / 2 / 24000;
      expect(seconds, inInclusiveRange(0.9, 1.8), reason: asset);
    }
  });

  test('phrases follow each other after they finish, never repeating', () {
    fakeAsync((async) {
      final phrases = <Uint8List>[
        Uint8List(24000 * 2), // one second each
        Uint8List(24000 * 2),
        Uint8List(24000 * 2),
      ];
      final played = <int>[];
      final typing = VoiceWorkClicks(
        sampleRate: 24000,
        clicks: phrases,
        random: math.Random(7),
      );
      typing.start((pcm) => played.add(phrases.indexOf(pcm)));

      async.elapse(Duration.zero);
      expect(played.length, 1);
      async.elapse(const Duration(milliseconds: 999));
      expect(played.length, 1, reason: 'the first phrase is still playing');
      async.elapse(const Duration(seconds: 30));
      for (var i = 1; i < played.length; i++) {
        expect(played[i], isNot(played[i - 1]));
      }
      typing.stop();
    });
  });
}
