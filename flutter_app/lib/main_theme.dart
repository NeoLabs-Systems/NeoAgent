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
const Color _brandAccent = Color(0xFF8F6D3E);
const Color _brandAccentAlt = Color(0xFF2F7D6E);
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
  colors: <Color>[
    _bgPrimary,
    Color.lerp(_bgSecondary, _accentAlt, 0.08)!.withValues(alpha: 0.98),
    Color.lerp(_bgPrimary, _accent, 0.05)!,
  ],
  stops: const <double>[0, 0.52, 1],
  begin: const Alignment(-0.95, -1),
  end: const Alignment(1, 0.92),
);

LinearGradient get _panelGradient => LinearGradient(
  colors: <Color>[
    Colors.white.withValues(alpha: 0.08),
    _bgCard.withValues(alpha: 0.9),
    _bgSecondary.withValues(alpha: 0.82),
  ],
  stops: const <double>[0, 0.18, 1],
  begin: const Alignment(-0.85, -1),
  end: const Alignment(1, 1),
);

List<BoxShadow> get _softPanelShadow => <BoxShadow>[
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.22),
    blurRadius: 52,
    offset: const Offset(0, 22),
  ),
  BoxShadow(
    color: _accent.withValues(alpha: 0.08),
    blurRadius: 30,
    offset: const Offset(0, 8),
  ),
];

Color get _glassFill =>
    _bgCard.withValues(alpha: _palette == _darkPalette ? 0.78 : 0.88);
Color get _glassOverlay =>
    Colors.white.withValues(alpha: _palette == _darkPalette ? 0.04 : 0.12);
Color get _glassBorder =>
    Colors.white.withValues(alpha: _palette == _darkPalette ? 0.12 : 0.26);
Color get _glassHighlight =>
    Colors.white.withValues(alpha: _palette == _darkPalette ? 0.1 : 0.18);

LinearGradient get _liquidMetalGradient => LinearGradient(
  colors: <Color>[
    _glassOverlay,
    Colors.white.withValues(alpha: 0.02),
    _accentMuted.withValues(alpha: 0.16),
  ],
  stops: const <double>[0, 0.44, 1],
  begin: const Alignment(-1, -1),
  end: const Alignment(1, 1),
);

TextStyle _displayTitleStyle([double size = 28]) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w700,
  height: 1.08,
  letterSpacing: -0.8,
  color: _textPrimary,
);

/// Heavy hero text — use for prominent numeric/stat displays, empty-state
/// headlines, and splash copy where w700 reads too light.
TextStyle _heroTitleStyle([double size = 24]) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w800,
  height: 1.1,
  letterSpacing: -1.0,
  color: _textPrimary,
);

TextStyle _sectionEyebrowStyle() => TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.0,
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
    focusColor: palette.accent.withValues(alpha: 0.2),
    scaffoldBackgroundColor: palette.bgPrimary,
    colorScheme: base.colorScheme.copyWith(
      primary: palette.accent,
      secondary: palette.accentHover,
      surface: palette.bgCard,
      onSurface: palette.textPrimary,
      error: palette.danger,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    ),
    cardTheme: CardThemeData(
      color: palette.bgCard.withValues(
        alpha: brightness == Brightness.dark ? 0.86 : 0.96,
      ),
      shadowColor: Colors.black.withValues(
        alpha: brightness == Brightness.dark ? 0.24 : 0.12,
      ),
      surfaceTintColor: Colors.transparent,
      elevation: brightness == Brightness.dark ? 8 : 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: Colors.white.withValues(
            alpha: brightness == Brightness.dark ? 0.08 : 0.22,
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.bgSecondary.withValues(
        alpha: brightness == Brightness.dark ? 0.82 : 0.84,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.accentHover, width: 1.4),
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
        shadowColor: palette.accent.withValues(alpha: 0.3),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: Colors.white.withValues(
              alpha: brightness == Brightness.dark ? 0.14 : 0.26,
            ),
          ),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(
          color: Colors.white.withValues(
            alpha: brightness == Brightness.dark ? 0.12 : 0.26,
          ),
        ),
        backgroundColor: palette.bgCard.withValues(
          alpha: brightness == Brightness.dark ? 0.2 : 0.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: _NeoAgentCupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: _NeoAgentCupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.accentHover,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.05,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.textPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: palette.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
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

class _NeoAgentCupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NeoAgentCupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration =>
      cupertino.CupertinoRouteTransitionMixin.kTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      cupertino.CupertinoPageTransition.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return cupertino.CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
