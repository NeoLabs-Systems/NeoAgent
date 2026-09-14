import 'package:flutter/widgets.dart';

/// Resolves the active [NeoAgentPalette] for the given [brightness].
NeoAgentPalette paletteFor(Brightness brightness) =>
    brightness == Brightness.light ? lightPalette : darkPalette;

/// Resolves the active [NeoAgentPalette] from the ambient theme brightness.
NeoAgentPalette paletteOf(BuildContext context) =>
    paletteFor(MediaQuery.platformBrightnessOf(context));

/// Color tokens for the NeoAgent UI. Screens should read these via theme getters.
class NeoAgentPalette {
  const NeoAgentPalette({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.bgCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentHover,
    required this.accentAlt,
    required this.accentMuted,
    required this.border,
    required this.borderLight,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// Page background ("paper" by day, "deep olive" by night).
  final Color bgPrimary;

  /// Slightly recessed background used for rails and inset wells.
  final Color bgSecondary;

  /// Tertiary surface for nested wells, track fills and pressed states.
  final Color bgTertiary;

  /// Raised surface for cards, sheets and bubbles.
  final Color bgCard;

  /// Primary ink — headings and body text.
  final Color textPrimary;

  /// Secondary ink — supporting copy and inactive labels.
  final Color textSecondary;

  /// Muted ink — captions, placeholders and disabled glyphs.
  final Color textMuted;

  /// Primary action and focus color.
  final Color accent;

  /// Hover/link variant of [accent].
  final Color accentHover;

  /// Secondary accent for calls and traces.
  final Color accentAlt;

  /// Translucent gold wash for soft fills and selection backgrounds.
  final Color accentMuted;

  /// Hairline divider color.
  final Color border;

  /// Stronger hairline for inputs and interactive outlines.
  final Color borderLight;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
}

/// Dark theme palette.
const NeoAgentPalette darkPalette = NeoAgentPalette(
  bgPrimary: Color(0xFF0E1511),
  bgSecondary: Color(0xFF171F1A),
  bgTertiary: Color(0xFF1C261F),
  bgCard: Color(0xFF171F1A),
  textPrimary: Color(0xFFECEFE5),
  textSecondary: Color(0xFFAEB7A6),
  textMuted: Color(0xFF7E8877),
  accent: Color(0xFFE1B052),
  accentHover: Color(0xFFEAC272),
  accentAlt: Color(0xFF84BA87),
  accentMuted: Color(0x24E1B052),
  border: Color(0x14E0F0E0),
  borderLight: Color(0x24E0F0E0),
  success: Color(0xFF74C07C),
  warning: Color(0xFFD9A24B),
  danger: Color(0xFFDE8A78),
  info: Color(0xFF6FB0A4),
);

/// Light theme palette.
const NeoAgentPalette lightPalette = NeoAgentPalette(
  bgPrimary: Color(0xFFF4F1E8),
  bgSecondary: Color(0xFFEDE9DC),
  bgTertiary: Color(0xFFF1EDE1),
  bgCard: Color(0xFFFDFCF8),
  textPrimary: Color(0xFF1C2117),
  textSecondary: Color(0xFF49503F),
  textMuted: Color(0xFF7E8470),
  accent: Color(0xFFB07D2B),
  accentHover: Color(0xFFC8943F),
  accentAlt: Color(0xFF5E6B4C),
  accentMuted: Color(0x24B07D2B),
  border: Color(0x1A1C2117),
  borderLight: Color(0x291C2117),
  success: Color(0xFF527C4F),
  warning: Color(0xFF9A6B1E),
  danger: Color(0xFFAE473C),
  info: Color(0xFF2F7D6E),
);
