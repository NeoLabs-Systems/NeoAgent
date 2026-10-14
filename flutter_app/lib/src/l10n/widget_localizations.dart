import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_language.dart';

/// Keep app translations available when Flutter lacks a widget catalogue.
/// Only those SDK controls fall back to the app's default language.
const appLocalizationsDelegates = <LocalizationsDelegate<Object>>[
  AppL10n.delegate,
  _WidgetLocalizationsDelegate<MaterialLocalizations>(
    GlobalMaterialLocalizations.delegate,
  ),
  _WidgetLocalizationsDelegate<CupertinoLocalizations>(
    GlobalCupertinoLocalizations.delegate,
  ),
  _WidgetLocalizationsDelegate<WidgetsLocalizations>(
    GlobalWidgetsLocalizations.delegate,
  ),
];

class _WidgetLocalizationsDelegate<T> extends LocalizationsDelegate<T> {
  const _WidgetLocalizationsDelegate(this.delegate);

  final LocalizationsDelegate<T> delegate;

  @override
  bool isSupported(Locale locale) =>
      AppLanguage.fromCode(locale.languageCode) != null;

  @override
  Future<T> load(Locale locale) => delegate.load(
    delegate.isSupported(locale) ? locale : AppLanguage.fallback.locale,
  );

  @override
  bool shouldReload(_WidgetLocalizationsDelegate<T> old) => false;
}
