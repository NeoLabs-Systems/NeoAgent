part of 'main.dart';

abstract class AppSpacing {
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

abstract class AppBreakpoints {
  static const double mobile = 480.0;
  static const double tablet = 960.0;
}

/// Deep dark color used for QR code modules rendered on a white background.
/// Matches the dark theme's primary background hue for brand consistency.
const Color _qrDarkColor = Color(0xFF04111D);
