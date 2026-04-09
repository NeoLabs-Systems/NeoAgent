part of 'main.dart';

const NeoAgentPalette _darkPalette = darkPalette;
const NeoAgentPalette _lightPalette = lightPalette;

NeoAgentPalette get _palette =>
    WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.light
    ? _lightPalette
    : _darkPalette;

Color get _bgPrimary => _palette.bgPrimary;
Color get _bgSecondary => _palette.bgSecondary;
Color get _bgTertiary => _palette.bgTertiary;
Color get _bgCard => _palette.bgCard;
Color get _textPrimary => _palette.textPrimary;
Color get _textSecondary => _palette.textSecondary;
Color get _textMuted => _palette.textMuted;
Color get _accent => _palette.accent;
Color get _accentHover => _palette.accentHover;
Color get _accentAlt => _palette.accentAlt;
Color get _accentMuted => _palette.accentMuted;
Color get _border => _palette.border;
Color get _borderLight => _palette.borderLight;
Color get _success => _palette.success;
Color get _warning => _palette.warning;
Color get _danger => _palette.danger;
Color get _info => _palette.info;

LinearGradient get _appBackgroundGradient => LinearGradient(
  colors: <Color>[_bgPrimary, _bgSecondary.withValues(alpha: 0.96), _bgPrimary],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

LinearGradient get _panelGradient => LinearGradient(
  colors: <Color>[
    _bgCard.withValues(alpha: 0.96),
    _bgSecondary.withValues(alpha: 0.92),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

List<BoxShadow> get _softPanelShadow => <BoxShadow>[
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.16),
    blurRadius: 40,
    offset: const Offset(0, 16),
  ),
  BoxShadow(
    color: _accent.withValues(alpha: 0.05),
    blurRadius: 28,
    offset: const Offset(0, 6),
  ),
];

TextStyle _displayTitleStyle([double size = 28]) => GoogleFonts.spaceGrotesk(
  fontSize: size,
  fontWeight: FontWeight.w700,
  height: 1.05,
  letterSpacing: -0.6,
  color: _textPrimary,
);

TextStyle _sectionEyebrowStyle() => GoogleFonts.spaceGrotesk(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.6,
  color: _accentHover,
);

ThemeData _buildNeoAgentTheme(NeoAgentPalette palette, Brightness brightness) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: palette.bgPrimary,
    colorScheme: base.colorScheme.copyWith(
      primary: palette.accent,
      secondary: palette.accentHover,
      surface: palette.bgCard,
      onSurface: palette.textPrimary,
      error: palette.danger,
    ),
    textTheme: GoogleFonts.manropeTextTheme(
      base.textTheme,
    ).apply(bodyColor: palette.textPrimary, displayColor: palette.textPrimary),
    cardTheme: CardThemeData(
      color: palette.bgCard.withValues(
        alpha: brightness == Brightness.dark ? 0.9 : 0.94,
      ),
      shadowColor: Colors.black.withValues(
        alpha: brightness == Brightness.dark ? 0.24 : 0.08,
      ),
      surfaceTintColor: Colors.transparent,
      elevation: brightness == Brightness.dark ? 8 : 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.borderLight),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.bgSecondary.withValues(
        alpha: brightness == Brightness.dark ? 0.76 : 0.68,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.accent, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(
        color: palette.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      hintStyle: TextStyle(color: palette.textMuted),
    ),
    dividerColor: palette.border,
    iconTheme: IconThemeData(color: palette.textSecondary),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: brightness == Brightness.dark
            ? palette.bgPrimary
            : Colors.white,
        disabledBackgroundColor: palette.bgTertiary,
        disabledForegroundColor: palette.textMuted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.borderLight),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.accentHover,
        textStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.textPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        color: palette.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.bgCard.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.borderLight),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.bgCard,
      contentTextStyle: TextStyle(color: palette.textPrimary),
    ),
  );
}
