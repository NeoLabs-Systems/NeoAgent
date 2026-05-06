import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'onboarding_chrome.dart';

class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 1,
      totalSteps: 4,
      eyebrow: 'WELCOME',
      title: 'Welcome to\nNeoOS',
      description: 'Your assistant layer for capture, context, and action.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          OnboardingPrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: onNext,
              )
              .animate()
              .fadeIn(duration: 600.ms, delay: 600.ms)
              .slideY(begin: 0.2),
        ],
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          'Set up your workspace in a few steps and start using NeoOS immediately.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 18,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 380.ms),
      ),
    );
  }
}
