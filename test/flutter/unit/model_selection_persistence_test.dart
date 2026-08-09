import 'dart:async';

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
