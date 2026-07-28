import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  test('integration status labels hide internal environment terminology', () {
    final integration = OfficialIntegrationItem.fromJson(<String, dynamic>{
      'id': 'google_workspace',
      'label': 'Google Workspace',
      'description': 'Google apps',
      'connection': <String, dynamic>{
        'status': 'env_not_configured',
        'connected': false,
      },
      'apps': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'gmail',
          'label': 'Gmail',
          'connection': <String, dynamic>{
            'status': 'env_not_configured',
            'connected': false,
          },
        },
      ],
      'env': <String, dynamic>{
        'configured': false,
        'missing': <String>[],
        'summary': 'Google Workspace still needs setup.',
      },
    });

    expect(integration.statusLabel, 'Setup Required');
    expect(integration.apps.single.statusLabel, 'Setup Required');
  });

  test(
    'connected accounts expose connection-test capability from the backend',
    () {
      final account = OfficialIntegrationAccountItem.fromJson(<String, dynamic>{
        'id': 7,
        'status': 'connected',
        'connected': true,
        'accountEmail': 'person@example.test',
        'supportsConnectionTest': true,
      });

      expect(account.connected, true);
      expect(account.supportsConnectionTest, true);
    },
  );
}
