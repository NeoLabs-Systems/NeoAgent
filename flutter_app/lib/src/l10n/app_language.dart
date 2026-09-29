import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/gen/app_l10n.dart';

export '../../l10n/gen/app_l10n.dart';

/// A language NeoAgent can present itself in.
///
/// [code] is what the account stores. The label is the language's own name,
/// which is what a picker must show: a German speaker is looking for "Deutsch".
enum AppLanguage {
  english('en', 'English'),
  german('de', 'Deutsch');

  const AppLanguage(this.code, this.label);

  /// The IETF/ISO 639-1 code exchanged with the account.
  final String code;

  /// The language's own name for itself.
  final String label;

  Locale get locale => Locale(code);

  /// The default when nothing has been chosen and nothing can be detected.
  static const AppLanguage fallback = AppLanguage.english;

  /// The language for a stored or account-supplied code.
  ///
  /// Returns null rather than a fallback so that callers can tell "not set"
  /// from "set to English" — first-login detection depends on that difference.
  static AppLanguage? fromCode(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final language in AppLanguage.values) {
      if (language.code == normalized) return language;
    }
    return null;
  }

  /// The language to start a fresh installation in.
  ///
  /// Matched on the primary subtag only, so de-AT and de-CH are German like
  /// de-DE is, and every locale this build does not speak lands on English.
  static AppLanguage detect(List<Locale> systemLocales) {
    for (final locale in systemLocales) {
      final match = fromCode(locale.languageCode);
      if (match != null) return match;
    }
    return fallback;
  }
}

/// Preference key for the language chosen on this device.
const String appLanguagePreferenceKey = 'appLanguage';

/// The language the app is currently in, for code that runs away from any
/// widget tree.
///
/// Screens read translations from here as well: the controller keeps this in
/// step with the chosen language and rebuilds the tree when it changes.
AppLanguage currentAppLanguage = AppLanguage.fallback;

/// The translations for [currentAppLanguage].
AppL10n get appStrings => lookupAppL10n(currentAppLanguage.locale);

/// Reads the stored language, or picks one from the device the first time.
///
/// Detection happens exactly once and is then written down, so a person who
/// later chooses English on a German phone still gets English after a restart.
Future<void> ensureAppLanguageLoaded() async {
  final preferences = await SharedPreferences.getInstance();
  final stored = AppLanguage.fromCode(
    preferences.getString(appLanguagePreferenceKey),
  );
  if (stored != null) {
    currentAppLanguage = stored;
    return;
  }
  final locales = PlatformDispatcher.instance.locales;
  currentAppLanguage = AppLanguage.detect(
    locales.isEmpty ? <Locale>[PlatformDispatcher.instance.locale] : locales,
  );
  await preferences.setString(
    appLanguagePreferenceKey,
    currentAppLanguage.code,
  );
}
