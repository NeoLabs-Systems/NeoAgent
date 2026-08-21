import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/computer_display.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

class _ComputerControlBackendClient extends BackendClient {
  bool acquiredControl = false;
  int displaySessionCount = 0;

  @override
  Future<Map<String, dynamic>> acquireComputerControl(
    String baseUrl, {
    String? deviceTarget,
  }) async {
    acquiredControl = true;
    return const <String, dynamic>{'ownerType': 'user'};
  }

  @override
  Future<Map<String, dynamic>> createComputerDisplaySession(
    String baseUrl, {
    String? deviceTarget,
  }) async {
    displaySessionCount++;
    return <String, dynamic>{
      'viewUrl': '/api/computer/display/session-$displaySessionCount',
      'viewOnly': !acquiredControl,
    };
  }

  @override
  Future<Map<String, dynamic>> fetchComputerStatus(
    String baseUrl, {
    String? deviceTarget,
  }) async {
    return <String, dynamic>{
      'state': acquiredControl ? 'user_control' : 'agent_control',
    };
  }
}

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

    expect(find.text('Computer'), findsOneWidget);
    expect(find.text('Android'), findsOneWidget);
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

    const labels = <String, String>{
      'stopped': 'Your computer is off',
      'starting': 'Starting your computer',
      'ready': 'Your computer is ready',
      'agent_control': 'NeoAgent is working',
      'user_control': 'You are in control',
      'teaching': 'Teaching in progress',
      'sleeping': 'Your computer is asleep',
      'capacity_wait': 'All computer slots are busy',
      'error': 'Could not start',
    };
    for (final entry in labels.entries) {
      final state = entry.key;
      controller.computerRuntime = <String, dynamic>{'state': state};
      controller.notifyListeners();
      await tester.pump();
      expect(find.text(entry.value), findsWidgets, reason: 'state $state');
    }
  });

  testWidgets('local computer stays connected without a Connect button', (
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
    controller.computerRuntime = <String, dynamic>{
      'state': 'stopped',
      'provider': 'local',
    };

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

    expect(find.text('Connect this device'), findsNothing);
    expect(find.text('Keeping this device connected'), findsOneWidget);
    expect(find.text('This device is paused'), findsOneWidget);
  });

  testWidgets('cowork local computer ignores default cloud status flashes', (
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
    controller.computerRuntime = <String, dynamic>{
      'state': 'ready',
      'provider': 'local',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => DevicesPanel(
              controller: controller,
              deviceTarget: 'local',
              computerOnly: true,
              showProviderPicker: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('This desktop is connected'), findsOneWidget);
    expect(find.text('This device is ready'), findsOneWidget);

    controller.computerRuntime = <String, dynamic>{
      'state': 'stopped',
      'provider': 'cloud',
    };
    controller.notifyListeners();
    await tester.pump();

    expect(find.text('This desktop is connected'), findsOneWidget);
    expect(find.text('This device is ready'), findsOneWidget);
    expect(find.text('Keeping this device connected'), findsNothing);
    expect(find.text('Your computer is off'), findsNothing);
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

    await tester.tap(
      find.byKey(const ValueKey<String>('computer-teach-toggle')),
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
    expect(find.text('Access permissions'), findsOneWidget);
    await tester.tap(find.text('Access permissions'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, 'Screen'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Mouse & keyboard'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Workspace files'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Commands & apps'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('computer-teach-start')),
      findsNothing,
    );
    expect(find.widgetWithText(OutlinedButton, 'Files'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Terminal'), findsNothing);
    expect(find.text('Computer'), findsOneWidget);
    expect(find.text('Android'), findsOneWidget);
  });

  testWidgets('storage errors are not presented as a capacity queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        NeoAgentController(
            backendClient: BackendClient(),
            healthBridge: HealthBridge(),
          )
          ..computerRuntime = const <String, dynamic>{
            'state': 'error',
            'errorCode': 'COMPUTER_STORAGE_CAPACITY',
            'lastError':
                'Starting this cloud computer needs more free storage: 22.3 GiB free, '
                '20% held back for the host, and 19.7 GiB still unwritten in existing '
                'computer disks.',
          };
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DevicesPanel(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.text('More free space is needed'), findsWidgets);
    expect(find.textContaining('19.7 GiB still unwritten'), findsOneWidget);
    expect(find.text('All computer slots are busy'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == Colors.black,
      ),
      findsNothing,
    );
  });

  testWidgets('ready cloud computer shows the live desktop surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        NeoAgentController(
            backendClient: BackendClient(),
            healthBridge: HealthBridge(),
          )
          ..computerRuntime = const <String, dynamic>{'state': 'user_control'}
          ..computerDisplayUrl = 'https://example.test/api/computer/display/token';
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DevicesPanel(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.byType(ComputerDisplay), findsOneWidget);
    expect(
      find.textContaining('interactive Linux desktop'),
      findsOneWidget,
    );
  });

  testWidgets('viewing an agent-controlled computer does not interrupt it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backendClient = _ComputerControlBackendClient();
    final controller = NeoAgentController(
      backendClient: backendClient,
      healthBridge: HealthBridge(),
    )..computerRuntime = const <String, dynamic>{'state': 'agent_control'};
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

    expect(find.text('View desktop'), findsOneWidget);
    expect(find.text('Interrupt AI'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('computer-ai-activity-glow')),
      findsOneWidget,
    );

    await tester.tap(find.text('View desktop'));
    await tester.pump();

    expect(backendClient.displaySessionCount, 1);
    expect(backendClient.acquiredControl, isFalse);
    expect(find.byType(ComputerDisplay), findsOneWidget);
    expect(find.text('Interrupt AI'), findsOneWidget);

    await tester.tap(find.text('Interrupt AI'));
    await tester.pump();

    expect(backendClient.acquiredControl, isTrue);
    expect(backendClient.displaySessionCount, 2);
    expect(controller.computerRuntime['state'], 'user_control');
    expect(
      find.byKey(const ValueKey<String>('computer-ai-activity-glow')),
      findsNothing,
    );
  });

  testWidgets('a starting cloud computer hides the guest boot console', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        NeoAgentController(
            backendClient: BackendClient(),
            healthBridge: HealthBridge(),
          )
          ..computerRuntime = const <String, dynamic>{'state': 'starting'}
          ..computerDisplayUrl = 'https://example.test/api/computer/display/token';
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DevicesPanel(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.byType(ComputerDisplay), findsNothing);
    expect(find.text('Starting your computer'), findsWidgets);
  });

  testWidgets('a failed desktop replaces the blank display with a repair action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        NeoAgentController(
            backendClient: BackendClient(),
            healthBridge: HealthBridge(),
          )
          ..computerRuntime = const <String, dynamic>{
            'state': 'user_control',
            'desktop': <String, dynamic>{
              'available': false,
              'error': 'Xorg did not create :0',
            },
          }
          ..computerDisplayUrl = 'https://example.test/api/computer/display/token';
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DevicesPanel(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.byType(ComputerDisplay), findsNothing);
    expect(find.text('The desktop did not start'), findsOneWidget);
    expect(find.text('Xorg did not create :0'), findsWidgets);
    expect(find.text('Repair desktop'), findsOneWidget);
  });

  testWidgets('first-time setup is only shown when the guest image is missing', (
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

    controller.computerRuntime = const <String, dynamic>{
      'state': 'starting',
      'readiness': <String, dynamic>{'imageReady': false},
    };
    controller.notifyListeners();
    await tester.pump();
    expect(find.text('Preparing your computer'), findsWidgets);

    controller.computerRuntime = const <String, dynamic>{
      'state': 'starting',
      'readiness': <String, dynamic>{'imageReady': true},
    };
    controller.notifyListeners();
    await tester.pump();
    expect(find.text('Starting your computer'), findsWidgets);
    expect(find.text('Preparing your computer'), findsNothing);
  });

  testWidgets(
    'embedded computer uses the desktop without duplicate navigation',
    (tester) async {
      tester.view.physicalSize = const Size(680, 900);
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
            body: DevicesPanel(
              controller: controller,
              computerOnly: true,
              showProviderPicker: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Devices'), findsNothing);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Your Linux computer'), findsOneWidget);
      expect(find.text('Start computer'), findsOneWidget);
    },
  );
}
