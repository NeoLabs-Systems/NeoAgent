import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

void main() {
  test(
    'incoming call payload does not require or expose an opening message',
    () {
      final call = IncomingAgentCall.fromJson(<String, dynamic>{
        'callId': 'call-1',
        'agentId': 'agent-1',
        'agentName': 'Research Agent',
        'expiresAt': DateTime.now()
            .add(const Duration(seconds: 30))
            .toIso8601String(),
        'openingMessage': 'private until answered',
      });

      expect(call.callId, 'call-1');
      expect(call.agentName, 'Research Agent');
    },
  );

  testWidgets('incoming call overlay offers accept and decline controls', (
    tester,
  ) async {
    final controller = NeoAgentController(
      backendClient: BackendClient(),
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);
    controller.incomingAgentCall = IncomingAgentCall(
      callId: 'call-1',
      agentId: 'agent-1',
      agentName: 'Research Agent',
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IncomingAgentCallOverlay(
          call: controller.incomingAgentCall!,
          controller: controller,
        ),
      ),
    );

    expect(
      find.byKey(const Key('incoming-agent-call-overlay')),
      findsOneWidget,
    );
    expect(find.text('Research Agent'), findsOneWidget);
    expect(find.byKey(const Key('accept-agent-call')), findsOneWidget);
    expect(find.byKey(const Key('decline-agent-call')), findsOneWidget);

    await tester.tap(find.byKey(const Key('decline-agent-call')));
    await tester.pump();
    expect(controller.incomingAgentCall, isNull);
  });
}
