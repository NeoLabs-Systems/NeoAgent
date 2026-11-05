import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

class _AgentsBackendClient extends BackendClient {
  final savedPolicies = <String, String>{};
  final cancelled = <String>[];

  @override
  Future<Map<String, dynamic>> fetchAgentTasks(String baseUrl) async {
    return <String, dynamic>{
      'tasks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'task-1',
          'mode': 'delegate',
          'goal': 'Compare competitor prices',
          'status': 'working',
          'awaitingReply': true,
          'requester': <String, dynamic>{'id': 'main-id', 'name': 'Main'},
          'owner': <String, dynamic>{'id': 'scout-id', 'name': 'Scout'},
          'updatedAt': '2026-11-05T10:00:00Z',
        },
        <String, dynamic>{
          'id': 'task-2',
          'mode': 'handoff',
          'goal': 'Fix the login bug',
          'status': 'completed',
          'result': 'Fixed in the auth module.',
          'requester': <String, dynamic>{'id': 'main-id', 'name': 'Main'},
          'owner': <String, dynamic>{'id': 'scout-id', 'name': 'Scout'},
          'updatedAt': '2026-11-05T09:00:00Z',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchSecurityPolicies(String baseUrl) async {
    return <String, dynamic>{
      'policies': <String, dynamic>{'agent_creation': 'require_approval'},
    };
  }

  @override
  Future<Map<String, dynamic>> saveSecurityPolicy(
    String baseUrl, {
    required String category,
    required String policy,
  }) async {
    savedPolicies[category] = policy;
    return const <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> cancelAgentTask(
    String baseUrl,
    String id,
  ) async {
    cancelled.add(id);
    return const <String, dynamic>{};
  }
}

void main() {
  testWidgets(
    'agents page shows provenance, limits, the creation policy and work between agents',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = _AgentsBackendClient();
      final controller = NeoAgentController(
        backendClient: client,
        healthBridge: HealthBridge(),
      );
      addTearDown(controller.dispose);
      controller.agentProfiles = <AgentProfile>[
        AgentProfile.fromJson(<String, dynamic>{
          'id': 'main-id',
          'slug': 'main',
          'displayName': 'Main',
          'isDefault': true,
          'canDelegate': true,
        }),
        AgentProfile.fromJson(<String, dynamic>{
          'id': 'scout-id',
          'slug': 'scout',
          'displayName': 'Scout',
          'responsibilities': 'Tracks competitors.',
          'createdByAgentId': 'main-id',
          'creationReason': 'Competitor checks come up every week.',
          'toolRestrictions': <String, dynamic>{'shell': 'deny'},
        }),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AgentsPanel(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tracks competitors.'), findsOneWidget);
      expect(
        find.text('Set up by Main: Competitor checks come up every week.'),
        findsOneWidget,
      );
      expect(find.textContaining('Not allowed: '), findsOneWidget);

      expect(find.text('Main asked Scout'), findsOneWidget);
      expect(find.text('Needs an answer'), findsOneWidget);
      expect(find.text('Main handed over to Scout'), findsOneWidget);
      expect(find.text('Fixed in the auth module.'), findsNothing);
      await tester.tap(find.text('Show result'));
      await tester.pumpAndSettle();
      expect(find.text('Fixed in the auth module.'), findsOneWidget);

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(client.cancelled, <String>['task-1']);

      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(client.savedPolicies['agent_creation'], 'allow');
      expect(controller.agentCreationPolicy, 'allow');
    },
  );
}
