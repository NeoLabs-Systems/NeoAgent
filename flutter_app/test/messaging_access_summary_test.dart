import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/messaging_access_summary.dart';

void main() {
  testWidgets('renders policy summary and hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagingAccessSummaryCard(
            accent: const Color(0xFF5865F2),
            summary: 'DMs allowlist • shared allowlist • mentions required • 3 rules',
            hint: 'Add users, channels, or roles.',
          ),
        ),
      ),
    );

    expect(find.textContaining('DMs allowlist'), findsOneWidget);
    expect(find.text('Add users, channels, or roles.'), findsOneWidget);
  });
}
