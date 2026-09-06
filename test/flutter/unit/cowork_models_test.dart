import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  _coworkUpgradeTests();
  test('Cowork chat keeps the per-chat mode and device override', () {
    final chat = CoworkChat.fromJson(<String, dynamic>{
      'id': 'chat-1',
      'agentId': 'agent-1',
      'agentName': 'Builder',
      'title': 'Implement desktop mode',
      'mode': 'plan',
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
    });

    expect(chat.mode, CoworkInteractionMode.plan);
    expect(chat.device.override, 'local');
    expect(chat.device.setting, 'cloud');
    expect(chat.device.effective, 'local');
    expect(chat.device.inherited, isFalse);
    expect(chat.device.localAvailable, isTrue);
  });

  test('Cowork structured questions expose options and pending state', () {
    final request = CoworkInputRequest.fromJson(<String, dynamic>{
      'id': 'request-1',
      'conversationId': 'chat-1',
      'runId': 'run-1',
      'status': 'pending',
      'schema': <String, dynamic>{
        'questions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'scope',
            'header': 'Scope',
            'question': 'Which scope?',
            'allowCustom': true,
            'options': <Map<String, dynamic>>[
              <String, dynamic>{
                'label': 'Desktop',
                'description': 'Desktop only.',
                'recommended': true,
              },
              <String, dynamic>{
                'label': 'All clients',
                'description': 'Every client.',
              },
            ],
          },
        ],
      },
    });

    expect(request.isPending, isTrue);
    expect(request.questions, hasLength(1));
    expect(request.questions.single.options.first.recommended, isTrue);
    expect(request.questions.single.allowCustom, isTrue);
  });
}

void _coworkUpgradeTests() {
  test('Cowork chat exposes the model override and workspace label', () {
    final chat = CoworkChat.fromJson(<String, dynamic>{
      'id': 'chat-2',
      'agentId': 'agent-1',
      'agentName': 'Builder',
      'title': 'Ship it',
      'modelOverride': 'openai:gpt-5',
      'workspacePathOverride': '/Users/neo/Projects/NeoAgent',
      'device': <String, dynamic>{'effective': 'local'},
      'latestRun': <String, dynamic>{
        'id': 'run-1',
        'status': 'completed',
        'model': 'openai:gpt-5',
        'totalTokens': 4321,
      },
    });

    expect(chat.modelOverride, 'openai:gpt-5');
    expect(chat.workspaceLabel, 'NeoAgent');
    expect(chat.isLocal, isTrue);
    expect(chat.latestRun?.model, 'openai:gpt-5');
    expect(chat.latestRun?.totalTokens, 4321);
  });

  test('Changed files derive name and directory from the path', () {
    final change = CoworkChangedFile.fromJson(<String, dynamic>{
      'path': 'server/services/cowork/changes.js',
      'action': 'written',
      'edits': 2,
      'runId': 'run-1',
      'changedAt': '2026-09-01T10:00:00Z',
    });
    expect(change.name, 'changes.js');
    expect(change.directory, 'server/services/cowork');
    expect(change.action, 'written');
    expect(change.edits, 2);
  });

  test('Activity items classify tools and expose the target path', () {
    final edit = CoworkActivityItem(
      id: 'step-1',
      runId: 'run-1',
      kind: 'tool',
      label: 'edit_file',
      status: 'completed',
      summary: '',
      createdAt: DateTime(2026, 9, 1),
      toolArgs: <String, dynamic>{'file_path': 'lib/main.dart'},
    );
    expect(edit.isWriteTool, isTrue);
    expect(edit.filePath, 'lib/main.dart');
    expect(edit.copyWith(status: 'failed').isFailed, isTrue);
    expect(edit.copyWith(status: 'failed').toolArgs, edit.toolArgs);

    final command = CoworkActivityItem(
      id: 'step-2',
      runId: 'run-1',
      kind: 'tool',
      label: 'execute_command',
      status: 'running',
      summary: '',
      createdAt: DateTime(2026, 9, 1),
    );
    expect(command.isCommand, isTrue);
    expect(command.isRunning, isTrue);
    expect(command.filePath, isNull);
  });

  test('Thread state filters activity per run and keeps changes on copy', () {
    final thread = CoworkThreadState(
      activity: <CoworkActivityItem>[
        CoworkActivityItem(
          id: 'a',
          runId: 'run-1',
          kind: 'tool',
          label: 'read_file',
          status: 'completed',
          summary: '',
          createdAt: DateTime(2026, 9, 1),
        ),
        CoworkActivityItem(
          id: 'b',
          runId: 'run-2',
          kind: 'tool',
          label: 'write_file',
          status: 'completed',
          summary: '',
          createdAt: DateTime(2026, 9, 1),
        ),
      ],
      changes: <CoworkChangedFile>[
        CoworkChangedFile(
          path: 'a.txt',
          action: 'edited',
          edits: 1,
          runId: 'run-2',
          changedAt: DateTime(2026, 9, 1),
        ),
      ],
      activeRunId: 'run-2',
      runStatus: 'running',
    );
    expect(thread.activityForRun('run-2').map((item) => item.id), <String>['b']);
    expect(thread.copyWith(phase: 'Working').changes.length, 1);
    expect(thread.copyWith(clearActiveRunId: true).hasLiveRun, isFalse);
  });
}
