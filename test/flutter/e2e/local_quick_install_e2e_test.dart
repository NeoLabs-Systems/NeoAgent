@TestOn('vm')
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:neoagent_flutter/src/local_backend_installer.dart';

void main() {
  test(
    'quick install produces a reachable NeoAgent handshake',
    () async {
      if (Platform.environment['NEOAGENT_E2E_INSTALL'] != '1') {
        markTestSkipped(
          'Set NEOAGENT_E2E_INSTALL=1 to run the live desktop installer.',
        );
        return;
      }

      final logFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}neoagent-e2e-install.log',
      );
      final installer = LocalBackendInstaller();
      addTearDown(installer.dispose);
      installer.events.listen((event) {
        if (event.state == 'progress') return;
        final suffix = event.errorCode == null ? '' : ' (${event.errorCode})';
        final line =
            '[setup] ${event.stage.name} ${event.state} ${event.message}$suffix';
        logFile.writeAsStringSync('$line\n', mode: FileMode.append);
        // ignore: avoid_print
        print(line);
      });

      try {
        final result = await installer.install(LocalBackendSetupProfile.quick);
        expect(result.backendUrl, startsWith('http://'));
        expect(result.instanceId, isNotEmpty);
        expect(result.serverVersion, isNotEmpty);

        final response = await http.get(
          Uri.parse('${result.backendUrl}/api/setup/handshake'),
        );
        expect(response.statusCode, 200);
        final decoded = jsonDecode(response.body);
        expect(decoded, isA<Map<String, dynamic>>());
        final handshake = Map<String, dynamic>.from(decoded as Map);
        expect(handshake['product'], 'NeoAgent');
        expect(handshake['protocolVersion'], 1);
        expect(handshake['instanceId'], result.instanceId);
      } catch (error, stack) {
        logFile.writeAsStringSync(
          'E2E_FAILED $error\n$stack\n',
          mode: FileMode.append,
        );
        rethrow;
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
