import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neoagent_flutter/main.dart';

const String _code = 'Q2hhbmdlTWVQbGVhc2VJdHNBVGVzdENvZGVYeXo';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'counts down, shows the paired phone, and offers a new code once expired',
    (tester) async {
      var now = DateTime(2026, 11, 11, 12);
      var status = const PairingStatus(state: PairingState.pending);
      var starts = 0;
      Future<PairingTicket> start() async {
        starts += 1;
        return PairingTicket(
          code: '$_code$starts',
          expiresAt: now.add(const Duration(minutes: 5)),
          server: 'https://example.com/neo',
          qrPayload:
              'neoagent://pair?server=https://example.com/neo&code=$_code',
        );
      }

      Future<void> advance(Duration step) async {
        now = now.add(step);
        await tester.pump(step);
      }

      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PairPhoneDialog(
              start: start,
              poll: (_) async => status,
              friendlyError: (error) => '$error',
              now: () => now,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Expires in 5:00'), findsOneWidget);
      expect(
        find.text('https://example.com/neo/app/pair?code=${_code}1'),
        findsOneWidget,
      );

      await advance(const Duration(seconds: 1));
      expect(find.text('Expires in 4:59'), findsOneWidget);
      await advance(const Duration(seconds: 59));
      expect(find.text('Expires in 4:00'), findsOneWidget);

      // Runs out: the code is greyed out and a new one can be asked for.
      await advance(const Duration(minutes: 4));
      await advance(const Duration(seconds: 1));
      expect(find.text('Code expired'), findsOneWidget);
      await tester.tap(find.text('New code'));
      await tester.pump();
      expect(starts, 2);
      expect(find.text('Expires in 5:00'), findsOneWidget);

      // A phone redeems it: the next poll says so.
      status = const PairingStatus(
        state: PairingState.used,
        deviceName: 'Android app',
      );
      await advance(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Paired with Android app ✓'), findsOneWidget);
      expect(find.textContaining('Expires in'), findsNothing);
    },
  );
}
