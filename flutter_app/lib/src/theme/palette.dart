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
  bgPrimary: Color(0xFF061015),
  bgSecondary: Color(0xFF0B1820),
  bgTertiary: Color(0xFF112733),
  bgCard: Color(0xFF142430),
  textPrimary: Color(0xFFF5EFE4),
  textSecondary: Color(0xFFD2D7DC),
  textMuted: Color(0xFF95A0A8),
  accent: Color(0xFFFFC857),
  accentHover: Color(0xFFFFE29A),
  accentAlt: Color(0xFF30D5C8),
  accentMuted: Color(0x2EFFC857),
  border: Color(0x30576875),
  borderLight: Color(0x4A7B8D99),
  success: Color(0xFF37B67E),
  warning: Color(0xFFD49A43),
  danger: Color(0xFFE26E61),
  info: Color(0xFF74A8D9),
);

const NeoAgentPalette lightPalette = NeoAgentPalette(
  bgPrimary: Color(0xFFF4F0E9),
  bgSecondary: Color(0xFFEDE5D9),
  bgTertiary: Color(0xFFDDD4C5),
  bgCard: Color(0xFFFFFEFC),
  textPrimary: Color(0xFF16181D),
  textSecondary: Color(0xFF444A55),
  textMuted: Color(0xFF727987),
  accent: Color(0xFFB47716),
  accentHover: Color(0xFFD69324),
  accentAlt: Color(0xFF128B86),
  accentMuted: Color(0x24B47716),
  border: Color(0x223F4652),
  borderLight: Color(0x3847505D),
  success: Color(0xFF1F8C58),
  warning: Color(0xFFB87322),
  danger: Color(0xFFD25B4D),
  info: Color(0xFF2F7AA8),
);
