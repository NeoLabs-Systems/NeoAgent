import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../src/theme/palette.dart';
import 'onboarding_chrome.dart';

class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 0,
      totalSteps: 4,
      eyebrow: 'WELCOME',
      title: 'Welcome to\nNeoAgent',
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
      child: Builder(
        builder: (context) {
          final p = paletteOf(context);
          return Align(
            alignment: Alignment.topLeft,
            child: Text(
              'Set up your workspace in a few steps and start using NeoAgent immediately.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: p.textSecondary,
                height: 1.6,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 380.ms),
          );
        },
      ),
    );
  }
}
