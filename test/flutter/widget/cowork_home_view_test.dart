import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

const String _chatId = 'chat-1';

Map<String, dynamic> _chatJson() => <String, dynamic>{
  'id': _chatId,
  'agentId': 'agent-1',
  'agentName': 'Builder',
  'title': 'Ship the cowork upgrade',
  'mode': 'agent',
  'workspacePathOverride': '/Users/neo/Projects/NeoAgent',
  'device': <String, dynamic>{
    'override': 'local',
    'setting': 'cloud',
    'effective': 'local',
    'inherited': false,
    'available': true,
    'providers': <String, dynamic>{
      'cloud': <String, dynamic>{'available': true},
      'local': <String, dynamic>{'available': true, 'connected': true},
    },
  },
  'createdAt': '2026-09-01T09:00:00Z',
  'updatedAt': '2026-09-01T09:05:00Z',
  'messageCount': 2,
  'pendingInputCount': 0,
  'latestRun': <String, dynamic>{
    'id': 'run-1',
    'status': 'completed',
    'title': 'Ship the cowork upgrade',
    'mode': 'agent',
    'model': 'anthropic:claude',
    'totalTokens': 2500,
  },
};

class _CoworkBackendClient extends BackendClient {
  @override
  Future<Map<String, dynamic>> fetchCoworkChat(
    String baseUrl,
    String conversationId,
  ) async {
    return <String, dynamic>{
      'chat': _chatJson(),
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'role': 'user',
          'runId': 'run-1',
          'content': 'Fix the flaky startup test.',
          'metadata': <String, dynamic>{},
          'createdAt': '2026-09-01T09:00:00Z',
        },
        <String, dynamic>{
          'id': 2,
          'role': 'assistant',
          'runId': 'run-1',
          'agentName': 'Builder',
          'content': 'The startup test is fixed and green.',
          'metadata': <String, dynamic>{},
          'createdAt': '2026-09-01T09:04:00Z',
        },
      ],
      'inputRequests': <Map<String, dynamic>>[],
      'activity': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'run-1',
          'status': 'completed',
          'createdAt': '2026-09-01T09:00:00Z',
          'steps': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'step-1',
              'index': 0,
              'type': 'tool',
              'status': 'completed',
              'toolName': 'read_file',
              'toolInput': <String, dynamic>{'path': 'README.md'},
              'result': <String, dynamic>{'content': '# NeoAgent'},
              'startedAt': '2026-09-01T09:00:10Z',
              'completedAt': '2026-09-01T09:00:10Z',
            },
            <String, dynamic>{
              'id': 'step-2',
              'index': 1,
              'type': 'tool',
              'status': 'completed',
              'toolName': 'edit_file',
              'toolInput': <String, dynamic>{'path': 'lib/main.dart'},
              'result': <String, dynamic>{'message': 'Applied 1 edit.'},
              'startedAt': '2026-09-01T09:01:00Z',
              'completedAt': '2026-09-01T09:01:00Z',
            },
          ],
          'events': <Map<String, dynamic>>[],
        },
      ],
      'changes': <Map<String, dynamic>>[
        <String, dynamic>{
          'path': 'lib/main.dart',
          'action': 'edited',
          'edits': 1,
          'runId': 'run-1',
          'changedAt': '2026-09-01T09:01:00Z',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchWorkspaceDirectory(
    String baseUrl, {
    String path = '.',
    String? deviceTarget,
    String? workspaceRoot,
  }) async {
    return <String, dynamic>{
      'path': path == '.' ? '' : path,
      'entries': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'lib', 'path': 'lib', 'type': 'directory'},
        <String, dynamic>{
          'name': 'README.md',
          'path': 'README.md',
          'type': 'file',
          'size': 120,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchWorkspaceFile(
    String baseUrl, {
    required String path,
    String? deviceTarget,
    String? workspaceRoot,
  }) async {
    return <String, dynamic>{'path': path, 'content': 'hello\nworld'};
  }

  @override
  Future<Map<String, dynamic>> fetchComputerStatus(
    String baseUrl, {
    String? deviceTarget,
  }) async {
    return <String, dynamic>{'state': 'stopped'};
  }
}

Future<NeoAgentController> _mount(
  WidgetTester tester, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = NeoAgentController(
    backendClient: _CoworkBackendClient(),
    healthBridge: HealthBridge(),
  );
  addTearDown(controller.dispose);
  controller.socketConnected = true;
  controller.coworkChats = <CoworkChat>[CoworkChat.fromJson(_chatJson())];

  await tester.pumpWidget(
    MaterialApp(
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => CoworkHomeView(controller: controller),
      ),
    ),
  );
  await tester.pump();
  await controller.selectCoworkChat(_chatId);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return controller;
}

void main() {
  testWidgets('wide layout shows sessions, transcript activity and workbench', (
    tester,
  ) async {
    await _mount(tester, size: const Size(1480, 960));

    // Sessions rail with the chat and its folder.
    expect(find.text('SESSIONS'), findsOneWidget);
    expect(find.text('Ship the cowork upgrade'), findsWidgets);

    // Header context: folder, device and latest-run usage.
    expect(find.text('NeoAgent'), findsWidgets);
    expect(find.text('This device'), findsOneWidget);
    expect(find.text('2.5k tokens'), findsOneWidget);

    // Transcript with the reply and the collapsed activity group.
    expect(
      find.textContaining('The startup test is fixed', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('2 steps · 1 file edited'), findsOneWidget);
    await tester.tap(find.text('2 steps · 1 file edited'));
    await tester.pump();
    expect(find.text('Read README.md'), findsOneWidget);
    expect(find.text('Edited lib/main.dart'), findsOneWidget);

    // Composer controls.
    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Default model'), findsOneWidget);

    // Workbench: changes and files.
    expect(find.text('Changes · 1'), findsOneWidget);
    await tester.tap(find.text('Changes · 1'));
    await tester.pump();
    expect(find.text('1 file changed'), findsOneWidget);
    expect(find.text('main.dart'), findsOneWidget);

    await tester.tap(find.text('Files'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('lib'), findsOneWidget);
    expect(find.text('README.md'), findsOneWidget);
    await tester.tap(find.text('README.md'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('world'), findsOneWidget);
  });

  testWidgets('compact layout collapses the rail behind a toggle', (
    tester,
  ) async {
    await _mount(tester, size: const Size(700, 820));

    expect(find.text('SESSIONS'), findsNothing);
    expect(find.byTooltip('Sessions'), findsOneWidget);
    expect(find.text('Agent'), findsOneWidget);

    await tester.tap(find.byTooltip('Sessions'));
    await tester.pump();
    expect(find.text('SESSIONS'), findsOneWidget);
  });
}
