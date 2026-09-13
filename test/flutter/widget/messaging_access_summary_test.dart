import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/messaging_access_summary.dart';

void main() {
  test('access mode labels stay non-technical', () {
    expect(messagingAccessModeLabel('allowlist'), 'Approved only');
    expect(messagingAccessModeLabel('open'), 'Anyone');
    expect(messagingAccessModeLabel('disabled'), 'No one');
    expect(messagingScopePickerLabel('phone_number'), 'Phone number');
    expect(messagingScopePickerLabel('user'), 'Person');
    expect(messagingScopePickerLabel('dm'), 'Private chat');
  });

  testWidgets('access summary card uses plain language', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagingAccessSummaryCard(
            accent: Colors.teal,
            headline: 'Neo only talks to people and groups you approve',
            hint: 'When you choose approved only, add people or groups below.',
            details: <String>['Private chats: Approved only', 'Groups: Anyone'],
          ),
        ),
      ),
    );

    expect(
      find.text('Neo only talks to people and groups you approve'),
      findsOneWidget,
    );
    expect(find.text('Private chats: Approved only'), findsOneWidget);
    expect(find.text('Allowlist'), findsNothing);
  });
}
