import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../src/theme/palette.dart';

/// Shared chrome for the onboarding flow, styled to the "Control Surface"
/// design language: paper/olive surfaces, ink text and mono gold-ink eyebrows.
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 980;
    return Stack(
      children: <Widget>[
        const Positioned.fill(child: _OnboardingBackdrop()),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 20 : 32,
              compact ? 16 : 22,
              compact ? 20 : 32,
              compact ? 20 : 28,
            ),
            child: Column(
              children: <Widget>[
                _OnboardingTopBar(step: step, totalSteps: totalSteps),
                const SizedBox(height: 18),
                Expanded(
                  child: _OnboardingPanel(
                    padding: EdgeInsets.all(
                      compact ? (dense ? 22 : 26) : 34,
                    ),
                    child: _OnboardingContentColumn(
                      eyebrow: eyebrow,
                      title: title,
                      description: description,
                      footer: footer,
                      sidePanel: sidePanel,
                      compact: compact,
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    return _OnboardingPanel(padding: padding, child: child);
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
    final radius = compact ? 16.0 : 21.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(compact ? 16 : 18),
          decoration: BoxDecoration(
            color: selected
                ? highlight.withValues(alpha: 0.08)
                : p.bgCard,
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
        foregroundColor: p.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
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
              Color.lerp(gold, Colors.white, 0.14)!,
              gold,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: gold.withValues(alpha: 0.32),
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
                    style: const TextStyle(
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
        color: p.bgSecondary,
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
            style: TextStyle(
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
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.8,
      ),
    );
  }
}

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final progress = totalSteps <= 1 ? 1.0 : (step + 1) / totalSteps;
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[p.accentAlt, p.accent],
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.blur_on_rounded,
            size: 17,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 11),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'NeoAgent',
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'SETUP',
              style: GoogleFonts.geistMono(
                color: p.textMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, _) {
                return LinearProgressIndicator(
                  value: animatedValue,
                  minHeight: 5,
                  backgroundColor: p.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(p.accent),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '${step + 1} / $totalSteps',
          style: GoogleFonts.geistMono(
            color: p.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _OnboardingContentColumn extends StatelessWidget {
  const _OnboardingContentColumn({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
    required this.footer,
    required this.sidePanel,
    required this.compact,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget child;
  final Widget footer;
  final Widget? sidePanel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OnboardingEyebrow(eyebrow),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            color: p.textPrimary,
            fontSize: compact ? 28 : 34,
            height: 1.08,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            description,
            style: TextStyle(
              color: p.textMuted,
              fontSize: compact ? 14.5 : 15.5,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          intro,
          const SizedBox(height: 26),
          if (sidePanel != null) ...<Widget>[
            sidePanel!,
            const SizedBox(height: 18),
          ],
          Expanded(child: child),
          const SizedBox(height: 20),
          footer,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 12, child: intro),
            if (sidePanel != null) ...<Widget>[
              const SizedBox(width: 28),
              Expanded(flex: 7, child: sidePanel!),
            ],
          ],
        ),
        const SizedBox(height: 28),
        Expanded(child: child),
        const SizedBox(height: 22),
        footer,
      ],
    );
  }
}

class _OnboardingPanel extends StatelessWidget {
  const _OnboardingPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.5 : 0.1),
            blurRadius: 46,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop();

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: p.bgPrimary),
      child: Stack(
        children: <Widget>[
          // Sage wash, top-right.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.85, -1.0),
                  radius: 1.1,
                  colors: <Color>[
                    p.accentAlt.withValues(alpha: 0.14),
                    p.accentAlt.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          // Gold wash, bottom-left.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.9, 1.1),
                  radius: 1.0,
                  colors: <Color>[
                    p.accentMuted,
                    p.accentMuted.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
