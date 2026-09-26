import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';
import 'package:neoagent_flutter/src/mascot/neo_mascot.dart';

void main() {
  // Launcher mode runs on small dedicated devices as well as phones: the
  // avatar-centred call must fit every one of them, before and during a call.
  for (final size in const <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(412, 915),
  ]) {
    for (final inCall in const <bool>[false, true]) {
      final label = '${size.width.toInt()}×${size.height.toInt()}';
      testWidgets('launcher home fits $label ${inCall ? 'in a call' : 'idle'}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = NeoAgentController(
          backendClient: BackendClient(),
          healthBridge: HealthBridge(),
        );
        addTearDown(controller.dispose);
        if (inCall) {
          controller.voiceAssistantLiveState = VoiceAssistantLiveState(
            sessionId: 'call',
            state: 'speaking',
          );
        }

        await tester.pumpWidget(
          MaterialApp(home: LauncherHomeView(controller: controller)),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text(inCall ? 'End' : 'Call'), findsOneWidget);
        expect(find.byTooltip('Back to chat'), findsNothing);
        // A layout squeezed for room clips the avatar instead of throwing.
        expect(
          tester.getSize(find.byType(NeoMascot)).shortestSide,
          greaterThanOrEqualTo(96),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
