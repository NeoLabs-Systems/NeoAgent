import 'package:flutter/material.dart';
import '../../main.dart';
import '../../src/theme/palette.dart';
import 'onboarding_video_step.dart';
import 'onboarding_welcome_step.dart';
import 'onboarding_companion_step.dart';
import 'onboarding_messaging_step.dart';
import 'onboarding_model_step.dart';

class OnboardingShell extends StatefulWidget {
  const OnboardingShell({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<OnboardingShell> {
  final PageController _pageController = PageController();

  void _nextStep() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  void _finish() {
    widget.controller.dismissOnboarding();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paletteOf(context).bgPrimary,
      body: PageView(
        controller: _pageController,
        physics:
            const NeverScrollableScrollPhysics(), // Managed programmatically
        children: <Widget>[
          OnboardingVideoStep(onComplete: _nextStep),
          OnboardingWelcomeStep(onNext: _nextStep),
          OnboardingCompanionStep(
            onNext: _nextStep,
            controller: widget.controller,
          ),
          OnboardingMessagingStep(
            onNext: _nextStep,
            controller: widget.controller,
          ),
          OnboardingModelStep(onNext: _finish, controller: widget.controller),
        ],
      ),
    );
  }
}

