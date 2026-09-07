import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

/// Pumps the app shell at [size] and returns the controller driving it.
Future<NeoAgentController> pumpShell(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // The chat composer's dictation plugin has no implementation under test.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.llfbandit.record/messages'),
        (call) async => null,
      );

  final controller = NeoAgentController(
    backendClient: BackendClient(),
    healthBridge: HealthBridge(),
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => HomeView(controller: controller),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  testWidgets('a phone navigates by the four group tabs, not a drawer', (
    tester,
  ) async {
    final controller = await pumpShell(tester, const Size(390, 844));

    expect(find.byType(Drawer), findsNothing);
    expect(find.byIcon(Icons.menu), findsNothing);

    for (final group in SidebarGroup.values) {
      expect(
        find.text(group.label),
        findsWidgets,
        reason: '${group.label} should have a tab',
      );
    }

    await tester.tap(find.text(SidebarGroup.automation.label).last);
    await tester.pumpAndSettle();
    expect(controller.selectedSection, AppSection.devices);
  });

  testWidgets('a group opens its sections as chips on a phone', (tester) async {
    final controller = await pumpShell(tester, const Size(390, 844));

    controller.setSelectedSection(AppSection.devices);
    await tester.pumpAndSettle();

    // Every section in Automation stays reachable from the chip row; the row
    // scrolls when the group is long, so later chips need a drag first.
    expect(find.text('Tasks'), findsWidgets);
    await tester.dragUntilVisible(
      find.text('Memory'),
      find.byKey(const ValueKey<String>('mobile-section-chips')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Memory').first);
    await tester.pumpAndSettle();
    expect(controller.selectedSection, AppSection.memory);
  });

  testWidgets('account settings is reachable on a phone without the drawer', (
    tester,
  ) async {
    final controller = await pumpShell(tester, const Size(390, 844));

    controller.setSelectedSection(AppSection.settings);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Account settings').first);
    await tester.pumpAndSettle();
    expect(controller.selectedSection, AppSection.accountSettings);
  });

  testWidgets('desktop keeps the sidebar and grows no bottom bar', (
    tester,
  ) async {
    await pumpShell(tester, const Size(1440, 900));

    expect(
      find.text('CONTROL SURFACE'),
      findsOneWidget,
    ); // the rail lockup only
    expect(find.byType(Drawer), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.bottomNavigationBar, isNull);
  });

  testWidgets('an empty chat greets with the date', (tester) async {
    await pumpShell(tester, const Size(1440, 900));

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('How can I help?'), findsNothing);
    expect(find.text('Summarise my last run'), findsOneWidget);
  });
}
