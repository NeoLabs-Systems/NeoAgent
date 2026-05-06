import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../main.dart';
import 'onboarding_chrome.dart';

class OnboardingMessagingStep extends StatefulWidget {
  const OnboardingMessagingStep({
    super.key,
    required this.onNext,
    required this.controller,
  });

  final VoidCallback onNext;
  final NeoAgentController controller;

  @override
  State<OnboardingMessagingStep> createState() =>
      _OnboardingMessagingStepState();
}

class _OnboardingMessagingStepState extends State<OnboardingMessagingStep> {
  MessagingPlatformDescriptor? _selectedPlatform;

  @override
  Widget build(BuildContext context) {
    final platforms = messagingPlatforms.length > 5
        ? messagingPlatforms.take(5).toList()
        : messagingPlatforms;

    return OnboardingScaffold(
      step: 2,
      totalSteps: 4,
      eyebrow: 'COMMUNICATION',
      title: 'Connect the channels\nyou actually use.',
      description:
          'Choose one messaging surface to start. NeoOS can prepare context, monitor the right signals, and keep the interaction layer close to your real workflow.',
      sidePanel: OnboardingPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Setup principle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Start with one high-value integration first. The product feels smarter when the first connection is relevant, not exhaustive.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            const Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OnboardingMetricPill(label: 'Signal', value: 'Relevant only'),
                OnboardingMetricPill(label: 'Access', value: 'Configurable'),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          OnboardingGhostButton(
            label: 'Skip for now',
            onPressed: widget.onNext,
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              if (_selectedPlatform != null)
                OnboardingGhostButton(
                  label: 'Configure',
                  icon: Icons.settings_rounded,
                  onPressed: () async {
                    try {
                      await openMessagingConfig(
                        context,
                        widget.controller,
                        _selectedPlatform!,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to connect: $e')),
                        );
                      }
                    }
                  },
                ),
              OnboardingPrimaryButton(
                label: _selectedPlatform == null ? 'Continue' : 'Next',
                icon: Icons.arrow_forward_rounded,
                onPressed: widget.onNext,
              ),
            ],
          ),
        ],
      ),
      child: ListView.separated(
        itemCount: platforms.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == platforms.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: Text(
                'More providers stay available later in Settings.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final platform = platforms[index];
          final selected = _selectedPlatform?.id == platform.id;
          return OnboardingOptionCard(
                selected: selected,
                accent: platform.accent,
                onTap: () => setState(() => _selectedPlatform = platform),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: platform.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        platform.icon,
                        color: platform.accent,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            platform.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            platform.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              key: ValueKey<String>(platform.id),
                              color: platform.accent,
                              size: 28,
                            )
                          : Icon(
                              Icons.add_circle_outline_rounded,
                              key: ValueKey<String>('idle-${platform.id}'),
                              color: Colors.white.withValues(alpha: 0.26),
                              size: 28,
                            ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 420.ms, delay: (180 + (index * 80)).ms)
              .slideY(begin: 0.16, end: 0);
        },
      ),
    );
  }
}
