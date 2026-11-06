import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class _FormController extends NeoAgentController {
  _FormController()
    : super(backendClient: BackendClient(), healthBridge: HealthBridge());

  int connections = 0;
  int taskSaves = 0;
  Completer<void>? taskWrite;

  @override
  Future<List<OfficialIntegrationItem>> fetchOfficialIntegrationsForAgent(
    String? agentId,
  ) async => const <OfficialIntegrationItem>[];

  @override
  Future<void> connectMessagingPlatform({
    required String platform,
    Map<String, dynamic>? config,
    Map<String, dynamic>? configSnapshot,
  }) async {
    connections += 1;
    throw const BackendException('Connection unavailable', statusCode: 409);
  }

  @override
  Future<void> saveTask({
    int? id,
    required String name,
    required String triggerType,
    required Map<String, dynamic> triggerConfig,
    required String prompt,
    Map<String, dynamic>? taskConfig,
    String? model,
    bool enabled = true,
    String? agentId,
  }) async {
    taskSaves += 1;
    if (taskWrite != null) await taskWrite!.future;
  }
}

class _SettingsBackend extends BackendClient {
  bool fail = true;

  @override
  Future<Map<String, dynamic>> saveSettings(
    String baseUrl,
    Map<String, dynamic> payload, {
    String? agentId,
  }) async {
    if (fail) {
      throw const BackendException('Unable to save', statusCode: 503);
    }
    return payload;
  }
}

void main() {
  setUp(() {
    currentAppLanguage = AppLanguage.english;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
  });

  tearDown(() => currentAppLanguage = AppLanguage.english);

  Future<void> pumpPanel(
    WidgetTester tester,
    Widget panel, {
    Size size = const Size(1100, 760),
    TextScaler? textScaler,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(body: panel),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  testWidgets('agent identifier follows typing and preserves a manual edit', (
    tester,
  ) async {
    final controller = _FormController();
    addTearDown(controller.dispose);
    await pumpPanel(tester, AgentsPanel(controller: controller));
    await tester.tap(find.text(appStrings.addAgent));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name'), 'R');
    await tester.enterText(field('Name'), 'Research assistant');
    expect(
      tester.widget<TextField>(field('Agent identifier')).controller!.text,
      'research-assistant',
    );
    await tester.enterText(field('Agent identifier'), 'research');
    await tester.enterText(field('Name'), 'Research and writing');
    expect(
      tester.widget<TextField>(field('Agent identifier')).controller!.text,
      'research',
    );
    await tester.enterText(field('Agent identifier'), '');
    await tester.enterText(field('Name'), 'Research again');
    expect(
      tester.widget<TextField>(field('Agent identifier')).controller!.text,
      'research-again',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'task validation is inside the dialog with purpose before schedule',
    (tester) async {
      final controller = _FormController();
      addTearDown(controller.dispose);
      await pumpPanel(tester, TasksPanel(controller: controller));
      await tester.tap(find.text(appStrings.addTask));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(field('What should the agent do?')).dy,
        lessThan(tester.getTopLeft(find.text(appStrings.triggerType)).dy),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Please enter a task name.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Please enter a prompt.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(controller.taskSaves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed task saves keep inputs and allow a retry without duplicates',
    (tester) async {
      final controller = _FormController();
      addTearDown(controller.dispose);
      await pumpPanel(tester, TasksPanel(controller: controller));
      await tester.tap(find.text(appStrings.addTask));
      await tester.pumpAndSettle();
      await tester.enterText(field('Name'), 'Evening review');
      await tester.enterText(
        field('What should the agent do?'),
        'Review my day.',
      );
      controller.taskWrite = Completer<void>();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(controller.taskSaves, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Saving...'),
            )
            .onPressed,
        isNull,
      );
      controller.taskWrite!.completeError(
        const BackendException('Unable to save this task', statusCode: 409),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Unable to save this task'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field('Name')).controller!.text,
        'Evening review',
      );
      expect(find.byType(SnackBar), findsNothing);
      controller.taskWrite = null;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(controller.taskSaves, 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Telegram validates locally and keeps connection errors in its dialog',
    (tester) async {
      final controller = _FormController();
      addTearDown(controller.dispose);
      final telegram = messagingPlatforms.firstWhere((p) => p.id == 'telegram');
      await pumpPanel(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                openPersonalMessagingConfig(context, controller, telegram),
            child: const Text('Open setup'),
          ),
        ),
      );
      await tester.tap(find.text('Open setup'));
      await tester.pumpAndSettle();
      expect(find.text('Incoming messages'), findsNothing);
      expect(
        find.text('Create a bot with @BotFather and copy its token.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Bot token.'), findsOneWidget);
      expect(controller.connections, 0);
      await tester.enterText(field('Bot token'), 'local-test-token');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Connection unavailable'),
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(controller.connections, 1);
      expect(
        tester.widget<TextField>(field('Bot token')).controller!.text,
        'local-test-token',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small German task form scrolls to inline validation without overflow',
    (tester) async {
      currentAppLanguage = AppLanguage.german;
      final controller = _FormController();
      addTearDown(controller.dispose);
      await pumpPanel(tester, TasksPanel(controller: controller));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aufgabe hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bitte geben Sie einen Aufgabennamen ein.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('German agent form supports larger text on a narrow screen', (
    tester,
  ) async {
    currentAppLanguage = AppLanguage.german;
    final controller = _FormController();
    addTearDown(controller.dispose);
    await pumpPanel(
      tester,
      SingleChildScrollView(child: AgentsPanel(controller: controller)),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(1.5),
    );
    await tester.tap(find.text(appStrings.addAgent));
    await tester.pumpAndSettle();
    await tester.tap(find.text(appStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(appStrings.agentNameRequired), findsOneWidget);
    await tester.enterText(field(appStrings.name), 'Recherche');
    await tester.pumpAndSettle();
    expect(find.text(appStrings.agentNameRequired), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'failed settings save is retained separately and cleared on a successful retry',
    () async {
      final backend = _SettingsBackend();
      final controller = NeoAgentController(
        backendClient: backend,
        healthBridge: HealthBridge(),
      );
      addTearDown(controller.dispose);
      controller.settings = <String, dynamic>{'default_chat_model': 'auto'};
      await expectLater(
        controller.saveSettingsPayload(<String, dynamic>{
          'default_chat_model': 'new-model',
        }),
        throwsA(isA<BackendException>()),
      );
      expect(controller.settings['default_chat_model'], 'auto');
      expect(controller.settingsSaveError, isNotNull);
      expect(controller.isSavingSettings, isFalse);
      backend.fail = false;
      await controller.saveSettingsPayload(<String, dynamic>{
        'default_chat_model': 'new-model',
      });
      expect(controller.settingsSaveError, isNull);
      expect(controller.settings['default_chat_model'], 'new-model');
    },
  );
}
