import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

void main() {
  testWidgets('device navigation contains exactly Computer and Android tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = NeoAgentController(
      backendClient: BackendClient(),
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DevicesPanel(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.widgetWithText(Tab, 'Computer'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Android'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Browser'), findsNothing);
    expect(find.widgetWithText(Tab, 'Desktop'), findsNothing);
    expect(find.widgetWithText(Tab, 'Files'), findsNothing);
  });

  testWidgets('computer renders every lifecycle and control state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = NeoAgentController(
      backendClient: BackendClient(),
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => DevicesPanel(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final state in <String>[
      'stopped',
      'starting',
      'ready',
      'agent_control',
      'user_control',
      'teaching',
      'sleeping',
      'capacity_wait',
      'error',
    ]) {
      controller.computerRuntime = <String, dynamic>{'state': state};
      controller.notifyListeners();
      await tester.pump();
      final label = state
          .replaceAll('_', ' ')
          .replaceFirstMapped(
            RegExp(r'^.'),
            (match) => match[0]!.toUpperCase(),
          );
      expect(find.text(label), findsOneWidget, reason: 'state $state');
    }
  });

  testWidgets('Teach Mode requires a goal before recording can start', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = NeoAgentController(
      backendClient: BackendClient(),
      healthBridge: HealthBridge(),
    )..computerRuntime = const <String, dynamic>{'state': 'ready'};
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DevicesPanel(controller: controller)),
      ),
    );
    await tester.pump();

    FilledButton teachButton() => tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('computer-teach-start')),
    );
    expect(teachButton().onPressed, isNull);

    await tester.enterText(
      find.byType(TextField).first,
      'Export the selected report',
    );
    await tester.pump();
    expect(teachButton().onPressed, isNotNull);
  });

  testWidgets('local computer stays inside Computer with permission UX', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        NeoAgentController(
            backendClient: BackendClient(),
            healthBridge: HealthBridge(),
          )
          ..computerRuntime = const <String, dynamic>{
            'state': 'ready',
            'provider': 'local',
            'device': <String, dynamic>{'label': 'Workstation'},
          };
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DevicesPanel(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.text('Cloud'), findsOneWidget);
    expect(find.text('This device'), findsOneWidget);
    expect(find.textContaining('This device is connected'), findsNothing);
    expect(find.text('See screen · ask'), findsOneWidget);
    expect(find.text('Control input · ask'), findsOneWidget);
    expect(find.text('Files · ask'), findsOneWidget);
    expect(find.text('CLI and apps · ask'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('computer-teach-start')),
      findsNothing,
    );
    expect(find.widgetWithText(Tab, 'Computer'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Android'), findsOneWidget);
  });
}
