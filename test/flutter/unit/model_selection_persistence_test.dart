import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

class _DelayedSettingsBackendClient extends BackendClient {
  final behaviorWrite = Completer<Map<String, dynamic>>();
  final List<Completer<Map<String, dynamic>>> settingsWrites = [];
  final List<Map<String, dynamic>> settingsPayloads = [];

  @override
  Future<Map<String, dynamic>> saveSettings(
    String baseUrl,
    Map<String, dynamic> payload, {
    String? agentId,
  }) {
    final write = Completer<Map<String, dynamic>>();
    settingsWrites.add(write);
    settingsPayloads.add(Map<String, dynamic>.from(payload));
    return write.future;
  }

  @override
  Future<Map<String, dynamic>> saveBehaviorConfig(
    String baseUrl,
    Map<String, dynamic> config, {
    String? agentId,
  }) {
    return behaviorWrite.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (_) async => null);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  test('configured chat model survives a temporary catalog gap', () {
    final controller = NeoAgentController(
      backendClient: BackendClient(),
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);

    controller.settings = <String, dynamic>{
      'default_chat_model': 'grok-oauth::grok-4.5',
    };
    controller.supportedModels = const <ModelMeta>[];

    expect(controller.defaultChatModel, 'grok-oauth::grok-4.5');
    expect(controller.modelIndicator, 'grok-oauth::grok-4.5');

    controller.supportedModels = const <ModelMeta>[
      ModelMeta(
        id: 'grok-oauth::grok-4.5',
        modelId: 'grok-4.5',
        label: 'Grok 4.5 (xAI OAuth)',
        provider: 'grok-oauth',
        purpose: 'general',
      ),
    ];

    expect(controller.defaultChatModel, 'grok-oauth::grok-4.5');
    expect(controller.modelIndicator, 'Grok 4.5 (xAI OAuth)');
  });

  test('provider routing survives a partial catalog gap', () {
    final controller = NeoAgentController(
      backendClient: BackendClient(),
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);

    const modelSelections = <String>[
      'openai::gpt-5.3',
      'openai-compatible::custom-model',
      'anthropic::claude-sonnet-4-6',
      'google::gemini-3.1-pro-preview',
      'grok::grok-4',
      'grok-oauth::grok-4',
      'nvidia::moonshotai/kimi-k2.5',
      'minimax::MiniMax-M2.7',
      'github-copilot::gpt-5.3',
      'openai-codex::gpt-5.5',
      'claude-code::claude-opus-4-8',
      'openrouter::anthropic/claude-sonnet-4.5',
      'ollama::qwen3.5:4b',
    ];
    controller.supportedModels = const <ModelMeta>[
      ModelMeta(
        id: 'openai::gpt-5-nano',
        modelId: 'gpt-5-nano',
        label: 'GPT-5 nano',
        provider: 'openai',
        purpose: 'fast',
      ),
    ];

    controller.settings = <String, dynamic>{'enabled_models': modelSelections};
    expect(controller.enabledModelIds, modelSelections);

    for (final selection in modelSelections) {
      controller.settings = <String, dynamic>{
        'default_chat_model': selection,
        'default_subagent_model': selection,
        'default_speech_model': selection,
        'fallback_model_id': selection,
      };
      expect(controller.defaultChatModel, selection);
      expect(controller.defaultSubagentModel, selection);
      expect(controller.defaultSpeechModel, selection);
      expect(controller.fallbackModel, selection);
    }
  });

  test('known unavailable models remain selected until explicitly changed', () {
    final controller = NeoAgentController(
      backendClient: BackendClient(),
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);

    controller.settings = <String, dynamic>{
      'enabled_models': <String>[
        'openrouter::anthropic/claude-sonnet-4.5',
        'openai::gpt-5-nano',
      ],
      'fallback_model_id': 'openrouter::anthropic/claude-sonnet-4.5',
    };
    controller.supportedModels = const <ModelMeta>[
      ModelMeta(
        id: 'openrouter::anthropic/claude-sonnet-4.5',
        modelId: 'anthropic/claude-sonnet-4.5',
        label: 'Claude Sonnet 4.5 (OpenRouter)',
        provider: 'openrouter',
        purpose: 'general',
        available: false,
      ),
      ModelMeta(
        id: 'openai::gpt-5-nano',
        modelId: 'gpt-5-nano',
        label: 'GPT-5 nano',
        provider: 'openai',
        purpose: 'fast',
      ),
    ];

    expect(controller.enabledModelIds, <String>[
      'openrouter::anthropic/claude-sonnet-4.5',
      'openai::gpt-5-nano',
    ]);
    expect(controller.fallbackModel, 'openrouter::anthropic/claude-sonnet-4.5');
  });

  testWidgets('late settings hydration never rewrites a saved model', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _DelayedSettingsBackendClient();
    final controller = NeoAgentController(
      backendClient: backend,
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);

    const savedModel = 'openrouter::anthropic/claude-sonnet-4.5';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPanel(controller: controller, embedded: true),
        ),
      ),
    );

    // The settings panel is already mounted when the remote settings and
    // dynamic catalog arrive. This is the lifecycle that previously left the
    // panel stuck on Auto with an empty Smart Selector pool.
    controller.settings = <String, dynamic>{
      'enabled_models': <String>[savedModel],
      'default_chat_model': savedModel,
      'default_subagent_model': savedModel,
      'default_speech_model': savedModel,
      'fallback_model_id': savedModel,
    };
    controller.supportedModels = const <ModelMeta>[
      ModelMeta(
        id: savedModel,
        modelId: 'anthropic/claude-sonnet-4.5',
        label: 'Claude Sonnet 4.5 (OpenRouter)',
        provider: 'openrouter',
        purpose: 'general',
        available: false,
      ),
      ModelMeta(
        id: 'openai::gpt-5-nano',
        modelId: 'gpt-5-nano',
        label: 'GPT-5 nano',
        provider: 'openai',
        purpose: 'fast',
      ),
    ];
    controller.notifyListeners();
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(backend.settingsPayloads, hasLength(1));
    expect(backend.settingsPayloads.single['enabled_models'], <String>[
      savedModel,
    ]);
    expect(backend.settingsPayloads.single['default_chat_model'], savedModel);
    expect(
      backend.settingsPayloads.single['default_subagent_model'],
      savedModel,
    );
    expect(backend.settingsPayloads.single['default_speech_model'], savedModel);
    expect(backend.settingsPayloads.single['fallback_model_id'], savedModel);

    backend.settingsWrites.single.complete(<String, dynamic>{'success': true});
    await tester.pump();
    backend.behaviorWrite.complete(<String, dynamic>{
      'config': <String, dynamic>{},
    });
    await tester.pumpAndSettle();
  });

  testWidgets('catalog refresh cannot overwrite an unsaved model choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _DelayedSettingsBackendClient();
    final controller = NeoAgentController(
      backendClient: backend,
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);

    const openRouterModel = 'openrouter::anthropic/claude-sonnet-4.5';
    const openAiModel = 'openai::gpt-5-nano';
    controller.settings = <String, dynamic>{
      'enabled_models': <String>[openRouterModel, openAiModel],
      'default_chat_model': openRouterModel,
      'default_subagent_model': 'auto',
      'default_speech_model': 'auto',
      'fallback_model_id': openAiModel,
    };
    controller.supportedModels = const <ModelMeta>[
      ModelMeta(
        id: openRouterModel,
        modelId: 'anthropic/claude-sonnet-4.5',
        label: 'Claude Sonnet 4.5 (OpenRouter)',
        provider: 'openrouter',
        purpose: 'general',
      ),
      ModelMeta(
        id: openAiModel,
        modelId: 'gpt-5-nano',
        label: 'GPT-5 nano',
        provider: 'openai',
        purpose: 'fast',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPanel(controller: controller, embedded: true),
        ),
      ),
    );
    await tester.tap(find.text('Models & routing'));
    await tester.pump();
    await tester.tap(find.text('Claude Sonnet 4.5 (OpenRouter)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GPT-5 nano').last);
    await tester.pumpAndSettle();

    // Simulate an older settings response or catalog refresh arriving after
    // the user made a local selection but before Save was pressed.
    controller.settings = <String, dynamic>{
      ...controller.settings,
      'default_chat_model': 'auto',
    };
    controller.supportedModels = List<ModelMeta>.from(
      controller.supportedModels,
    );
    controller.notifyListeners();
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(backend.settingsPayloads, hasLength(1));
    expect(backend.settingsPayloads.single['default_chat_model'], openAiModel);

    backend.settingsWrites.single.complete(<String, dynamic>{'success': true});
    await tester.pump();
    backend.behaviorWrite.complete(<String, dynamic>{
      'config': <String, dynamic>{},
    });
    await tester.pumpAndSettle();
  });

  test(
    'model selection saves while another settings operation is active',
    () async {
      final backend = _DelayedSettingsBackendClient();
      final controller = NeoAgentController(
        backendClient: backend,
        healthBridge: HealthBridge(),
      );
      addTearDown(controller.dispose);
      controller.settings = <String, dynamic>{'default_chat_model': 'auto'};

      final behaviorSave = controller.saveBehaviorConfig(<String, dynamic>{
        'enabled': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(controller.isSavingSettings, isTrue);

      final modelSave = controller.saveSettingsPayload(<String, dynamic>{
        'default_chat_model': 'grok-oauth::grok-4.5',
      });
      expect(controller.defaultChatModel, 'grok-oauth::grok-4.5');
      await Future<void>.delayed(Duration.zero);
      expect(
        backend.settingsPayloads.single['default_chat_model'],
        'grok-oauth::grok-4.5',
      );

      backend.settingsWrites.single.complete(<String, dynamic>{
        'success': true,
      });
      await modelSave;
      expect(controller.isSavingSettings, isTrue);

      backend.behaviorWrite.complete(<String, dynamic>{
        'config': <String, dynamic>{'enabled': true},
      });
      await behaviorSave;
      expect(controller.isSavingSettings, isFalse);
      expect(controller.defaultChatModel, 'grok-oauth::grok-4.5');
    },
  );

  test(
    'consecutive model selections are serialized and the latest wins',
    () async {
      final backend = _DelayedSettingsBackendClient();
      final controller = NeoAgentController(
        backendClient: backend,
        healthBridge: HealthBridge(),
      );
      addTearDown(controller.dispose);
      controller.settings = <String, dynamic>{'default_chat_model': 'auto'};

      final grokSave = controller.saveSettingsPayload(<String, dynamic>{
        'default_chat_model': 'grok-oauth::grok-4.5',
      });
      final claudeSave = controller.saveSettingsPayload(<String, dynamic>{
        'default_chat_model': 'claude-code::claude-opus-4-8',
      });

      await Future<void>.delayed(Duration.zero);
      expect(backend.settingsPayloads, hasLength(1));
      expect(controller.defaultChatModel, 'claude-code::claude-opus-4-8');

      backend.settingsWrites.first.complete(<String, dynamic>{'success': true});
      await grokSave;
      await Future<void>.delayed(Duration.zero);
      expect(backend.settingsPayloads, hasLength(2));
      expect(
        backend.settingsPayloads.last['default_chat_model'],
        'claude-code::claude-opus-4-8',
      );

      backend.settingsWrites.last.complete(<String, dynamic>{'success': true});
      await claudeSave;
      expect(controller.defaultChatModel, 'claude-code::claude-opus-4-8');
      expect(controller.isSavingSettings, isFalse);
    },
  );
}
