import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/agent_import_service.dart';

void main() {
  final found = ImportSources.fromJson(<String, dynamic>{
    'parts': <String>[
      'keys',
      'memories',
      'skills',
      'model',
      'tasks',
      'mcp',
      'channels',
    ],
    'aiReady': false,
    'sources': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': '/home/neo/.openclaw',
        'label': 'OpenClaw',
        'path': '~/.openclaw',
        'needsHand': 2,
        'contents': <Map<String, dynamic>>[
          <String, dynamic>{
            'part': 'agents',
            'count': 1,
            'names': <String>['Jarvis'],
          },
          <String, dynamic>{
            'part': 'memories',
            'count': 4,
            'names': <String>[],
            'days': 3,
          },
          <String, dynamic>{
            'part': 'skills',
            'count': 1,
            'names': <String>['meal-planner'],
          },
        ],
      },
    ],
  });

  test('only parts a found install holds are offered', () {
    expect(found.offeredParts, <String>['memories', 'skills']);
    expect(found.sources.single.contents[1].days, 3);
    expect(found.sources.single.needsHand, 2);
  });

  test('the selection starts with everything and sends what is left', () {
    final selection = ImportSelection.everything(found);
    expect(selection.canRun, isTrue);
    selection.togglePart('skills', false);
    selection.finish = false;
    final json = selection.toJson();
    expect(json['sources'], <String>['/home/neo/.openclaw']);
    expect(json['parts'], isNot(contains('skills')));
    expect(json['parts'], contains('memories'));
    expect(json['finish'], isFalse);
    selection.toggleSource('/home/neo/.openclaw', false);
    expect(selection.canRun, isFalse);
  });

  test('the summary reads what the server reports', () {
    final summary = ImportSummary.fromJson(<String, dynamic>{
      'broughtOver': <String>['4 memories', '1 skill'],
      'alreadyThere': 2,
      'attention': <Map<String, dynamic>>[
        <String, dynamic>{
          'kind': 'Automation',
          'status': 'skipped',
          'name': 'Backup',
          'detail': 'runs a command',
        },
        <String, dynamic>{
          'kind': 'Skills',
          'status': 'failed',
          'name': 'OpenClaw',
          'detail': 'disk full',
        },
      ],
      'attentionTotal': 5,
      'reportFile': '/home/neo/.neoagent/imports/import.md',
      'finishTask': null,
      'restartRequired': true,
    });
    expect(summary.broughtOver, hasLength(2));
    expect(summary.attention.first.failed, isFalse);
    expect(summary.attention.last.failed, isTrue);
    expect(summary.attentionTotal, 5);
    expect(summary.finishTask, isNull);
    expect(summary.restartRequired, isTrue);
  });
}
