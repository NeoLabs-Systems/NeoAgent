import 'package:flutter/widgets.dart';

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

  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgTertiary;
  final Color bgCard;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentHover;
  final Color accentAlt;
  final Color accentMuted;
  final Color border;
  final Color borderLight;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
}

const NeoAgentPalette darkPalette = NeoAgentPalette(
  bgPrimary: Color(0xFF071015),
  bgSecondary: Color(0xFF0E171E),
  bgTertiary: Color(0xFF15232B),
  bgCard: Color(0xFF131E25),
  textPrimary: Color(0xFFF5EFE4),
  textSecondary: Color(0xFFB4B3AE),
  textMuted: Color(0xFF7E8B93),
  accent: Color(0xFFC7A36A),
  accentHover: Color(0xFFE4C58D),
  accentAlt: Color(0xFF5FA897),
  accentMuted: Color(0x24C7A36A),
  border: Color(0x204F626E),
  borderLight: Color(0x30667A86),
  success: Color(0xFF37B67E),
  warning: Color(0xFFD49A43),
  danger: Color(0xFFE26E61),
  info: Color(0xFF74A8D9),
);

const NeoAgentPalette lightPalette = NeoAgentPalette(
  bgPrimary: Color(0xFFF6F1E8),
  bgSecondary: Color(0xFFF0E7DA),
  bgTertiary: Color(0xFFE3D7C7),
  bgCard: Color(0xFFFFFCF7),
  textPrimary: Color(0xFF211B16),
  textSecondary: Color(0xFF5E584F),
  textMuted: Color(0xFF998D7E),
  accent: Color(0xFF8F6D3E),
  accentHover: Color(0xFFAF8750),
  accentAlt: Color(0xFF2F7D6E),
  accentMuted: Color(0x1F8F6D3E),
  border: Color(0x1F3C3227),
  borderLight: Color(0x333C3227),
  success: Color(0xFF1F8C58),
  warning: Color(0xFFB87322),
  danger: Color(0xFFD25B4D),
  info: Color(0xFF2F7AA8),
);
