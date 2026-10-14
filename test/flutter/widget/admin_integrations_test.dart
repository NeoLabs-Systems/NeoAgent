import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

import '../support/scripted_http_client.dart';

void main() {
  testWidgets('integration switches discard and save typed boolean changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var enabled = true;
    final saves = <Map<String, dynamic>>[];
    final http = ScriptedHttpClient((method, uri, body) {
      if (uri.path != '/api/admin/config/integrations') {
        return jsonResponse(200, <String, dynamic>{});
      }
      if (method == 'PUT') {
        final payload = jsonDecode(body! as String) as Map<String, dynamic>;
        saves.add(payload);
        final integrations = payload['integrations'] as Map<String, dynamic>;
        final openrouter = integrations['openrouter'] as Map<String, dynamic>;
        enabled = openrouter['enabled'] as bool;
        return jsonResponse(200, <String, dynamic>{'ok': true});
      }
      return jsonResponse(200, <String, dynamic>{
        'integrations': <Map<String, dynamic>>[
          <String, dynamic>{
            'key': 'google',
            'label': 'Google Workspace',
            'configured': true,
            'fields': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'clientId',
                'value': 'google-client-id',
                'secret': false,
              },
              <String, dynamic>{
                'name': 'clientSecret',
                'configured': true,
                'secret': true,
              },
            ],
          },
          <String, dynamic>{
            'key': 'openrouter',
            'label': 'OpenRouter account sign-in',
            'description': 'Allow registration, login, and account linking.',
            'configured': enabled,
            'fields': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'enabled',
                'type': 'boolean',
                'value': enabled,
              },
            ],
          },
        ],
        'liveVoice': <String, dynamic>{},
      });
    });
    final controller = NeoAgentController(
      backendClient: BackendClient(httpClient: http),
      healthBridge: HealthBridge(),
    );
    controller.backendUrl = 'http://localhost:3333';
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminPanel(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Integrations'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('GOOGLE WORKSPACE'), findsOneWidget);
    expect(find.text('OPENROUTER ACCOUNT SIGN-IN'), findsOneWidget);
    expect(
      find.text('Allow registration, login, and account linking.'),
      findsOneWidget,
    );
    final toggle = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(toggle).value, true);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, false);
    await tester.tap(find.text('Discard').first);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, true);
    expect(saves, isEmpty);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes').first);
    await tester.pumpAndSettle();
    expect(saves, <Map<String, dynamic>>[
      <String, dynamic>{
        'integrations': <String, dynamic>{
          'openrouter': <String, dynamic>{'enabled': false},
        },
      },
    ]);
    expect(tester.widget<SwitchListTile>(toggle).value, false);
    expect(find.text('Disabled'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes').first);
    await tester.pumpAndSettle();
    expect(enabled, true);
    expect(tester.widget<SwitchListTile>(toggle).value, true);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
