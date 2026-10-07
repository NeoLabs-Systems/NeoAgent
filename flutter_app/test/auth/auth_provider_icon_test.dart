import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/auth_provider_icon.dart';

void main() {
  testWidgets('ChatGPT mark parses and paints inside its box', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: AuthProviderIcon(icon: 'chatgpt', size: 20)),
      ),
    );
    expect(tester.takeException(), isNull);
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(AuthProviderIcon),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(paint.size, const Size.square(20));
  });

  testWidgets('unknown providers fall back to a link icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthProviderIcon(icon: 'someday')),
    );
    expect(find.byIcon(Icons.link), findsOneWidget);
  });
}
