import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'local_backend_installer_models.dart';
import 'local_runtime_paths.dart';
import 'setup_contract.g.dart';

typedef LocalSetupEventSink = void Function(LocalBackendInstallEvent event);

LocalBackendInstallStage setupEngineStage(String stage) {
  if (!setupEventStages.contains(stage)) {
    return LocalBackendInstallStage.prepare;
  }
  return switch (stage) {
    'dependencies' || 'install' => LocalBackendInstallStage.install,
    'service' => LocalBackendInstallStage.service,
    'connect' || 'complete' => LocalBackendInstallStage.connect,
    'download' => LocalBackendInstallStage.download,
    'verify' => LocalBackendInstallStage.verify,
    _ => LocalBackendInstallStage.prepare,
  };
}

(LocalBackendInstallEvent, LocalBackendInstallResult?)? parseSetupEngineEvent(
  String line,
) {
  try {
    final decoded = jsonDecode(line);
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != setupContractSchemaVersion) {
      return null;
    }
    final stageName = decoded['stage']?.toString() ?? '';
    if (!setupEventStages.contains(stageName)) return null;
    final state = decoded['state']?.toString() ?? 'message';
    final error = decoded['error'];
    final rawResult = decoded['result'];
    LocalBackendInstallResult? installResult;
    if (state == 'ready' && rawResult is Map) {
      final result = Map<String, dynamic>.from(rawResult);
      final backendUrl = result['backendUrl']?.toString().trim() ?? '';
      final instanceId = result['instanceId']?.toString().trim() ?? '';
      final serverVersion = result['serverVersion']?.toString().trim() ?? '';
      final parsedBackendUrl = Uri.tryParse(backendUrl);
      if (backendUrl.isEmpty ||
          instanceId.isEmpty ||
          serverVersion.isEmpty ||
          parsedBackendUrl == null ||
          !const <String>{'http', 'https'}.contains(parsedBackendUrl.scheme) ||
          parsedBackendUrl.host.isEmpty) {
        return null;
      }
      installResult = LocalBackendInstallResult(
        backendUrl: backendUrl,
        instanceId: instanceId,
        serverVersion: serverVersion,
        claimToken: result['claimToken']?.toString(),
        claimExpiresAt: DateTime.tryParse(
          result['claimExpiresAt']?.toString() ?? '',
        ),
      );
    }
    return (
      LocalBackendInstallEvent(
        stage: setupEngineStage(stageName),
        state: state,
        message: decoded['message']?.toString() ?? 'Preparing NeoAgent',
        progress: (decoded['progress'] as num?)?.toDouble(),
        errorCode: error is Map ? error['code']?.toString() : null,
        retryable: error is! Map || error['retryable'] != false,
      ),
      installResult,
    );
  } on Object {
    return null;
  }
}

class LocalSetupEngine {
  LocalSetupEngine({required LocalSetupEventSink onEvent}) : _onEvent = onEvent;

  final LocalSetupEventSink _onEvent;
  Process? _process;
  bool _cancelled = false;

  Future<LocalBackendInstallResult> run({
    required Directory versionDirectory,
    required LocalRuntimePaths paths,
    required LocalBackendSetupProfile profile,
    required File nodeExecutable,
  }) async {
    _cancelled = false;
    final cli =
        '${versionDirectory.path}${Platform.pathSeparator}app'
        '${Platform.pathSeparator}bin${Platform.pathSeparator}neoagent.js';
    final process = await Process.start(
      nodeExecutable.path,
      <String>[
        cli,
        'install',
        profile == LocalBackendSetupProfile.full ? '--full' : '--quick',
        '--non-interactive',
        if (profile == LocalBackendSetupProfile.full)
          '--defer-optional-sections',
        '--json',
        '--runtime-package',
      ],
      environment: <String, String>{
        ...Platform.environment,
        'NEOAGENT_HOME': paths.runtimeHome,
        'NEOAGENT_SETUP_REQUESTED_PROFILE': profile.name,
      },
      workingDirectory: '${versionDirectory.path}${Platform.pathSeparator}app',
    );
    _process = process;
    final stderrSubscription = process.stderr.listen((_) {});
    LocalBackendInstallResult? result;
    try {
      await for (final line
          in process.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final parsed = parseSetupEngineEvent(line);
        if (parsed == null) continue;
        _onEvent(parsed.$1);
        if (parsed.$2 != null) result = parsed.$2;
      }
      final exitCode = await process.exitCode;
      if (_cancelled) {
        throw const LocalBackendInstallerException(
          'SETUP_CANCELLED',
          'Setup was cancelled.',
        );
      }
      if (exitCode != 0 || result == null) {
        throw const LocalBackendInstallerException(
          'SETUP_ENGINE_FAILED',
          'NeoAgent could not finish the local setup.',
        );
      }
      return result;
    } finally {
      await stderrSubscription.cancel();
      _process = null;
    }
  }

  void cancel() {
    _cancelled = true;
    _process?.kill(ProcessSignal.sigterm);
  }
}
