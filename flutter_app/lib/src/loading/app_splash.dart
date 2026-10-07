import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/app_language.dart';

// The full-screen boot splash. It is a copy of the pre-Flutter splash in
// web/index.html — same mark, colors, sizes and motion — so the web handoff
// from HTML to Flutter is invisible. Keep the two in sync.

const _darkGlow = <Color>[
  Color(0xFF131B16),
  Color(0xFF0A0F0C),
  Color(0xFF0E1511),
];
const Alignment _glowCenter = Alignment(0, -0.24);
const _lightGlow = <Color>[
  Color(0xFFFDFCF8),
  Color(0xFFEDE9DC),
  Color(0xFFF4F1E8),
];

/// The NeoAgent mark breathing over a soft glow, with the wordmark and three
/// bouncing dots below. Holds still when the platform asks for reduced motion.
class AppSplash extends StatefulWidget {
  const AppSplash({super.key});

  @override
  State<AppSplash> createState() => _AppSplashState();
}

class _AppSplashState extends State<AppSplash> with TickerProviderStateMixin {
  /// Seconds since the splash appeared; every motion is a function of it.
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);

  /// Null while the platform asks for reduced motion.
  Ticker? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ticker?.dispose();
      _ticker = null;
    } else {
      _ticker ??= createTicker(
        (elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6,
      )..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final animate = _ticker != null;
    return Semantics(
      label: appStrings.loadingNeoagent,
      liveRegion: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: _glowCenter,
              radius: 1.2,
              colors: dark ? _darkGlow : _lightGlow,
              stops: const <double>[0, 0.7, 1],
              transform: const _StretchToBox(),
            ),
          ),
          child: Center(
            child: ListenableBuilder(
              listenable: _seconds,
              builder: (context, _) {
                final seconds = animate ? _seconds.value : null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _SplashMark(seconds: seconds, dark: dark),
                    const SizedBox(height: 20),
                    Text(
                      'NEOAGENT',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 15 * 0.28,
                        color:
                            (dark
                                    ? const Color(0xFFAEB7A6)
                                    : const Color(0xFF49503F))
                                .withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SplashDots(seconds: seconds, dark: dark),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Stretches the circular gradient into an ellipse over the whole box, like
/// CSS `radial-gradient(120% 120% at …)`.
class _StretchToBox extends GradientTransform {
  const _StretchToBox();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final shortest = bounds.shortestSide;
    final center = _glowCenter.withinRect(bounds);
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(bounds.width / shortest, bounds.height / shortest, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }
}

class _SplashMark extends StatelessWidget {
  const _SplashMark({required this.seconds, required this.dark});

  /// Null holds the mark still.
  final double? seconds;
  final bool dark;

  static const double _size = 88;

  @override
  Widget build(BuildContext context) {
    final t = seconds;
    final breathe = t == null ? 1.0 : 1 + 0.045 * _breath(t / 2.4 % 1);
    return Transform.scale(
      scale: breathe,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_size * 0.225),
          boxShadow: <BoxShadow>[
            dark
                ? const BoxShadow(
                    color: Color(0x59000000),
                    offset: Offset(0, 6),
                    blurRadius: 18,
                  )
                : const BoxShadow(
                    color: Color(0x2E1C2117),
                    offset: Offset(0, 6),
                    blurRadius: 16,
                  ),
          ],
        ),
        child: CustomPaint(
          size: const Size.square(_size),
          painter: _MarkPainter(seconds: t),
        ),
      ),
    );
  }
}

/// CSS `splash-breathe`: up over the first half, down over the second,
/// each half on the default `ease` curve.
double _breath(double cycle) => cycle < 0.5
    ? Curves.ease.transform(cycle * 2)
    : 1 - Curves.ease.transform((cycle - 0.5) * 2);

/// The logo tile, drawn in the SVG's 100-unit space and scaled to fit.
class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.seconds});

  final double? seconds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    const tile = Rect.fromLTWH(0, 0, 100, 100);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(tile, const Radius.circular(22.5)),
    );

    canvas.drawRect(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF705331), Color(0xFF22564C)],
        ).createShader(tile),
    );
    canvas.drawRect(
      tile,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.48, -0.72),
          radius: 0.72,
          colors: <Color>[Color(0x38FFFFFF), Color(0x00FFFFFF)],
        ).createShader(tile),
    );

    // While animating the spin replaces each orbit's resting angle, as the
    // CSS animation replaces the SVG transform attribute.
    final t = seconds;
    _orbit(
      canvas,
      radius: 17,
      dash: 78,
      opacity: 0.92,
      angle: t == null ? -35 : 360 * (t / 5.5 % 1),
    );
    _orbit(
      canvas,
      radius: 30,
      dash: 150,
      opacity: 0.8,
      angle: t == null ? 70 : -360 * (t / 8.5 % 1),
    );

    _ball(
      canvas,
      const Offset(50, 50),
      7,
      const Alignment(-0.24, -0.36),
      0.75,
      const <Color>[Color(0xFFFFFDF6), Color(0xFFEEE3CC), Color(0xFFB5A888)],
      const <double>[0, 0.48, 1],
    );
    _ball(
      canvas,
      const Offset(50, 20),
      5.6,
      const Alignment(-0.28, -0.4),
      0.8,
      const <Color>[Color(0xFFF8DCA8), Color(0xFFD3A85F), Color(0xFF9B6F2F)],
      const <double>[0, 0.52, 1],
    );
    canvas.drawCircle(
      const Offset(48, 18.4),
      1.7,
      Paint()..color = const Color(0xCCFFF7E6),
    );
    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.6, 0.6, 98.8, 98.8),
        const Radius.circular(22),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x29FFFFFF),
    );
  }

  /// One dashed ring: a single arc [dash] units long, rotated by [angle]°.
  void _orbit(
    Canvas canvas, {
    required double radius,
    required double dash,
    required double opacity,
    required double angle,
  }) {
    final bounds = Rect.fromCircle(
      center: const Offset(50, 50),
      radius: radius,
    );
    final alpha = (opacity * 255).round();
    canvas.drawArc(
      bounds,
      angle * math.pi / 180,
      dash / radius,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFFFFFAF0).withAlpha(alpha),
            const Color(0xFFEFE7D6).withAlpha(alpha),
            const Color(0xFFCABF9F).withAlpha(alpha),
          ],
          stops: const <double>[0, 0.52, 1],
        ).createShader(bounds),
    );
  }

  void _ball(
    Canvas canvas,
    Offset center,
    double radius,
    Alignment light,
    double spread,
    List<Color> colors,
    List<double> stops,
  ) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: light,
          radius: spread,
          colors: colors,
          stops: stops,
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.seconds != seconds;
}

class _SplashDots extends StatelessWidget {
  const _SplashDots({required this.seconds, required this.dark});

  /// Null holds the dots still.
  final double? seconds;
  final bool dark;

  /// Rises over the first 40% of each 1.2s cycle, falls by 80%, then rests.
  static double _lift(double cycle) {
    if (cycle < 0.4) return Curves.easeInOut.transform(cycle / 0.4);
    if (cycle < 0.8) return 1 - Curves.easeInOut.transform((cycle - 0.4) / 0.4);
    return 0;
  }

  Widget _dot(Color color, double lift) => Transform.translate(
    offset: Offset(0, -3 * lift),
    child: Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.35 + 0.65 * lift),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final color = dark ? const Color(0xFFE1B052) : const Color(0xFFB07D2B);
    final t = seconds;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < 3; index += 1) ...<Widget>[
          if (index > 0) const SizedBox(width: 6),
          _dot(color, t == null ? 0 : _lift((t - index * 0.15) / 1.2 % 1)),
        ],
      ],
    );
  }
}
