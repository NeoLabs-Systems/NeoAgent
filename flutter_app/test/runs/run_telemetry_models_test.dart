import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  test('a run detail reads its metrics and ledger', () {
    final detail = RunDetailSnapshot.fromJson(<String, dynamic>{
      'run': <String, dynamic>{'id': 'run-1', 'title': 't', 'status': 'completed'},
      'steps': <dynamic>[],
      'events': <dynamic>[
        <String, dynamic>{
          'id': 1,
          'eventType': 'tool.result',
          'sequenceIndex': 1,
          'payload': <String, dynamic>{
            'duration_ms': 184,
            'tool': <String, dynamic>{'name': 'search_files'},
            'outcome': <String, dynamic>{'status': 'failed'},
          },
        },
      ],
      'response': 'done',
      'metrics': <String, dynamic>{
        'task_class': 'coding',
        'duration_ms': 8420,
        'first_action_ms': 730,
        'turns': 4,
        'latency': <String, dynamic>{'queue_ms': 50, 'model_ms': 4000, 'tool_ms': 3000, 'sandbox_ms': 100, 'delivery_ms': 84},
        'tools': <String, dynamic>{'calls': 5, 'failed': 1, 'suppressed': 1},
        'tokens': <String, dynamic>{'input': 18400, 'output': 1200, 'cachedRead': 9000},
        'memory': <String, dynamic>{'recalls': 2, 'tokens': 320},
        'compactions': 1,
        'recoveries': 1,
        'delivery': <String, dynamic>{'sent': 1, 'suppressed': 1, 'failed': 0},
      },
      'ledger': <String, dynamic>{
        'goal': 'Fix auth tests',
        'steps': <dynamic>[
          <String, dynamic>{'id': 'patch', 'status': 'active'},
        ],
        'verified_facts': <dynamic>['failure reproduced'],
        'blockers': <dynamic>[],
      },
    });

    final metrics = detail.metrics!;
    expect(metrics.firstActionMs, 730);
    expect(metrics.modelMs, 4000);
    expect(metrics.toolsSuppressed, 1);
    expect(metrics.cachedTokens, 9000);
    expect(metrics.deliverySuppressed, 1);

    expect(detail.ledger!.goal, 'Fix auth tests');
    expect(detail.ledger!.steps.single.status, 'active');
    expect(detail.ledger!.verifiedFacts.single, 'failure reproduced');

    final event = detail.events.single;
    expect(event.toolName, 'search_files');
    expect(event.durationMs, 184);
    expect(event.isFailure, isTrue);
    expect(event.detail, 'search_files');
  });

  test('a run from before the ledger still reads', () {
    final detail = RunDetailSnapshot.fromJson(<String, dynamic>{
      'run': <String, dynamic>{'id': 'run-2', 'title': 't', 'status': 'completed'},
      'steps': <dynamic>[],
      'events': <dynamic>[],
      'response': '',
    });
    expect(detail.metrics, isNull);
    expect(detail.ledger, isNull);
  });
}
