import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/scripted_http_client.dart';

const Map<String, dynamic> _sharedUsage = <String, dynamic>{
  'participants': <String, dynamic>{'sharing': 3, 'total': 8},
  'audience': <String, dynamic>{
    'platforms': <Map<String, dynamic>>[
      <String, dynamic>{'label': 'android', 'count': 2},
      <String, dynamic>{'label': 'web', 'count': 1},
    ],
    'appVersions': <Map<String, dynamic>>[
      <String, dynamic>{'label': '3.6.1', 'count': 3},
    ],
    'languages': <Map<String, dynamic>>[
      <String, dynamic>{'label': 'de', 'count': 2},
    ],
    'regions': <Map<String, dynamic>>[
      <String, dynamic>{'label': 'Europe', 'count': 3},
    ],
  },
  'features': <Map<String, dynamic>>[
    <String, dynamic>{'key': 'scheduledTasks', 'users': 2},
    <String, dynamic>{'key': 'memory', 'users': 3},
  ],
  'integrations': <Map<String, dynamic>>[
    <String, dynamic>{'label': 'google', 'count': 1},
  ],
  'messaging': <Map<String, dynamic>>[
    <String, dynamic>{'label': 'telegram', 'count': 1},
  ],
  'tools': <Map<String, dynamic>>[
    <String, dynamic>{'tool': 'execute_command', 'calls': 40, 'failures': 10},
  ],
  'triggers': <Map<String, dynamic>>[
    <String, dynamic>{'label': 'agent_delegation', 'count': 4},
  ],
  'activity': <Map<String, dynamic>>[
    <String, dynamic>{'weekday': 1, 'hour': 9, 'runs': 5},
  ],
  'outcomes': <String, dynamic>{
    'runs': 12,
    'successRate': 75,
    'avgDurationSeconds': 84,
    'avgTokens': 5300,
    'avgSteps': 4.5,
  },
  'models': <Map<String, dynamic>>[
    <String, dynamic>{
      'provider': 'openai',
      'model': 'gpt-5',
      'calls': 20,
      'avgLatencyMs': 1800,
      'inputTokens': 1000,
      'cachedTokens': 400,
      'outputTokens': 300,
      'costUsd': 0.42,
    },
  ],
};

Future<void> _openAnalytics(
  WidgetTester tester,
  Map<String, dynamic> sharedUsage, {
  required double width,
}) async {
  tester.view.physicalSize = Size(width, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final http = ScriptedHttpClient(
    (method, uri, body) => jsonResponse(
      200,
      uri.path == '/api/admin/analytics'
          ? <String, dynamic>{
              'stats': <String, dynamic>{},
              'sharedUsage': sharedUsage,
            }
          : <String, dynamic>{},
    ),
  );
  final controller = NeoAgentController(
    backendClient: BackendClient(httpClient: http),
    healthBridge: HealthBridge(),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AdminPanel(controller: controller)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Analytics').first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  // 600px stacks every pair; 1400px shows them side by side.
  for (final width in <double>[600, 1400]) {
    testWidgets('admin analytics renders shared usage at ${width.toInt()}px', (
      tester,
    ) async {
      await _openAnalytics(tester, _sharedUsage, width: width);
      expect(find.text('SHARED USAGE'), findsOneWidget);
      expect(
        find.text('3 of 8 accounts share usage data. Totals only, no content.'),
        findsOneWidget,
      );
      expect(find.text('Android'), findsOneWidget);
      expect(find.text('Deutsch'), findsOneWidget);
      expect(find.text('execute_command'), findsOneWidget);
      expect(find.text('25% failed'), findsOneWidget);
      expect(find.text('Agent delegation'), findsOneWidget);
      expect(find.text('openai / gpt-5'), findsOneWidget);
      expect(find.text('Memory'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('admin analytics explains how to start when nobody shares', (
    tester,
  ) async {
    await _openAnalytics(tester, <String, dynamic>{
      'participants': <String, dynamic>{'sharing': 0, 'total': 4},
    }, width: 1400);
    expect(find.textContaining('Nobody shares usage data yet'), findsOneWidget);
    expect(find.text('FEATURE ADOPTION'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('turning sharing on asks first, then saves', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'NeoAgent',
      packageName: 'neoagent',
      version: '3.6.1',
      buildNumber: '1',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final http = ScriptedHttpClient(
      (method, uri, body) => jsonResponse(
        200,
        uri.path == '/api/account/data-sharing'
            ? <String, dynamic>{
                'dataSharing': <String, dynamic>{
                  'enabled': true,
                  'since': '2026-10-17T09:00:00.000Z',
                  'client': null,
                },
              }
            : <String, dynamic>{},
      ),
    );
    final controller = NeoAgentController(
      backendClient: BackendClient(httpClient: http),
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => SingleChildScrollView(
              child: AccountSettingsPanel(
                controller: controller,
                page: SettingsPage.profile,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("What's shared"));
    await tester.pumpAndSettle();
    expect(find.text('Messages, prompts and replies'), findsOneWidget);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(find.text('Share usage data?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(
      http.requests.where((r) => r.$2.path == '/api/account/data-sharing'),
      isEmpty,
    );

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    final saved = http.requests.singleWhere(
      (r) => r.$2.path == '/api/account/data-sharing',
    );
    expect(saved.$1, 'PUT');
    final payload = saved.$3 is String
        ? jsonDecode(saved.$3! as String) as Map<String, dynamic>
        : saved.$3! as Map<String, dynamic>;
    expect(payload['enabled'], isTrue);
    expect((payload['client'] as Map)['appVersion'], '3.6.1');
    expect(controller.sharesUsageData, isTrue);
    expect(find.textContaining('Sharing since'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
