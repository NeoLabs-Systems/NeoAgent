import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/local_backend_installer.dart';
import 'package:neoagent_flutter/src/local_runtime_app.dart';
import 'package:neoagent_flutter/src/local_runtime_manager.dart';
import 'package:neoagent_flutter/src/local_runtime_paths.dart';
import 'package:neoagent_flutter/src/local_setup_engine.dart';
import 'package:neoagent_flutter/src/setup_contract.g.dart';

// Download, signature, archive and activation safety are tested with the shared
// installer in neolabs_flutter; this covers what is NeoAgent's.
void main() {
  test('the shared installer is given NeoAgent release settings', () {
    expect(neoAgentRuntimeApp.manifestPrefix, 'neoagent-runtime-manifest-');
    expect(neoAgentRuntimeApp.publicKey, embeddedRuntimeSigningPublicKey);
    expect(neoAgentRuntimeApp.targets, setupRuntimeTargets);
    expect(neoAgentRuntimeApp.schemaVersion, setupContractSchemaVersion);
  });

  test('setup engine parser accepts only versioned complete events', () {
    final parsed = parseSetupEngineEvent(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'runId': 'setup-run',
        'profile': 'quick',
        'stage': 'complete',
        'state': 'ready',
        'message': 'NeoAgent is ready',
        'result': <String, dynamic>{
          'backendUrl': 'http://localhost:4444',
          'instanceId': 'instance-id',
          'serverVersion': '3.4.0',
        },
      }),
    );
    expect(parsed, isNotNull);
    expect(parsed!.$1.stage, LocalBackendInstallStage.connect);
    expect(parsed.$2?.backendUrl, 'http://localhost:4444');
    expect(
      parseSetupEngineEvent(
        jsonEncode(<String, dynamic>{
          'schemaVersion': 2,
          'stage': 'complete',
          'state': 'ready',
        }),
      ),
      isNull,
    );
  });

  test('setup engine parser surfaces failed event details', () {
    final parsed = parseSetupEngineEvent(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'runId': 'setup-run',
        'profile': 'quick',
        'stage': 'service',
        'state': 'failed',
        'error': <String, dynamic>{
          'code': 'SETUP_SERVER_NOT_READY',
          'retryable': true,
          'detail': 'NeoAgent did not become reachable on port 3333.',
        },
      }),
    );
    expect(parsed, isNotNull);
    expect(parsed!.$1.state, 'failed');
    expect(parsed.$1.errorCode, 'SETUP_SERVER_NOT_READY');
    expect(
      parsed.$1.message,
      'NeoAgent did not become reachable on port 3333.',
    );
  });

  test('setup engine fallback message keeps the last stderr detail', () {
    expect(
      setupEngineFallbackMessage(''),
      'NeoAgent could not finish the local setup.',
    );
    expect(
      setupEngineFallbackMessage('better-sqlite3 failed to load'),
      'NeoAgent could not finish the local setup. better-sqlite3 failed to load',
    );
  });

  test(
    'runtime manager reports a missing local runtime without prerequisites',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'neoagent-runtime-manager-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final paths = LocalRuntimePaths.fromEnvironment(<String, String>{
        if (Platform.isWindows) 'USERPROFILE': directory.path,
        if (!Platform.isWindows) 'HOME': directory.path,
        'NEOAGENT_HOME': '${directory.path}${Platform.pathSeparator}runtime',
      }, isWindows: Platform.isWindows);
      final manager = LocalRuntimeManager(paths: paths);

      final status = await manager.inspect();
      expect(status.installed, false);
      expect(status.running, false);
      expect(status.errorCode, isNull);
    },
  );
}
