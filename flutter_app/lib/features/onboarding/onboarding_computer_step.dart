import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../src/theme/palette.dart';
import 'onboarding_chrome.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class OnboardingComputerStep extends StatelessWidget {
  const OnboardingComputerStep({super.key, required this.onNext});

  final VoidCallback onNext;

  static List<_ComputerPoint> _points = <_ComputerPoint>[
    _ComputerPoint(
      icon: Icons.terminal_rounded,
      title: appStrings.worksLikeYouWould,
      body:
          appStrings.runsCommandsBrowsesTheWebAnd +
          appStrings.desktopToFinishTheJob,
    ),
    _ComputerPoint(
      icon: Icons.visibility_rounded,
      title: appStrings.watchItLive,
      body:
          appStrings.openTheComputerTabNextTo +
          appStrings.whileItWorks,
    ),
    _ComputerPoint(
      icon: Icons.lock_outline_rounded,
      title: appStrings.privateAndIsolated,
      body:
          appStrings.theCloudComputerIsSandboxedFrom +
          appStrings.sessionToThisDeviceWhenYou,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 3,
      totalSteps: 5,
      eyebrow: 'COMPUTER',
      title: appStrings.neoagentHasItsOwnComputer,
      description:
          appStrings.everySessionGetsAPrivateCloud +
          appStrings.realWorkInsteadOfJustTalking,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          OnboardingPrimaryButton(
            label: appStrings.continue2,
            icon: Icons.arrow_forward_rounded,
            onPressed: onNext,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _ComputerPreview()
                .animate()
                .fadeIn(duration: 500.ms, delay: 150.ms)
                .slideY(begin: 0.08, end: 0),
            const SizedBox(height: 22),
            for (var i = 0; i < _points.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ComputerPointRow(point: _points[i])
                    .animate()
                    .fadeIn(duration: 420.ms, delay: (320 + i * 90).ms)
                    .slideX(begin: 0.05, end: 0),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComputerPoint {
  const _ComputerPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _ComputerPointRow extends StatelessWidget {
  const _ComputerPointRow({required this.point});

  final _ComputerPoint point;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(point.icon, size: 19, color: p.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                point.title,
                style: GoogleFonts.geist(
                  color: p.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                point.body,
                style: GoogleFonts.geist(
                  color: p.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Stylised window showing the agent at work on its computer.
class _ComputerPreview extends StatelessWidget {
  const _ComputerPreview();

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final mono = GoogleFonts.geistMono(
      color: p.textSecondary,
      fontSize: 12,
      height: 1.7,
    );
    return Container(
      decoration: BoxDecoration(
        color: p.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.bgTertiary,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Row(
              children: <Widget>[
                for (final color in const <Color>[
                  Color(0xFFFF5F57),
                  Color(0xFFFEBC2E),
                  Color(0xFF28C840),
                ])
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.cloud_outlined, size: 14, color: p.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    appStrings.cloudComputer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.geist(
                      color: p.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _LiveBadge(color: p.success),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '\$ ',
                        style: mono.copyWith(color: p.accent),
                      ),
                      TextSpan(text: appStrings.gitCloneRepoNpmTest),
                    ],
                  ),
                  style: mono,
                ),
                Text(appStrings.n42Passing, style: mono.copyWith(color: p.success)),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '\$ ',
                        style: mono.copyWith(color: p.accent),
                      ),
                      TextSpan(text: appStrings.openBrowserCheckingDocs),
                    ],
                  ),
                  style: mono,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .fade(begin: 1, end: 0.25, duration: 900.ms),
        const SizedBox(width: 6),
        Text(
          'LIVE',
          style: GoogleFonts.geistMono(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
