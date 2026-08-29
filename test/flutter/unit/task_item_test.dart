import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

TaskItem _taskWithModel(String model) => TaskItem.fromJson(<String, dynamic>{
  'id': 7,
  'name': 'Calendar reminder',
  'triggerType': 'schedule',
  'triggerSummary': 'Hourly',
  'triggerConfig': <String, dynamic>{
    'mode': 'recurring',
    'cronExpression': '0 * * * *',
  },
  'prompt': 'Check the calendar.',
  'model': model,
  'enabled': true,
});

Future<DropdownButton<String>> _openTaskModelEditor(
  WidgetTester tester, {
  required String selectedModel,
  required List<ModelMeta> models,
}) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1;

  final controller = NeoAgentController(
    backendClient: BackendClient(),
    healthBridge: HealthBridge(),
  );
  addTearDown(controller.dispose);
  controller.supportedModels = models;
  controller.taskItems = <TaskItem>[_taskWithModel(selectedModel)];

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TasksPanel(controller: controller)),
    ),
  );
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();

  final formFinder = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == 'Model Override',
  );
  expect(formFinder, findsOneWidget);
  final dropdownFinder = find.descendant(
    of: formFinder,
    matching: find.byType(DropdownButton<String>),
  );
  expect(dropdownFinder, findsOneWidget);
  return tester.widget<DropdownButton<String>>(dropdownFinder);
}

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

  testWidgets('task editor displays an unknown saved model as unavailable', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const unknownModel = 'google::retired-model';
    const availableModel = 'openai::gpt-5-nano';
    const unavailableModel = 'google::gemini-2.5-pro';

    final dropdown = await _openTaskModelEditor(
      tester,
      selectedModel: unknownModel,
      models: const <ModelMeta>[
        ModelMeta(
          id: availableModel,
          modelId: 'gpt-5-nano',
          label: 'GPT-5 nano',
          provider: 'openai',
          purpose: 'fast',
        ),
        ModelMeta(
          id: unavailableModel,
          modelId: 'gemini-2.5-pro',
          label: 'Gemini 2.5 Pro',
          provider: 'google',
          purpose: 'general',
          available: false,
        ),
      ],
    );

    final items = dropdown.items!;
    expect(dropdown.value, unknownModel);
    expect(items.map((item) => item.value), <String>[
      'auto',
      unknownModel,
      availableModel,
    ]);
    expect(
      items.singleWhere((item) => item.value == unknownModel).enabled,
      isFalse,
    );
    expect(items.singleWhere((item) => item.value == 'auto').enabled, isTrue);
    expect(
      items.singleWhere((item) => item.value == availableModel).enabled,
      isTrue,
    );
    expect(items.any((item) => item.value == unavailableModel), isFalse);
    expect(
      find.text('$unknownModel (Unavailable saved override)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('task editor keeps a known unavailable saved model visible', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const unavailableModel = 'google::gemini-2.5-pro';
    const availableModel = 'openai::gpt-5-nano';

    final dropdown = await _openTaskModelEditor(
      tester,
      selectedModel: unavailableModel,
      models: const <ModelMeta>[
        ModelMeta(
          id: unavailableModel,
          modelId: 'gemini-2.5-pro',
          label: 'Gemini 2.5 Pro',
          provider: 'google',
          purpose: 'general',
          available: false,
        ),
        ModelMeta(
          id: availableModel,
          modelId: 'gpt-5-nano',
          label: 'GPT-5 nano',
          provider: 'openai',
          purpose: 'fast',
        ),
      ],
    );

    final savedItem = dropdown.items!.singleWhere(
      (item) => item.value == unavailableModel,
    );
    expect(dropdown.value, unavailableModel);
    expect(savedItem.enabled, isFalse);
    expect(
      find.text('Gemini 2.5 Pro (Unavailable saved override)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
