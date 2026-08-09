import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

void main() {
  testWidgets(
    'voice panel renders ordered chat timeline and separate controls',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = NeoAgentController(
        backendClient: BackendClient(),
        healthBridge: HealthBridge(),
      );
      addTearDown(controller.dispose);
      controller.voiceAssistantLiveState = VoiceAssistantLiveState(
        sessionId: 'session-1',
        mediaMode: 'duplex',
        inputMode: 'ptt',
        provider: 'openai',
        model: 'backend-advertised-model',
        activeRunId: 'run-1',
        state: 'working',
        timeline: <VoiceTimelineItem>[
          VoiceTimelineItem(
            id: 'turn-1-user',
            sessionId: 'session-1',
            turnId: 'turn-1',
            role: 'user',
            kind: 'transcript_final',
            content: 'Inspect the deployment.',
            isFinal: true,
            createdAt: DateTime.utc(2026, 8, 9),
          ),
          VoiceTimelineItem(
            id: 'progress-1',
            sessionId: 'session-1',
            turnId: 'turn-1',
            runId: 'run-1',
            messageId: 'progress-1',
            role: 'assistant',
            kind: 'progress',
            content: 'The health check is running.',
            isFinal: false,
            createdAt: DateTime.utc(2026, 8, 9, 0, 0, 15),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VoiceAssistantPanel(controller: controller)),
        ),
      );
      await tester.pump();

      expect(find.text('Conversation'), findsOneWidget);
      expect(find.text('Inspect the deployment.'), findsOneWidget);
      expect(find.text('The health check is running.'), findsOneWidget);
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Stop speaking'), findsAtLeastNWidgets(1));
      expect(find.text('Cancel task'), findsOneWidget);
      expect(find.text('End session'), findsOneWidget);
      expect(find.text('Working'), findsAtLeastNWidgets(1));
    },
  );
}
