import 'dart:convert';
import 'dart:io';

import 'local_backend_installer_models.dart';
import 'local_runtime_paths.dart';
import 'setup_contract.g.dart';

typedef RuntimeActivationEventSink =
    void Function(LocalBackendInstallEvent event);

class RuntimeActivationService {
  RuntimeActivationService({required RuntimeActivationEventSink onEvent})
    : _onEvent = onEvent;

  final RuntimeActivationEventSink _onEvent;

  void validateExtractedRuntime(Directory directory) {
    final nodePath = nodeExecutable(directory);
    final cliPath = File(
      '${directory.path}${Platform.pathSeparator}app'
      '${Platform.pathSeparator}bin${Platform.pathSeparator}neoagent.js',
    );
    if (!nodePath.existsSync() || !cliPath.existsSync()) {
      throw const LocalBackendInstallerException(
        'SETUP_RUNTIME_INCOMPLETE',
        'The verified runtime package is missing required files.',
        retryable: false,
      );
    }
  }

  File nodeExecutable(Directory directory) {
    final path = Platform.isWindows
        ? '${directory.path}${Platform.pathSeparator}node'
              '${Platform.pathSeparator}node.exe'
        : '${directory.path}${Platform.pathSeparator}node'
              '${Platform.pathSeparator}bin${Platform.pathSeparator}node';
    return File(path);
  }

  Future<String?> activate(Directory runtimeRoot, String version) async {
    final previousVersion = readCurrentVersion(runtimeRoot);
    await _writeCurrentVersion(runtimeRoot, version);
    return previousVersion;
  }

  String? readCurrentVersion(Directory runtimeRoot) {
    try {
      final decoded = jsonDecode(
        _currentMarker(runtimeRoot).readAsStringSync(),
      );
      if (decoded is! Map) return null;
      final version = decoded['version']?.toString().trim() ?? '';
      return RegExp(r'^[0-9A-Za-z.+_-]+$').hasMatch(version) ? version : null;
    } on Object {
      return null;
    }
  }

  Future<void> rollback({
    required Directory runtimeRoot,
    required LocalRuntimePaths paths,
    required String failedVersion,
    required String? previousVersion,
  }) async {
    _emit('rollback', 'Restoring the previous NeoAgent runtime');
    final current = _currentMarker(runtimeRoot);
    if (previousVersion == null) {
      try {
        current.deleteSync();
      } on Object {
        // The failed setup error remains the primary actionable failure.
      }
    } else {
      await _writeCurrentVersion(runtimeRoot, previousVersion);
    }

    final rollbackVersion = previousVersion ?? failedVersion;
    final rollbackDirectory = Directory(
      '${runtimeRoot.path}${Platform.pathSeparator}app'
      '${Platform.pathSeparator}versions'
      '${Platform.pathSeparator}$rollbackVersion',
    );
    try {
      final cli =
          '${rollbackDirectory.path}${Platform.pathSeparator}app'
          '${Platform.pathSeparator}bin${Platform.pathSeparator}neoagent.js';
      await Process.run(
        nodeExecutable(rollbackDirectory).path,
        <String>[
          cli,
          previousVersion == null ? 'stop' : 'repair',
          '--runtime-package',
          '--json',
        ],
        environment: <String, String>{
          ...Platform.environment,
          'NEOAGENT_HOME': paths.runtimeHome,
        },
        workingDirectory:
            '${rollbackDirectory.path}${Platform.pathSeparator}app',
      ).timeout(const Duration(seconds: 45));
    } on Object {
      _emit(
        'message',
        'Automatic rollback needs a retry from the setup screen.',
        errorCode: 'SETUP_ROLLBACK_INCOMPLETE',
      );
    }
  }

  File _currentMarker(Directory runtimeRoot) {
    return File(
      '${runtimeRoot.path}${Platform.pathSeparator}app'
      '${Platform.pathSeparator}current.json',
    );
  }

  Future<void> _writeCurrentVersion(
    Directory runtimeRoot,
    String version,
  ) async {
    final appDirectory = Directory(
      '${runtimeRoot.path}${Platform.pathSeparator}app',
    );
    appDirectory.createSync(recursive: true);
    final current = _currentMarker(runtimeRoot);
    final uniqueSuffix =
        '${pid}_${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final temporary = File('${current.path}.$uniqueSuffix.tmp');
    final backup = File('${current.path}.$uniqueSuffix.backup');
    await temporary.writeAsString(
      '${jsonEncode(<String, dynamic>{'schemaVersion': setupContractSchemaVersion, 'version': version, 'activatedAt': DateTime.now().toUtc().toIso8601String()})}\n',
      flush: true,
    );
    try {
      try {
        await temporary.rename(current.path);
      } on FileSystemException {
        if (!await current.exists()) rethrow;
        await current.rename(backup.path);
        try {
          await temporary.rename(current.path);
          try {
            await backup.delete();
          } on FileSystemException {
            // Activation succeeded; a stale backup is safe to remove later.
          }
        } on Object {
          if (!await current.exists() && await backup.exists()) {
            await backup.rename(current.path);
          }
          rethrow;
        }
      }
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  void _emit(String state, String message, {String? errorCode}) {
    _onEvent(
      LocalBackendInstallEvent(
        stage: LocalBackendInstallStage.install,
        state: state,
        message: message,
        errorCode: errorCode,
      ),
    );
  }
}
