import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  testWidgets('SplashView renders the branded loading screen', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const MaterialApp(home: SplashView()));
      expect(find.text('NEOAGENT'), findsOneWidget);
      expect(find.bySemanticsLabel('Loading NeoAgent'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
