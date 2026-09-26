import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/mascot/mascot_mood.dart';

void main() {
  late DateTime now;
  late MascotMoodStabilizer stabilizer;

  void advance(Duration by) => now = now.add(by);

  setUp(() {
    now = DateTime(2026, 9, 24, 12);
    stabilizer = MascotMoodStabilizer(clock: () => now);
  });

  test('a finished run already there at first sight does not play', () {
    expect(stabilizer.update(MascotMood.done, moment: 'run-1'), isNull);
    expect(stabilizer.mood, MascotMood.idle);
  });

  test('done plays once for a new run, then settles to idle', () {
    stabilizer.update(MascotMood.thinking);
    final settleIn = stabilizer.update(MascotMood.done, moment: 'run-1');
    expect(stabilizer.mood, MascotMood.done);
    expect(settleIn, MascotMoodStabilizer.doneHold);

    advance(const Duration(seconds: 1));
    expect(
      stabilizer.update(MascotMood.done, moment: 'run-1'),
      MascotMoodStabilizer.doneHold - const Duration(seconds: 1),
    );
    expect(stabilizer.mood, MascotMood.done);

    advance(MascotMoodStabilizer.doneHold);
    expect(stabilizer.update(MascotMood.done, moment: 'run-1'), isNull);
    expect(stabilizer.mood, MascotMood.idle);
  });

  test('a reconnect does not replay the same failure', () {
    stabilizer.update(MascotMood.working);
    stabilizer.update(MascotMood.blocked, moment: 'run-7');
    expect(stabilizer.mood, MascotMood.blocked);
    advance(MascotMoodStabilizer.blockedHold);
    stabilizer.update(MascotMood.blocked, moment: 'run-7');
    expect(stabilizer.mood, MascotMood.idle);

    stabilizer.update(MascotMood.asleep);
    expect(stabilizer.mood, MascotMood.asleep);
    stabilizer.update(MascotMood.blocked, moment: 'run-7');
    expect(stabilizer.mood, MascotMood.idle);
  });

  test('a new run interrupts done straight away', () {
    stabilizer.update(MascotMood.idle);
    stabilizer.update(MascotMood.done, moment: 'run-1');
    advance(const Duration(milliseconds: 300));
    expect(stabilizer.update(MascotMood.thinking), isNull);
    expect(stabilizer.mood, MascotMood.thinking);
  });

  test('starting work shows at once', () {
    stabilizer.update(MascotMood.idle);
    expect(stabilizer.update(MascotMood.thinking), isNull);
    expect(stabilizer.mood, MascotMood.thinking);
  });

  test('thinking and working hold for the dwell before swapping', () {
    stabilizer.update(MascotMood.thinking);
    advance(const Duration(milliseconds: 100));
    final settleIn = stabilizer.update(MascotMood.working);
    expect(stabilizer.mood, MascotMood.thinking);
    expect(
      settleIn,
      MascotMoodStabilizer.activityDwell - const Duration(milliseconds: 100),
    );

    advance(settleIn!);
    expect(stabilizer.update(MascotMood.working), isNull);
    expect(stabilizer.mood, MascotMood.working);
  });

  test('a flicker back within the dwell never reaches the screen', () {
    stabilizer.update(MascotMood.thinking);
    advance(const Duration(milliseconds: 50));
    stabilizer.update(MascotMood.working);
    advance(const Duration(milliseconds: 50));
    expect(stabilizer.update(MascotMood.thinking), isNull);
    expect(stabilizer.mood, MascotMood.thinking);
  });

  test('work ending waits out the dwell before going idle', () {
    stabilizer.update(MascotMood.working);
    advance(const Duration(milliseconds: 200));
    expect(stabilizer.update(MascotMood.idle), isNotNull);
    expect(stabilizer.mood, MascotMood.working);
    advance(MascotMoodStabilizer.activityDwell);
    expect(stabilizer.update(MascotMood.idle), isNull);
    expect(stabilizer.mood, MascotMood.idle);
  });

  test('needing the user cuts through the dwell', () {
    stabilizer.update(MascotMood.working);
    advance(const Duration(milliseconds: 10));
    expect(stabilizer.update(MascotMood.waiting), isNull);
    expect(stabilizer.mood, MascotMood.waiting);
  });
}
