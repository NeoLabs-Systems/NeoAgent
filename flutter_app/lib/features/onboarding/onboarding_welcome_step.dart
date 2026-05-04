import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Stack(
      children: <Widget>[
        // Abstract animated background
        Positioned.fill(
          child: CustomPaint(
            painter: _AbstractBackgroundPainter(accentColor: accent),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scaleXY(begin: 1.0, end: 1.1, curve: Curves.easeInOutSine, duration: 6000.ms)
           .shimmer(duration: 8000.ms, color: accent.withValues(alpha: 0.1)),
        ),
        
        // Grid pattern overlay
        Positioned.fill(
          child: Opacity(
            opacity: 0.05,
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),
        ),
        
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Spacer(flex: 3),
                
                // Welcome text
                Text(
                  'Welcome to\nNeoOS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -2.5,
                    color: Colors.white,
                  ),
                ).animate()
                 .fadeIn(duration: 800.ms, delay: 200.ms)
                 .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                 
                const SizedBox(height: 24),
                
                Text(
                  'A new era of intelligent interaction.\nPrivate, powerful, and deeply integrated into your workflow.',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ).animate()
                 .fadeIn(duration: 800.ms, delay: 400.ms)
                 .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                 
                const Spacer(flex: 4),
                
                // Action Button
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text(
                        'Get Started',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ).animate()
                   .fadeIn(duration: 800.ms, delay: 800.ms)
                   .slideX(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AbstractBackgroundPainter extends CustomPainter {
  _AbstractBackgroundPainter({required this.accentColor});
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      size.width * 0.4,
      paint,
    );

    paint.color = const Color(0xFF6EDBFF).withValues(alpha: 0.1);
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.8),
      size.width * 0.5,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AbstractBackgroundPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
      
    const double spacing = 40.0;
    
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
