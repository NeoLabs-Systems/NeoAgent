import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../main.dart';
import '../../src/theme/palette.dart';
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
    final width = MediaQuery.sizeOf(context).width;
    final useGrid = width >= 700;

    return OnboardingScaffold(
      step: 2,
      totalSteps: 4,
      eyebrow: 'COMMUNICATION',
      title: 'Connect a\nmessaging platform.',
      description: 'Choose one to get started now. You can add more later.',
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
      child: useGrid
          ? GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 160,
              ),
              itemCount: platforms.length,
              itemBuilder: (context, index) {
                final platform = platforms[index];
                return _MessagingPlatformCard(
                      platform: platform,
                      selected: _selectedPlatform?.id == platform.id,
                      compact: true,
                      onTap: () => setState(() => _selectedPlatform = platform),
                    )
                    .animate()
                    .fadeIn(duration: 420.ms, delay: (180 + (index * 80)).ms)
                    .slideY(begin: 0.16, end: 0);
              },
            )
          : ListView.separated(
              itemCount: platforms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final platform = platforms[index];
                return _MessagingPlatformCard(
                      platform: platform,
                      selected: _selectedPlatform?.id == platform.id,
                      onTap: () => setState(() => _selectedPlatform = platform),
                    )
                    .animate()
                    .fadeIn(duration: 420.ms, delay: (180 + (index * 80)).ms)
                    .slideY(begin: 0.16, end: 0);
              },
            ),
    );
  }
}

class _MessagingPlatformCard extends StatelessWidget {
  const _MessagingPlatformCard({
    required this.platform,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final MessagingPlatformDescriptor platform;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final iconSize = compact ? 24.0 : 30.0;
    final shellSize = compact ? 48.0 : 58.0;
    return OnboardingOptionCard(
      selected: selected,
      accent: platform.accent,
      compact: compact,
      onTap: onTap,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: shellSize,
                      height: shellSize,
                      decoration: BoxDecoration(
                        color: platform.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        platform.icon,
                        color: platform.accent,
                        size: iconSize,
                      ),
                    ),
                    const Spacer(),
                    _SelectionIcon(
                      selected: selected,
                      color: platform.accent,
                      id: platform.id,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  platform.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  platform.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            )
          : Row(
              children: <Widget>[
                Container(
                  width: shellSize,
                  height: shellSize,
                  decoration: BoxDecoration(
                    color: platform.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    platform.icon,
                    color: platform.accent,
                    size: iconSize,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        platform.label,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        platform.subtitle,
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                _SelectionIcon(
                  selected: selected,
                  color: platform.accent,
                  id: platform.id,
                ),
              ],
            ),
    );
  }
}

class _SelectionIcon extends StatelessWidget {
  const _SelectionIcon({
    required this.selected,
    required this.color,
    required this.id,
  });

  final bool selected;
  final Color color;
  final String id;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: selected
          ? Icon(
              Icons.check_circle_rounded,
              key: ValueKey<String>(id),
              color: color,
              size: 28,
            )
          : Icon(
              Icons.add_circle_outline_rounded,
              key: ValueKey<String>('idle-$id'),
              color: p.textMuted.withValues(alpha: 0.5),
              size: 28,
            ),
    );
  }
}
