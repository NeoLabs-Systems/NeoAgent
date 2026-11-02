import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

import '../support/scripted_http_client.dart';

Future<void> openServer(WidgetTester tester, ScriptedHttpClient http) async {
  tester.view.physicalSize = const Size(1400, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
  await tester.tap(find.text('Server'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Map<String, dynamic> updateJson({
  String? blockedReason,
  String? available,
  String state = 'idle',
  int progress = 0,
  String message = '',
  String channel = 'beta',
}) {
  return <String, dynamic>{
    'version': '1.2.3',
    'channel': channel,
    'selfUpdate': blockedReason == null,
    'blockedReason': blockedReason,
    'checkedAt': DateTime.now().toUtc().toIso8601String(),
    'checkFailed': false,
    'available': available == null
        ? null
        : <String, dynamic>{
            'version': available,
            'branch': 'beta',
            'changes': <String>['Faster chats'],
          },
    'job': <String, dynamic>{
      'state': state,
      'progress': progress,
      'message': message,
      'versionAfter': available,
      'logs': <String>[],
      if (state == 'completed') 'completedAt': DateTime.now().toUtc().toIso8601String(),
    },
  };
}

void main() {
  testWidgets(
    'Docker shows host commands and offers no update controls',
    (tester) async {
      final http = ScriptedHttpClient(
        (method, uri, body) => jsonResponse(
          200,
          uri.path == '/api/admin/update'
              ? updateJson(blockedReason: 'container')
              : uri.path == '/api/admin/version'
              ? <String, dynamic>{
                  'version': '1.2.3',
                  'containerImage': true,
                  'deploymentMode': 'self_hosted',
                }
              : <String, dynamic>{},
        ),
      );
      await openServer(tester, http);
      expect(find.text('Docker'), findsOneWidget);
      expect(
        find.text('docker compose pull\ndocker compose up -d'),
        findsOneWidget,
      );
      expect(find.text('Update now'), findsNothing);
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .onSelectionChanged,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a new version is offered in a banner, followed through the restart and reported',
    (tester) async {
      var started = false;
      var disconnected = false;
      var completed = false;
      final http = ScriptedHttpClient((method, uri, body) {
        if (uri.path == '/api/admin/update' && method == 'POST') {
          started = true;
          return jsonResponse(
            202,
            updateJson(available: '1.3.0', state: 'running', progress: 1),
          );
        }
        if (uri.path != '/api/admin/update') {
          return jsonResponse(200, <String, dynamic>{});
        }
        if (disconnected) throw const BackendException('Server is restarting');
        if (completed) {
          return jsonResponse(
            200,
            updateJson(available: '1.3.0', state: 'completed', progress: 100),
          );
        }
        return jsonResponse(
          200,
          started
              ? updateJson(
                  available: '1.3.0',
                  state: 'running',
                  progress: 47,
                  message: 'Installing it',
                )
              : updateJson(available: '1.3.0'),
        );
      });
      await openServer(tester, http);
      expect(find.text('Version 1.3.0 is ready'), findsWidgets);

      await tester.tap(find.text('Update now').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update now').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(started, true);
      expect(find.text('Updating to 1.3.0'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Installing it'), findsOneWidget);

      disconnected = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Restarting NeoAgent…'), findsOneWidget);

      disconnected = false;
      completed = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Updated to 1.3.0'), findsOneWidget);
      expect(find.text('Restarting NeoAgent…'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
