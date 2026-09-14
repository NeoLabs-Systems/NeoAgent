import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';
import 'package:neoagent_flutter/src/local_runtime_manager.dart';

/// Reports an installed local runtime without touching the real machine.
class _InstalledRuntimeManager extends LocalRuntimeManager {
  @override
  Future<LocalRuntimeStatus> inspect() async => const LocalRuntimeStatus(
    installed: true,
    running: true,
    version: '3.4.8',
    backendUrl: 'http://localhost:8081',
    releaseChannel: 'stable',
  );
}

class _MissingRuntimeManager extends LocalRuntimeManager {
  @override
  Future<LocalRuntimeStatus> inspect() async =>
      const LocalRuntimeStatus(installed: false, running: false);
}

Future<void> _pumpServerPanel(
  WidgetTester tester,
  String backendUrl, {
  LocalRuntimeManager? runtimeManager,
}) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = NeoAgentController(
    backendClient: BackendClient(),
    healthBridge: HealthBridge(),
  );
  addTearDown(controller.dispose);
  controller.backendUrl = backendUrl;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ServerPanel(
          controller: controller,
          runtimeManager: runtimeManager ?? _InstalledRuntimeManager(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('local actions appear when this window uses the local runtime', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    // Loopback spelled differently than the runtime reports it.
    await _pumpServerPanel(tester, 'http://127.0.0.1:8081');

    expect(find.text('Desktop app'), findsOneWidget);
    expect(find.text('View logs'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a remote backend gets neither the updater nor local logs', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _pumpServerPanel(tester, 'https://neoagent.example.com');

    expect(find.text('Desktop app'), findsNothing);
    expect(find.text('View logs'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a remote host that only looks like loopback stays locked out', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _pumpServerPanel(tester, 'https://localhost.attacker.example:8081');

    expect(find.text('Desktop app'), findsNothing);
    expect(find.text('View logs'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the same port on a remote host is not the local runtime', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _pumpServerPanel(tester, 'http://10.0.0.4:8081');

    expect(find.text('Desktop app'), findsNothing);
    expect(find.text('View logs'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a non-desktop client never renders the local actions', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _pumpServerPanel(tester, 'http://127.0.0.1:8081');

    expect(find.text('Desktop app'), findsNothing);
    expect(find.text('View logs'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the connected server address is stated once', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _pumpServerPanel(tester, 'http://127.0.0.1:8081');

    expect(find.text('This computer'), findsOneWidget);
    expect(find.text('http://127.0.0.1:8081'), findsOneWidget);
    // The runtime card does not repeat the address in its own spelling.
    expect(find.text('http://localhost:8081'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('installing is the only offer before a runtime exists', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _pumpServerPanel(
      tester,
      'https://neoagent.example.com',
      runtimeManager: _MissingRuntimeManager(),
    );

    // The install section opens itself, so its controls are already on screen.
    expect(find.text('Install NeoAgent'), findsOneWidget);
    expect(find.text('Quickstart'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Stop'), findsNothing);
    expect(find.text('View logs'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
