import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../src/mascot/mascot_mood.dart';
import '../../src/mascot/neo_mascot.dart';
import '../../src/theme/palette.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

/// Where a page sits in the onboarding flow. The shell decides which steps a
/// platform gets, so the pages read their position from here instead of
/// hard-coding it.
class OnboardingStepScope extends InheritedWidget {
  const OnboardingStepScope({
    super.key,
    required this.step,
    required this.totalSteps,
    required super.child,
  });

  /// Zero-based step, -1 before the first step and [totalSteps] once done.
  final int step;
  final int totalSteps;

  static OnboardingStepScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingStepScope>()!;

  @override
  bool updateShouldNotify(OnboardingStepScope oldWidget) =>
      step != oldWidget.step || totalSteps != oldWidget.totalSteps;
}

/// Shared chrome for the onboarding flow.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.mood,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
    required this.footer,
    this.sidePanel,
    this.fill = false,
  });

  /// The mascot's face for this step.
  final MascotMood mood;
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;
  final Widget footer;
  final Widget? sidePanel;

  /// The step's content is a long list that should take the full height
  /// instead of sitting centred.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (!wide) {
      return ColoredBox(
        color: p.bgPrimary,
        child: SafeArea(child: _CompactBody(scaffold: this)),
      );
    }

    return ColoredBox(
      color: p.bgPrimary,
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(flex: 43, child: _NarrativePane(scaffold: this)),
            Expanded(flex: 57, child: _InteractionPane(scaffold: this)),
          ],
        ),
      ),
    );
  }
}

class _NarrativePane extends StatelessWidget {
  const _NarrativePane({required this.scaffold});

  final OnboardingScaffold scaffold;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: p.bgPrimary),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.8, -0.9),
                  radius: 1.2,
                  colors: <Color>[
                    p.accentAlt.withValues(alpha: 0.20),
                    p.accentAlt.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(52, 44, 44, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _Brand(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(height: 24),
                          NeoMascot(mood: scaffold.mood, size: 96),
                          const SizedBox(height: 32),
                          OnboardingEyebrow(scaffold.eyebrow),
                          const SizedBox(height: 18),
                          Text(
                            scaffold.title,
                            style: GoogleFonts.geist(
                              color: p.textPrimary,
                              fontSize: 42,
                              height: 1.04,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Text(
                              scaffold.description,
                              style: GoogleFonts.geist(
                                color: p.textSecondary,
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
                          ),
                          if (scaffold.sidePanel != null) ...<Widget>[
                            const SizedBox(height: 28),
                            scaffold.sidePanel!,
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                const _ProgressRail(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionPane extends StatelessWidget {
  const _InteractionPane({required this.scaffold});

  final OnboardingScaffold scaffold;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bgSecondary,
        border: Border(left: BorderSide(color: p.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(44),
        child: Center(
          child: ConstrainedBox(
            // Choices read as one group instead of stretching across the pane.
            constraints: BoxConstraints(maxWidth: scaffold.fill ? 560 : 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: scaffold.fill
                      ? scaffold.child
                      : Center(child: scaffold.child),
                ),
                const SizedBox(height: 26),
                scaffold.footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactBody extends StatelessWidget {
  const _CompactBody({required this.scaffold});

  final OnboardingScaffold scaffold;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Short screens (a phone in landscape after the intro) cap the
          // header and let it scroll, so the step's own content keeps room.
          final short = constraints.maxHeight < 600;
          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _Brand(),
              const SizedBox(height: 16),
              const _ProgressRail(),
              SizedBox(height: short ? 14 : 24),
              // Long lists need the room more than the face does.
              if (!short && !scaffold.fill) ...<Widget>[
                NeoMascot(mood: scaffold.mood, size: 56),
                const SizedBox(height: 18),
              ],
              OnboardingEyebrow(scaffold.eyebrow),
              const SizedBox(height: 12),
              Text(
                scaffold.title,
                style: GoogleFonts.geist(
                  color: p.textPrimary,
                  fontSize: short ? 22 : 28,
                  height: 1.06,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                scaffold.description,
                style: GoogleFonts.geist(
                  color: p.textSecondary,
                  fontSize: 14.5,
                  height: 1.55,
                ),
              ),
              if (scaffold.sidePanel != null) ...<Widget>[
                const SizedBox(height: 18),
                scaffold.sidePanel!,
              ],
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * (short ? 0.34 : 0.45),
                ),
                child: SingleChildScrollView(child: header),
              ),
              SizedBox(height: short ? 12 : 22),
              Expanded(child: scaffold.child),
              SizedBox(height: short ? 10 : 18),
              scaffold.footer,
            ],
          );
        },
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final scope = OnboardingStepScope.of(context);
    final String? counter;
    if (scope.step < 0) {
      counter = appStrings.onboardingQuickSteps(scope.totalSteps);
    } else if (scope.step < scope.totalSteps) {
      counter = appStrings.stepArg1OfArg2(scope.step + 1, scope.totalSteps);
    } else {
      counter = null;
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: p.accent.withValues(alpha: 0.16),
                blurRadius: 14,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              dark
                  ? 'assets/branding/app_icon_1024.png'
                  : 'assets/branding/app_icon_light_1024.png',
              width: 36,
              height: 36,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'NeoAgent',
              style: GoogleFonts.geist(
                color: p.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (counter != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                counter.toUpperCase(),
                style: GoogleFonts.geistMono(
                  color: p.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ProgressRail extends StatelessWidget {
  const _ProgressRail();

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final scope = OnboardingStepScope.of(context);
    final step = scope.step;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(scope.totalSteps, (index) {
        final active = index == step;
        final done = index < step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(right: 8),
          width: active ? 30 : 16,
          height: 5,
          decoration: BoxDecoration(
            color: active || done ? p.accent : p.borderLight,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    super.key,
    required this.child,
    required this.selected,
    this.onTap,
    this.accent,
    this.compact = false,
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final Color? accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final highlight = accent ?? p.accent;
    final radius = compact ? 16.0 : 20.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(compact ? 16 : 18),
          decoration: BoxDecoration(
            color: selected ? highlight.withValues(alpha: 0.08) : p.bgCard,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? highlight : p.borderLight,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: highlight.withValues(alpha: 0.22),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: child,
        ),
      ),
    );
  }
}

class OnboardingGhostButton extends StatelessWidget {
  const OnboardingGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: p.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: GoogleFonts.geist(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.border),
        ),
      ),
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final enabled = onPressed != null;
    final gold = p.accent;
    // Dark ink on the bright dark-theme gold; white on the deeper light one.
    final ink = Theme.of(context).brightness == Brightness.dark
        ? p.bgPrimary
        : Colors.white;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color.lerp(gold, Colors.white, 0.16)!, gold],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: gold.withValues(alpha: 0.34),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            // Centred when a narrow footer stretches the button full width.
            child: Center(
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 17,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: GoogleFonts.geist(
                        color: ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (icon != null) ...<Widget>[
                      const SizedBox(width: 9),
                      Icon(icon, size: 18, color: ink),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mono gold-ink eyebrow label, matching the design's `.eyebrow` treatment.
class OnboardingEyebrow extends StatelessWidget {
  const OnboardingEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.geistMono(
        color: p.accentHover,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.8,
      ),
    );
  }
}

/// Footer actions for an onboarding step: an optional Back button, optional
/// secondary actions and the primary action. Lays out in one row where there
/// is room and stacks with the primary action on top on narrow screens.
class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({
    super.key,
    required this.primary,
    this.onBack,
    this.secondary = const <Widget>[],
  });

  final Widget primary;
  final VoidCallback? onBack;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    final leading = <Widget>[
      if (onBack != null)
        OnboardingGhostButton(
          label: appStrings.back,
          icon: Icons.arrow_back_rounded,
          onPressed: onBack,
        ),
      ...secondary,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return Row(
            children: <Widget>[
              Expanded(
                child: Wrap(spacing: 12, runSpacing: 12, children: leading),
              ),
              const SizedBox(width: 12),
              primary,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            primary,
            if (leading.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 10,
                runSpacing: 10,
                children: leading,
              ),
            ],
          ],
        );
      },
    );
  }
}
