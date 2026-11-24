import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

ToolApprovalRequest _request({
  Duration left = const Duration(minutes: 5),
  Map<String, dynamic> extra = const <String, dynamic>{},
}) {
  return ToolApprovalRequest.fromJson(<String, dynamic>{
    'approvalId': 'a1',
    'runId': 'r1',
    'toolName': 'execute_command',
    'toolArgs': <String, dynamic>{'command': 'ls -la', 'api_key': 'hunter2'},
    'category': 'shell',
    'expiresAt': DateTime.now().add(left).toIso8601String(),
    'title': 'Neo needs your OK',
    'action': 'Run a command',
    'detail': 'ls -la',
    ...extra,
  });
}

Future<NeoAgentController> _pump(
  WidgetTester tester,
  ToolApprovalRequest request,
) async {
  final controller = NeoAgentController(
    backendClient: BackendClient(),
    healthBridge: HealthBridge(),
  );
  controller.pendingApproval = request;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  ToolApprovalSheet(request: request, controller: controller),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('it reads as a request, with the tool only in the details', (
    tester,
  ) async {
    await _pump(tester, _request());
    expect(find.text('Neo needs your OK'), findsOneWidget);
    expect(find.text('Run a command'), findsOneWidget);
    expect(find.text('ls -la'), findsOneWidget);
    expect(find.text('execute_command'), findsNothing);

    await tester.tap(find.text('ls -la'));
    await tester.pump();
    expect(find.textContaining('api_key'), findsOneWidget);
    expect(find.textContaining('hunter2'), findsNothing);
  });

  testWidgets('a long wait counts down from the real expiry', (tester) async {
    await _pump(tester, _request());
    // A chat approval has five minutes; the sheet must not give up at 30s.
    expect(find.textContaining(RegExp(r'^4:5\d$|^5:00$')), findsOneWidget);
    await tester.pump(const Duration(seconds: 40));
    expect(find.byType(ToolApprovalSheet), findsOneWidget);
  });

  testWidgets('not now leaves it waiting, and it can come back', (
    tester,
  ) async {
    final controller = await _pump(tester, _request());
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.byType(ToolApprovalSheet), findsNothing);
    expect(controller.pendingApproval, isNotNull);
    expect(controller.approvalSheetDismissedId, 'a1');

    controller.reviewPendingApproval();
    expect(controller.approvalSheetDismissedId, isNull);
  });

  testWidgets('answering in a chat closes the sheet', (tester) async {
    final controller = await _pump(tester, _request());
    controller.clearPendingApproval();
    await tester.pumpAndSettle();
    expect(find.byType(ToolApprovalSheet), findsNothing);
  });

  testWidgets('an older server still gets a readable sheet', (tester) async {
    final request = ToolApprovalRequest.fromJson(<String, dynamic>{
      'approvalId': 'a2',
      'runId': 'r1',
      'toolName': 'execute_command',
      'toolArgs': <String, dynamic>{'command': 'ls'},
      'category': 'shell',
      'expiresAt': DateTime.now()
          .add(const Duration(seconds: 30))
          .toIso8601String(),
    });
    await _pump(tester, request);
    expect(find.text('Approval required'), findsOneWidget);
    expect(find.text('Shell Commands'), findsOneWidget);
  });
}
