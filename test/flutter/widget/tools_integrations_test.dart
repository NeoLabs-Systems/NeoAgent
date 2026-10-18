import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

import '../support/scripted_http_client.dart';

Map<String, dynamic> _account(int id, String email, {String status = 'connected'}) =>
    <String, dynamic>{
      'id': id,
      'status': status,
      'connected': status == 'connected',
      'accountEmail': email,
    };

Map<String, dynamic> _app(String id, List<Map<String, dynamic>> accounts) {
  final connected = accounts.where((a) => a['connected'] == true).length;
  return <String, dynamic>{
    'id': id,
    'label': id[0].toUpperCase() + id.substring(1),
    'accounts': accounts,
    'connection': <String, dynamic>{
      'status': connected > 0 ? 'connected' : 'not_connected',
      'connected': connected > 0,
      'accountCount': connected,
    },
  };
}

Map<String, dynamic> _provider(
  String id,
  String label,
  List<Map<String, dynamic>> apps, {
  bool signInCoversAllApps = false,
}) {
  final accounts = apps.fold<int>(
    0,
    (sum, app) => sum + ((app['connection'] as Map)['accountCount'] as int),
  );
  return <String, dynamic>{
    'id': id,
    'label': label,
    'icon': 'google',
    'description': '$label description',
    'apps': apps,
    'env': <String, dynamic>{'configured': true, 'summary': ''},
    'signInCoversAllApps': signInCoversAllApps,
    'connection': <String, dynamic>{
      'status': accounts > 0 ? 'connected' : 'not_connected',
      'connected': accounts > 0,
      'accountCount': accounts,
    },
  };
}

void main() {
  Future<NeoAgentController> pumpTools(
    WidgetTester tester, {
    bool signInCoversAllApps = false,
  }) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
    final controller = NeoAgentController(
      backendClient: BackendClient(
        httpClient: ScriptedHttpClient(
          (method, uri, body) => jsonResponse(200, <String, dynamic>{}),
        ),
      ),
      healthBridge: HealthBridge(),
    );
    controller.backendUrl = 'http://localhost:3333';
    controller.officialIntegrations = <Map<String, dynamic>>[
      // One Google account connected to three apps is stored as three
      // connections; the second account is on Gmail only.
      _provider('google_workspace', 'Google Workspace', <Map<String, dynamic>>[
        _app('gmail', <Map<String, dynamic>>[
          _account(1, 'me@example.com'),
          _account(4, 'work@example.com'),
        ]),
        _app('calendar', <Map<String, dynamic>>[_account(2, 'me@example.com')]),
        _app('docs', <Map<String, dynamic>>[
          _account(3, 'me@example.com', status: 'expired'),
        ]),
        _app('sheets', const <Map<String, dynamic>>[]),
      ], signInCoversAllApps: signInCoversAllApps),
      _provider('trello', 'Trello', <Map<String, dynamic>>[
        _app('boards', const <Map<String, dynamic>>[]),
      ]),
    ].map(OfficialIntegrationItem.fromJson).toList();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ToolsPanel(controller: controller))),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('integrations split into connected and available cards', (
    tester,
  ) async {
    await pumpTools(tester);

    expect(find.text('Integrations'), findsOneWidget);
    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('MCP servers'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    // The expired Docs connection marks the card, and the apps that work
    // are named on it.
    expect(find.text('Reconnect needed'), findsOneWidget);
    expect(find.text('Gmail · Calendar'), findsOneWidget);
  });

  testWidgets('detail lists each account once across apps', (tester) async {
    await pumpTools(tester);
    await tester.tap(find.text('Google Workspace'));
    await tester.pumpAndSettle();

    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.text('work@example.com'), findsOneWidget);
    expect(
      find.textContaining('Gmail · Calendar · Reconnect needed: Docs'),
      findsOneWidget,
    );
    // Connected apps get no button of their own; Docs reconnects, Sheets
    // connects, and one menu adds accounts.
    Finder inDialog(String text) =>
        find.descendant(of: find.byType(Dialog), matching: find.text(text));
    expect(inDialog('Reconnect'), findsOneWidget);
    expect(inDialog('Connect'), findsOneWidget);
    expect(inDialog('Add Account'), findsOneWidget);
  });

  testWidgets('a sign-in that covers every app needs no per-app buttons', (
    tester,
  ) async {
    await pumpTools(tester, signInCoversAllApps: true);
    await tester.tap(find.text('Google Workspace'));
    await tester.pumpAndSettle();

    Finder inDialog(String text) =>
        find.descendant(of: find.byType(Dialog), matching: find.text(text));
    expect(find.text('me@example.com'), findsOneWidget);
    expect(inDialog('Connect'), findsNothing);
    expect(inDialog('Reconnect'), findsNothing);
    expect(inDialog('Add Account'), findsOneWidget);
  });
}
