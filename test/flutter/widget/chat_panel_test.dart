import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

NeoAgentController _buildController() {
  final controller = NeoAgentController(
    backendClient: BackendClient(),
    healthBridge: HealthBridge(),
  );
  controller.chatMessages = <ChatEntry>[
    ChatEntry(
      id: 'msg-1',
      role: 'user',
      content: 'Check the deployment.',
      platform: 'web',
      createdAt: DateTime.utc(2026, 8, 9, 10),
    ),
    ChatEntry(
      id: 'msg-2',
      role: 'assistant',
      content: 'Deployment is healthy.',
      platform: 'web',
      runId: 'run-1',
      createdAt: DateTime.utc(2026, 8, 9, 10, 1),
    ),
  ];
  return controller;
}

void main() {
  testWidgets('run steps stay collapsed behind an expand arrow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _buildController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // The app shell rebuilds the panel on controller changes.
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => ChatPanel(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('Deployment is healthy.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Steps'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    // Collapsed means no run detail request and no step timeline on screen.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Steps'));
    await tester.pump();

    expect(find.text('Hide steps'), findsOneWidget);
    // Opening is what triggers the run detail load; the backend is stubbed out
    // in tests, so the disclosure resolves to its unavailable state.
    await tester.pumpAndSettle();
    expect(
      find.text('Execution details are unavailable for this run.'),
      findsOneWidget,
    );
  });

  testWidgets('thread re-pins to the bottom when content grows late', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _buildController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // The app shell rebuilds the panel on controller changes.
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => ChatPanel(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Late-arriving history: the thread must follow it down without the user
    // touching the scrollbar.
    controller.chatMessages = <ChatEntry>[
      ...controller.chatMessages,
      for (var i = 0; i < 30; i++)
        ChatEntry(
          id: 'late-$i',
          role: i.isEven ? 'user' : 'assistant',
          content: 'Late message $i with enough text to take up a full line.',
          platform: 'web',
          runId: i == 29 ? 'run-2' : null,
          createdAt: DateTime.utc(2026, 8, 9, 11, i),
        ),
    ];
    controller.notifyListeners();
    await tester.pumpAndSettle();

    ScrollPosition position() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position().pixels, closeTo(position().maxScrollExtent, 1));
    expect(
      find.textContaining('Late message 29', findRichText: true),
      findsOneWidget,
    );

    // Growth that the message list itself never sees — expanding the steps
    // disclosure of the last message — must keep the thread pinned too.
    final extentBeforeExpand = position().maxScrollExtent;
    await tester.tap(find.text('Steps').last);
    await tester.pumpAndSettle();

    expect(position().maxScrollExtent, greaterThan(extentBeforeExpand));
    expect(position().pixels, closeTo(position().maxScrollExtent, 1));
  });
}
