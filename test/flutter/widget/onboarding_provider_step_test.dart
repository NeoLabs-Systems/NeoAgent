import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neoagent_flutter/features/onboarding/onboarding_provider_step.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('onboarding provider step lists API-key providers for any setup path', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = NeoAgentController(
      backendClient: BackendClient(),
      healthBridge: HealthBridge(),
    );
    controller.aiProviders = const <AiProviderMeta>[
      AiProviderMeta(
        id: 'openai',
        label: 'OpenAI',
        description: 'GPT models',
        enabled: true,
        available: false,
        supportsApiKey: true,
        supportsBaseUrl: true,
        defaultBaseUrl: '',
        credentialConfigured: false,
        baseUrl: '',
        status: 'needs_setup',
        statusLabel: 'Setup Needed',
        availabilityReason: '',
        modelCount: 0,
        availableModelCount: 0,
      ),
      AiProviderMeta(
        id: 'ollama',
        label: 'Ollama',
        description: 'Local models',
        enabled: true,
        available: true,
        supportsApiKey: false,
        supportsBaseUrl: true,
        defaultBaseUrl: 'http://localhost:11434',
        credentialConfigured: false,
        baseUrl: 'http://localhost:11434',
        status: 'local',
        statusLabel: 'Local',
        availabilityReason: '',
        modelCount: 0,
        availableModelCount: 0,
        authentication: 'local',
      ),
    ];
    addTearDown(controller.dispose);

    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingProviderStep(
          controller: controller,
          onNext: () => continued = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('Connect an'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Ollama'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);

    await tester.tap(find.text('Skip for now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(continued, isTrue);
  });
}
