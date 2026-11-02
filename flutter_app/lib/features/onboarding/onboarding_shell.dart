import 'dart:async';

import 'package:flutter/material.dart';
import '../../main.dart';
import '../../src/theme/palette.dart';
import '../tasks/task_recommendations.dart';
import 'onboarding_chrome.dart';
import 'onboarding_computer_step.dart';
import 'onboarding_flow.dart';
import 'onboarding_messaging_step.dart';
import 'onboarding_model_step.dart';
import 'onboarding_ready_step.dart';
import 'onboarding_tasks_step.dart';
import 'onboarding_video_step.dart';

class OnboardingShell extends StatefulWidget {
  const OnboardingShell({super.key, required this.controller, this.startPage});

  final NeoAgentController controller;

  /// Where to begin instead of the remembered page.
  final OnboardingPage? startPage;

  @override
  State<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<OnboardingShell> {
  /// Whether this person gets the model step; unknown until the catalog loads.
  /// Decided once, so someone who just connected a model can still go back to it.
  bool? _modelStepNeeded;
  late OnboardingPage _page;

  NeoAgentController get _controller => widget.controller;

  /// Only the desktop app can hand NeoAgent its own computer, so only there is
  /// there a choice to make; web and phones always use the cloud computer.
  List<OnboardingPage> get _pages => onboardingPages(
    needsModelStep: _modelStepNeeded ?? true,
    hasComputerChoice: _controller.localComputerSupported,
    hasRoutines: taskRecommendations.any(
      (recommendation) =>
          _controller.taskRecommendationBlockedReason(recommendation) == null,
    ),
  );

  @override
  void initState() {
    super.initState();
    _settleModelStep();
    _page =
        widget.startPage ??
        resumeOnboardingPage(_pages, _controller.onboardingResumeStep);
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _settleModelStep() {
    if (_modelStepNeeded != null || !_controller.hasLoadedInitialData) return;
    _modelStepNeeded = !_controller.hasUsableChatModel;
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _settleModelStep();
    final pages = _pages;
    if (pages.contains(_page)) {
      setState(() {});
      return;
    }
    // This page turned out not to be needed, like the model step once the
    // catalog arrives with models in it.
    _goTo(resumeOnboardingPage(pages, _page.index));
  }

  void _goTo(OnboardingPage page) {
    setState(() => _page = page);
    _controller.rememberOnboardingStep(page.index);
  }

  void _nextStep() {
    final pages = _pages;
    final index = pages.indexOf(_page);
    if (index >= 0 && index < pages.length - 1) _goTo(pages[index + 1]);
  }

  void _previousStep() {
    final pages = _pages;
    final index = pages.indexOf(_page);
    // The intro is not somewhere to go back to.
    if (index > 1) _goTo(pages[index - 1]);
  }

  /// Leaves onboarding for the normal chat, sending [message] there once the
  /// server has confirmed setup is complete.
  Future<void> _finish(String message) async {
    _controller.setSelectedSection(AppSection.chat);
    await _controller.dismissOnboarding();
    if (_controller.showOnboarding || message.isEmpty) return;
    unawaited(_controller.sendMessage(message));
  }

  Widget _buildPage(OnboardingPage page, bool canGoBack) {
    final onBack = canGoBack ? _previousStep : null;
    return switch (page) {
      OnboardingPage.intro => OnboardingVideoStep(onComplete: _nextStep),
      OnboardingPage.model => OnboardingModelStep(
        onNext: _nextStep,
        onBack: onBack,
        controller: _controller,
      ),
      OnboardingPage.computer => OnboardingComputerStep(
        onNext: _nextStep,
        onBack: onBack,
        controller: _controller,
      ),
      OnboardingPage.messaging => OnboardingMessagingStep(
        onNext: _nextStep,
        onBack: onBack,
        controller: _controller,
      ),
      OnboardingPage.routines => OnboardingTasksStep(
        onNext: _nextStep,
        onBack: onBack,
        controller: _controller,
      ),
      OnboardingPage.ready => OnboardingReadyStep(
        onFinish: _finish,
        onBack: onBack,
        controller: _controller,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final steps = pages.sublist(1, pages.length - 1);
    final canGoBack = pages.indexOf(_page) > 1;
    return PopScope(
      // System back walks the steps backwards instead of leaving the app.
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previousStep();
      },
      child: Scaffold(
        backgroundColor: paletteOf(context).bgPrimary,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: OnboardingStepScope(
            key: ValueKey<OnboardingPage>(_page),
            step: _page == OnboardingPage.intro
                ? -1
                : _page == OnboardingPage.ready
                ? steps.length
                : steps.indexOf(_page),
            totalSteps: steps.length,
            child: _buildPage(_page, canGoBack),
          ),
        ),
      ),
    );
  }
}
