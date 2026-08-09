import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
