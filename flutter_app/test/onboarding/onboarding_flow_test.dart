import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/features/onboarding/onboarding_flow.dart';
import 'package:neoagent_flutter/features/onboarding/onboarding_shell.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

const _model = ModelMeta(
  id: 'openrouter/some-model',
  modelId: 'some-model',
  label: 'Some model',
  provider: 'openrouter',
  purpose: 'chat',
);

class _FakeBackend extends BackendClient {
  @override
  Future<Map<String, dynamic>> fetchMessagingStatus(
    String baseUrl, {
    String? agentId,
  }) async => const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> fetchSharedMessagingOptions(
    String baseUrl,
  ) async => const <String, dynamic>{'options': <dynamic>[]};

  @override
  Future<Map<String, dynamic>> fetchByokProviders(
    String baseUrl, {
    String? agentId,
  }) async => const <String, dynamic>{
    'providers': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'openrouter',
        'label': 'OpenRouter',
        'signInAvailable': true,
        'configured': false,
      },
    ],
  };
}

void main() {
  group('which pages a person gets', () {
    test('a server with a model never asks for one', () {
      expect(
        onboardingPages(
          needsModelStep: false,
          hasComputerChoice: false,
          hasRoutines: true,
        ),
        <OnboardingPage>[
          OnboardingPage.intro,
          OnboardingPage.messaging,
          OnboardingPage.routines,
          OnboardingPage.ready,
        ],
      );
    });

    test('routines that cannot run yet are not a page', () {
      expect(
        onboardingPages(
          needsModelStep: true,
          hasComputerChoice: false,
          hasRoutines: false,
        ),
        <OnboardingPage>[
          OnboardingPage.intro,
          OnboardingPage.model,
          OnboardingPage.messaging,
          OnboardingPage.ready,
        ],
      );
    });

    test('only the desktop app has a computer choice', () {
      expect(
        onboardingPages(
          needsModelStep: false,
          hasComputerChoice: true,
          hasRoutines: true,
        ),
        contains(OnboardingPage.computer),
      );
    });

    test('resuming on a page that dropped out lands on the next one', () {
      final pages = onboardingPages(
        needsModelStep: false,
        hasComputerChoice: false,
        hasRoutines: true,
      );
      expect(
        resumeOnboardingPage(pages, OnboardingPage.model.index),
        OnboardingPage.messaging,
      );
      expect(resumeOnboardingPage(pages, 0), OnboardingPage.intro);
      expect(resumeOnboardingPage(pages, 999), OnboardingPage.ready);
    });
  });

  group('walking through it', () {
    late NeoAgentController controller;

    Future<void> pumpShell(
      WidgetTester tester, {
      required OnboardingPage start,
      bool loaded = true,
      List<ModelMeta> models = const <ModelMeta>[],
      Size size = const Size(1200, 900),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      controller = NeoAgentController(
        backendClient: _FakeBackend(),
        healthBridge: HealthBridge(),
      );
      addTearDown(controller.dispose);
      controller.hasLoadedInitialData = loaded;
      controller.supportedModels = models;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingShell(controller: controller, startPage: start),
        ),
      );
      await settle(tester);
    }

    testWidgets(
      'with no model it asks, offers one button, and keeps keys folded',
      (tester) async {
        await pumpShell(tester, start: OnboardingPage.model);
        expect(find.text('Connect an AI.'), findsOneWidget);
        expect(find.text('Sign in with OpenRouter'), findsOneWidget);
        expect(find.text('Use an API key instead'), findsOneWidget);
        expect(find.text('Skip for now'), findsOneWidget);
        expect(find.text('Back'), findsNothing, reason: 'the first real step');
      },
    );

    testWidgets('connecting a model turns the step into a success with Next', (
      tester,
    ) async {
      await pumpShell(tester, start: OnboardingPage.model);
      controller.supportedModels = const <ModelMeta>[_model];
      controller.notifyListeners();
      await settle(tester);
      expect(find.textContaining('Connected.'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Sign in with OpenRouter'), findsNothing);
    });

    testWidgets('a catalog that arrives with models skips the step entirely', (
      tester,
    ) async {
      await pumpShell(tester, start: OnboardingPage.model, loaded: false);
      controller.hasLoadedInitialData = true;
      controller.supportedModels = const <ModelMeta>[_model];
      controller.notifyListeners();
      await settle(tester);
      expect(find.text('Connect an AI.'), findsNothing);
      expect(find.text('Message your agent from anywhere.'), findsOneWidget);
    });

    testWidgets('without a model, routines are skipped and the end says so', (
      tester,
    ) async {
      await pumpShell(tester, start: OnboardingPage.messaging);
      await tester.tap(find.text('Skip for now'));
      await settle(tester);
      expect(find.text('Almost there.'), findsOneWidget);
      expect(find.text('No AI model yet'), findsOneWidget);
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'nothing could answer',
      );
    });

    testWidgets(
      'with a model, routines show only what can run, then the recap',
      (tester) async {
        await pumpShell(
          tester,
          start: OnboardingPage.routines,
          models: const <ModelMeta>[_model],
        );
        expect(find.text('Daily recap'), findsOneWidget);
        expect(
          find.text('Hourly inbox check'),
          findsNothing,
          reason: 'needs email',
        );
        expect(find.text('Skip for now'), findsOneWidget);

        await tester.tap(find.text('Skip for now'));
        await settle(tester);
        expect(find.text('AI model ready'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      },
    );

    testWidgets('going back walks the pages actually shown', (tester) async {
      await pumpShell(
        tester,
        start: OnboardingPage.ready,
        models: const <ModelMeta>[_model],
      );
      await tester.tap(find.text('Back'));
      await settle(tester);
      expect(find.text('Daily recap'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await settle(tester);
      expect(find.text('Message your agent from anywhere.'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
    });

    for (final size in const <Size>[Size(320, 640), Size(412, 915)]) {
      for (final page in <OnboardingPage>[
        OnboardingPage.model,
        OnboardingPage.messaging,
        OnboardingPage.routines,
        OnboardingPage.ready,
      ]) {
        for (final hasModel in const <bool>[false, true]) {
          testWidgets(
            '${page.name} fits ${size.width.toInt()} wide, model: $hasModel',
            (tester) async {
              await pumpShell(
                tester,
                start: page,
                size: size,
                models: hasModel
                    ? const <ModelMeta>[_model]
                    : const <ModelMeta>[],
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i += 1) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}
