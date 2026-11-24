import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

class _PauseClient extends BackendClient {
  final paused = <String>[];
  bool fail = false;

  @override
  Future<Map<String, dynamic>> pauseAgentRun(
    String baseUrl,
    String runId,
  ) async {
    if (fail) throw Exception('Pause failed');
    paused.add(runId);
    return <String, dynamic>{'success': true};
  }
}

class _CallController extends NeoAgentController {
  _CallController(_PauseClient client)
    : super(backendClient: client, healthBridge: HealthBridge());

  bool closed = false;
  bool saved = false;

  @override
  Future<void> closeLiveVoiceSession({
    bool cancelTask = false,
    bool tasksSaved = false,
    String? error,
  }) async {
    closed = true;
    saved = tasksSaved;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async => null,
        );
  });

  test('saving a call pauses every task before closing', () async {
    final client = _PauseClient();
    final controller = _CallController(client);
    addTearDown(controller.dispose);
    controller.voiceAssistantLiveState = VoiceAssistantLiveState(
      sessionId: 'call',
      tasks: const [
        VoiceCallTask(runId: 'first'),
        VoiceCallTask(runId: 'second'),
      ],
    );

    await controller.hangUpVoiceCall(saveForNextTime: true);

    expect(client.paused, ['first', 'second']);
    expect(controller.closed, isTrue);
    expect(controller.saved, isTrue);
  });

  test('a failed save keeps the call open and exposes the error', () async {
    final client = _PauseClient()..fail = true;
    final controller = _CallController(client);
    addTearDown(controller.dispose);
    controller.voiceAssistantLiveState = VoiceAssistantLiveState(
      sessionId: 'call',
      tasks: const [VoiceCallTask(runId: 'first')],
    );

    await controller.hangUpVoiceCall(saveForNextTime: true);

    expect(controller.closed, isFalse);
    expect(controller.voiceAssistantLiveState.sessionId, 'call');
    expect(controller.errorMessage, isNotEmpty);
  });

  testWidgets('hang up offers saving running work for later', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = _PauseClient();
    final controller = _CallController(client);
    addTearDown(controller.dispose);
    controller.voiceAssistantLiveState = VoiceAssistantLiveState(
      sessionId: 'call',
      tasks: const [VoiceCallTask(runId: 'first', request: 'Check deployment')],
    );
    await tester.pumpWidget(
      MaterialApp(home: AgentCallScreen(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Keep task running'), findsOneWidget);
    expect(find.text('Cancel task'), findsOneWidget);
    await tester.tap(find.text('Save for next time'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(client.paused, ['first']);
    expect(controller.saved, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
