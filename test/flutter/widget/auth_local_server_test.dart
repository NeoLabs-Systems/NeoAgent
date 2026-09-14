import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';
import 'package:neoagent_flutter/src/local_runtime_manager.dart';

/// An installed runtime that is not answering — the case the shortcut is for.
class _StoppedRuntimeManager extends LocalRuntimeManager {
  @override
  Future<LocalRuntimeStatus> inspect() async => const LocalRuntimeStatus(
    installed: true,
    running: false,
    version: '3.4.8',
    backendUrl: 'http://localhost:8081',
    releaseChannel: 'stable',
  );
}

Future<void> _pumpAuthView(WidgetTester tester, String backendUrl) async {
  tester.view.physicalSize = const Size(1400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = NeoAgentController(
    backendClient: BackendClient(),
    healthBridge: HealthBridge(),
  );
  addTearDown(controller.dispose);
  controller.backendUrl = backendUrl;
  controller.hasUser = true;

  await tester.pumpWidget(
    MaterialApp(
      home: AuthView(
        controller: controller,
        runtimeManager: _StoppedRuntimeManager(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a stopped self-hosted server offers repair from the login', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _pumpAuthView(tester, 'http://127.0.0.1:8081');

    expect(
      find.text('The server on this computer is not running'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('signing in to a remote server offers no local repair', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _pumpAuthView(tester, 'https://neoagent.example.com');

    expect(
      find.text('The server on this computer is not running'),
      findsNothing,
    );
    expect(find.text('Server on this computer'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a phone signing in to the same address gets no repair button', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _pumpAuthView(tester, 'http://127.0.0.1:8081');

    expect(
      find.text('The server on this computer is not running'),
      findsNothing,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
