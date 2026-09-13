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

  test('raw Discord DMs are shown as private chats', () {
    expect(looksLikeDirectMessagingValue('dm_7016331103035310899'), isTrue);
    expect(looksLikeRawMessagingId('dm_7016331103035310899'), isTrue);
    expect(looksLikeRawMessagingId('153099835322836170'), isTrue);
    expect(looksLikeRawMessagingId('#neoagent'), isFalse);
    expect(
      messagingRuleDisplayLabel(
        label: 'dm_7016331103035310899',
        value: 'dm_7016331103035310899',
      ),
      'Private chat',
    );
    expect(
      messagingRuleDisplayLabel(label: '#neoagent', value: '153099835322836170'),
      '#neoagent',
    );
  });

  test('access help uses the active agent name', () {
    expect(
      messagingAccessModeHelp(
        'allowlist',
        shared: false,
        agentName: 'Atlas',
      ),
      'Atlas only replies to the people you add below.',
    );
    expect(
      messagingSubjectName(''),
      'this agent',
    );
  });

  testWidgets('access summary card uses plain language', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagingAccessSummaryCard(
            accent: Colors.teal,
            headline: 'Atlas only talks to people and groups you approve',
            hint: 'When you choose approved only, add people or groups below.',
            details: <String>['Private chats: Approved only', 'Groups: Anyone'],
          ),
        ),
      ),
    );

    expect(
      find.text('Atlas only talks to people and groups you approve'),
      findsOneWidget,
    );
    expect(find.text('Private chats: Approved only'), findsOneWidget);
    expect(find.text('Allowlist'), findsNothing);
    expect(find.textContaining('Neo'), findsNothing);
  });
}
