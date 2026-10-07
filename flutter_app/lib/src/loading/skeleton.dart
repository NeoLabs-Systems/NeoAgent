import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Sweeps one soft highlight across every [SkeletonBlock] below it, so a
/// whole placeholder page shimmers in sync instead of block by block.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with TickerProviderStateMixin {
  /// Null while the platform asks for reduced motion.
  AnimationController? _sweep;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep?.dispose();
      _sweep = null;
    } else {
      _sweep ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _sweep?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sweep = _sweep;
    if (sweep == null) {
      return widget.child;
    }
    final tones = _SkeletonTones.of(context);
    return AnimatedBuilder(
      animation: sweep,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[tones.base, tones.highlight, tones.base],
          stops: const <double>[0.35, 0.5, 0.65],
          transform: _SlideGradient(sweep.value),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

/// Placeholder colors as a faint wash of the ink over the page, so blocks
/// read the same in the light and the dark theme.
class _SkeletonTones {
  const _SkeletonTones(this.base, this.highlight);

  factory _SkeletonTones.of(BuildContext context) {
    final palette = paletteFor(Theme.of(context).brightness);
    Color wash(double alpha) => Color.alphaBlend(
      palette.textPrimary.withValues(alpha: alpha),
      palette.bgPrimary,
    );
    return _SkeletonTones(wash(0.07), wash(0.15));
  }

  final Color base;
  final Color highlight;
}

/// Moves the gradient from fully off the left edge to fully off the right.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
}

/// A rounded placeholder shape. Inside a [SkeletonShimmer] its fill is
/// replaced by the shimmer; on its own it shows the resting tone.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
  });

  /// A circle, for avatars and status icons.
  const SkeletonBlock.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = size / 2;

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _SkeletonTones.of(context).base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A text line of [widthFactor] of the available width.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.widthFactor = 1, this.height = 11});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: SkeletonBlock(height: height),
    );
  }
}
