import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../src/theme/palette.dart';

/// Shared chrome for the onboarding flow.
///
/// On wide viewports this renders the "Control Surface" two-pane onboarding:
/// a brand / narrative pane on the left (logo, step counter, eyebrow, title,
/// supporting copy and progress rail) over the olive [bgPrimary] surface, and
/// an interaction pane on the right (the step's content + nav) over the deeper
/// [bgSecondary]. It is fully theme-aware — light or dark follows the system
/// brightness via [paletteOf].
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
    required this.footer,
    this.sidePanel,
    this.dense = false,
  });

  final int step;
  final int totalSteps;
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;
  final Widget footer;
  final Widget? sidePanel;
  final bool dense;

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
          // Sage glow, top-left — the brand "agent OS" atmosphere.
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
                _Brand(step: scaffold.step, totalSteps: scaffold.totalSteps),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(height: 24),
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
                _ProgressRail(
                  step: scaffold.step,
                  totalSteps: scaffold.totalSteps,
                ),
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
        padding: EdgeInsets.all(scaffold.dense ? 36 : 44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: scaffold.child),
            const SizedBox(height: 26),
            scaffold.footer,
          ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Brand(step: scaffold.step, totalSteps: scaffold.totalSteps),
          const SizedBox(height: 16),
          _ProgressRail(step: scaffold.step, totalSteps: scaffold.totalSteps),
          const SizedBox(height: 24),
          OnboardingEyebrow(scaffold.eyebrow),
          const SizedBox(height: 12),
          Text(
            scaffold.title,
            style: GoogleFonts.geist(
              color: p.textPrimary,
              fontSize: 28,
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
          const SizedBox(height: 22),
          Expanded(child: scaffold.child),
          const SizedBox(height: 18),
          scaffold.footer,
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[p.accentAlt, p.accent],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.blur_on_rounded, size: 19, color: Colors.white),
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
            const SizedBox(height: 2),
            Text(
              'STEP ${step + 1} OF $totalSteps',
              style: GoogleFonts.geistMono(
                color: p.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressRail extends StatelessWidget {
  const _ProgressRail({required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(totalSteps, (index) {
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

class OnboardingPanel extends StatelessWidget {
  const OnboardingPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: child,
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
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.lerp(gold, Colors.white, 0.16)!,
              gold,
            ],
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 17),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: GoogleFonts.geist(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (icon != null) ...<Widget>[
                    const SizedBox(width: 9),
                    Icon(icon, size: 18, color: Colors.white),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingMetricPill extends StatelessWidget {
  const OnboardingMetricPill({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: GoogleFonts.geistMono(
              color: p.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.geist(
              color: p.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
