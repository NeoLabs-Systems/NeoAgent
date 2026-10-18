import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/app_link.dart';

void main() {
  test('settings links carry the page and the setting to scroll to', () {
    final link = AppLink.tryParse(
      Uri.parse('https://agent.example.com/app/open/settings/security/twoFactor'),
    )!;
    expect(link.section, 'settings');
    expect(link.page, 'security');
    expect(link.focus, 'twoFactor');
  });

  test('a focus written as a fragment is read too', () {
    final link = AppLink.tryParse(
      Uri.parse('https://agent.example.com/app/open/settings/security#twoFactor'),
    )!;
    expect(link.page, 'security');
    expect(link.focus, 'twoFactor');
  });

  test('other sections carry an optional focus', () {
    final integration = AppLink.tryParse(
      Uri.parse('/app/open/integrations/google'),
    )!;
    expect(integration.section, 'integrations');
    expect(integration.page, isNull);
    expect(integration.focus, 'google');

    final tasks = AppLink.tryParse(Uri.parse('/app/open/tasks'))!;
    expect(tasks.section, 'tasks');
    expect(tasks.focus, isNull);
  });

  test('anything else is not an app link', () {
    expect(AppLink.tryParse(Uri.parse('https://example.com/docs')), isNull);
    expect(AppLink.tryParse(Uri.parse('/app/')), isNull);
    expect(AppLink.tryParse(Uri.parse('/app/open')), isNull);
    expect(AppLink.tryParse(Uri.parse('/other/open/settings')), isNull);
  });
}
