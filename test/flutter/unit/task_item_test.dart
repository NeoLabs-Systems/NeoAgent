import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  test('TaskItem parses durable run status and error details', () {
    final task = TaskItem.fromJson(<String, dynamic>{
      'id': 7,
      'name': 'Daily summary',
      'triggerType': 'schedule',
      'triggerSummary': '0 6 * * *',
      'prompt': 'Prepare the summary.',
      'enabled': true,
      'lastRun': '2026-06-06 10:00:00',
      'lastRunId': 'run-123',
      'lastRunStatus': 'failed',
      'lastRunError': 'Messaging delivery is unavailable.',
    });

    expect(task.lastRunId, 'run-123');
    expect(task.lastRunStatusLabel, 'Failed');
    expect(task.lastRunFailed, isTrue);
    expect(task.lastRunError, 'Messaging delivery is unavailable.');
    expect(task.lastRun, isNotNull);
  });

  test('TaskDeliveryTarget parses discovery metadata', () {
    final target = TaskDeliveryTarget.fromJson(<String, dynamic>{
      'platform': 'slack',
      'platformLabel': 'Slack',
      'to': 'C123',
      'label': '#ops',
      'subtitle': 'Slack channel',
      'source': 'discovered',
      'connected': true,
      'supportsDelivery': true,
    });

    expect(target.id, 'slack:C123');
    expect(target.label, '#ops');
    expect(target.sourceLabel, 'Discovered');
    expect(target.selectable, isTrue);
  });
}
