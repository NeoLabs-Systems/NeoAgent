import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  testWidgets('SplashView renders loading progress and text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashView()));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Loading NeoAgent'), findsOneWidget);
  });
}
