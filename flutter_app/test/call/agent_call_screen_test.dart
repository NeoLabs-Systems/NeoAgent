import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

void main() {
  NeoAgentController controllerFor(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = NeoAgentController(
      backendClient: BackendClient(),
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  testWidgets('a ringing call shows the calling agent and its choices', (
    tester,
  ) async {
    final controller = controllerFor(tester);
    controller.incomingAgentCall = IncomingAgentCall(
      callId: 'call-1',
      agentId: 'agent-1',
      agentName: 'Atlas',
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
    );

    await tester.pumpWidget(
      MaterialApp(home: AgentCallScreen(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Atlas'), findsOneWidget);
    expect(find.text('Incoming call'), findsOneWidget);
    expect(find.text('Call me later'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.byTooltip('Back to chat'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an ended call recaps who and how long', (tester) async {
    final controller = controllerFor(tester);
    controller.lastEndedCall = const EndedAgentCall(
      agentName: 'Atlas',
      duration: Duration(minutes: 4, seconds: 37),
      backgroundTask: 'Booking the table',
    );

    await tester.pumpWidget(
      MaterialApp(home: AgentCallScreen(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Call ended'), findsOneWidget);
    expect(find.text('Atlas · 04:37'), findsOneWidget);
    expect(find.textContaining('Booking the table'), findsOneWidget);
    expect(find.text('Call back'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
