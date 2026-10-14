import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/features/onboarding/onboarding_chrome.dart';
import 'package:neoagent_flutter/features/onboarding/onboarding_messaging_step.dart';
import 'package:neoagent_flutter/features/onboarding/onboarding_model_step.dart';
import 'package:neoagent_flutter/features/onboarding/onboarding_ready_step.dart';
import 'package:neoagent_flutter/features/onboarding/onboarding_tasks_step.dart';
import 'package:neoagent_flutter/features/onboarding/onboarding_video_step.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

/// Backend stub: one BYOK provider to offer, and an onboarding completion
/// that fails the way an unreachable server does.
class _FakeBackendClient extends BackendClient {
  int completeOnboardingCalls = 0;

  @override
  Future<Map<String, dynamic>> fetchByokProviders(
    String baseUrl, {
    String? agentId,
  }) async {
    return <String, dynamic>{
      'providers': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'openai',
          'label': 'OpenAI',
          'supportsApiKey': true,
          'configured': false,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> completeOnboarding(String baseUrl) async {
    completeOnboardingCalls += 1;
    throw const BackendException('The server is unreachable.');
  }
}

NeoAgentController _controller(_FakeBackendClient client) {
  return NeoAgentController(
    backendClient: client,
    healthBridge: HealthBridge(),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Steps read their place in the flow from the shell; tests stand in for it.
Widget _inFlow(Widget step) =>
    OnboardingStepScope(step: 0, totalSteps: 4, child: step);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: _inFlow(child))));
  // Let entrance animations finish so no timers are left pending.
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The controller's dictation recorder has no plugin implementation here.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async => null,
        );
  });

  testWidgets('intro video offers a way out on a portrait screen', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingVideoStep(onComplete: () => completed++)),
    );
    await tester.pump();

    // Whether the video is still loading, failed or waiting for rotation,
    // the screen always carries a button that moves on.
    final skip = find.byWidgetPredicate(
      (widget) =>
          widget is OnboardingGhostButton || widget is OnboardingPrimaryButton,
    );
    expect(skip, findsOneWidget);
    await tester.tap(skip);
    expect(completed, 1);

    // A load that never finishes falls back to the continue screen.
    await tester.pump(const Duration(seconds: 9));
    expect(
      find.byWidgetPredicate((widget) => widget is OnboardingPrimaryButton),
      findsOneWidget,
    );
  });

  testWidgets('model step shows a spinner while models load', (tester) async {
    _setSize(tester, const Size(800, 900));
    final controller = _controller(_FakeBackendClient());
    addTearDown(controller.dispose);
    controller.isRefreshing = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _inFlow(
            OnboardingModelStep(
              onNext: () {},
              onBack: () {},
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No AI model is set up yet'), findsNothing);
  });

  testWidgets('model step without models offers key entry', (tester) async {
    _setSize(tester, const Size(800, 900));
    final controller = _controller(_FakeBackendClient());
    addTearDown(controller.dispose);
    controller.hasLoadedInitialData = true;

    await _pump(
      tester,
      OnboardingModelStep(onNext: () {}, onBack: () {}, controller: controller),
    );

    expect(find.text('No AI model is set up yet'), findsOneWidget);
    expect(find.byType(ByokSettingsCard), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
  });

  testWidgets(
    'model step offers Smart Selector first and picks it by default',
    (tester) async {
      _setSize(tester, const Size(800, 900));
      final controller = _controller(_FakeBackendClient());
      addTearDown(controller.dispose);
      controller.hasLoadedInitialData = true;
      controller.supportedModels = const <ModelMeta>[
        ModelMeta(
          id: 'gpt-x',
          modelId: 'gpt-x',
          label: 'GPT X',
          provider: 'openai',
          purpose: 'General work',
        ),
      ];

      await _pump(
        tester,
        OnboardingModelStep(
          onNext: () {},
          onBack: () {},
          controller: controller,
        ),
      );

      expect(find.text('Smart Selector'), findsOneWidget);
      expect(find.text('GPT X'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Smart Selector')).dy,
        lessThan(tester.getTopLeft(find.text('GPT X')).dy),
      );
    },
  );

  for (final size in const <Size>[
    Size(360, 640),
    Size(800, 360),
    Size(1280, 800),
  ]) {
    testWidgets('steps lay out without overflow at $size', (tester) async {
      _setSize(tester, size);
      final controller = _controller(_FakeBackendClient());
      addTearDown(controller.dispose);
      controller.hasLoadedInitialData = true;

      await _pump(
        tester,
        OnboardingMessagingStep(
          onNext: () {},
          onBack: () {},
          controller: controller,
        ),
      );
      expect(tester.takeException(), isNull);

      // Selecting a platform swaps in the Connect action next to Back and
      // Skip, the widest footer this flow has.
      await tester.tap(find.text('WhatsApp'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Connect'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        OnboardingModelStep(
          onNext: () {},
          onBack: () {},
          controller: controller,
        ),
      );
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        OnboardingTasksStep(
          onNext: () {},
          onBack: () {},
          controller: controller,
        ),
      );
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        OnboardingReadyStep(
          onFinish: (_) async {},
          onBack: () {},
          controller: controller,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ready step hands the typed message to the chat', (tester) async {
    _setSize(tester, const Size(1280, 800));
    final controller = _controller(_FakeBackendClient());
    addTearDown(controller.dispose);
    final sent = <String>[];

    await _pump(
      tester,
      OnboardingReadyStep(
        onFinish: (message) async => sent.add(message),
        onBack: () {},
        controller: controller,
      ),
    );

    await tester.enterText(find.byType(TextField), '  Plan my week  ');
    await tester.tap(find.text('Open NeoAgent'));
    await tester.pump();

    expect(sent, <String>['Plan my week']);
  });

  test('a failed completion keeps onboarding open with an error', () async {
    final client = _FakeBackendClient();
    final controller = _controller(client);
    addTearDown(controller.dispose);
    controller.showOnboarding = true;

    await controller.dismissOnboarding();

    expect(client.completeOnboardingCalls, 1);
    expect(controller.showOnboarding, isTrue);
    expect(controller.isCompletingOnboarding, isFalse);
    expect(controller.onboardingCompletionError, isNotNull);
  });

  testWidgets('ready step shows the failure inline and offers a retry', (
    tester,
  ) async {
    _setSize(tester, const Size(1200, 900));
    final client = _FakeBackendClient();
    final controller = _controller(client);
    addTearDown(controller.dispose);
    controller.showOnboarding = true;

    await _pump(
      tester,
      OnboardingReadyStep(
        onFinish: (_) => controller.dismissOnboarding(),
        onBack: () {},
        controller: controller,
      ),
    );

    await tester.tap(find.text('Open NeoAgent'));
    await tester.pump();
    await tester.pump();

    expect(controller.showOnboarding, isTrue);
    expect(find.textContaining('The server is unreachable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(client.completeOnboardingCalls, 2);
  });

  testWidgets('first chat explains a missing model before the first send', (
    tester,
  ) async {
    _setSize(tester, const Size(1200, 1800));
    final controller = _controller(_FakeBackendClient());
    addTearDown(controller.dispose);
    controller.hasLoadedInitialData = true;

    await _pump(
      tester,
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ChatPanel(controller: controller),
      ),
    );

    expect(find.text('No AI model is set up yet'), findsOneWidget);
    expect(find.text('Add API key'), findsOneWidget);
    // With no runs yet there is nothing to summarise.
    expect(find.text('Summarise my last run'), findsNothing);
  });
}
