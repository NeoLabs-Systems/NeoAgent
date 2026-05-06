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
      title: 'A private\noperating layer\nfor your day.',
      description:
          'NeoOS watches the right signals, stays out of the way, and surfaces context exactly when you need it. The experience should feel calm, tactile, and immediate.',
      sidePanel: _WelcomeSidePanel(),
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
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: const <Widget>[
            OnboardingMetricPill(label: 'Memory', value: 'Context retained'),
            OnboardingMetricPill(
              label: 'Privacy',
              value: 'Local-first controls',
            ),
            OnboardingMetricPill(
              label: 'Automation',
              value: 'Reactive by design',
            ),
          ],
        ).animate().fadeIn(duration: 600.ms, delay: 380.ms),
      ),
    );
  }
}

class _WelcomeSidePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return OnboardingPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[accent, const Color(0xFF6EDBFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.layers_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Designed to feel premium,\nnot noisy.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Borrowing from Apple’s hierarchy guidance: stronger content contrast, fewer competing layers, and motion that explains rather than distracts.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms, delay: 260.ms).slideX(begin: 0.12);
  }
}
