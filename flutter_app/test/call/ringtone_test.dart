import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/call/ringtone.dart';

void main() {
  test('one ring cycle is two bursts and a rest, without clicks', () {
    final samples = Int16List.sublistView(ringtoneCyclePcm());
    const rate = 24000;
    expect(samples.length, rate * 3);

    bool audible(int fromMs, int toMs) {
      for (var i = fromMs * rate ~/ 1000; i < toMs * rate ~/ 1000; i++) {
        if (samples[i].abs() > 1000) return true;
      }
      return false;
    }

    expect(audible(0, 400), isTrue);
    expect(audible(400, 600), isFalse);
    expect(audible(600, 1000), isTrue);
    expect(audible(1000, 3000), isFalse);
    // Each burst fades in from silence, so looping never pops.
    expect(samples.first, 0);
    expect(samples[rate * 600 ~/ 1000], 0);
  });
}
