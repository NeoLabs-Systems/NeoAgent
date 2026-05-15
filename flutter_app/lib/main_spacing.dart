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

/// Canonical border-radius scale. Use these instead of raw `circular()` values.
///
/// tag   → chips, code blocks, inline badges
/// card  → secondary cards, list items, dialogs
/// input → buttons, text fields (matches theme InputDecorationTheme)
/// panel → major glass surfaces, primary cards (matches theme CardTheme)
/// pill  → avatars, full-pill badges, status indicators
abstract class AppRadius {
  static const double tag   = 8.0;
  static const double card  = 14.0;
  static const double input = 18.0;
  static const double panel = 28.0;
  static const double pill  = 999.0;
}

/// Deep dark color used for QR code modules rendered on a white background.
/// Matches the dark theme's primary background hue for brand consistency.
const Color _qrDarkColor = Color(0xFF04111D);
