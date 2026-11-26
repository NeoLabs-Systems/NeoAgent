import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:neolabs_flutter/installer.dart';

import 'local_backend_installer_models.dart';
import 'local_runtime_app.dart';
import 'local_runtime_paths.dart';
import 'local_setup_engine.dart';

/// Runs the shared NeoLabs runtime installer, then NeoAgent's own setup.
class LocalBackendInstaller {
  LocalBackendInstaller({http.Client? client}) {
    _runtime = NeoRuntimeInstaller(
      app: neoAgentRuntimeApp,
      client: client,
      onEvent: (event) => _add(
        LocalBackendInstallEvent(
          stage: LocalBackendInstallStage.values.byName(event.stage.name),
          state: event.state,
          message: event.message,
          progress: event.progress,
          errorCode: event.errorCode,
          retryable: event.retryable,
        ),
      ),
    );
    _setupEngine = LocalSetupEngine(onEvent: _add);
  }

  late final NeoRuntimeInstaller _runtime;
  late final LocalSetupEngine _setupEngine;
  final StreamController<LocalBackendInstallEvent> _events =
      StreamController<LocalBackendInstallEvent>.broadcast();

  Stream<LocalBackendInstallEvent> get events => _events.stream;

  Future<LocalBackendInstallResult> install(
    LocalBackendSetupProfile profile, {
    required String channel,
  }) async {
    try {
      final paths = LocalRuntimePaths.fromEnvironment(
        Platform.environment,
        isWindows: Platform.isWindows,
      );
      return await _runtime.install(
        channel: channel,
        runtimeHome: Directory(paths.runtimeHome),
        environment: <String, String>{'NEOAGENT_HOME': paths.runtimeHome},
        rollbackArguments: (hasPrevious) => <String>[
          hasPrevious ? 'repair' : 'stop',
          '--runtime-package',
          '--json',
        ],
        configure: (version, executable) => _setupEngine.run(
          versionDirectory: version,
          paths: paths,
          profile: profile,
          executable: executable,
          channel: channel,
        ),
      );
    } on NeoInstallerException catch (error) {
      // A failure of the setup engine arrives wrapped; keep its own code.
      throw LocalBackendInstallerException(
        error.code,
        error.message,
        retryable: error.retryable,
      );
    }
  }

  void _add(LocalBackendInstallEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void cancel() {
    _runtime.cancel();
    _setupEngine.cancel();
  }

  void dispose() {
    cancel();
    _runtime.dispose();
    unawaited(_events.close());
  }
}
