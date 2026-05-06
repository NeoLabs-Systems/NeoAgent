import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

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
                  child: compact
                      ? _OnboardingPanel(
                          padding: EdgeInsets.all(dense ? 22 : 26),
                          child: _OnboardingContentColumn(
                            eyebrow: eyebrow,
                            title: title,
                            description: description,
                            footer: footer,
                            sidePanel: sidePanel,
                            compact: true,
                            child: child,
                          ),
                        )
                      : _OnboardingPanel(
                          padding: const EdgeInsets.all(34),
                          child: _OnboardingContentColumn(
                            eyebrow: eyebrow,
                            title: title,
                            description: description,
                            footer: footer,
                            sidePanel: sidePanel,
                            compact: false,
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
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final highlight = accent ?? Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: selected
                ? highlight.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: selected
                  ? highlight.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.1),
              width: selected ? 1.8 : 1,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: highlight.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
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
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.26),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(label),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    final progress = totalSteps <= 1 ? 1.0 : (step + 1) / totalSteps;
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'NeoOS Setup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
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
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '${step + 1} / $totalSteps',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w700,
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
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.92),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 40 : 56,
            height: compact ? 1.04 : 1.0,
            fontWeight: FontWeight.w800,
            letterSpacing: compact ? -1.6 : -2.3,
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: compact ? 17 : 19,
              height: 1.55,
              fontWeight: FontWeight.w500,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.08),
                const Color(0xFF111317).withValues(alpha: 0.72),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 46,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.8, -0.95),
          radius: 1.8,
          colors: <Color>[
            Color(0xFF20242C),
            Color(0xFF0C0F13),
            Color(0xFF040506),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            left: -80,
            child: _GlowOrb(size: 340, color: accent.withValues(alpha: 0.24)),
          ),
          const Positioned(
            top: 120,
            right: -60,
            child: _GlowOrb(size: 300, color: Color(0x226EDBFF)),
          ),
          const Positioned(
            bottom: -120,
            left: 160,
            child: _GlowOrb(size: 420, color: Color(0x18D7B27C)),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.04),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.26),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(color: color, blurRadius: 160, spreadRadius: 28),
          ],
        ),
      ),
    );
  }
}
