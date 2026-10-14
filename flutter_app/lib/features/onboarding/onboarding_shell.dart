import 'dart:async';

import 'package:flutter/material.dart';
import '../../main.dart';
import '../../src/theme/palette.dart';
import 'onboarding_chrome.dart';
import 'onboarding_computer_step.dart';
import 'onboarding_ready_step.dart';
import 'onboarding_tasks_step.dart';
import 'onboarding_video_step.dart';
import 'onboarding_welcome_step.dart';
import 'onboarding_messaging_step.dart';
import 'onboarding_model_step.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

enum _Page { video, welcome, model, computer, messaging, routines, ready }

class OnboardingShell extends StatefulWidget {
  const OnboardingShell({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<OnboardingShell> {
  /// The welcome page: the first content step, which has nothing to go back to.
  static const int _welcomePage = 1;

  /// Only the desktop app can hand NeoAgent its own computer, so only there
  /// is there a choice to make; web and phones always use the cloud computer.
  late final List<_Page> _pages = <_Page>[
    _Page.video,
    _Page.welcome,
    _Page.model,
    if (widget.controller.localComputerSupported) _Page.computer,
    _Page.messaging,
    _Page.routines,
    _Page.ready,
  ];

  /// The steps counted in the progress rail, between welcome and ready.
  late final List<_Page> _steps = _pages.sublist(
    _welcomePage + 1,
    _pages.length - 1,
  );

  late final PageController _pageController;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.controller.onboardingResumeStep.clamp(0, _pages.length - 1);
    _pageController = PageController(initialPage: _page);
  }

  void _goTo(int page) {
    setState(() => _page = page);
    widget.controller.rememberOnboardingStep(page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  void _nextStep() {
    if (_page < _pages.length - 1) _goTo(_page + 1);
  }

  void _previousStep() {
    if (_page > _welcomePage) _goTo(_page - 1);
  }

  /// Leaves onboarding for the normal chat, sending [message] there once the
  /// server has confirmed setup is complete.
  Future<void> _finish(String message) async {
    final controller = widget.controller;
    controller.setSelectedSection(AppSection.chat);
    await controller.dismissOnboarding();
    if (controller.showOnboarding || message.isEmpty) return;
    unawaited(controller.sendMessage(message));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ({String label, String tag}) _stepSummary(_Page page) => switch (page) {
    _Page.model => (
      label: appStrings.model,
      tag: appStrings.onboardingStepRequired,
    ),
    _Page.computer => (
      label: appStrings.onboardingStepComputer,
      tag: appStrings.onboardingStepCloudOrLocal,
    ),
    _Page.messaging => (
      label: appStrings.messaging,
      tag: appStrings.onboardingStepOptional,
    ),
    _ => (
      label: appStrings.onboardingStepRoutines,
      tag: appStrings.onboardingStepOptional,
    ),
  };

  Widget _buildPage(_Page page) {
    final controller = widget.controller;
    return switch (page) {
      _Page.video => OnboardingVideoStep(onComplete: _nextStep),
      _Page.welcome => OnboardingWelcomeStep(
        onNext: _nextStep,
        steps: _steps.map(_stepSummary).toList(),
      ),
      _Page.model => OnboardingModelStep(
        onNext: _nextStep,
        onBack: _previousStep,
        controller: controller,
      ),
      _Page.computer => OnboardingComputerStep(
        onNext: _nextStep,
        onBack: _previousStep,
        controller: controller,
      ),
      _Page.messaging => OnboardingMessagingStep(
        onNext: _nextStep,
        onBack: _previousStep,
        controller: controller,
      ),
      _Page.routines => OnboardingTasksStep(
        onNext: _nextStep,
        onBack: _previousStep,
        controller: controller,
      ),
      _Page.ready => OnboardingReadyStep(
        onFinish: _finish,
        onBack: _previousStep,
        controller: controller,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _page > _welcomePage;
    return PopScope(
      // System back walks the steps backwards instead of leaving the app.
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previousStep();
      },
      child: Scaffold(
        backgroundColor: paletteOf(context).bgPrimary,
        body: PageView(
          controller: _pageController,
          physics:
              const NeverScrollableScrollPhysics(), // Managed programmatically
          children: <Widget>[
            for (var i = 0; i < _pages.length; i++)
              OnboardingStepScope(
                step: i <= _welcomePage
                    ? -1
                    : (i - _welcomePage - 1).clamp(0, _steps.length),
                totalSteps: _steps.length,
                child: _buildPage(_pages[i]),
              ),
          ],
        ),
      ),
    );
  }
}
