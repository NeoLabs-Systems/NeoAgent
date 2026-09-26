import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

const String _mainAgentId = 'agent-main';
const String _specialistAgentId = 'agent-specialist';

/// Holds the integrations response open so the selected agent can change while
/// the request is still in flight, which is what happens on startup when the
/// persisted agent is restored after the first refresh has already begun.
class _PendingIntegrationsClient extends BackendClient {
  final Completer<List<Map<String, dynamic>>> integrations =
      Completer<List<Map<String, dynamic>>>();
  final List<String?> requestedAgentIds = <String?>[];

  @override
  Future<Map<String, dynamic>> getAuthStatus(String baseUrl) async {
    return <String, dynamic>{
      'authenticated': true,
      'user': <String, dynamic>{'id': 1, 'username': 'neo'},
    };
  }

  @override
  Future<Map<String, dynamic>> fetchAgentProfiles(String baseUrl) async {
    return <String, dynamic>{
      'agents': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': _mainAgentId,
          'slug': 'main',
          'displayName': 'Main',
          'isDefault': true,
          'status': 'active',
        },
        <String, dynamic>{
          'id': _specialistAgentId,
          'slug': 'specialist',
          'displayName': 'Specialist',
          'isDefault': false,
          'status': 'active',
        },
      ],
      'defaultAgentId': _mainAgentId,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOfficialIntegrations(
    String baseUrl, {
    String? agentId,
  }) {
    requestedAgentIds.add(agentId);
    return integrations.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (_) async => null);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  test('a refresh started for one agent never applies to another', () async {
    final client = _PendingIntegrationsClient();
    final controller = NeoAgentController(
      backendClient: client,
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);
    controller.backendUrl = 'http://localhost:3999';
    controller.isAuthenticated = true;

    final refreshing = controller.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(client.requestedAgentIds, <String?>[_mainAgentId]);

    // The user switches bots while Main's response is still outstanding.
    controller.selectedAgentId = _specialistAgentId;
    client.integrations.complete(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'github',
        'label': 'GitHub',
        'connection': <String, dynamic>{'connected': true, 'accountCount': 1},
        'apps': <Map<String, dynamic>>[],
        'env': <String, dynamic>{'configured': true},
      },
    ]);
    await refreshing;

    expect(controller.selectedAgentId, _specialistAgentId);
    expect(controller.officialIntegrations, isEmpty);
  });
}
