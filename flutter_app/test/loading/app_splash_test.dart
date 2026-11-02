import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/loading/app_splash.dart';

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox.fromSize(size: size, child: const AppSplash()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  // The first frame on the web can lay out before the window has a size.
  for (final size in const <Size>[
    Size.zero,
    Size(0, 600),
    Size(800, 0),
    Size(40, 30),
  ]) {
    testWidgets('survives a ${size.width}x${size.height} window', (
      tester,
    ) async {
      await _pumpAt(tester, size);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows the mark once there is room', (tester) async {
    await _pumpAt(tester, const Size(400, 600));
    expect(tester.takeException(), isNull);
    expect(find.text('NEOAGENT'), findsOneWidget);
  });

  testWidgets('appears when a zero-sized window gets its size', (tester) async {
    await _pumpAt(tester, Size.zero);
    expect(find.text('NEOAGENT'), findsNothing);
    await _pumpAt(tester, const Size(400, 600));
    expect(tester.takeException(), isNull);
    expect(find.text('NEOAGENT'), findsOneWidget);
  });
}
