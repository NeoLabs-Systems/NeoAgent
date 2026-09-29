import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../src/theme/palette.dart';
import 'onboarding_chrome.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 0,
      totalSteps: 5,
      eyebrow: 'WELCOME',
      title: appStrings.welcomeToNeoagent2,
      description: appStrings.yourAssistantLayerForCaptureContext,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          OnboardingPrimaryButton(
                label: appStrings.continue2,
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
              appStrings.setUpYourWorkspaceInA,
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
