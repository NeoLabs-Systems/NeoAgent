import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../src/mascot/mascot_mood.dart';
import '../../src/theme/palette.dart';
import 'onboarding_chrome.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({
    super.key,
    required this.onNext,
    required this.steps,
  });

  final VoidCallback onNext;

  /// The steps ahead, each with a tag saying whether it can be skipped.
  final List<({String label, String tag})> steps;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return OnboardingScaffold(
      mood: MascotMood.idle,
      eyebrow: appStrings.onboardingEyebrowWelcome,
      title: appStrings.welcomeToNeoagent2,
      description: appStrings.yourAssistantLayerForCaptureContext,
      footer: OnboardingFooter(
        primary: OnboardingPrimaryButton(
          label: appStrings.continue2,
          icon: Icons.arrow_forward_rounded,
          onPressed: onNext,
        ).animate().fadeIn(duration: 600.ms, delay: 600.ms).slideY(begin: 0.2),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child:
                    Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: p.bgPrimary,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: p.border),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: p.accent.withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: GoogleFonts.geistMono(
                                    color: p.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  steps[i].label,
                                  style: GoogleFonts.geist(
                                    color: p.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                steps[i].tag.toUpperCase(),
                                style: GoogleFonts.geistMono(
                                  color: p.textMuted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 420.ms, delay: (300 + i * 80).ms)
                        .slideY(begin: 0.12, end: 0),
              ),
          ],
        ),
      ),
    );
  }
}
