import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/mascot/mascot_frames.dart';
import 'package:neoagent_flutter/src/mascot/mascot_mood.dart';
import 'package:neoagent_flutter/src/mascot/neo_mascot.dart';

Widget _host(Widget child, {bool reduceMotion = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

void main() {
  test('every frame is a full 9×9 grid', () {
    for (final mood in MascotMood.values) {
      for (final frame in MascotClips.forMood(mood).frames) {
        expect(frame.dots.length, 81);
      }
      expect(MascotClips.keyFrame(mood).dots.length, 81);
    }
    expect(MascotClips.working.frames.length, 32);
  });

  testWidgets('plays every mood at every size and cleans up its timers', (
    tester,
  ) async {
    for (final size in <double>[16, 38, 96]) {
      for (final mood in MascotMood.values) {
        await tester.pumpWidget(_host(NeoMascot(mood: mood, size: size)));
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('switching moods mid-fade keeps rendering', (tester) async {
    for (var i = 0; i < 40; i++) {
      final mood = MascotMood.values[i % MascotMood.values.length];
      await tester.pumpWidget(_host(NeoMascot(mood: mood)));
      await tester.pump(const Duration(milliseconds: 23));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('at rest it stops asking for frames', (tester) async {
    await tester.pumpWidget(_host(const NeoMascot(mood: MascotMood.idle)));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('holds still when motion is reduced or animation is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const NeoMascot(mood: MascotMood.working), reduceMotion: true),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(
      _host(const NeoMascot(mood: MascotMood.thinking, animate: false)),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('announces what it is doing', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const NeoMascot(mood: MascotMood.waiting, animate: false)),
    );
    expect(find.bySemanticsLabel('NeoAgent, waiting for you'), findsOneWidget);
    semantics.dispose();
  });

  test('renders each mood as a distinct PNG for home-screen widgets', () async {
    final pngs = <String>{};
    for (final mood in MascotMood.values) {
      final png = await renderMascotPng(mood, size: 64);
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
      pngs.add(String.fromCharCodes(png));
    }
    expect(pngs.length, MascotMood.values.length);
  });
}
