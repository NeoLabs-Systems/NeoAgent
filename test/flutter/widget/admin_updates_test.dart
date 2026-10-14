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

void main() {
  testWidgets(
    'Docker shows host commands and hides unavailable update controls',
    (tester) async {
      final http = ScriptedHttpClient(
        (method, uri, body) => jsonResponse(
          200,
          uri.path == '/api/admin/version'
              ? <String, dynamic>{
                  'version': '1.2.3',
                  'containerImage': true,
                  'allowSelfUpdate': false,
                  'deploymentMode': 'self_hosted',
                  'updateStatus': <String, dynamic>{'state': 'idle'},
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
      expect(find.text('Copy update commands'), findsOneWidget);
      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(find.text('Update now'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'progress survives a restart and stops polling after verified completion',
    (tester) async {
      var disconnected = false;
      var completed = false;
      var reads = 0;
      final http = ScriptedHttpClient((method, uri, body) {
        if (uri.path != '/api/admin/version')
          return jsonResponse(200, <String, dynamic>{});
        reads++;
        if (disconnected) throw const BackendException('Server is restarting');
        return jsonResponse(200, <String, dynamic>{
          'version': '1.2.3',
          'releaseChannel': 'beta',
          'allowSelfUpdate': true,
          'updateStatus': <String, dynamic>{
            'state': completed ? 'completed' : 'running',
            'progress': completed ? 100 : 79,
            'phase': completed ? 'completed' : 'verifying',
            'message': completed
                ? 'New version is ready'
                : 'Checking the restarted server',
            'releaseChannel': 'stable',
            'logs': <String>['Saved a backup'],
          },
        });
      });
      await openServer(tester, http);
      expect(find.text('Checking the restarted server'), findsOneWidget);
      expect(find.text('79% · verifying'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        <String>{'beta'},
      );
      disconnected = true;
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(
        find.textContaining('Waiting for the server to reconnect.'),
        findsOneWidget,
      );
      disconnected = false;
      completed = true;
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('New version is ready'), findsOneWidget);
      expect(
        find.textContaining('Waiting for the server to reconnect.'),
        findsNothing,
      );
      final completedReads = reads;
      await tester.pump(const Duration(seconds: 5));
      expect(reads, completedReads);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('a lost update response keeps polling until the server returns', (
    tester,
  ) async {
    var started = false;
    var disconnected = false;
    final http = ScriptedHttpClient((method, uri, body) {
      if (uri.path == '/api/settings/update' && method == 'POST') {
        started = true;
        disconnected = true;
        throw const BackendException('Connection closed during restart');
      }
      if (uri.path != '/api/admin/version')
        return jsonResponse(200, <String, dynamic>{});
      if (disconnected) throw const BackendException('Server is restarting');
      return jsonResponse(200, <String, dynamic>{
        'version': '1.2.3',
        'allowSelfUpdate': true,
        'updateStatus': <String, dynamic>{
          'state': started ? 'running' : 'idle',
          'progress': started ? 79 : 0,
          'message': started ? 'Verifying the server' : 'Ready to update',
        },
      });
    });
    await openServer(tester, http);
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update now').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(started, true);
    expect(
      find.textContaining('Waiting for the server to reconnect.'),
      findsOneWidget,
    );
    disconnected = false;
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('Verifying the server'), findsOneWidget);
    expect(
      find.textContaining('Waiting for the server to reconnect.'),
      findsNothing,
    );
    expect(
      find.textContaining('Connection closed during restart'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
