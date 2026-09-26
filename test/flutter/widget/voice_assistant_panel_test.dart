import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

void main() {
  testWidgets(
    'voice panel shows the live call, its background task, and the transcript',
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
        inputMode: 'hands_free',
        provider: 'openai',
        model: 'gpt-live-1',
        voice: 'marin',
        activeRunId: 'run-1',
        activeTaskRequest: 'Inspect the deployment',
        state: 'speaking',
        timeline: <VoiceTimelineItem>[
          VoiceTimelineItem(
            id: 'user-1',
            role: 'user',
            content: 'Inspect the deployment.',
            isFinal: true,
            createdAt: DateTime.utc(2026, 9, 26),
          ),
          VoiceTimelineItem(
            id: 'assistant-1',
            role: 'assistant',
            content: 'I am on it and will tell you what I find.',
            isFinal: false,
            createdAt: DateTime.utc(2026, 9, 26, 0, 0, 1),
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
      expect(
        find.text('I am on it and will tell you what I find.'),
        findsOneWidget,
      );
      expect(
        find.text('Working in the background: Inspect the deployment'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Stop speaking'), findsOneWidget);
      expect(find.text('End call'), findsOneWidget);
      expect(find.text('Speaking'), findsOneWidget);
      expect(find.text('gpt-live-1'), findsOneWidget);
      expect(find.text('HANDS-FREE'), findsOneWidget);

      const voiceError = 'The live voice connection ended.';
      controller.voiceAssistantLiveState = controller.voiceAssistantLiveState
          .copyWith(error: voiceError);
      controller.notifyListeners();
      await tester.pump();

      expect(find.text(voiceError), findsOneWidget);
    },
  );
}
