import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/local_backend_installer.dart';
import 'package:neoagent_flutter/src/setup_diagnostics_service.dart';

void main() {
  test('setup diagnostics redact server addresses and personal paths', () {
    final report = buildSetupDiagnosticReport(
      profile: LocalBackendSetupProfile.quick,
      events: const <LocalBackendInstallEvent>[
        LocalBackendInstallEvent(
          stage: LocalBackendInstallStage.install,
          state: 'failed',
          message:
              'Failed at https://host.example/setup in /Users/neo/.neoagent',
          errorCode: 'SETUP_FAILED',
        ),
      ],
      createdAt: DateTime.utc(2026, 7, 28),
      environment: const <String, String>{'HOME': '/Users/neo'},
    );

    final event = (report['events'] as List<Object?>).single;
    expect(event, isA<Map<String, dynamic>>());
    final message = (event as Map<String, dynamic>)['message'];
    expect(message, contains('[server-address]'));
    expect(message, contains('[user-path]'));
    expect(message, isNot(contains('host.example')));
    expect(message, isNot(contains('/Users/neo')));
  });
}
