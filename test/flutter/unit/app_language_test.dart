import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/l10n/gen/app_l10n.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the first launch takes its language from the device', () {
    expect(
      AppLanguage.detect(const <Locale>[Locale('de', 'AT')]),
      AppLanguage.german,
    );
    expect(
      AppLanguage.detect(const <Locale>[Locale('en')]),
      AppLanguage.english,
    );
    expect(
      AppLanguage.detect(const <Locale>[Locale('fr'), Locale('de')]),
      AppLanguage.german,
    );
    expect(
      AppLanguage.detect(const <Locale>[Locale('ja')]),
      AppLanguage.english,
    );
    expect(AppLanguage.detect(const <Locale>[]), AppLanguage.english);
  });

  test('an unset or unknown stored code is not mistaken for a choice', () {
    expect(AppLanguage.fromCode(null), isNull);
    expect(AppLanguage.fromCode(''), isNull);
    expect(AppLanguage.fromCode('klingon'), isNull);
    expect(AppLanguage.fromCode('DE'), AppLanguage.german);
  });

  test('the German catalogue is a translation, not a copy of the English', () {
    final english = lookupAppL10n(const Locale('en'));
    final german = lookupAppL10n(const Locale('de'));
    expect(german.accountLanguageTitle, 'Sprache');
    expect(german.cancel, 'Abbrechen');
    expect(german.accountSettings, 'Kontoeinstellungen');
    expect(german.settings, 'Einstellungen');
    expect(german.accountLanguageTitle, isNot(english.accountLanguageTitle));
  });

  testWidgets(
    'the language setting switches the interface and is remembered',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      currentAppLanguage = AppLanguage.english;
      final controller = NeoAgentController(
        backendClient: BackendClient(),
        healthBridge: HealthBridge(),
      );
      addTearDown(controller.dispose);
      addTearDown(() => currentAppLanguage = AppLanguage.english);
      controller.settingsPage = SettingsPage.general;

      await tester.pumpWidget(
        AnimatedBuilder(
          animation: controller,
          builder: (_, _) => MaterialApp(
            locale: controller.language.locale,
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Scaffold(body: SettingsPanel(controller: controller)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      expect(controller.language, AppLanguage.german);
      expect(find.text('Sprache'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(appLanguagePreferenceKey), 'de');
      expect(tester.takeException(), isNull);
    },
  );
}
