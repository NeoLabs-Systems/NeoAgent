import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

void main() {
  testWidgets(
    'desktop setup keeps manual addresses advanced and defaults to Quickstart',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      tester.view.physicalSize = const Size(1100, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = NeoAgentController(
        backendClient: BackendClient(),
        healthBridge: HealthBridge(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: BackendSetupView(controller: controller)),
      );
      await tester.pump();

      expect(find.text('Set up NeoAgent on this computer'), findsOneWidget);
      expect(find.text('Nearby NeoAgent servers'), findsOneWidget);
      expect(find.text('Enter an address manually'), findsOneWidget);
      expect(find.text('NeoAgent server address'), findsNothing);

      await tester.tap(find.text('Set up NeoAgent on this computer'));
      await tester.pump();
      expect(find.text('Quickstart'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Start Quickstart'), findsOneWidget);

      await tester.tap(find.text('Full setup'));
      await tester.pump();
      expect(find.text('Start full setup'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(home: ServerPanel(controller: controller)),
      );
      await tester.pump();
      expect(find.text('NeoAgent on this computer'), findsOneWidget);
      expect(
        find.textContaining('terminal commands are not required'),
        findsOneWidget,
      );
      expect(find.text('Node.js'), findsNothing);
      expect(find.text('npm'), findsNothing);
      expect(find.text('Git'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
