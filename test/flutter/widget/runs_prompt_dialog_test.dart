import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

class _PromptBackendClient extends BackendClient {
  @override
  Future<Map<String, dynamic>> fetchRunSteps(String baseUrl, String runId) async {
    return <String, dynamic>{
      'run': <String, dynamic>{
        'id': runId,
        'title': 'Check the deployment',
        'status': 'completed',
        'model': 'test/model',
        'created_at': '2026-08-09T10:00:00Z',
      },
      'steps': <dynamic>[],
      'events': <dynamic>[],
      'response': 'Deployment is healthy.',
    };
  }

  @override
  Future<Map<String, dynamic>> fetchRunPromptTurns(
    String baseUrl,
    String runId,
  ) async {
    return <String, dynamic>{
      'runId': runId,
      'turns': <dynamic>[
        <String, dynamic>{
          'requestId': 'req-1',
          'phase': 'model_turn',
          'iteration': 1,
          'provider': 'test',
          'model': 'test/model',
          'messageCount': 2,
          'toolCount': 1,
          'characters': 42,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchRunPrompt(
    String baseUrl,
    String runId,
    String requestId,
  ) async {
    return <String, dynamic>{
      'requestId': requestId,
      'sections': <dynamic>[
        <String, dynamic>{
          'role': 'system',
          'label': 'System prompt',
          'text': 'You are NeoAgent.',
          'characters': 17,
        },
        <String, dynamic>{
          'role': 'system',
          'label': 'Recalled context',
          'text': '- remembers the cat',
          'characters': 19,
        },
      ],
      'tools': <dynamic>[
        <String, dynamic>{'name': 'lookup', 'description': 'Look things up'},
      ],
    };
  }
}

void main() {
  testWidgets('run detail opens a popup with the full prompt', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = NeoAgentController(
      backendClient: _PromptBackendClient(),
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);
    controller.recentRuns = <RunSummary>[
      RunSummary(
        id: 'run-1',
        title: 'Check the deployment',
        status: 'completed',
        model: 'test/model',
        triggerSource: 'web',
        totalTokens: 120,
        createdAt: DateTime.utc(2026, 8, 9, 10),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => RunsPanel(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show full prompt'));
    await tester.pumpAndSettle();

    expect(find.text('Full prompt'), findsOneWidget);
    expect(find.text('System prompt'), findsOneWidget);
    expect(find.text('Recalled context'), findsOneWidget);
    expect(find.textContaining('You are NeoAgent.'), findsOneWidget);
    expect(find.textContaining('lookup'), findsOneWidget);
  });
}
