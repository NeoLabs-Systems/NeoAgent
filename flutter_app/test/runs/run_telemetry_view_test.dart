import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

// run_detail_sample.json is the response of GET /api/agents/runs/:id for a real
// run through the harness, so these tests also catch the two sides drifting apart.
Map<String, dynamic> _sample() =>
    jsonDecode(File('test/runs/run_detail_sample.json').readAsStringSync())
        as Map<String, dynamic>;

Future<void> _pump(WidgetTester tester, RunDetailSnapshot detail, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: RunTelemetryView(detail: detail)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in <double>[360, 1200]) {
    testWidgets('a real run renders without overflow at $width wide', (tester) async {
      await _pump(tester, RunDetailSnapshot.fromJson(_sample()), width);
      expect(tester.takeException(), isNull);

      expect(find.textContaining('Context build'), findsOneWidget);
      expect(find.text('Tool selection'), findsOneWidget);
      expect(find.text('Model request #1'), findsOneWidget);
      expect(find.text('Model request #4'), findsOneWidget);
      expect(find.text('web_search'), findsNWidgets(2));
      expect(find.text('Delivered: final'), findsOneWidget);
      expect(find.text('Find the failing auth test'), findsOneWidget);
      expect(find.textContaining('102 known'), findsOneWidget);
      expect(find.textContaining('undefined'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
    });
  }

  testWidgets('the latency bar is actually drawn, in proportion', (tester) async {
    await _pump(tester, RunDetailSnapshot.fromJson(_sample()), 360);
    final segments = find.descendant(of: find.byType(ClipRRect), matching: find.byType(ColoredBox));
    expect(segments, findsWidgets);
    final sizes = segments.evaluate().map((element) => element.size!).toList();
    expect(sizes.every((size) => size.height == 8), isTrue);
    // Queue is 309 of the sample's 314 ms.
    expect(sizes.first.width, greaterThan(sizes.last.width * 10));
    expect(sizes.fold<double>(0, (sum, size) => sum + size.width), closeTo(360, 0.01));
  });

  testWidgets('a result that was not cut is not reported as cut', (tester) async {
    await _pump(tester, RunDetailSnapshot.fromJson(_sample()), 360);
    expect(find.text('847 bytes'), findsNWidgets(2));
    expect(find.textContaining('bytes kept'), findsNothing);
  });

  testWidgets('a cut result says how much survived', (tester) async {
    final json = _sample();
    (json['events'] as List<dynamic>).add(<String, dynamic>{
      'id': 899,
      'eventType': 'tool.result',
      'sequenceIndex': 899,
      'payload': <String, dynamic>{
        'tool': <String, dynamic>{'name': 'read_log', 'result_bytes': 90000, 'result_compacted_bytes': 4000},
        'outcome': <String, dynamic>{'status': 'ok'},
      },
    });
    await _pump(tester, RunDetailSnapshot.fromJson(json), 360);
    expect(find.text('4000 of 90000 bytes kept'), findsOneWidget);
  });

  testWidgets('a failed tool stands out and its error is readable', (tester) async {
    await _pump(tester, RunDetailSnapshot.fromJson(_sample()), 360);
    expect(find.text('read_file'), findsOneWidget);
    expect(find.textContaining('ENOENT'), findsOneWidget);
  });

  testWidgets('tool selection opens to show what was considered and used', (tester) async {
    await _pump(tester, RunDetailSnapshot.fromJson(_sample()), 360);
    expect(find.textContaining('← used'), findsNothing);
    await tester.tap(find.text('Tool selection'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('web_search'), findsWidgets);
    expect(find.textContaining('← used'), findsWidgets);
  });

  testWidgets('stopped duplicates, denials and failed sends are shown', (tester) async {
    final json = _sample();
    (json['events'] as List<dynamic>).addAll(<dynamic>[
      <String, dynamic>{
        'id': 900,
        'eventType': 'tool.suppressed',
        'sequenceIndex': 900,
        'payload': <String, dynamic>{
          'reason': 'same_read_same_state',
          'tool': <String, dynamic>{'name': 'search_files'},
        },
      },
      <String, dynamic>{
        'id': 901,
        'eventType': 'permission.decision',
        'sequenceIndex': 901,
        'payload': <String, dynamic>{'decision': 'deny', 'tool': 'send_message', 'by': 'policy', 'tainted': true},
      },
      <String, dynamic>{
        'id': 902,
        'eventType': 'delivery.suppressed',
        'sequenceIndex': 902,
        'payload': <String, dynamic>{'purpose': 'final', 'reason': 'already_delivered'},
      },
      <String, dynamic>{
        'id': 903,
        'eventType': 'delivery.failed',
        'sequenceIndex': 903,
        'payload': <String, dynamic>{'purpose': 'task_result', 'ambiguous': true},
      },
    ]);
    await _pump(tester, RunDetailSnapshot.fromJson(json), 360);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('same read same state'), findsOneWidget);
    expect(find.text('send_message denied'), findsOneWidget);
    expect(find.text('Duplicate stopped: final'), findsOneWidget);
    expect(find.textContaining('will not be sent again'), findsOneWidget);
  });

  testWidgets('what went wrong in a run is spelled out above its events', (tester) async {
    final json = _sample();
    json['diagnostics'] = <dynamic>[
      <String, dynamic>{'code': 'delivery_ambiguous', 'count': 1},
      <String, dynamic>{'code': 'tool_not_on_first_turn', 'tools': <dynamic>['web_search']},
      <String, dynamic>{'code': 'tools_fill_context', 'share': 0.58, 'tokens': 6000},
      <String, dynamic>{'code': 'something_new'},
    ];
    await _pump(tester, RunDetailSnapshot.fromJson(json), 360);
    expect(tester.takeException(), isNull);
    expect(find.text('A message may have arrived'), findsOneWidget);
    expect(find.textContaining('web_search had to be found first'), findsOneWidget);
    expect(find.textContaining('58% of the first prompt'), findsOneWidget);
    // A code from a newer server still shows.
    expect(find.text('something new'), findsOneWidget);
  });

  testWidgets('a run from before the ledger says so instead of breaking', (tester) async {
    await _pump(
      tester,
      RunDetailSnapshot.fromJson(<String, dynamic>{
        'run': <String, dynamic>{'id': 'old', 'title': 't', 'status': 'completed'},
        'steps': <dynamic>[],
        'events': <dynamic>[],
        'response': '',
      }),
      360,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('This run has no telemetry yet.'), findsOneWidget);
  });

  testWidgets('the health report reads the server\'s report', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RunHealthReportView(
            report: <String, dynamic>{
              'runs': 12,
              'success_rate': 0.9167,
              'latency_ms': <String, dynamic>{
                'total': <String, dynamic>{'p50': 4200, 'p95': 61000},
                'first_action': <String, dynamic>{'p50': null, 'p95': null},
              },
              'per_run': <String, dynamic>{
                'tool_calls': <String, dynamic>{'p50': 3, 'p95': 14},
                'input_tokens': <String, dynamic>{'p50': 1800, 'p95': 92000},
              },
              'rates': <String, dynamic>{
                'prompt_cache_hit': 0.41,
                'no_tool_runs': 0.25,
                'tool_failure': 0.05,
                'tool_selection_recall': 0.875,
                'duplicate_tool_calls': 0.02,
                'tool_suppressed': 0.01,
                'duplicate_deliveries_stopped_per_1000_runs': 83.3,
                'delivery_failures_per_1000_runs': 0,
                'recoveries_per_run': 0.08,
                'compactions_per_run': 0.16,
              },
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('91.7%'), findsOneWidget);
    expect(find.text('3 / 14'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('83.3'), findsOneWidget);
    expect(find.text('87.5%'), findsOneWidget);
  });

  testWidgets('an empty health report says so', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RunHealthReportView(report: <String, dynamic>{'runs': 0})),
      ),
    );
    expect(find.text('No runs with telemetry in this period yet.'), findsOneWidget);
  });
}
